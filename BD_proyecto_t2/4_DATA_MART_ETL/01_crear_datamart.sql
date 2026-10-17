/*
Arte y Publicidad E&D - T2 - C7
01. Crear Data Mart dimensional (enfoque Kimball / esquema estrella)
Fuente: BD_ArtePublicidadED (NO se modifica)
Destino: DW_ArtePublicidadED
SEGURIDAD: este script no borra ni vacia tablas existentes.
SQL Server 2017 o superior.
*/
USE master;
GO
IF DB_ID(N'BD_ArtePublicidadED') IS NULL
    THROW 52101, N'Falta BD_ArtePublicidadED. No se ha creado el Data Mart.', 1;
IF DB_ID(N'DW_ArtePublicidadED') IS NULL
    EXEC(N'CREATE DATABASE DW_ArtePublicidadED');
GO
USE DW_ArtePublicidadED;
GO
SET NOCOUNT ON;
GO
IF SCHEMA_ID(N'stg') IS NULL EXEC(N'CREATE SCHEMA stg');
IF SCHEMA_ID(N'etl') IS NULL EXEC(N'CREATE SCHEMA etl');
GO

/* DIMENSIONES: claves sustitutas y claves naturales unicas */
IF OBJECT_ID(N'dbo.DimFecha', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimFecha (
        FechaKey INT NOT NULL CONSTRAINT PK_DimFecha PRIMARY KEY,
        FechaCompleta DATE NOT NULL CONSTRAINT UQ_DimFecha_Fecha UNIQUE,
        Dia TINYINT NOT NULL,
        Mes TINYINT NOT NULL,
        Trimestre TINYINT NOT NULL,
        Anio SMALLINT NOT NULL
    );
END;
GO
IF OBJECT_ID(N'dbo.DimCliente', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimCliente (
        ClienteKey INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimCliente PRIMARY KEY,
        ClienteID INT NOT NULL CONSTRAINT UQ_DimCliente_Natural UNIQUE,
        NombreCliente NVARCHAR(120) NOT NULL,
        TipoCliente VARCHAR(15) NOT NULL
    );
END;
GO
IF OBJECT_ID(N'dbo.DimServicio', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimServicio (
        ServicioKey INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimServicio PRIMARY KEY,
        ServicioID INT NOT NULL CONSTRAINT UQ_DimServicio_Natural UNIQUE,
        NombreServicio NVARCHAR(100) NOT NULL,
        CategoriaID INT NOT NULL,
        NombreCategoria NVARCHAR(70) NOT NULL
    );
END;
GO
IF OBJECT_ID(N'dbo.DimEmpleado', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimEmpleado (
        EmpleadoKey INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimEmpleado PRIMARY KEY,
        EmpleadoID INT NOT NULL CONSTRAINT UQ_DimEmpleado_Natural UNIQUE,
        NombreEmpleado NVARCHAR(100) NOT NULL,
        Cargo NVARCHAR(60) NOT NULL
    );
END;
GO
IF OBJECT_ID(N'dbo.DimEstadoPedido', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimEstadoPedido (
        EstadoKey TINYINT NOT NULL CONSTRAINT PK_DimEstadoPedido PRIMARY KEY,
        Estado VARCHAR(16) NOT NULL CONSTRAINT UQ_DimEstadoPedido_Estado UNIQUE,
        GrupoEstado VARCHAR(16) NOT NULL
    );
END;
GO
-- Miembros fijos de dimension estado; no altera hechos existentes.
INSERT INTO dbo.DimEstadoPedido (EstadoKey, Estado, GrupoEstado)
SELECT v.EstadoKey, v.Estado, v.GrupoEstado
FROM (VALUES
    (CONVERT(TINYINT,1),'REGISTRADO','ABIERTO'),
    (CONVERT(TINYINT,2),'EN_PRODUCCION','ABIERTO'),
    (CONVERT(TINYINT,3),'ENTREGADO','CERRADO'),
    (CONVERT(TINYINT,4),'CANCELADO','NO_EJECUTADO')
) AS v(EstadoKey,Estado,GrupoEstado)
WHERE NOT EXISTS (SELECT 1 FROM dbo.DimEstadoPedido AS e WHERE e.EstadoKey=v.EstadoKey);
GO

/* TABLA DE HECHOS: una fila = un DetallePedidoID de un pedido.
   ImporteNeto es aditivo; descuentos y brutos pertenecen a la LINEA.
   No se une Pagos para no multiplicar los importes de las lineas. */
IF OBJECT_ID(N'dbo.FactVentas', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.FactVentas (
        VentaKey BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_FactVentas PRIMARY KEY,
        PedidoID INT NOT NULL,
        DetallePedidoID BIGINT NOT NULL CONSTRAINT UQ_FactVentas_Detalle UNIQUE,
        FechaKey INT NOT NULL,
        ClienteKey INT NOT NULL,
        ServicioKey INT NOT NULL,
        EmpleadoKey INT NOT NULL,
        EstadoKey TINYINT NOT NULL,
        Cantidad INT NOT NULL,
        PrecioUnitario DECIMAL(14,2) NOT NULL,
        DescuentoPct DECIMAL(5,4) NOT NULL,
        ImporteBruto DECIMAL(28,6) NOT NULL,
        ImporteDescuento DECIMAL(28,6) NOT NULL,
        ImporteNeto DECIMAL(28,6) NOT NULL,
        CONSTRAINT FK_FactVentas_Fecha FOREIGN KEY(FechaKey) REFERENCES dbo.DimFecha(FechaKey),
        CONSTRAINT FK_FactVentas_Cliente FOREIGN KEY(ClienteKey) REFERENCES dbo.DimCliente(ClienteKey),
        CONSTRAINT FK_FactVentas_Servicio FOREIGN KEY(ServicioKey) REFERENCES dbo.DimServicio(ServicioKey),
        CONSTRAINT FK_FactVentas_Empleado FOREIGN KEY(EmpleadoKey) REFERENCES dbo.DimEmpleado(EmpleadoKey),
        CONSTRAINT FK_FactVentas_Estado FOREIGN KEY(EstadoKey) REFERENCES dbo.DimEstadoPedido(EstadoKey),
        CONSTRAINT CK_FactVentas_Cantidad CHECK (Cantidad > 0)
    );
END;
GO

/* STAGING: conserva filas extraidas durante el lote vigente. */
IF OBJECT_ID(N'stg.LineasPedido', N'U') IS NULL
BEGIN
    CREATE TABLE stg.LineasPedido (
        StagingID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_stg_LineasPedido PRIMARY KEY,
        CargaID BIGINT NOT NULL,
        PedidoID INT NULL,
        DetallePedidoID BIGINT NULL,
        FechaPedido DATE NULL,
        ClienteID INT NULL,
        NombreCliente NVARCHAR(120) NULL,
        TipoCliente VARCHAR(15) NULL,
        ServicioID INT NULL,
        NombreServicio NVARCHAR(100) NULL,
        CategoriaID INT NULL,
        NombreCategoria NVARCHAR(70) NULL,
        EmpleadoID INT NULL,
        NombreEmpleado NVARCHAR(100) NULL,
        Cargo NVARCHAR(60) NULL,
        Estado VARCHAR(16) NULL,
        Cantidad INT NULL,
        PrecioUnitario DECIMAL(14,2) NULL,
        DescuentoPct DECIMAL(5,4) NULL,
        ImporteBruto DECIMAL(28,6) NULL,
        ImporteDescuento DECIMAL(28,6) NULL,
        ImporteNeto DECIMAL(28,6) NULL
    );
END;
GO

/* AUDITORIA: cada ejecucion deja lote, tiempos, importes y estado. */
IF OBJECT_ID(N'etl.AuditoriaCarga', N'U') IS NULL
BEGIN
    CREATE TABLE etl.AuditoriaCarga (
        CargaID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_etl_AuditoriaCarga PRIMARY KEY,
        FechaInicio DATETIME2(0) NOT NULL CONSTRAINT DF_Carga_Inicio DEFAULT (SYSDATETIME()),
        FechaFin DATETIME2(0) NULL,
        Estado VARCHAR(12) NOT NULL,
        FilasLeidas BIGINT NOT NULL CONSTRAINT DF_Carga_Leidas DEFAULT (0),
        FilasCargadas BIGINT NOT NULL CONSTRAINT DF_Carga_Cargadas DEFAULT (0),
        FilasRechazadas BIGINT NOT NULL CONSTRAINT DF_Carga_Rechazos DEFAULT (0),
        MontoOrigen DECIMAL(19,2) NULL,
        MontoDestino DECIMAL(19,2) NULL,
        DiferenciaMonto DECIMAL(19,2) NULL,
        Mensaje NVARCHAR(2000) NULL
    );
END;
GO
IF OBJECT_ID(N'etl.RechazosCarga', N'U') IS NULL
BEGIN
    CREATE TABLE etl.RechazosCarga (
        RechazoID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_etl_RechazosCarga PRIMARY KEY,
        CargaID BIGINT NOT NULL,
        StagingID BIGINT NOT NULL,
        DetallePedidoID BIGINT NULL,
        Motivo NVARCHAR(250) NOT NULL,
        CONSTRAINT FK_Rechazos_Auditoria FOREIGN KEY(CargaID)
            REFERENCES etl.AuditoriaCarga(CargaID)
    );
END;
GO

SELECT N'DW preparado; sin eliminar datos existentes' AS Resultado,
       DB_NAME() AS BaseDestino,
       (SELECT COUNT(*) FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id
        WHERE s.name IN ('dbo','etl','stg')) AS TotalTablas;
GO
