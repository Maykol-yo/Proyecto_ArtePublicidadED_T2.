# Proyecto Arte y Publicidad E&D — T2

## Bases de Datos Avanzadas y Big Data

**Universidad:** Universidad Privada del Norte (UPN)  
**Carrera:** Ingeniería de Sistemas Computacionales  
**Campus:** Cajamarca  
**Periodo académico:** 2026-2  
**NRC:** 16025  
**Docente:** Patricia Janet Uceda Martos

## Integrantes

- Luzmila Chilon Sangay
- Ruth Berania Huaman Cuenca
- Maykol Edinson Marin Ortiz
- Eberth Daniel Sanchez Llamoctanta

## 1. Descripción del proyecto

Este proyecto académico desarrolla una solución de gestión, integración y análisis de datos para la empresa simulada **Arte y Publicidad E&D**, dedicada a servicios de impresión, diseño gráfico, publicidad y merchandising.

La solución utiliza una base de datos transaccional en SQL Server, automatización mediante T-SQL, almacenamiento documental con MongoDB, un Data Mart dimensional, procesos ETL con SQL Server Integration Services (SSIS), consultas OLAP y visualizaciones mediante Power BI.

Se emplean datos sintéticos para realizar las pruebas y evaluaciones.

## 2. Objetivo del proyecto

Implementar y evaluar una solución de bases de datos avanzadas y análisis de información que permita mejorar la organización, integración, procesamiento y consulta de los datos de pedidos y ventas de Arte y Publicidad E&D.

## 3. Tecnologías utilizadas

| Tecnología | Aplicación |
|---|---|
| Microsoft SQL Server | Base de datos transaccional y Data Mart |
| SQL Server Management Studio | Consultas, procedimientos y validaciones |
| MongoDB Compass y mongosh | Gestión documental y operaciones CRUD |
| Visual Studio + SSIS | Diseño y ejecución de procesos ETL |
| Power BI Desktop | Dashboard comercial e indicadores |
| GitHub | Almacenamiento de scripts, proyectos y evidencias |

## 4. Componentes desarrollados

### 4.1. Base de datos transaccional

Se implementó `BD_ArtePublicidadED`, con tablas relacionadas para administrar clientes, empleados, servicios, pedidos, detalles de pedidos y otras operaciones de negocio.

Se generaron datos sintéticos para simular el funcionamiento histórico de la empresa.

### 4.2. Automatización con SQL Server

Se implementaron objetos de base de datos como procedimientos almacenados, vistas, funciones, triggers y transacciones.

También se realizaron pruebas de integridad, auditoría y recuperación mediante rollback.

### 4.3. Base de datos NoSQL

Se implementó `BD_ArtePublicidadED_NoSQL` en MongoDB, con la colección `pedidosPersonalizadosT2`.

Se realizaron operaciones CRUD, consultas y verificaciones sobre documentos con distintas especificaciones de servicios.

### 4.4. Data Mart y procesamiento ETL

Se creó `DW_ArtePublicidadED` utilizando un modelo dimensional de tipo estrella.

El modelo incluye:

- `DimCliente`
- `DimServicio`
- `DimEmpleado`
- `DimFecha`
- `DimEstadoPedido`
- `FactVentas`

Se implementaron procesos ETL en T-SQL con controles de calidad, auditoría de carga y verificación de importes.

### 4.5. Integración de datos mediante SSIS

Se desarrolló un proyecto en Visual Studio utilizando **SQL Server Integration Services (SSIS)**.

El proyecto contiene cinco paquetes:

| Paquete | Función |
|---|---|
| `00_Master.dtsx` | Ejecuta los paquetes en orden |
| `01_Extract_Staging.dtsx` | Extrae y carga datos en staging |
| `02_Load_Dimensions.dtsx` | Carga y actualiza dimensiones |
| `03_Load_FactVentas.dtsx` | Inserta ventas pendientes |
| `04_Validaciones.dtsx` | Comprueba integridad, duplicados e importes |

El paquete Master ejecuta secuencialmente los cuatro procesos y fue probado satisfactoriamente en Visual Studio.

**Ruta del proyecto SSIS:** `BD_proyecto_t2/4_DATA_MART_ETL/SSIS/`

