/*
Arte y Publicidad E&D - T2 - C8
03. Ejecutar ETL dos veces. Guardar capturas de ambas salidas.
Se esperan misma cantidad de hechos e igual monto en ambas ejecuciones.
Atencion: FULL REFRESH en DW; NO elimina ni cambia registros de BD_ArtePublicidadED.
*/
USE DW_ArtePublicidadED;
GO
SET NOCOUNT ON;
PRINT '=== PRIMERA EJECUCION ===';
EXEC etl.usp_CargarDataMart;
GO
SELECT N'DESPUES_1' AS Momento,
       (SELECT COUNT_BIG(*) FROM dbo.FactVentas) AS FilasFact,
       (SELECT COUNT_BIG(DISTINCT DetallePedidoID) FROM dbo.FactVentas) AS DetallesDistintos,
       (SELECT CONVERT(DECIMAL(19,2),ROUND(SUM(ImporteNeto),2)) FROM dbo.FactVentas) AS MontoTotal;
GO
PRINT '=== SEGUNDA EJECUCION (IDEMPOTENCIA) ===';
EXEC etl.usp_CargarDataMart;
GO
SELECT N'DESPUES_2' AS Momento,
       (SELECT COUNT_BIG(*) FROM dbo.FactVentas) AS FilasFact,
       (SELECT COUNT_BIG(DISTINCT DetallePedidoID) FROM dbo.FactVentas) AS DetallesDistintos,
       (SELECT CONVERT(DECIMAL(19,2),ROUND(SUM(ImporteNeto),2)) FROM dbo.FactVentas) AS MontoTotal;
GO
SELECT TOP (5) CargaID,FechaInicio,FechaFin,Estado,
       FilasLeidas,FilasCargadas,FilasRechazadas,MontoOrigen,MontoDestino,DiferenciaMonto,Mensaje
FROM etl.AuditoriaCarga ORDER BY CargaID DESC;
GO
