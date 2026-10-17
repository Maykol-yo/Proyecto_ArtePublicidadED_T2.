/* C6 - U: UPDATE. Modifica solamente el documento temporal creado en 02. */
(function () {
  const pedidos = db.getSiblingDB("BD_ArtePublicidadED_NoSQL")
    .getCollection("pedidosPersonalizadosT2");
  const id = "C6-CRUD-TEMP-001";
  print("== 04: UPDATE ==");
  const antes = pedidos.findOne({ _id: id });
  if (antes === null) throw new Error("Falta el documento de prueba. Ejecuta 02_crear_documento.js primero.");
  print("ANTES:");
  printjson({ _id: antes._id, estado: antes.estado, acabado: antes.especificaciones.acabado });

  const r = pedidos.updateOne(
    { _id: id },
    { $set: {
      estado: "EN_PRODUCCION",
      "especificaciones.acabado": "Laminado mate",
      ultimaActualizacionPrueba: new Date()
    } }
  );
  printjson({ operacion: "updateOne", matchedCount: r.matchedCount, modifiedCount: r.modifiedCount });
  const despues = pedidos.findOne({ _id: id });
  print("DESPUES:");
  printjson({ _id: despues._id, estado: despues.estado, acabado: despues.especificaciones.acabado });
  if (r.matchedCount !== 1 || despues.estado !== "EN_PRODUCCION" ||
      despues.especificaciones.acabado !== "Laminado mate") {
    throw new Error("UPDATE no paso la comprobacion.");
  }
})();
