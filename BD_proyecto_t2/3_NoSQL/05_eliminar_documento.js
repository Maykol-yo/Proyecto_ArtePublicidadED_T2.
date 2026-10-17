/* C6 - D: DELETE. Elimina SOLO la fila documental temporal, NUNCA las tres semillas. */
(function () {
  const pedidos = db.getSiblingDB("BD_ArtePublicidadED_NoSQL")
    .getCollection("pedidosPersonalizadosT2");
  const id = "C6-CRUD-TEMP-001";
  print("== 05: DELETE ==");
  print("ANTES:");
  printjson(pedidos.findOne({ _id: id }, { _id: 1, codigoPedido: 1, estado: 1 }));
  const r = pedidos.deleteOne({ _id: id });
  printjson({ operacion: "deleteOne", deletedCount: r.deletedCount });
  const restantes = pedidos.countDocuments({ _id: id });
  printjson({ documentosTemporalesRestantes: restantes,
              documentosSemillaIntactos: pedidos.countDocuments({ tipoRegistro: "SEMILLA_T2" }) });
  if (restantes !== 0) throw new Error("DELETE no se verifico.");
  print("NOTA: al terminar se conserva la coleccion con los 3 pedidos ficticios de ejemplo.");
})();
