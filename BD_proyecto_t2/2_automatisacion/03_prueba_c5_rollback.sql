/*
Archivo 03: prueba C5 del error controlado y recuperacion mediante ROLLBACK.
NO requiere restaurar base ni borra datos. Seguro para reejecutar si el codigo
PRB-T2-ERR-01 no existe: la transaccion fallida no deja datos persistidos.
*/
USE BD_ArtePublicidadED;
GO
SET NOCOUNT ON;

DECLARE @Codigo VARCHAR(20) = 'PRB-T2-ERR-01';
DECLARE @FallidoPedidoID INT;

-- Estado ANTES (normalmente 0 pedidos y 0 lineas con este codigo).
SELECT N'ANTES del intento fallido' AS Momento,
       COUNT(*) AS Cabeceras,
       (SELECT COUNT(*) FROM dbo.DetallePedido AS dp
        JOIN dbo.Pedidos AS p ON p.PedidoID=dp.PedidoID
        WHERE p.CodigoPedido=@Codigo) AS Lineas
FROM dbo.Pedidos WHERE CodigoPedido=@Codigo;

BEGIN TRY
    IF EXISTS (SELECT 1 FROM dbo.Pedidos WHERE CodigoPedido=@Codigo)
        THROW 51011, N'El codigo de error ya existe; escoja otro codigo PRB-.', 1;

    EXEC dbo.usp_RegistrarPedidoPrueba
         @CodigoPedido=@Codigo,
         @ClienteID=1,
         @EmpleadoID=1,
         @ServicioID=1,
         @Cantidad=3,
         @DescuentoPct=0,
         @ForzarError=1,
         @PedidoID=@FallidoPedidoID OUTPUT;

    SELECT N'Inesperado: la operacion debio lanzar error' AS Advertencia;
END TRY
BEGIN CATCH
    SELECT N'Error capturado por la prueba (ESPERADO)' AS Resultado,
           ERROR_NUMBER() AS NumeroError,
           ERROR_MESSAGE() AS MensajeError,
           XACT_STATE() AS EstadoTransaccion,
           @@TRANCOUNT AS TransaccionesAbiertas;
END CATCH;

-- Estado DESPUES: debe ser 0 cabeceras y 0 lineas; la prueba registra la evidencia.
SELECT N'DESPUES del ROLLBACK' AS Momento,
       COUNT(*) AS Cabeceras,
       (SELECT COUNT(*) FROM dbo.DetallePedido AS dp
        JOIN dbo.Pedidos AS p ON p.PedidoID=dp.PedidoID
        WHERE p.CodigoPedido=@Codigo) AS Lineas
FROM dbo.Pedidos WHERE CodigoPedido=@Codigo;

IF EXISTS(SELECT 1 FROM dbo.Pedidos WHERE CodigoPedido=@Codigo)
    THROW 51012, N'FALLO DE PRUEBA: la cabecera persiste tras el error.', 1;
IF @@TRANCOUNT <> 0
    THROW 51013, N'FALLO DE PRUEBA: quedo una transaccion abierta.', 1;
SELECT N'C5 APROBADO: ningun registro parcial y ninguna transaccion abierta' AS Verificacion;
GO
