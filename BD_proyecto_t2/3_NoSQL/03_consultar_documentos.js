/* C6 - R: READ. Dos consultas: filtro y documentos con especificaciones diferentes. */
(function () {
  const pedidos = db.getSiblingDB("BD_ArtePublicidadED_NoSQL")
    .getCollection("pedidosPersonalizadosT2");
  print("== 03: READ CON FILTRO ==");
  const filtro = { categoriaServicio: "Impresion", estado: "REGISTRADO" };
  print("Filtro: categoriaServicio=Impresion y estado=REGISTRADO");
  printjson(pedidos.find(filtro, {
    _id: 1, codigoPedido: 1, categoriaServicio: 1, estado: 1,
    "especificaciones.material": 1
  }).sort({ codigoPedido: 1 }).toArray());

  print("== READ: DIFERENTES ESTRUCTURAS DE ESPECIFICACIONES ==");
  printjson(pedidos.find({
    _id: { $in: ["C6-SEM-IMP-001", "C6-SEM-DIS-002", "C6-SEM-MER-003"] }
  }, { _id: 1, servicio: 1, especificaciones: 1 }).sort({ _id: 1 }).toArray());
})();
