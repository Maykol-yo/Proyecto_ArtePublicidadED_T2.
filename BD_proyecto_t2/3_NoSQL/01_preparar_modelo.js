/*
  Arte y Publicidad E&D | T2 | C6 NoSQL
  01 - Preparar base documental y TRES pedidos ficticios.
  Motor: MongoDB (ejecutar en mongosh / consola de MongoDB Compass).
  No lee ni modifica SQL Server. No elimina ninguna colección ni documento.
  Repetible: usa upsert con $setOnInsert únicamente para las 3 semillas de práctica.
*/
(function () {
  const base = db.getSiblingDB("BD_ArtePublicidadED_NoSQL");
  const nombreColeccion = "pedidosPersonalizadosT2";
  if (!base.getCollectionNames().includes(nombreColeccion)) {
    base.createCollection(nombreColeccion);
  }
  const pedidos = base.getCollection(nombreColeccion);
  pedidos.createIndex({ codigoPedido: 1 }, { unique: true, name: "ux_codigoPedido_t2" });

  // La forma de especificaciones cambia según el tipo de servicio.
  // Todos los datos son inventados; el campo clienteFicticio NO es un cliente real.
  const semillas = [
    {
      _id: "C6-SEM-IMP-001",
      codigoPedido: "NOSQL-T2-IMP-001",
      tipoRegistro: "SEMILLA_T2",
      clienteFicticio: "Cliente de prueba A",
      categoriaServicio: "Impresion",
      servicio: "Impresion de banners",
      estado: "REGISTRADO",
      fechaSolicitud: ISODate("2025-08-12T10:00:00Z"),
      cantidad: 2,
      especificaciones: {
        anchoCm: 150,
        altoCm: 80,
        material: "Lona",
        acabado: "Sin laminar",
        archivoDiseno: { nombre: "banner_ejemplo.pdf", formato: "PDF", esFicticio: true }
      }
    },
    {
      _id: "C6-SEM-DIS-002",
      codigoPedido: "NOSQL-T2-DIS-002",
      tipoRegistro: "SEMILLA_T2",
      clienteFicticio: "Cliente de prueba B",
      categoriaServicio: "Diseno grafico",
      servicio: "Diseno de logotipo",
      estado: "EN_PRODUCCION",
      fechaSolicitud: ISODate("2025-09-03T11:30:00Z"),
      cantidad: 1,
      especificaciones: {
        coloresPreferidos: ["Azul", "Blanco"],
        estilo: "Minimalista",
        formatosEntrega: ["PNG", "SVG", "PDF"],
        revisionesPermitidas: 3
      }
    },
    {
      _id: "C6-SEM-MER-003",
      codigoPedido: "NOSQL-T2-MER-003",
      tipoRegistro: "SEMILLA_T2",
      clienteFicticio: "Cliente de prueba C",
      categoriaServicio: "Merchandising",
      servicio: "Polos personalizados",
      estado: "ENTREGADO",
      fechaSolicitud: ISODate("2025-09-15T09:15:00Z"),
      cantidad: 25,
      especificaciones: {
        tecnica: "Serigrafia",
        colorTela: "Negro",
        tallas: [
          { talla: "S", unidades: 5 },
          { talla: "M", unidades: 10 },
          { talla: "L", unidades: 10 }
        ],
        ubicacionEstampado: "Pecho"
      }
    }
  ];

  print("== 01: PREPARAR MODELO DOCUMENTAL ==");
  for (const doc of semillas) {
    // En upsert, la _id viene del filtro; las demás propiedades se agregan al insertar.
    const { _id, ...atributos } = doc;
    const r = pedidos.updateOne(
      { _id: _id },
      { $setOnInsert: atributos },
      { upsert: true }
    );
    print(doc._id + ": " + (r.upsertedCount === 1 ? "CREADO" : "YA EXISTIA; CONSERVADO"));
  }
  printjson({
    base: base.getName(),
    coleccion: nombreColeccion,
    documentosSemilla: pedidos.countDocuments({ tipoRegistro: "SEMILLA_T2" }),
    indices: pedidos.getIndexes().map(i => i.name)
  });
  print("Listo. La forma de 'especificaciones' es distinta por tipo de servicio.");
})();
