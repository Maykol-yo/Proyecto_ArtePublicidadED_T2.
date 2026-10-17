/*
PROYECTO ACADEMICO: Arte y Publicidad E&D
Script 01 - Base transaccional original (OLTP)
Motor: Microsoft SQL Server (T-SQL)
Datos: exclusivamente sinteticos. No corresponde a la infraestructura real de la empresa.
CUIDADO: este script NO elimina bases ni tablas existentes. Ejecucion inicial una sola vez.
*/

USE master;
GO
IF DB_ID(N'BD_ArtePublicidadED') IS NULL
    EXEC(N'CREATE DATABASE BD_ArtePublicidadED');
GO
USE BD_ArtePublicidadED;
GO
SET NOCOUNT ON;
GO
IF OBJECT_ID(N'dbo.Clientes', N'U') IS NOT NULL
    THROW 50001, N'La estructura ya existe. No ejecute de nuevo el script 01.', 1;
GO

CREATE TABLE dbo.Clientes (
    ClienteID INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Clientes PRIMARY KEY,
    CodigoCliente VARCHAR(20) NOT NULL CONSTRAINT UQ_Clientes_Codigo UNIQUE,
    NombreCliente NVARCHAR(120) NOT NULL,
    TipoCliente VARCHAR(15) NOT NULL,
    Correo NVARCHAR(150) NULL,
    FechaRegistro DATE NOT NULL CONSTRAINT DF_Clientes_Fecha DEFAULT (CONVERT(DATE, GETDATE())),
    CONSTRAINT CK_Clientes_Tipo CHECK (TipoCliente IN ('PERSONA','EMPRESA'))
);
GO
CREATE TABLE dbo.Empleados (
    EmpleadoID INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Empleados PRIMARY KEY,
    NombreEmpleado NVARCHAR(100) NOT NULL,
    Cargo NVARCHAR(60) NOT NULL,
    Activo BIT NOT NULL CONSTRAINT DF_Empleados_Activo DEFAULT(1)
);
GO
CREATE TABLE dbo.CategoriasServicio (
    CategoriaID INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_CategoriasServicio PRIMARY KEY,
    NombreCategoria NVARCHAR(70) NOT NULL CONSTRAINT UQ_CategoriasServicio_Nombre UNIQUE
);
GO
CREATE TABLE dbo.Servicios (
    ServicioID INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Servicios PRIMARY KEY,
    CategoriaID INT NOT NULL,
    NombreServicio NVARCHAR(100) NOT NULL CONSTRAINT UQ_Servicios_Nombre UNIQUE,
    PrecioReferencial DECIMAL(14,2) NOT NULL,
    Activo BIT NOT NULL CONSTRAINT DF_Servicios_Activo DEFAULT(1),
    CONSTRAINT FK_Servicios_Categoria FOREIGN KEY (CategoriaID) REFERENCES dbo.CategoriasServicio(CategoriaID),
    CONSTRAINT CK_Servicios_Precio CHECK (PrecioReferencial >= 0)
);
GO
CREATE TABLE dbo.Cotizaciones (
    CotizacionID INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Cotizaciones PRIMARY KEY,
    CodigoCotizacion VARCHAR(20) NOT NULL CONSTRAINT UQ_Cotizaciones_Codigo UNIQUE,
    ClienteID INT NOT NULL,
    EmpleadoID INT NOT NULL,
    FechaCotizacion DATE NOT NULL,
    Estado VARCHAR(12) NOT NULL,
    CONSTRAINT FK_Cotizaciones_Cliente FOREIGN KEY (ClienteID) REFERENCES dbo.Clientes(ClienteID),
    CONSTRAINT FK_Cotizaciones_Empleado FOREIGN KEY (EmpleadoID) REFERENCES dbo.Empleados(EmpleadoID),
    CONSTRAINT CK_Cotizaciones_Estado CHECK (Estado IN ('PENDIENTE','APROBADA','RECHAZADA','VENCIDA'))
);
GO
CREATE TABLE dbo.DetalleCotizacion (
    DetalleCotizacionID INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DetalleCotizacion PRIMARY KEY,
    CotizacionID INT NOT NULL,
    ServicioID INT NOT NULL,
    Cantidad INT NOT NULL,
    PrecioUnitario DECIMAL(14,2) NOT NULL,
    DescuentoPct DECIMAL(5,4) NOT NULL CONSTRAINT DF_DetalleCotizacion_Dto DEFAULT(0),
    CONSTRAINT FK_DetalleCotizacion_Cotizacion FOREIGN KEY (CotizacionID) REFERENCES dbo.Cotizaciones(CotizacionID),
    CONSTRAINT FK_DetalleCotizacion_Servicio FOREIGN KEY (ServicioID) REFERENCES dbo.Servicios(ServicioID),
    CONSTRAINT CK_DetalleCotizacion_Cantidad CHECK (Cantidad > 0),
    CONSTRAINT CK_DetalleCotizacion_Precio CHECK (PrecioUnitario >= 0),
    CONSTRAINT CK_DetalleCotizacion_Descuento CHECK (DescuentoPct BETWEEN 0 AND 1)
);
GO
CREATE TABLE dbo.Pedidos (
    PedidoID INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Pedidos PRIMARY KEY,
    CodigoPedido VARCHAR(20) NOT NULL CONSTRAINT UQ_Pedidos_Codigo UNIQUE,
    CotizacionID INT NULL,
    ClienteID INT NOT NULL,
    EmpleadoID INT NOT NULL,
    FechaPedido DATE NOT NULL,
    Estado VARCHAR(16) NOT NULL,
    CONSTRAINT FK_Pedidos_Cotizacion FOREIGN KEY (CotizacionID) REFERENCES dbo.Cotizaciones(CotizacionID),
    CONSTRAINT FK_Pedidos_Cliente FOREIGN KEY (ClienteID) REFERENCES dbo.Clientes(ClienteID),
    CONSTRAINT FK_Pedidos_Empleado FOREIGN KEY (EmpleadoID) REFERENCES dbo.Empleados(EmpleadoID),
    CONSTRAINT CK_Pedidos_Estado CHECK (Estado IN ('REGISTRADO','EN_PRODUCCION','ENTREGADO','CANCELADO'))
);
GO
CREATE UNIQUE INDEX UX_Pedidos_Cotizacion
    ON dbo.Pedidos(CotizacionID) WHERE CotizacionID IS NOT NULL;
