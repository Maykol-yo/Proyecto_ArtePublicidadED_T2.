/* C6 - C: CREATE. Inserta UN documento ficticio temporal, sin tocar SQL Server. */
(function () {
  const pedidos = db.getSiblingDB("BD_ArtePublicidadED_NoSQL")
    .getCollection("pedidosPersonalizadosT2");
  const id = "C6-CRUD-TEMP-001";
  const doc = {
    _id: id,
    codigoPedido: "NOSQL-T2-CRUD-001",
    tipoRegistro: "PRUEBA_CRUD_T2",
    clienteFicticio: "Cliente de prueba CRUD",
    categoriaServicio: "Impresion",
    servicio: "Impresion de banners",
    estado: "REGISTRADO",
    fechaSolicitud: ISODate("2025-10-01T09:00:00Z"),
    cantidad: 1,
    especificaciones: {
      anchoCm: 120,
      altoCm: 60,
      material: "Lona",
      acabado: "Sin laminar",
      archivoDiseno: { nombre: "prueba_crud.pdf", esFicticio: true }
    }
  };
  print("== 02: CREATE ==");
  if (pedidos.findOne({ _id: id }) !== null) {
    print("El documento de prueba ya existe. No se duplica. Si deseas repetir CREATE, ejecuta el archivo 05 para borrarlo primero.");
  } else {
    const r = pedidos.insertOne(doc);
    printjson({ operacion: "insertOne", acknowledged: r.acknowledged, insertedId: r.insertedId });
  }
  const creado = pedidos.findOne({ _id: id });
  printjson(creado);
  if (creado === null) throw new Error("CREATE no se verifico: el documento no existe.");
})();
