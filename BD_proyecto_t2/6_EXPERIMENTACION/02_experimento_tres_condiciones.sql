/*
Arte y Publicidad E&D | T2 | EXP-01, EXP-02, EXP-03
SOLO LECTURA DE DATOS EMPRESARIALES: utiliza tablas temporales de sesion para mediciones.
No crea indices, no cambia tablas permanentes, no actualiza ni elimina registros.
Se mide el mismo indicador por ANIO-MES-CATEGORIA en 2025 para pedidos ENTREGADOS.
5 ejecuciones medidas por escenario (15 en total) + 1 calentamiento por escenario.
Orden contrabalanceado predefinido, NO aleatorio.
La comparacion evalua estrategias completas, no el efecto causal aislado de cada componente.
Ejecutar despues de 01_prechequeo_sin_cambios.sql y guardar resultados de SSMS.
*/
USE DW_ArtePublicidadED;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @SQL1 nvarchar(max)=N'
 SELECT YEAR(p.FechaPedido) AS Anio, MONTH(p.FechaPedido) AS Mes,
        cat.NombreCategoria AS Categoria,
        CONVERT(decimal(19,2),ROUND(SUM(d.Cantidad*d.PrecioUnitario*(1-d.DescuentoPct)),2)) AS Monto
 FROM BD_ArtePublicidadED.dbo.Pedidos p
 JOIN BD_ArtePublicidadED.dbo.DetallePedido d ON d.PedidoID=p.PedidoID
 JOIN BD_ArtePublicidadED.dbo.Servicios s ON s.ServicioID=d.ServicioID
 JOIN BD_ArtePublicidadED.dbo.CategoriasServicio cat ON cat.CategoriaID=s.CategoriaID
 WHERE p.Estado=''ENTREGADO'' AND YEAR(p.FechaPedido)=2025
 GROUP BY YEAR(p.FechaPedido),MONTH(p.FechaPedido),cat.NombreCategoria;';

DECLARE @SQL2 nvarchar(max)=N'
 SELECT YEAR(p.FechaPedido) AS Anio, MONTH(p.FechaPedido) AS Mes,
        cat.NombreCategoria AS Categoria,
        CONVERT(decimal(19,2),ROUND(SUM(d.Cantidad*d.PrecioUnitario*(1-d.DescuentoPct)),2)) AS Monto
 FROM BD_ArtePublicidadED.dbo.Pedidos p
 JOIN BD_ArtePublicidadED.dbo.DetallePedido d ON d.PedidoID=p.PedidoID
 JOIN BD_ArtePublicidadED.dbo.Servicios s ON s.ServicioID=d.ServicioID
 JOIN BD_ArtePublicidadED.dbo.CategoriasServicio cat ON cat.CategoriaID=s.CategoriaID
 WHERE p.Estado=''ENTREGADO'' AND p.FechaPedido>=''20250101'' AND p.FechaPedido<''20260101''
 GROUP BY YEAR(p.FechaPedido),MONTH(p.FechaPedido),cat.NombreCategoria;';

DECLARE @SQL3 nvarchar(max)=N'
 SELECT fe.Anio,fe.Mes,sv.NombreCategoria AS Categoria,
        CONVERT(decimal(19,2),ROUND(SUM(f.ImporteNeto),2)) AS Monto
 FROM DW_ArtePublicidadED.dbo.FactVentas f
 JOIN DW_ArtePublicidadED.dbo.DimFecha fe ON fe.FechaKey=f.FechaKey
 JOIN DW_ArtePublicidadED.dbo.DimServicio sv ON sv.ServicioKey=f.ServicioKey
 JOIN DW_ArtePublicidadED.dbo.DimEstadoPedido ep ON ep.EstadoKey=f.EstadoKey
 WHERE ep.Estado=''ENTREGADO'' AND fe.Anio=2025
 GROUP BY fe.Anio,fe.Mes,sv.NombreCategoria;';

CREATE TABLE #ResultadosConsulta (Anio int NOT NULL, Mes int NOT NULL,
 Categoria nvarchar(70) NOT NULL, Monto decimal(19,2) NULL);
CREATE TABLE #Referencia (Anio int NOT NULL, Mes int NOT NULL,
 Categoria nvarchar(70) NOT NULL, Monto decimal(19,2) NULL,
 CONSTRAINT PK_Referencia PRIMARY KEY (Anio,Mes,Categoria));
CREATE TABLE #Metricas (Iteracion tinyint NOT NULL, Escenario varchar(10) NOT NULL,
 DuracionMs decimal(19,3) NOT NULL, Grupos int NOT NULL,
 MontoAgrupado decimal(19,2) NULL, GruposDiferentes int NOT NULL,
 DiferenciaAbsoluta decimal(19,2) NOT NULL, FechaUTC datetime2(7) NOT NULL);

