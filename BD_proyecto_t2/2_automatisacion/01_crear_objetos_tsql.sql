/*
Arte y Publicidad E&D | T2 | Criterio C4 y soporte C5
Archivo 01: objetos de automatizacion.
Requisitos previos: BD_ArtePublicidadED creada y poblada (etapa 1).
SEGURO: no elimina tablas ni registros ni modifica pedidos historicos.
Crea 1 tabla de auditoria, 1 vista, 1 funcion, 1 trigger y 1 procedimiento.
*/
USE BD_ArtePublicidadED;
GO
SET NOCOUNT ON;
GO

-- 1) AUDITORIA: registra transiciones de estado reales en pedidos.
IF OBJECT_ID(N'dbo.AuditoriaEstadoPedidos', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.AuditoriaEstadoPedidos
    (
        AuditoriaID BIGINT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_AuditoriaEstadoPedidos PRIMARY KEY,
        PedidoID INT NOT NULL,
        EstadoAnterior VARCHAR(16) NOT NULL,
        EstadoNuevo VARCHAR(16) NOT NULL,
        FechaCambioUTC DATETIME2(0) NOT NULL
            CONSTRAINT DF_Auditoria_Fecha DEFAULT (SYSUTCDATETIME()),
        UsuarioSQL SYSNAME NOT NULL
            CONSTRAINT DF_Auditoria_Usuario DEFAULT (ORIGINAL_LOGIN()),
        CONSTRAINT FK_Auditoria_Pedido
            FOREIGN KEY (PedidoID) REFERENCES dbo.Pedidos(PedidoID)
    );
END;
GO

-- 2) FUNCION: calcula importe neto de UNA linea. Es util para validar
-- operaciones puntuales; no se recomienda ejecutarla fila a fila en un reporte masivo.
CREATE OR ALTER FUNCTION dbo.fn_MontoNetoLinea
(
    @Cantidad INT,
    @PrecioUnitario DECIMAL(14,2),
    @DescuentoPct DECIMAL(5,4)
)
RETURNS DECIMAL(19,2)
AS
BEGIN
    IF @Cantidad IS NULL OR @PrecioUnitario IS NULL OR @DescuentoPct IS NULL
       OR @Cantidad <= 0 OR @PrecioUnitario < 0 OR @DescuentoPct < 0 OR @DescuentoPct > 1
        RETURN NULL;

    RETURN CONVERT(DECIMAL(19,2),
                   ROUND(@Cantidad * @PrecioUnitario * (1 - @DescuentoPct), 2));
END;
GO

-- 3) VISTA: 1 fila por pedido (no une pagos, para no multiplicar lineas).
-- Util para supervision diaria, NO sustituye el futuro Data Mart.
CREATE OR ALTER VIEW dbo.vw_ResumenPedidos
AS
SELECT
    p.PedidoID, p.CodigoPedido, p.FechaPedido, p.Estado,
    p.ClienteID, c.NombreCliente,
    p.EmpleadoID, e.NombreEmpleado,
    CASE
        WHEN p.Estado = 'ENTREGADO' THEN 'CERRADO'
        WHEN p.Estado = 'CANCELADO' THEN 'NO_EJECUTADO'
        ELSE 'ABIERTO'
    END AS GrupoEstado,
    COALESCE(d.TotalLineas, CONVERT(BIGINT,0)) AS TotalLineas,
    COALESCE(d.TotalUnidades, CONVERT(BIGINT,0)) AS TotalUnidades,
    COALESCE(d.MontoPedido, CONVERT(DECIMAL(19,2),0)) AS MontoPedido
FROM dbo.Pedidos AS p
INNER JOIN dbo.Clientes AS c ON c.ClienteID = p.ClienteID
INNER JOIN dbo.Empleados AS e ON e.EmpleadoID = p.EmpleadoID
LEFT JOIN
(
    SELECT dp.PedidoID,
           COUNT_BIG(*) AS TotalLineas,
           SUM(CONVERT(BIGINT,dp.Cantidad)) AS TotalUnidades,
           CONVERT(DECIMAL(19,2),
               ROUND(SUM(dp.Cantidad * dp.PrecioUnitario * (1 - dp.DescuentoPct)),2))
                AS MontoPedido
    FROM dbo.DetallePedido AS dp
    GROUP BY dp.PedidoID
) AS d ON d.PedidoID = p.PedidoID;
GO

