/*
PROYECTO ACADEMICO: Arte y Publicidad E&D
Script 02 - Carga reproducible de datos sinteticos para pruebas.
No usa informacion real de clientes ni empleados.
Ejecucion UNICA sobre la base recien creada.
Cambie @NumeroCotizaciones ANTES de ejecutar, segun los recursos del equipo.
Prueba inicial recomendada: 20000. Maximo admitido: 500000.
Nota: N > 200000 puede demandar tiempo, memoria y espacio considerables.
*/
USE BD_ArtePublicidadED;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @NumeroCotizaciones INT = 20000;
IF @NumeroCotizaciones < 1000 OR @NumeroCotizaciones > 500000
    THROW 50010, N'Cantidad fuera del intervalo permitido [1000, 500000].', 1;
IF EXISTS(SELECT 1 FROM dbo.CategoriasServicio)
    OR EXISTS(SELECT 1 FROM dbo.Cotizaciones)
    OR EXISTS(SELECT 1 FROM dbo.Pedidos)
    THROW 50011, N'La base ya contiene datos. No ejecute nuevamente este generador.', 1;

-- Se crea una secuencia entera reproducible; no depende de datos reales.
CREATE TABLE #Numeros (n INT NOT NULL PRIMARY KEY);
WITH Digitos AS (
    SELECT v.n FROM (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS v(n)
)
INSERT INTO #Numeros(n)
SELECT z.n
FROM (
    SELECT 1 + a.n + 10*b.n + 100*c.n + 1000*d.n + 10000*e.n + 100000*f.n AS n
    FROM Digitos a CROSS JOIN Digitos b CROSS JOIN Digitos c
         CROSS JOIN Digitos d CROSS JOIN Digitos e CROSS JOIN Digitos f
) z
WHERE z.n <= @NumeroCotizaciones;

BEGIN TRY
  BEGIN TRANSACTION;

  INSERT INTO dbo.CategoriasServicio(NombreCategoria) VALUES
    (N'Diseno grafico'), (N'Impresion'), (N'Publicidad'), (N'Merchandising');

  INSERT INTO dbo.Empleados(NombreEmpleado,Cargo) VALUES
    (N'Empleado sintetico 01',N'Atencion'),(N'Empleado sintetico 02',N'Atencion'),
    (N'Empleado sintetico 03',N'Diseno'),(N'Empleado sintetico 04',N'Produccion'),
    (N'Empleado sintetico 05',N'Ventas'),(N'Empleado sintetico 06',N'Administracion');

  INSERT INTO dbo.Servicios(CategoriaID,NombreServicio,PrecioReferencial) VALUES
    (1,N'Diseno de logotipo',150),(1,N'Diseno de afiche',80),(1,N'Diseno de identidad',280),
    (2,N'Impresion de volantes',120),(2,N'Impresion de banners',95),(2,N'Impresion de tarjetas',65),
    (3,N'Rotulos para locales',200),(3,N'Panel publicitario',380),(3,N'Publicidad vehicular',350),
    (4,N'Polos personalizados',45),(4,N'Tazas personalizadas',26),(4,N'Llaveros personalizados',14);

  INSERT INTO dbo.Proveedores(NombreProveedor) VALUES
    (N'Proveedor sintetico A'),(N'Proveedor sintetico B'),
    (N'Proveedor sintetico C'),(N'Proveedor sintetico D');

  INSERT INTO dbo.Materiales(NombreMaterial,UnidadMedida,StockMinimo) VALUES
    (N'Papel couche', 'PAQUETE', 20),(N'Vinil adhesivo','METRO',30),
    (N'Lona publicitaria','METRO',30),(N'Tinta negra','LITRO',10),
    (N'Tinta color','LITRO',10),(N'Tela para polo','METRO',40),
    (N'Taza blanca','UNIDAD',50),(N'Accesorio llavero','UNIDAD',50);

  INSERT INTO dbo.Clientes(CodigoCliente,NombreCliente,TipoCliente,Correo,FechaRegistro)
  SELECT CONCAT('CLI-', RIGHT(CONCAT('000000', CAST(n AS VARCHAR(6))),6)),
         CONCAT(N'Cliente sintetico ',n),
         CASE WHEN n % 4 = 0 THEN 'EMPRESA' ELSE 'PERSONA' END,
         CONCAT('cliente',n,'@example.com'),
         DATEADD(DAY,n % 365,CONVERT(DATE,'2022-01-01'))
  FROM #Numeros WHERE n <= 500;

  -- Cotizaciones: 20% rechazadas y un subconjunto adicional pendientes.
  INSERT INTO dbo.Cotizaciones(CodigoCotizacion,ClienteID,EmpleadoID,FechaCotizacion,Estado)
  SELECT CONCAT('COT-',RIGHT(CONCAT('0000000',CAST(n AS VARCHAR(7))),7)),
         ((n-1)%500)+1,((n-1)%6)+1,
         DATEADD(DAY,(n*7)%1320,CONVERT(DATE,'2023-01-01')),
         CASE WHEN n%5=0 THEN 'RECHAZADA'
              WHEN n%17=0 THEN 'PENDIENTE'
              ELSE 'APROBADA' END
  FROM #Numeros;

  INSERT INTO dbo.DetalleCotizacion(CotizacionID,ServicioID,Cantidad,PrecioUnitario,DescuentoPct)
  SELECT q.CotizacionID,
         CASE WHEN d.r=1 THEN ((q.CotizacionID-1)%12)+1
              ELSE ((q.CotizacionID+3)%12)+1 END,
         1 + ((q.CotizacionID+d.r)%8),
         s.PrecioReferencial,
         CASE WHEN (q.CotizacionID+d.r)%7=0 THEN 0.0500 ELSE 0 END
  FROM dbo.Cotizaciones q
  CROSS JOIN (VALUES(1),(2)) AS d(r)
  INNER JOIN dbo.Servicios s
    ON s.ServicioID = CASE WHEN d.r=1 THEN ((q.CotizacionID-1)%12)+1
                          ELSE ((q.CotizacionID+3)%12)+1 END;

  -- Solo las cotizaciones aprobadas se convierten en pedidos.
  INSERT INTO dbo.Pedidos(CodigoPedido,CotizacionID,ClienteID,EmpleadoID,FechaPedido,Estado)
  SELECT REPLACE(q.CodigoCotizacion,'COT-','PED-'),
         q.CotizacionID,q.ClienteID,q.EmpleadoID,
         DATEADD(DAY,1+q.CotizacionID%10,q.FechaCotizacion),
         CASE WHEN q.CotizacionID%13=0 THEN 'CANCELADO'
              WHEN q.CotizacionID%7=0 THEN 'EN_PRODUCCION'
              ELSE 'ENTREGADO' END
  FROM dbo.Cotizaciones q WHERE q.Estado='APROBADA';

  INSERT INTO dbo.DetallePedido(PedidoID,ServicioID,Cantidad,PrecioUnitario,DescuentoPct)
  SELECT p.PedidoID,dc.ServicioID,dc.Cantidad,dc.PrecioUnitario,dc.DescuentoPct
  FROM dbo.Pedidos p
  INNER JOIN dbo.DetalleCotizacion dc ON dc.CotizacionID=p.CotizacionID;

  -- El pago corresponde al total de lineas entregadas, sin duplicar cabeceras.
  INSERT INTO dbo.Pagos(PedidoID,FechaPago,Monto,MedioPago,Estado)
  SELECT p.PedidoID,DATEADD(DAY,2,p.FechaPedido),
         CAST(ROUND(SUM(dp.Cantidad*dp.PrecioUnitario*(1-dp.DescuentoPct)),2) AS DECIMAL(18,2)),
         CASE WHEN p.PedidoID%4=0 THEN 'YAPE'
              WHEN p.PedidoID%4=1 THEN 'EFECTIVO'
              WHEN p.PedidoID%4=2 THEN 'TARJETA'
              ELSE 'TRANSFERENCIA' END,
         'CONFIRMADO'
  FROM dbo.Pedidos p
  INNER JOIN dbo.DetallePedido dp ON dp.PedidoID=p.PedidoID
  WHERE p.Estado='ENTREGADO'
  GROUP BY p.PedidoID,p.FechaPedido;

  -- Compra y consumo de materiales: parte secundaria del caso.
  INSERT INTO dbo.Compras(ProveedorID,EmpleadoID,FechaCompra,Estado)
  SELECT ((n-1)%4)+1,6,
         DATEADD(DAY,n*20,CONVERT(DATE,'2023-01-01')),'RECIBIDA'
  FROM #Numeros WHERE n <= 60;

  INSERT INTO dbo.DetalleCompra(CompraID,MaterialID,Cantidad,CostoUnitario)
  SELECT co.CompraID, ((co.CompraID+d.r*3)%8)+1,
         CAST(70+(co.CompraID%10) AS DECIMAL(14,2)),
         CAST(5+((co.CompraID+d.r)%11) AS DECIMAL(14,2))
  FROM dbo.Compras co CROSS JOIN (VALUES(1),(2)) d(r);

  INSERT INTO dbo.MovimientosMaterial(MaterialID,DetalleCompraID,PedidoID,FechaMovimiento,TipoMovimiento,Cantidad)
  SELECT dc.MaterialID,dc.DetalleCompraID,NULL,c.FechaCompra,'ENTRADA',dc.Cantidad
  FROM dbo.DetalleCompra dc INNER JOIN dbo.Compras c ON c.CompraID=dc.CompraID;

  INSERT INTO dbo.MovimientosMaterial(MaterialID,DetalleCompraID,PedidoID,FechaMovimiento,TipoMovimiento,Cantidad)
  SELECT ((p.PedidoID-1)%8)+1,NULL,p.PedidoID,
         p.FechaPedido,'SALIDA',CAST(1+(p.PedidoID%3) AS DECIMAL(14,2))
  FROM dbo.Pedidos p
  WHERE p.Estado='ENTREGADO' AND p.PedidoID%20=0;

  COMMIT TRANSACTION;
END TRY
BEGIN CATCH
  IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
  THROW;
END CATCH;

SELECT @NumeroCotizaciones AS CotizacionesPlanificadas,
       (SELECT COUNT(*) FROM dbo.Cotizaciones) AS CotizacionesCargadas,
       (SELECT COUNT(*) FROM dbo.Pedidos) AS PedidosCargados,
       (SELECT COUNT(*) FROM dbo.DetallePedido) AS LineasPedido,
       (SELECT COUNT(*) FROM dbo.Pagos) AS PagosCargados;
GO
