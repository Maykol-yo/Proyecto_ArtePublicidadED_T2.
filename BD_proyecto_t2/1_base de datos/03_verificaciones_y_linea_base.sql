/*
Script 03 - Primeras verificaciones y consulta analitica de linea base
No incluye resultados inventados: ejecutar en SQL Server Management Studio.
NO aplicar indices de optimizacion hasta registrar la linea base.
*/
USE BD_ArtePublicidadED;
GO
SET NOCOUNT ON;

-- A. Conteos para documentar el dataset sintetico
SELECT 'Clientes' AS Tabla, COUNT_BIG(*) AS Filas FROM dbo.Clientes
UNION ALL SELECT 'Cotizaciones',COUNT_BIG(*) FROM dbo.Cotizaciones
UNION ALL SELECT 'DetalleCotizacion',COUNT_BIG(*) FROM dbo.DetalleCotizacion
UNION ALL SELECT 'Pedidos',COUNT_BIG(*) FROM dbo.Pedidos
UNION ALL SELECT 'DetallePedido',COUNT_BIG(*) FROM dbo.DetallePedido
UNION ALL SELECT 'Pagos',COUNT_BIG(*) FROM dbo.Pagos
UNION ALL SELECT 'Compras',COUNT_BIG(*) FROM dbo.Compras
UNION ALL SELECT 'DetalleCompra',COUNT_BIG(*) FROM dbo.DetalleCompra
UNION ALL SELECT 'MovimientosMaterial',COUNT_BIG(*) FROM dbo.MovimientosMaterial;
GO

-- B. Validar relaciones y conversion de cotizaciones
SELECT Estado,COUNT(*) AS TotalCotizaciones
FROM dbo.Cotizaciones GROUP BY Estado ORDER BY Estado;
SELECT Estado,COUNT(*) AS TotalPedidos
FROM dbo.Pedidos GROUP BY Estado ORDER BY Estado;
SELECT COUNT(*) AS PedidosSinDetalle
FROM dbo.Pedidos p WHERE NOT EXISTS
    (SELECT 1 FROM dbo.DetallePedido d WHERE d.PedidoID=p.PedidoID);
SELECT COUNT(*) AS PedidosConClienteInconsistente
FROM dbo.Pedidos p INNER JOIN dbo.Cotizaciones q ON q.CotizacionID=p.CotizacionID
WHERE p.ClienteID <> q.ClienteID;
GO

-- C. Reporte gerencial de referencia: ventas por mes y categoria en 2025.
-- Definicion de KPI: suma de importes por LINEA de pedidos ENTREGADOS;
-- los importes de Pagos NO se agregan aqui para evitar multiplicacion de filas.
-- Este filtro YEAR() es parte del codigo inicial que se evaluara mas adelante.
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
SELECT YEAR(p.FechaPedido) AS Anio,
       MONTH(p.FechaPedido) AS Mes,
       cs.NombreCategoria AS Categoria,
       COUNT_BIG(*) AS LineasPedido,
       SUM(d.Cantidad) AS Unidades,
       CAST(ROUND(SUM(d.Cantidad*d.PrecioUnitario*(1-d.DescuentoPct)),2)
            AS DECIMAL(19,2)) AS MontoPedidosEntregados
FROM dbo.Pedidos AS p
INNER JOIN dbo.DetallePedido AS d ON d.PedidoID=p.PedidoID
INNER JOIN dbo.Servicios AS s ON s.ServicioID=d.ServicioID
INNER JOIN dbo.CategoriasServicio AS cs ON cs.CategoriaID=s.CategoriaID
WHERE YEAR(p.FechaPedido)=2025 AND p.Estado='ENTREGADO'
GROUP BY YEAR(p.FechaPedido),MONTH(p.FechaPedido),cs.NombreCategoria
ORDER BY Anio,Mes,Categoria;
SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

-- D. Integridad monetaria de pedidos ENTREGADOS: base para comparacion futura con el Data Mart.
SELECT CAST(ROUND(SUM(d.Cantidad*d.PrecioUnitario*(1-d.DescuentoPct)),2)
        AS DECIMAL(19,2)) AS Monto2025Entregado
FROM dbo.Pedidos p INNER JOIN dbo.DetallePedido d ON d.PedidoID=p.PedidoID
WHERE p.Estado='ENTREGADO' AND p.FechaPedido>='2025-01-01' AND p.FechaPedido<'2026-01-01';
GO
