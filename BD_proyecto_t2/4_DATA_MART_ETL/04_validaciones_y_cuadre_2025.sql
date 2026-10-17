/*
Arte y Publicidad E&D - T2 - C7/C8
04. Validacion de calidad, unicidad, FK y monto del KPI 2025.
Debe ejecutarse DESPUES de 03. Todas las consultas son SELECT, no modifican datos.
*/
USE DW_ArtePublicidadED;
GO
SET NOCOUNT ON;

-- A. FILAS: una fila en DW por una linea de detalle en la fuente.
SELECT
  (SELECT COUNT_BIG(*) FROM BD_ArtePublicidadED.dbo.DetallePedido) AS DetallesOLTP,
  (SELECT COUNT_BIG(*) FROM stg.LineasPedido) AS FilasStaging,
  (SELECT COUNT_BIG(*) FROM dbo.FactVentas) AS FilasFact,
  (SELECT COUNT_BIG(DISTINCT DetallePedidoID) FROM dbo.FactVentas) AS HechosDistintos,
  (SELECT COUNT_BIG(*) FROM etl.RechazosCarga r
      WHERE r.CargaID=(SELECT MAX(a.CargaID) FROM etl.AuditoriaCarga a WHERE a.Estado='CORRECTO'))
    AS RechazosUltimoLote;

-- B. DUPLICADOS (se espera 0 resultados).
SELECT DetallePedidoID,COUNT_BIG(*) AS Repeticiones
FROM dbo.FactVentas GROUP BY DetallePedidoID HAVING COUNT_BIG(*)>1;

-- C. INTEGRIDAD DE CLAVES (se espera 0).
SELECT COUNT_BIG(*) AS HechosConDimensionFaltante
FROM dbo.FactVentas f
LEFT JOIN dbo.DimFecha d ON d.FechaKey=f.FechaKey
LEFT JOIN dbo.DimCliente c ON c.ClienteKey=f.ClienteKey
LEFT JOIN dbo.DimServicio s ON s.ServicioKey=f.ServicioKey
LEFT JOIN dbo.DimEmpleado e ON e.EmpleadoKey=f.EmpleadoKey
LEFT JOIN dbo.DimEstadoPedido ep ON ep.EstadoKey=f.EstadoKey
WHERE d.FechaKey IS NULL OR c.ClienteKey IS NULL OR s.ServicioKey IS NULL
   OR e.EmpleadoKey IS NULL OR ep.EstadoKey IS NULL;

-- D. KPI comparado con la formula ORIGINAL del OLTP. No confundir con pagos cobrados.
;WITH KPI_OLTP AS (
    SELECT CONVERT(DECIMAL(19,2), ROUND(
        SUM(d.Cantidad*d.PrecioUnitario*(1-d.DescuentoPct)),2)) AS Monto
    FROM BD_ArtePublicidadED.dbo.Pedidos p
    INNER JOIN BD_ArtePublicidadED.dbo.DetallePedido d ON d.PedidoID=p.PedidoID
    WHERE p.Estado='ENTREGADO'
      AND p.FechaPedido >= '20250101' AND p.FechaPedido < '20260101'
),
KPI_DW AS (
    SELECT CONVERT(DECIMAL(19,2),ROUND(SUM(f.ImporteNeto),2)) AS Monto
    FROM dbo.FactVentas f
    INNER JOIN dbo.DimFecha fecha ON fecha.FechaKey=f.FechaKey
    INNER JOIN dbo.DimEstadoPedido ep ON ep.EstadoKey=f.EstadoKey
    WHERE ep.Estado='ENTREGADO' AND fecha.Anio=2025
)
SELECT o.Monto AS Monto2025_OLTP,d.Monto AS Monto2025_DW,
       o.Monto-d.Monto AS Diferencia,
       CASE WHEN o.Monto IS NULL OR d.Monto IS NULL THEN 'REVISAR'
            WHEN ABS(o.Monto-d.Monto)<=0.01 THEN 'CUADRE_OK' ELSE 'NO_CUADRA' END AS Estado
FROM KPI_OLTP o CROSS JOIN KPI_DW d;
GO

-- E. Cuadre fino por MES y CATEGORIA, con la MISMA granularidad.
;WITH Origen AS (
  SELECT YEAR(p.FechaPedido) AS Anio,MONTH(p.FechaPedido) AS Mes,
         cat.NombreCategoria AS Categoria,
         CONVERT(DECIMAL(19,2),ROUND(SUM(d.Cantidad*d.PrecioUnitario*(1-d.DescuentoPct)),2)) AS Monto
  FROM BD_ArtePublicidadED.dbo.Pedidos p
  JOIN BD_ArtePublicidadED.dbo.DetallePedido d ON d.PedidoID=p.PedidoID
  JOIN BD_ArtePublicidadED.dbo.Servicios s ON s.ServicioID=d.ServicioID
  JOIN BD_ArtePublicidadED.dbo.CategoriasServicio cat ON cat.CategoriaID=s.CategoriaID
  WHERE p.Estado='ENTREGADO' AND p.FechaPedido >= '20250101' AND p.FechaPedido < '20260101'
  GROUP BY YEAR(p.FechaPedido),MONTH(p.FechaPedido),cat.NombreCategoria
),
Destino AS (
  SELECT fe.Anio,fe.Mes,sv.NombreCategoria AS Categoria,
         CONVERT(DECIMAL(19,2),ROUND(SUM(f.ImporteNeto),2)) AS Monto
  FROM dbo.FactVentas f
  JOIN dbo.DimFecha fe ON fe.FechaKey=f.FechaKey
  JOIN dbo.DimServicio sv ON sv.ServicioKey=f.ServicioKey
  JOIN dbo.DimEstadoPedido ep ON ep.EstadoKey=f.EstadoKey
  WHERE ep.Estado='ENTREGADO' AND fe.Anio=2025
  GROUP BY fe.Anio,fe.Mes,sv.NombreCategoria
)
SELECT COALESCE(o.Anio,d.Anio) AS Anio,COALESCE(o.Mes,d.Mes) AS Mes,
       COALESCE(o.Categoria,d.Categoria) AS Categoria,
       o.Monto AS MontoOLTP,d.Monto AS MontoDW,
       COALESCE(o.Monto,0)-COALESCE(d.Monto,0) AS Diferencia
FROM Origen o
FULL OUTER JOIN Destino d ON d.Anio=o.Anio AND d.Mes=o.Mes AND d.Categoria=o.Categoria
ORDER BY Anio,Mes,Categoria;
GO
