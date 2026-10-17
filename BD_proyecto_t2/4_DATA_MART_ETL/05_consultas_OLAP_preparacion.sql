/*
Arte y Publicidad E&D - T2 - C9
Consultas preparatorias de analisis OLAP; posteriormente pueden conectarse a Power BI.
Se espera que los montos agregados por mes y categoria cuadren con 04.
*/
USE DW_ArtePublicidadED;
GO
SET NOCOUNT ON;

-- OLAP 1: ROLL-UP: detalle -> mes (ventas entregadas de 2025).
SELECT fecha.Anio,fecha.Mes,
       COUNT_BIG(*) AS LineasVendidas,
       COUNT(DISTINCT f.PedidoID) AS PedidosDistintos,
       SUM(CONVERT(BIGINT,f.Cantidad)) AS Unidades,
       CONVERT(DECIMAL(19,2),ROUND(SUM(f.ImporteNeto),2)) AS MontoPedidosEntregados
FROM dbo.FactVentas f
JOIN dbo.DimFecha fecha ON fecha.FechaKey=f.FechaKey
JOIN dbo.DimEstadoPedido estado ON estado.EstadoKey=f.EstadoKey
WHERE fecha.Anio=2025 AND estado.Estado='ENTREGADO'
GROUP BY fecha.Anio,fecha.Mes
ORDER BY fecha.Anio,fecha.Mes;

-- OLAP 2: DRILL-DOWN: mes -> categoria -> servicio.
SELECT fecha.Anio,fecha.Mes,s.NombreCategoria,s.NombreServicio,
       COUNT_BIG(*) AS LineasVendidas,
       CONVERT(DECIMAL(19,2),ROUND(SUM(f.ImporteNeto),2)) AS MontoPedidosEntregados
FROM dbo.FactVentas f
JOIN dbo.DimFecha fecha ON fecha.FechaKey=f.FechaKey
JOIN dbo.DimServicio s ON s.ServicioKey=f.ServicioKey
JOIN dbo.DimEstadoPedido estado ON estado.EstadoKey=f.EstadoKey
WHERE fecha.Anio=2025 AND estado.Estado='ENTREGADO'
GROUP BY fecha.Anio,fecha.Mes,s.NombreCategoria,s.NombreServicio
ORDER BY fecha.Anio,fecha.Mes,s.NombreCategoria,s.NombreServicio;

-- OLAP 3: SLICE: un solo estado, una categoria; total por tipo de cliente.
SELECT cliente.TipoCliente,COUNT(DISTINCT f.PedidoID) AS PedidosDistintos,
       CONVERT(DECIMAL(19,2),ROUND(SUM(f.ImporteNeto),2)) AS Monto
FROM dbo.FactVentas f
JOIN dbo.DimFecha fecha ON fecha.FechaKey=f.FechaKey
JOIN dbo.DimCliente cliente ON cliente.ClienteKey=f.ClienteKey
JOIN dbo.DimServicio s ON s.ServicioKey=f.ServicioKey
JOIN dbo.DimEstadoPedido estado ON estado.EstadoKey=f.EstadoKey
WHERE fecha.Anio=2025 AND estado.Estado='ENTREGADO' AND s.NombreCategoria=N'Impresion'
GROUP BY cliente.TipoCliente ORDER BY cliente.TipoCliente;
GO