-- Referencia: misma consulta que EXP-02; se excluye de las mediciones.
INSERT INTO #Referencia (Anio,Mes,Categoria,Monto)
EXEC sys.sp_executesql @SQL2;
DECLARE @RefGrupos int=(SELECT COUNT(*) FROM #Referencia);
DECLARE @RefMonto decimal(19,2)=(SELECT SUM(Monto) FROM #Referencia);
IF @RefGrupos=0 OR @RefMonto IS NULL
    THROW 52001, 'No hay resultados de referencia para 2025. Revisar datos y filtro.',1;

-- Calentamiento, no se mide: una vez cada escenario.
INSERT INTO #ResultadosConsulta EXEC sys.sp_executesql @SQL1;
TRUNCATE TABLE #ResultadosConsulta;
INSERT INTO #ResultadosConsulta EXEC sys.sp_executesql @SQL2;
TRUNCATE TABLE #ResultadosConsulta;
INSERT INTO #ResultadosConsulta EXEC sys.sp_executesql @SQL3;
TRUNCATE TABLE #ResultadosConsulta;

CREATE TABLE #Orden(Numero int IDENTITY(1,1) PRIMARY KEY, Iteracion tinyint, Escenario varchar(10));
INSERT INTO #Orden (Iteracion,Escenario) VALUES
 (1,'EXP-01'),(1,'EXP-02'),(1,'EXP-03'),
 (2,'EXP-02'),(2,'EXP-03'),(2,'EXP-01'),
 (3,'EXP-03'),(3,'EXP-01'),(3,'EXP-02'),
 (4,'EXP-01'),(4,'EXP-03'),(4,'EXP-02'),
 (5,'EXP-02'),(5,'EXP-01'),(5,'EXP-03');

DECLARE @i int=1,@n int=(SELECT COUNT(*) FROM #Orden), @Iter tinyint,
 @Escenario varchar(10),@SQL nvarchar(max),
 @Inicio datetime2(7), @Fin datetime2(7),
 @Ms decimal(19,3),@Grupos int,@Monto decimal(19,2),
 @GruposDiferentes int,@Diferencia decimal(19,2);

WHILE @i<=@n
BEGIN
    SELECT @Iter=Iteracion,@Escenario=Escenario FROM #Orden WHERE Numero=@i;
    SET @SQL=CASE @Escenario WHEN 'EXP-01' THEN @SQL1
                             WHEN 'EXP-02' THEN @SQL2 ELSE @SQL3 END;
    TRUNCATE TABLE #ResultadosConsulta;
    SET @Inicio=SYSUTCDATETIME();
    INSERT INTO #ResultadosConsulta (Anio,Mes,Categoria,Monto)
        EXEC sys.sp_executesql @SQL;
    SET @Fin=SYSUTCDATETIME();
    SET @Ms=CONVERT(decimal(19,3),DATEDIFF_BIG(MICROSECOND,@Inicio,@Fin)/1000.0);
    SELECT @Grupos=COUNT(*),@Monto=SUM(Monto) FROM #ResultadosConsulta;
    -- Cuadre completo, por mes y categoria, frente a la referencia.
    ;WITH Comparacion AS (
        SELECT r.Anio AS RAnio, a.Anio AS AAnio, r.Mes AS RMes, a.Mes AS AMes,
               r.Categoria AS RCategoria, a.Categoria AS ACategoria,
               COALESCE(r.Monto,CONVERT(decimal(19,2),0)) AS RMonto,
               COALESCE(a.Monto,CONVERT(decimal(19,2),0)) AS AMonto
        FROM #Referencia r FULL OUTER JOIN #ResultadosConsulta a
          ON a.Anio=r.Anio AND a.Mes=r.Mes AND a.Categoria=r.Categoria
    )
    SELECT @GruposDiferentes=COALESCE(SUM(CASE WHEN RAnio IS NULL OR AAnio IS NULL
                               OR RMonto<>AMonto THEN 1 ELSE 0 END),0),
           @Diferencia=COALESCE(SUM(ABS(RMonto-AMonto)),0)
    FROM Comparacion;
    INSERT INTO #Metricas VALUES(@Iter,@Escenario,@Ms,@Grupos,@Monto,
                               @GruposDiferentes,@Diferencia,SYSUTCDATETIME());
    SET @i+=1;
END;

SELECT 'CONTROLES' AS Seccion,@RefGrupos AS GruposEsperados,
       @RefMonto AS MontoAgrupadoReferencia2025,
       (SELECT COUNT(*) FROM #Metricas) AS EjecucionesMedidas,
       (SELECT COUNT(*) FROM #Metricas WHERE GruposDiferentes>0 OR DiferenciaAbsoluta>0
                    OR Grupos<>@RefGrupos) AS EjecucionesConDiferencia;

SELECT Iteracion,Escenario,DuracionMs,Grupos,MontoAgrupado,GruposDiferentes,
       DiferenciaAbsoluta,FechaUTC
FROM #Metricas ORDER BY Iteracion,
 CASE Escenario WHEN 'EXP-01' THEN 1 WHEN 'EXP-02' THEN 2 ELSE 3 END;

;WITH Estadistica AS (
 SELECT Escenario,DuracionMs,GruposDiferentes,
   PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY DuracionMs)
       OVER (PARTITION BY Escenario) AS Mediana,
   PERCENTILE_CONT(0.95) WITHIN GROUP(ORDER BY DuracionMs)
       OVER (PARTITION BY Escenario) AS P95
 FROM #Metricas
)
SELECT Escenario,COUNT(*) AS Repeticiones,
       MIN(DuracionMs) AS MinMs,MAX(DuracionMs) AS MaxMs,
       CONVERT(decimal(19,3),MAX(Mediana)) AS MedianaMs,
       CONVERT(decimal(19,3),MAX(P95)) AS P95DescriptivoMs,
       SUM(CASE WHEN GruposDiferentes>0 THEN 1 ELSE 0 END) AS CorridasConDiferencias
FROM Estadistica GROUP BY Escenario ORDER BY Escenario;

-- Resultados de referencia para respaldo y verificaciones.
SELECT TOP(12) Anio,Mes,Categoria,Monto
FROM #Referencia ORDER BY Anio,Mes,Categoria;
GO
