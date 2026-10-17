/*
Archivo 04: C4, demostracion de ciclo WHILE en un alcance pequeno.
Compara un conteo mes por mes usando WHILE con un GROUP BY por conjuntos.
Justificacion: WHILE se usa solo como demostracion de control de flujo;
para informes y ETL reales se prefiere SQL por conjuntos.
*/
USE BD_ArtePublicidadED;
GO
SET NOCOUNT ON;

DECLARE @Mes INT=1, @InicioMes DATE, @FinMes DATE;
DECLARE @ConteoCiclo TABLE (Mes INT PRIMARY KEY, Pedidos BIGINT NOT NULL);

WHILE @Mes <= 3
BEGIN
    SET @InicioMes = DATEFROMPARTS(2025, @Mes, 1);
    SET @FinMes = DATEADD(MONTH, 1, @InicioMes);
    INSERT INTO @ConteoCiclo (Mes, Pedidos)
    SELECT @Mes, COUNT_BIG(*)
    FROM dbo.Pedidos
    WHERE FechaPedido >= @InicioMes AND FechaPedido < @FinMes;
    SET @Mes = @Mes+1;
END;

SELECT c.Mes, c.Pedidos AS PedidosConWHILE,
       COALESCE(g.Pedidos,CONVERT(BIGINT,0)) AS PedidosPorConjuntos,
       c.Pedidos - COALESCE(g.Pedidos,CONVERT(BIGINT,0)) AS Diferencia
FROM @ConteoCiclo AS c
LEFT JOIN
(
    SELECT MONTH(FechaPedido) AS Mes, COUNT_BIG(*) AS Pedidos
    FROM dbo.Pedidos
    WHERE FechaPedido >= '20250101' AND FechaPedido < '20250401'
    GROUP BY MONTH(FechaPedido)
) AS g ON g.Mes=c.Mes
ORDER BY c.Mes;
GO