GO
CREATE TABLE dbo.DetallePedido (
    DetallePedidoID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DetallePedido PRIMARY KEY,
    PedidoID INT NOT NULL,
    ServicioID INT NOT NULL,
    Cantidad INT NOT NULL,
    PrecioUnitario DECIMAL(14,2) NOT NULL,
    DescuentoPct DECIMAL(5,4) NOT NULL CONSTRAINT DF_DetallePedido_Dto DEFAULT(0),
    CONSTRAINT FK_DetallePedido_Pedido FOREIGN KEY (PedidoID) REFERENCES dbo.Pedidos(PedidoID),
    CONSTRAINT FK_DetallePedido_Servicio FOREIGN KEY (ServicioID) REFERENCES dbo.Servicios(ServicioID),
    CONSTRAINT CK_DetallePedido_Cantidad CHECK (Cantidad > 0),
    CONSTRAINT CK_DetallePedido_Precio CHECK (PrecioUnitario >= 0),
    CONSTRAINT CK_DetallePedido_Descuento CHECK (DescuentoPct BETWEEN 0 AND 1)
);
GO
CREATE TABLE dbo.Pagos (
    PagoID INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Pagos PRIMARY KEY,
    PedidoID INT NOT NULL,
    FechaPago DATE NOT NULL,
    Monto DECIMAL(18,2) NOT NULL,
    MedioPago VARCHAR(15) NOT NULL,
    Estado VARCHAR(12) NOT NULL,
    CONSTRAINT FK_Pagos_Pedido FOREIGN KEY (PedidoID) REFERENCES dbo.Pedidos(PedidoID),
    CONSTRAINT CK_Pagos_Monto CHECK (Monto > 0),
    CONSTRAINT CK_Pagos_Medio CHECK (MedioPago IN ('EFECTIVO','TARJETA','TRANSFERENCIA','YAPE')),
    CONSTRAINT CK_Pagos_Estado CHECK (Estado IN ('CONFIRMADO','PENDIENTE','ANULADO'))
);
GO
CREATE TABLE dbo.Proveedores (
    ProveedorID INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Proveedores PRIMARY KEY,
    NombreProveedor NVARCHAR(120) NOT NULL,
    Activo BIT NOT NULL CONSTRAINT DF_Proveedores_Activo DEFAULT(1)
);
GO
CREATE TABLE dbo.Materiales (
    MaterialID INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Materiales PRIMARY KEY,
    NombreMaterial NVARCHAR(100) NOT NULL CONSTRAINT UQ_Materiales_Nombre UNIQUE,
    UnidadMedida VARCHAR(20) NOT NULL,
    StockMinimo DECIMAL(14,2) NOT NULL CONSTRAINT DF_Materiales_Minimo DEFAULT(0),
    CONSTRAINT CK_Materiales_Minimo CHECK (StockMinimo >= 0)
);
GO
CREATE TABLE dbo.Compras (
    CompraID INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Compras PRIMARY KEY,
    ProveedorID INT NOT NULL,
    EmpleadoID INT NOT NULL,
    FechaCompra DATE NOT NULL,
    Estado VARCHAR(12) NOT NULL,
    CONSTRAINT FK_Compras_Proveedor FOREIGN KEY (ProveedorID) REFERENCES dbo.Proveedores(ProveedorID),
    CONSTRAINT FK_Compras_Empleado FOREIGN KEY (EmpleadoID) REFERENCES dbo.Empleados(EmpleadoID),
    CONSTRAINT CK_Compras_Estado CHECK (Estado IN ('PENDIENTE','RECIBIDA','ANULADA'))
);
GO
CREATE TABLE dbo.DetalleCompra (
    DetalleCompraID INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DetalleCompra PRIMARY KEY,
    CompraID INT NOT NULL,
    MaterialID INT NOT NULL,
    Cantidad DECIMAL(14,2) NOT NULL,
    CostoUnitario DECIMAL(14,2) NOT NULL,
    CONSTRAINT FK_DetalleCompra_Compra FOREIGN KEY (CompraID) REFERENCES dbo.Compras(CompraID),
    CONSTRAINT FK_DetalleCompra_Material FOREIGN KEY (MaterialID) REFERENCES dbo.Materiales(MaterialID),
    CONSTRAINT CK_DetalleCompra_Cantidad CHECK (Cantidad > 0),
    CONSTRAINT CK_DetalleCompra_Costo CHECK (CostoUnitario >= 0)
);
GO
CREATE TABLE dbo.MovimientosMaterial (
    MovimientoID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_MovimientosMaterial PRIMARY KEY,
    MaterialID INT NOT NULL,
    DetalleCompraID INT NULL,
    PedidoID INT NULL,
    FechaMovimiento DATE NOT NULL,
    TipoMovimiento VARCHAR(7) NOT NULL,
    Cantidad DECIMAL(14,2) NOT NULL,
    CONSTRAINT FK_Movimientos_Material FOREIGN KEY (MaterialID) REFERENCES dbo.Materiales(MaterialID),
    CONSTRAINT FK_Movimientos_Compra FOREIGN KEY (DetalleCompraID) REFERENCES dbo.DetalleCompra(DetalleCompraID),
    CONSTRAINT FK_Movimientos_Pedido FOREIGN KEY (PedidoID) REFERENCES dbo.Pedidos(PedidoID),
    CONSTRAINT CK_Movimientos_Cantidad CHECK (Cantidad > 0),
    CONSTRAINT CK_Movimientos_Tipo CHECK (
      (TipoMovimiento = 'ENTRADA' AND DetalleCompraID IS NOT NULL AND PedidoID IS NULL)
      OR (TipoMovimiento = 'SALIDA' AND DetalleCompraID IS NULL AND PedidoID IS NOT NULL)
    )
);
GO
CREATE UNIQUE INDEX UX_Movimientos_CompraDetalle
    ON dbo.MovimientosMaterial(DetalleCompraID) WHERE DetalleCompraID IS NOT NULL;
GO

-- Mantener intencionalmente sin indices analiticos adicionales: la linea base se evaluara despues.
SELECT N'Estructura OLTP creada correctamente' AS Mensaje,
       (SELECT COUNT(*) FROM sys.tables WHERE schema_id = SCHEMA_ID('dbo')) AS TablasUsuario;
GO
