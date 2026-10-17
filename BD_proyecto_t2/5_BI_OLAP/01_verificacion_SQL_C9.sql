/*
Arte y Publicidad E&D — C9: contraste SQL para dashboard Power BI
LECTURA SOLAMENTE. Ejecutar en SSMS.
Origen BI: DW_ArtePublicidadED. Indicador: importe de pedidos ENTREGADOS de 2025.
No es dinero cobrado: mide el valor de las líneas de pedidos entregados.
*/
USE DW_ArtePublicidadED;
GO
SET NOCOUNT ON;

-- 1) KPI que debe coincidir con la tarjeta de Power BI (sin filtros adicionales).
SELECT
    fch.Anio,
    ep.Estado,
    COUNT_BIG(*) AS Lineas,
    COUNT(DISTINCT f.PedidoID) AS PedidosDistintos,
    SUM(CONVERT(BIGINT, f.Cantidad)) AS Unidades,
    CONVERT(DECIMAL(19,2), ROUND(SUM(f.ImporteNeto), 2)) AS MontoPedidosEntregados
FROM dbo.FactVentas AS f
JOIN dbo.DimFecha AS fch ON fch.FechaKey = f.FechaKey
JOIN dbo.DimEstadoPedido AS ep ON ep.EstadoKey = f.EstadoKey
WHERE fch.Anio = 2025 AND ep.Estado = 'ENTREGADO'
GROUP BY fch.Anio, ep.Estado;
GO

-- 2) ROLL-UP: año/mes; debe coincidir con gráfico de ventas mensuales.
SELECT fch.Anio, fch.Mes,
       COUNT(DISTINCT f.PedidoID) AS PedidosDistintos,
       CONVERT(DECIMAL(19,2), ROUND(SUM(f.ImporteNeto), 2)) AS Monto
FROM dbo.FactVentas AS f
JOIN dbo.DimFecha AS fch ON fch.FechaKey = f.FechaKey
JOIN dbo.DimEstadoPedido AS ep ON ep.EstadoKey = f.EstadoKey
WHERE fch.Anio = 2025 AND ep.Estado = 'ENTREGADO'
GROUP BY fch.Anio, fch.Mes
ORDER BY fch.Anio, fch.Mes;
GO

-- 3) DRILL-DOWN: categoría -> servicio, el mismo indicador.
SELECT s.NombreCategoria, s.NombreServicio,
       COUNT_BIG(*) AS Lineas,
       CONVERT(DECIMAL(19,2), ROUND(SUM(f.ImporteNeto), 2)) AS Monto
FROM dbo.FactVentas AS f
JOIN dbo.DimFecha AS fch ON fch.FechaKey = f.FechaKey
JOIN dbo.DimEstadoPedido AS ep ON ep.EstadoKey = f.EstadoKey
JOIN dbo.DimServicio AS s ON s.ServicioKey = f.ServicioKey
WHERE fch.Anio = 2025 AND ep.Estado = 'ENTREGADO'
GROUP BY s.NombreCategoria, s.NombreServicio
ORDER BY s.NombreCategoria, s.NombreServicio;
GO

-- 4) SLICE: solo categoría 'Impresion' y tipo de cliente.
SELECT c.TipoCliente,
       COUNT(DISTINCT f.PedidoID) AS PedidosDistintos,
       CONVERT(DECIMAL(19,2), ROUND(SUM(f.ImporteNeto), 2)) AS Monto
FROM dbo.FactVentas AS f
JOIN dbo.DimFecha AS fch ON fch.FechaKey = f.FechaKey
JOIN dbo.DimEstadoPedido AS ep ON ep.EstadoKey = f.EstadoKey
JOIN dbo.DimServicio AS s ON s.ServicioKey = f.ServicioKey
JOIN dbo.DimCliente AS c ON c.ClienteKey = f.ClienteKey
WHERE fch.Anio = 2025 AND ep.Estado = 'ENTREGADO'
  AND s.NombreCategoria = N'Impresion'
GROUP BY c.TipoCliente
ORDER BY c.TipoCliente;
GO
