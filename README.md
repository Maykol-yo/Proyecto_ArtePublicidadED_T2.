
# Proyecto Arte y Publicidad E&D

## Curso
**Bases de Datos Avanzadas y Big Data**

Ingeniería de Sistemas Computacionales - UPN  
Periodo académico: 2026-2

## 1. Descripción del proyecto

El presente proyecto académico desarrolla una solución de Inteligencia de Negocios para la empresa Arte y Publicidad E&D, dedicada a los servicios de diseño gráfico, publicidad, impresión y merchandising.

Se construyó una base de datos transaccional con información sintética para simular las operaciones comerciales de la empresa y evaluar los problemas de rendimiento asociados con la generación de reportes históricos de pedidos y ventas.

## 2. Problema identificado

El crecimiento de los registros históricos puede ocasionar dificultades en el rendimiento de las consultas comerciales.

Se busca evaluar cómo la optimización de consultas y la implementación de un Data Mart contribuyen a mejorar el procesamiento y análisis de información.

## 3. Objetivo del proyecto

Implementar y evaluar una solución de Inteligencia de Negocios mediante SQL Server, programación T-SQL, modelado dimensional, procesos ETL y Power BI, complementada con ejercicios NoSQL y una propuesta inicial de arquitectura Big Data.

## 4. Tecnologías utilizadas

- Microsoft SQL Server
- SQL Server Management Studio (SSMS)
- MongoDB y MongoDB Compass
- Microsoft Power BI Desktop
- T-SQL
- DAX
- GitHub

## 5. Bases de datos

### Base transaccional
`BD_ArtePublicidadED`

Almacena clientes, servicios, cotizaciones, pedidos, pagos, compras y materiales.

### Data Mart
`DW_ArtePublicidadED`

Implementa un modelo dimensional tipo estrella para analizar los pedidos y ventas históricos.

### Base NoSQL
`BD_ArtePublicidadED_NoSQL`

Contiene documentos con las especificaciones de servicios personalizados.

## 6. Estructura del proyecto

Las carpetas contienen:

**1_base de datos:** scripts de creación, generación de datos sintéticos y verificaciones.

**2_Automatizacion:** procedimientos almacenados, vistas, funciones, triggers y transacciones.

**3_NoSQL:** implementación y pruebas de operaciones CRUD en MongoDB.

**4_DATA_MART_ETL:** diseño dimensional, procedimiento ETL, auditoría y validaciones.

**5_BI_OLAP:** consultas analíticas, modelo Power BI y dashboard comercial.

**6_EXPERIMENTACION:** scripts, mediciones, diseño experimental y evidencias.

**7_Informe:** documentación académica e informe T2.

## 7. Implementación

### SQL Server
1. Crear la base de datos transaccional.
2. Ejecutar la generación de datos sintéticos.
3. Ejecutar las verificaciones de integridad.
4. Implementar los objetos de automatización T-SQL.
5. Crear el Data Mart dimensional.
6. Ejecutar el procedimiento ETL.
7. Validar la carga y los indicadores.

### MongoDB
Ejecutar los scripts JavaScript del directorio NoSQL en el orden indicado para demostrar las operaciones CREATE, READ, UPDATE y DELETE.

### Power BI
Abrir el archivo `Dashboard_ArtePublicidadED_T2.pbix` y configurar la conexión a `DW_ArtePublicidadED`.

## 8. Resultados obtenidos

En las verificaciones realizadas se registraron:

- 30 119 filas en la tabla de hechos.
- 0 registros rechazados durante la carga ETL.
- Cargas ETL repetidas sin duplicación de hechos.
- Importe de pedidos entregados en 2025: 4 511 603,65.
- Diferencia monetaria entre OLTP y Data Mart: 0,00.

### Resultados experimentales

Se compararon tres escenarios con cinco repeticiones por condición.

| Escenario | Mediana (ms) |
|-----------|-------------:|
| EXP-01: Consulta original | 176,159 |
| EXP-02: Consulta modificada | 37,883 |
| EXP-03: Consulta Data Mart | 28,103 |

Los valores corresponden a una corrida experimental con datos sintéticos y no representan mediciones de una empresa real.

## 9. Inteligencia de Negocios

El dashboard de Power BI incluye:

- Indicador de pedidos entregados.
- Análisis mensual de ventas.
- Comparación por categoría de servicio.
- Comparación por tipo de cliente.
- Filtros interactivos por categoría y mes.

## 10. Evidencias

Las carpetas del proyecto contienen scripts ejecutables y capturas que documentan la implementación y las pruebas.

## 11. Consideraciones éticas

El proyecto utiliza datos sintéticos generados con fines académicos.

Los resultados experimentales se limitan al entorno, los datos y las condiciones evaluadas.

Se empleó asistencia de inteligencia artificial durante el desarrollo y documentación del proyecto. El código y los resultados requieren validación por parte del equipo.

## 12. Estado del proyecto

Implementación de SQL Server, NoSQL, Data Mart, ETL y Power BI desarrollada para la T2.

La arquitectura distribuida Big Data queda como propuesta para las siguientes etapas académicas.

---
**Universidad Privada del Norte - 2026**