El proyecto incluye el archivo de solución `.slnx`, el archivo `.dtproj`, los paquetes `.dtsx` y los administradores de conexión.

### 4.6. Business Intelligence y OLAP

Se realizaron consultas analíticas para estudiar las ventas por mes, categoría de servicio y tipo de cliente.

Se creó un dashboard en Power BI con indicadores comerciales y filtros interactivos para analizar los pedidos entregados durante 2025.

### 4.7. Experimentación

Se evaluaron tres escenarios de consulta sobre datos sintéticos:

| Escenario | Mediana | P95 descriptivo |
|---|---:|---:|
| EXP-01: Consulta original | 176,159 ms | 195,812 ms |
| EXP-02: Consulta modificada | 37,883 ms | 45,365 ms |
| EXP-03: Consulta al Data Mart | 28,103 ms | 29,637 ms |

Se realizaron cinco repeticiones por escenario y se verificaron 48 grupos de análisis, sin diferencias detectadas en los importes.

En esta ejecución experimental, el Data Mart presentó la menor mediana de duración.

## 5. Resultados de validación del ETL SSIS

Después de ejecutar el paquete `00_Master.dtsx`, se obtuvieron los siguientes resultados:

| Indicador | Resultado |
|---|---:|
| Filas cargadas en staging | 30 119 |
| Registros en FactVentas | 30 119 |
| Detalles de pedido únicos | 30 119 |
| Registros duplicados | 0 |
| Ventas pendientes | 0 |
| Importe neto total | 20 463 594,40 |

Las verificaciones confirmaron la consistencia de los recuentos e importes después de ejecutar el proceso completo.

El resultado de **4 511 603,65** corresponde específicamente al análisis de pedidos entregados durante 2025.

## 6. Estructura del repositorio

El directorio principal `BD_proyecto_t2` organiza los materiales del proyecto en las siguientes áreas:

1. Base de datos: scripts de creación, generación de datos y verificaciones.
2. Automatización: objetos SQL y pruebas transaccionales.
3. NoSQL: comandos MongoDB y evidencias CRUD.
4. Data Mart y ETL: modelo dimensional, scripts, validaciones, evidencias y proyecto SSIS.
5. BI y OLAP: consultas analíticas y dashboard Power BI.
6. Experimentación: escenarios, mediciones y resultados.
7. Informe: documentación académica y referencias.

## 7. Ejecución del proyecto SSIS

Para revisar y ejecutar la solución:

1. Tener instalado SQL Server y restaurar o preparar las bases de datos requeridas.
2. Abrir Visual Studio con la extensión SQL Server Integration Services Projects.
3. Abrir la solución `Integration Services Project1.slnx`.
4. Configurar las conexiones `CM_ArtePublicidad_OLTP` y `CM_ArtePublicidad_DW` según el entorno local.
5. Verificar la existencia de las tablas y datos de origen y destino.
6. Abrir y ejecutar `00_Master.dtsx`.
7. Revisar los resultados y verificar las cantidades e importes en SQL Server.

**Precaución:** los paquetes están diseñados para el entorno académico utilizado en las pruebas. Antes de ejecutarlos en otra instalación se deben revisar las conexiones, los datos iniciales y las condiciones de recarga.

## 8. Evidencias

El repositorio incluye capturas de las consultas SQL, operaciones MongoDB, validaciones del Data Mart, visualizaciones de Power BI y ejecuciones SSIS.

Entre las evidencias finales del proceso SSIS se encuentran:

- `CAP-33`: primera carga SSIS.
- `CAP-34`: validación inicial de staging.
- `CAP-35` y `CAP-36`: recarga y comprobación de duplicados.
- `CAP-37` y `CAP-38`: carga y validación de dimensiones.
- `CAP-39` y `CAP-40`: ejecución y validación de FactVentas.
- `CAP-41`: validaciones SSIS.
- `CAP-42`: ejecución del paquete Master.
- `CAP-43`: validación final del Data Mart.

## 9. Consideraciones académicas

Este repositorio corresponde a un proyecto universitario desarrollado con fines de aprendizaje y evaluación.

Los datos utilizados son sintéticos y no representan registros reales ni resultados operativos de la empresa Arte y Publicidad E&D.
