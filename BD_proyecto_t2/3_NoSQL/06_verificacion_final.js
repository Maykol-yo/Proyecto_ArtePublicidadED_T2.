/* C6 - Comprobacion final tras el CRUD. Lectura solamente. */
(function () {
  const pedidos = db.getSiblingDB("BD_ArtePublicidadED_NoSQL")
    .getCollection("pedidosPersonalizadosT2");
  const idsSemilla = ["C6-SEM-IMP-001", "C6-SEM-DIS-002", "C6-SEM-MER-003"];
  const verificacion = {
    documentosSemillaEsperados: 3,
    documentosSemillaEncontrados: pedidos.countDocuments({ _id: { $in: idsSemilla } }),
    documentoTemporalRestante: pedidos.countDocuments({ _id: "C6-CRUD-TEMP-001" }),
    indiceCodigoUnico: pedidos.getIndexes().some(i => i.name === "ux_codigoPedido_t2" && i.unique === true),
    tiposEspecificacion: pedidos.find({ _id: { $in: idsSemilla } },
      { _id: 1, servicio: 1, especificaciones: 1 }).toArray().map(d => ({
        servicio: d.servicio, campos: Object.keys(d.especificaciones).sort()
      }))
  };
  print("== 06: VERIFICACION FINAL ==");
  printjson(verificacion);
  if (verificacion.documentosSemillaEncontrados !== 3 ||
      verificacion.documentoTemporalRestante !== 0 ||
      !verificacion.indiceCodigoUnico) {
    print("ATENCION: falta ejecutar o completar alguno de los pasos 01 a 05.");
  } else {
    print("C6: comprobacion final esperada. Adjunta capturas y scripts como evidencia.");
  }
})();
