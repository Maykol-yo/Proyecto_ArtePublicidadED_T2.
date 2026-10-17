/*
Arte y Publicidad E&D - T2 - C8
02. Crea el ETL (no lo ejecuta todavia).
Metodo: Kimball bottom-up, carga FULL REFRESH en transaccion.
SCD tipo 1 en dimensiones (actualiza descripciones sin version historica).
Requiere ejecutar previamente 01_crear_datamart.sql.
SQL Server 2017+.
*/
USE DW_ArtePublicidadED;
GO
CREATE OR ALTER PROCEDURE etl.usp_CargarDataMart
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @CargaID BIGINT,
            @FilasFuente BIGINT=0, @Leidas BIGINT=0, @Cargadas BIGINT=0, @Rechazadas BIGINT=0,
            @MontoOrigen DECIMAL(19,2)=0, @MontoDestino DECIMAL(19,2)=0,
            @Mensaje NVARCHAR(2000);

    IF DB_ID(N'BD_ArtePublicidadED') IS NULL
        THROW 52110, N'No existe la fuente BD_ArtePublicidadED.', 1;

    -- La fila de auditoria se crea antes de la transaccion para conservar el fallo.
    INSERT INTO etl.AuditoriaCarga (Estado, Mensaje)
    VALUES ('EN_PROCESO', N'Inicio de ETL completo, DW_ArtePublicidadED');
    SET @CargaID = CONVERT(BIGINT,SCOPE_IDENTITY());

    BEGIN TRY
        BEGIN TRANSACTION;

        -- ETAPA A: EXTRAER de OLTP a staging. No se modifica la base fuente.
        DELETE FROM stg.LineasPedido;
        INSERT INTO stg.LineasPedido
        (CargaID,PedidoID,DetallePedidoID,FechaPedido,ClienteID,NombreCliente,TipoCliente,
         ServicioID,NombreServicio,CategoriaID,NombreCategoria,
         EmpleadoID,NombreEmpleado,Cargo,Estado,
         Cantidad,PrecioUnitario,DescuentoPct,ImporteBruto,ImporteDescuento,ImporteNeto)
        SELECT
            @CargaID,p.PedidoID,d.DetallePedidoID,p.FechaPedido,
            c.ClienteID,LTRIM(RTRIM(c.NombreCliente)),c.TipoCliente,
            s.ServicioID,LTRIM(RTRIM(s.NombreServicio)),cs.CategoriaID,LTRIM(RTRIM(cs.NombreCategoria)),
            e.EmpleadoID,LTRIM(RTRIM(e.NombreEmpleado)),e.Cargo,p.Estado,
            d.Cantidad,d.PrecioUnitario,d.DescuentoPct,
            CONVERT(DECIMAL(28,6),d.Cantidad*d.PrecioUnitario),
            CONVERT(DECIMAL(28,6),d.Cantidad*d.PrecioUnitario*d.DescuentoPct),
            CONVERT(DECIMAL(28,6),d.Cantidad*d.PrecioUnitario*(1-d.DescuentoPct))
        FROM BD_ArtePublicidadED.dbo.DetallePedido AS d
        INNER JOIN BD_ArtePublicidadED.dbo.Pedidos AS p ON p.PedidoID=d.PedidoID
        INNER JOIN BD_ArtePublicidadED.dbo.Clientes AS c ON c.ClienteID=p.ClienteID
        INNER JOIN BD_ArtePublicidadED.dbo.Servicios AS s ON s.ServicioID=d.ServicioID
        INNER JOIN BD_ArtePublicidadED.dbo.CategoriasServicio AS cs ON cs.CategoriaID=s.CategoriaID
        INNER JOIN BD_ArtePublicidadED.dbo.Empleados AS e ON e.EmpleadoID=p.EmpleadoID;

        SELECT @Leidas=COUNT_BIG(*) FROM stg.LineasPedido WHERE CargaID=@CargaID;
        SELECT @FilasFuente=COUNT_BIG(*) FROM BD_ArtePublicidadED.dbo.DetallePedido;
        IF @Leidas <> @FilasFuente
            THROW 52116, N'La extraccion no coincide con el total de lineas de la fuente.', 1;
        IF @Leidas = 0
            THROW 52111, N'No se extrajeron lineas; no se modifico el Data Mart previo.', 1;

        -- ETAPA B: CALIDAD: campos requeridos, medidas y duplicados.
        ;WITH Marcadas AS (
            SELECT x.*,
                   ROW_NUMBER() OVER (PARTITION BY x.DetallePedidoID ORDER BY x.StagingID) AS rn
            FROM stg.LineasPedido AS x
            WHERE x.CargaID=@CargaID
        )
        INSERT INTO etl.RechazosCarga (CargaID,StagingID,DetallePedidoID,Motivo)
        SELECT @CargaID,StagingID,DetallePedidoID,
            CASE
                WHEN DetallePedidoID IS NULL OR PedidoID IS NULL OR FechaPedido IS NULL
                     OR ClienteID IS NULL OR ServicioID IS NULL OR EmpleadoID IS NULL OR Estado IS NULL
                     OR NombreCliente IS NULL OR NombreServicio IS NULL OR NombreCategoria IS NULL
                     OR NombreEmpleado IS NULL OR Cargo IS NULL
                    THEN N'Nulo en atributo obligatorio'
                WHEN Cantidad IS NULL OR Cantidad <= 0 OR PrecioUnitario IS NULL OR PrecioUnitario < 0
                     OR DescuentoPct IS NULL OR DescuentoPct NOT BETWEEN 0 AND 1
                    THEN N'Medida invalida'
                WHEN rn > 1 THEN N'DetallePedidoID duplicado'
                WHEN NOT EXISTS (SELECT 1 FROM dbo.DimEstadoPedido v WHERE v.Estado=Marcadas.Estado)
                    THEN N'Estado sin correspondencia'
                ELSE N'ERROR_NO_CLASIFICADO'
            END
        FROM Marcadas
        WHERE DetallePedidoID IS NULL OR PedidoID IS NULL OR FechaPedido IS NULL
              OR ClienteID IS NULL OR ServicioID IS NULL OR EmpleadoID IS NULL OR Estado IS NULL
              OR NombreCliente IS NULL OR NombreServicio IS NULL OR NombreCategoria IS NULL
              OR NombreEmpleado IS NULL OR Cargo IS NULL
              OR Cantidad IS NULL OR Cantidad <= 0 OR PrecioUnitario IS NULL OR PrecioUnitario < 0
              OR DescuentoPct IS NULL OR DescuentoPct NOT BETWEEN 0 AND 1
              OR rn > 1
              OR NOT EXISTS (SELECT 1 FROM dbo.DimEstadoPedido v WHERE v.Estado=Marcadas.Estado);

        SELECT @Rechazadas=COUNT_BIG(*) FROM etl.RechazosCarga WHERE CargaID=@CargaID;
        -- Politica de este laboratorio: no publicar un mart incompleto.
        IF @Rechazadas > 0
            THROW 52112, N'Existen registros rechazados; se revierte el lote y se conserva el mart anterior.', 1;

        -- ETAPA C: DIMENSIONES SCD-1. Fecha: observaciones de fecha del origen.
        INSERT INTO dbo.DimFecha (FechaKey,FechaCompleta,Dia,Mes,Trimestre,Anio)
        SELECT DISTINCT CONVERT(INT,CONVERT(CHAR(8),s.FechaPedido,112)),
               s.FechaPedido,DAY(s.FechaPedido),MONTH(s.FechaPedido),
               DATEPART(QUARTER,s.FechaPedido),YEAR(s.FechaPedido)
        FROM stg.LineasPedido s
        WHERE s.CargaID=@CargaID
          AND NOT EXISTS (SELECT 1 FROM dbo.DimFecha x WHERE x.FechaCompleta=s.FechaPedido);

        UPDATE d SET d.NombreCliente=s.NombreCliente,d.TipoCliente=s.TipoCliente
        FROM dbo.DimCliente d
        INNER JOIN (SELECT DISTINCT ClienteID,NombreCliente,TipoCliente
                    FROM stg.LineasPedido WHERE CargaID=@CargaID) s ON s.ClienteID=d.ClienteID;
        INSERT INTO dbo.DimCliente (ClienteID,NombreCliente,TipoCliente)
        SELECT DISTINCT s.ClienteID,s.NombreCliente,s.TipoCliente
        FROM stg.LineasPedido s
        WHERE s.CargaID=@CargaID
          AND NOT EXISTS (SELECT 1 FROM dbo.DimCliente d WHERE d.ClienteID=s.ClienteID);

        UPDATE d SET d.NombreServicio=s.NombreServicio,d.CategoriaID=s.CategoriaID,
                     d.NombreCategoria=s.NombreCategoria
        FROM dbo.DimServicio d
        INNER JOIN (SELECT DISTINCT ServicioID,NombreServicio,CategoriaID,NombreCategoria
                    FROM stg.LineasPedido WHERE CargaID=@CargaID) s ON s.ServicioID=d.ServicioID;
        INSERT INTO dbo.DimServicio (ServicioID,NombreServicio,CategoriaID,NombreCategoria)
        SELECT DISTINCT s.ServicioID,s.NombreServicio,s.CategoriaID,s.NombreCategoria
        FROM stg.LineasPedido s
        WHERE s.CargaID=@CargaID
          AND NOT EXISTS (SELECT 1 FROM dbo.DimServicio d WHERE d.ServicioID=s.ServicioID);

        UPDATE d SET d.NombreEmpleado=s.NombreEmpleado,d.Cargo=s.Cargo
        FROM dbo.DimEmpleado d
        INNER JOIN (SELECT DISTINCT EmpleadoID,NombreEmpleado,Cargo
                    FROM stg.LineasPedido WHERE CargaID=@CargaID) s ON s.EmpleadoID=d.EmpleadoID;
        INSERT INTO dbo.DimEmpleado (EmpleadoID,NombreEmpleado,Cargo)
        SELECT DISTINCT s.EmpleadoID,s.NombreEmpleado,s.Cargo
        FROM stg.LineasPedido s
        WHERE s.CargaID=@CargaID
          AND NOT EXISTS (SELECT 1 FROM dbo.DimEmpleado d WHERE d.EmpleadoID=s.EmpleadoID);

        -- ETAPA D: FULL REFRESH ATOMICO DE HECHOS. Idempotente: no acumula duplicados.
        DELETE FROM dbo.FactVentas;
        INSERT INTO dbo.FactVentas
        (PedidoID,DetallePedidoID,FechaKey,ClienteKey,ServicioKey,EmpleadoKey,EstadoKey,
         Cantidad,PrecioUnitario,DescuentoPct,ImporteBruto,ImporteDescuento,ImporteNeto)
        SELECT
            s.PedidoID,s.DetallePedidoID,f.FechaKey,c.ClienteKey,v.ServicioKey,
            e.EmpleadoKey,ep.EstadoKey,
            s.Cantidad,s.PrecioUnitario,s.DescuentoPct,
            s.ImporteBruto,s.ImporteDescuento,s.ImporteNeto
        FROM stg.LineasPedido AS s
        INNER JOIN dbo.DimFecha f ON f.FechaCompleta=s.FechaPedido
        INNER JOIN dbo.DimCliente c ON c.ClienteID=s.ClienteID
        INNER JOIN dbo.DimServicio v ON v.ServicioID=s.ServicioID
        INNER JOIN dbo.DimEmpleado e ON e.EmpleadoID=s.EmpleadoID
        INNER JOIN dbo.DimEstadoPedido ep ON ep.Estado=s.Estado
        WHERE s.CargaID=@CargaID;

        SELECT @Cargadas=COUNT_BIG(*) FROM dbo.FactVentas;
        SELECT @MontoOrigen=COALESCE(CONVERT(DECIMAL(19,2),ROUND(SUM(ImporteNeto),2)),0)
        FROM stg.LineasPedido WHERE CargaID=@CargaID;
        SELECT @MontoDestino=COALESCE(CONVERT(DECIMAL(19,2),ROUND(SUM(ImporteNeto),2)),0)
        FROM dbo.FactVentas;
        IF @Leidas <> @Cargadas + @Rechazadas
            THROW 52113, N'No cuadran filas extraidas, cargadas y rechazadas.', 1;
        IF ABS(@MontoOrigen-@MontoDestino) > 0.01
            THROW 52114, N'No cuadran los montos origen y destino.', 1;
        IF EXISTS (SELECT DetallePedidoID FROM dbo.FactVentas GROUP BY DetallePedidoID HAVING COUNT_BIG(*)>1)
            THROW 52115, N'Hechos duplicados.', 1;

        UPDATE etl.AuditoriaCarga
           SET Estado='CORRECTO',FechaFin=SYSDATETIME(),FilasLeidas=@Leidas,
               FilasCargadas=@Cargadas,FilasRechazadas=@Rechazadas,
               MontoOrigen=@MontoOrigen,MontoDestino=@MontoDestino,
               DiferenciaMonto=@MontoOrigen-@MontoDestino,
               Mensaje=N'ETL completo; dimensiones SCD1; sin duplicados'
        WHERE CargaID=@CargaID;

        COMMIT TRANSACTION;
        SELECT CargaID,Estado,FilasLeidas,FilasCargadas,FilasRechazadas,
               MontoOrigen,MontoDestino,DiferenciaMonto
        FROM etl.AuditoriaCarga WHERE CargaID=@CargaID;
    END TRY
    BEGIN CATCH
        SET @Mensaje=ERROR_MESSAGE();
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        UPDATE etl.AuditoriaCarga
           SET Estado='ERROR',FechaFin=SYSDATETIME(),Mensaje=@Mensaje,
               FilasLeidas=@Leidas,FilasCargadas=0,FilasRechazadas=@Rechazadas
        WHERE CargaID=@CargaID;
        THROW;
    END CATCH;
END;
GO
SELECT N'Procedimiento ETL creado/actualizado' AS Resultado,
       OBJECT_ID(N'etl.usp_CargarDataMart',N'P') AS IdProcedimiento;
GO
