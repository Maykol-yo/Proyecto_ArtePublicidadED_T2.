/*
Arte y Publicidad E&D | T2 | Etapa 6 | Prechequeo del experimento
SOLO LECTURA. No altera tablas, indices, datos ni configuraciones.
Requiere BD_ArtePublicidadED y DW_ArtePublicidadED ya cargadas.
*/
USE DW_ArtePublicidadED;
GO
SET NOCOUNT ON;

SELECT DB_NAME() AS BaseAnalitica,
       @@SERVERNAME AS Servidor,
       CONVERT(varchar(30), SERVERPROPERTY('ProductVersion')) AS VersionSQLServer,
       CONVERT(varchar(30), SERVERPROPERTY('Edition')) AS Edicion;

SELECT
 (SELECT COUNT_BIG(*) FROM BD_ArtePublicidadED.dbo.DetallePedido) AS FilasDetalleOLTP,
 (SELECT COUNT_BIG(*) FROM dbo.FactVentas) AS FilasFactDW,
 (SELECT COUNT_BIG(DISTINCT DetallePedidoID) FROM dbo.FactVentas) AS DetallesUnicosDW;

;WITH OLTP AS (
 SELECT CONVERT(decimal(19,2),ROUND(SUM(d.Cantidad*d.PrecioUnitario*(1-d.DescuentoPct)),2)) AS Importe
 FROM BD_ArtePublicidadED.dbo.Pedidos p
 JOIN BD_ArtePublicidadED.dbo.DetallePedido d ON p.PedidoID=d.PedidoID
 WHERE p.Estado='ENTREGADO'
   AND p.FechaPedido >= '20250101' AND p.FechaPedido < '20260101'
), DW AS (
 SELECT CONVERT(decimal(19,2),ROUND(SUM(f.ImporteNeto),2)) AS Importe
 FROM dbo.FactVentas f
 JOIN dbo.DimFecha fecha ON f.FechaKey=fecha.FechaKey
 JOIN dbo.DimEstadoPedido estado ON f.EstadoKey=estado.EstadoKey
 WHERE fecha.Anio=2025 AND estado.Estado='ENTREGADO'
)
SELECT o.Importe AS ImporteOLTP2025, d.Importe AS ImporteDW2025,
       o.Importe-d.Importe AS Diferencia,
       CASE WHEN o.Importe IS NULL OR d.Importe IS NULL THEN 'REVISAR'
            WHEN ABS(o.Importe-d.Importe)<=0.01 THEN 'CUADRE_OK' ELSE 'REVISAR' END AS Estado
FROM OLTP o CROSS JOIN DW d;
GO
