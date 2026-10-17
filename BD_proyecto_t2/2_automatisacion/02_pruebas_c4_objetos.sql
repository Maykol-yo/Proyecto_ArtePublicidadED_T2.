/*
Archivo 02: pruebas positivas de C4. Ejecutar DESPUES de 01_crear_objetos_tsql.sql.
La prueba inserta UN pedido PRB- y una linea. No altera pedidos anteriores.
En ejecuciones posteriores detecta el pedido ya existente y no lo duplica.
*/
USE BD_ArtePublicidadED;
GO
SET NOCOUNT ON;

-- PRUEBA C4-01. Funcion (resultado esperado para 2*150*(1-0.05) = 285.00).
SELECT dbo.fn_MontoNetoLinea(2, CONVERT(DECIMAL(14,2),150.00),
      CONVERT(DECIMAL(5,4),0.0500)) AS MontoNetoEsperado285,
       dbo.fn_MontoNetoLinea(0, CONVERT(DECIMAL(14,2),150),
      CONVERT(DECIMAL(5,4),0)) AS EntradaInvalidaDevuelveNULL;

-- PRUEBA C4-02. Vista (un registro por pedido) y CASE en GrupoEstado.
SELECT TOP (5) CodigoPedido, NombreCliente, Estado,
       GrupoEstado, TotalLineas, MontoPedido
FROM dbo.vw_ResumenPedidos
ORDER BY PedidoID;

-- PRUEBA C4-03. Procedimiento y COMMIT. Asegurar codigo de prueba reservado.
DECLARE @Codigo VARCHAR(20) = 'PRB-T2-C4-01';
DECLARE @NuevoPedidoID INT;
IF NOT EXISTS (SELECT 1 FROM dbo.Pedidos WHERE CodigoPedido=@Codigo)
BEGIN
    EXEC dbo.usp_RegistrarPedidoPrueba
         @CodigoPedido=@Codigo,
         @ClienteID=1,
         @EmpleadoID=1,
         @ServicioID=1,
         @Cantidad=2,
         @DescuentoPct=0.0500,
         @ForzarError=0,
         @PedidoID=@NuevoPedidoID OUTPUT;
    SELECT N'COMMIT correcto: cabecera + detalle' AS Caso,
           @NuevoPedidoID AS PedidoInsertado;
END
ELSE
BEGIN
    SELECT N'La prueba ya se ejecuto: no se inserto nuevamente' AS Caso,
           PedidoID AS PedidoInsertado
    FROM dbo.Pedidos WHERE CodigoPedido=@Codigo;
END;

SELECT p.PedidoID,p.CodigoPedido,p.Estado,
       COUNT(dp.DetallePedidoID) AS TotalLineas,
       CONVERT(DECIMAL(19,2),ROUND(SUM(dp.Cantidad*dp.PrecioUnitario*(1-dp.DescuentoPct)),2))
           AS ImporteDetalle
FROM dbo.Pedidos AS p
LEFT JOIN dbo.DetallePedido AS dp ON dp.PedidoID=p.PedidoID
WHERE p.CodigoPedido='PRB-T2-C4-01'
GROUP BY p.PedidoID,p.CodigoPedido,p.Estado;

-- PRUEBA C4-04. Trigger: modifica SOLO el pedido de prueba y comprueba auditoria.
UPDATE dbo.Pedidos
SET Estado='EN_PRODUCCION'
WHERE CodigoPedido='PRB-T2-C4-01' AND Estado='REGISTRADO';

SELECT p.CodigoPedido,p.Estado AS EstadoActual,
       a.EstadoAnterior,a.EstadoNuevo,a.FechaCambioUTC,a.UsuarioSQL
FROM dbo.Pedidos AS p
LEFT JOIN dbo.AuditoriaEstadoPedidos AS a ON a.PedidoID=p.PedidoID
WHERE p.CodigoPedido='PRB-T2-C4-01'
ORDER BY a.AuditoriaID;

-- Control: monto del KPI entregado 2025 no cambia por una orden de prueba de hoy.
SELECT CONVERT(DECIMAL(19,2),
          ROUND(SUM(dp.Cantidad*dp.PrecioUnitario*(1-dp.DescuentoPct)),2))
       AS Monto2025EntregadoControl
FROM dbo.Pedidos AS p
JOIN dbo.DetallePedido AS dp ON dp.PedidoID=p.PedidoID
WHERE p.Estado='ENTREGADO' AND p.FechaPedido >= '20250101'
      AND p.FechaPedido < '20260101';
GO