-- 4) TRIGGER: audita ACTUALIZACIONES reales de Estado.
-- Opera por conjuntos: una actualizacion de 100 pedidos genera 100 registros.
-- Ignora updates que no cambian el estado.
CREATE OR ALTER TRIGGER dbo.trg_Pedidos_AuditarEstado
ON dbo.Pedidos
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(Estado) RETURN;

    INSERT INTO dbo.AuditoriaEstadoPedidos
        (PedidoID, EstadoAnterior, EstadoNuevo)
    SELECT i.PedidoID, d.Estado, i.Estado
    FROM inserted AS i
    INNER JOIN deleted AS d ON d.PedidoID = i.PedidoID
    WHERE i.Estado <> d.Estado;
END;
GO

-- 5) PROCEDIMIENTO PARAMETRIZADO: crea pedido y detalle en una transaccion.
-- Prefijo PRB- obligatorio: evita confundir registros de prueba con pedidos originales.
-- @ForzarError solo sirve para demostrar ROLLBACK en el laboratorio.
CREATE OR ALTER PROCEDURE dbo.usp_RegistrarPedidoPrueba
    @CodigoPedido VARCHAR(20),
    @ClienteID INT,
    @EmpleadoID INT,
    @ServicioID INT,
    @Cantidad INT,
    @DescuentoPct DECIMAL(5,4) = 0,
    @ForzarError BIT = 0,
    @PedidoID INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @PedidoID = NULL;

    BEGIN TRY
        -- Estas verificaciones no modifican los datos.
        IF @CodigoPedido IS NULL OR @CodigoPedido NOT LIKE 'PRB-%'
            THROW 51001, N'El codigo de prueba debe comenzar con PRB-.', 1;
        IF @Cantidad IS NULL OR @Cantidad <= 0
            THROW 51002, N'La cantidad debe ser mayor que cero.', 1;
        IF @DescuentoPct IS NULL OR @DescuentoPct NOT BETWEEN 0 AND 1
            THROW 51003, N'Descuento fuera del rango [0,1].', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.Clientes WHERE ClienteID = @ClienteID)
            THROW 51004, N'No existe el cliente.', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.Empleados WHERE EmpleadoID = @EmpleadoID AND Activo = 1)
            THROW 51005, N'El empleado no existe o esta inactivo.', 1;

        DECLARE @Precio DECIMAL(14,2);
        SELECT @Precio = PrecioReferencial
        FROM dbo.Servicios
        WHERE ServicioID = @ServicioID AND Activo = 1;
        IF @Precio IS NULL
            THROW 51006, N'El servicio no existe o esta inactivo.', 1;

        BEGIN TRANSACTION;
            IF EXISTS (SELECT 1 FROM dbo.Pedidos WITH (UPDLOCK, HOLDLOCK)
                       WHERE CodigoPedido = @CodigoPedido)
                THROW 51007, N'Ya existe un pedido con ese codigo.', 1;

            INSERT INTO dbo.Pedidos
                (CodigoPedido, CotizacionID, ClienteID, EmpleadoID, FechaPedido, Estado)
            VALUES
                (@CodigoPedido, NULL, @ClienteID, @EmpleadoID,
                 CONVERT(DATE,GETDATE()), 'REGISTRADO');

            SET @PedidoID = CONVERT(INT,SCOPE_IDENTITY());

            -- Falla provocada DESPUES de escribir cabecera y ANTES de escribir detalle.
            -- En un sistema sin transaccion esta operacion dejaria un pedido incompleto.
            IF @ForzarError = 1
                THROW 51008, N'Error controlado de laboratorio tras insertar la cabecera.', 1;

            INSERT INTO dbo.DetallePedido
                (PedidoID, ServicioID, Cantidad, PrecioUnitario, DescuentoPct)
            VALUES (@PedidoID, @ServicioID, @Cantidad, @Precio, @DescuentoPct);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        SET @PedidoID = NULL;
        THROW;
    END CATCH;
END;
GO

SELECT N'Objetos C4 creados o actualizados' AS Resultado,
       OBJECT_ID('dbo.vw_ResumenPedidos', 'V') AS IdVista,
       OBJECT_ID('dbo.fn_MontoNetoLinea', 'FN') AS IdFuncion,
       OBJECT_ID('dbo.trg_Pedidos_AuditarEstado', 'TR') AS IdTrigger,
       OBJECT_ID('dbo.usp_RegistrarPedidoPrueba', 'P') AS IdProcedimiento,
       OBJECT_ID('dbo.AuditoriaEstadoPedidos', 'U') AS IdTablaAuditoria;
GO
