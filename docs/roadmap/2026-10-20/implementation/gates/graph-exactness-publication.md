# Grafo exacto y publicación comprensible

Petición del usuario: ejecutar los 206 pasos del plan, refinar la presentación y detectar qué está publicado. Este contrato concreta criterios de T20/T21/T22/T27/T28/T29/T31, sin declarar precisión matemática por inspección visual.

- [ ] E1: Comparar nodos y aristas con SHA/padres de Git real: cadenas, bifurcaciones, merges de varios padres, múltiples tips, fechas desordenadas, detached, shallow y límites de página. Cada conexión dibujada corresponde a una arista o tramo de continuidad justificado.
  EVIDENCE: pending
- [ ] E2: Verificar invariantes de lanes y continuidad entre filas, curvas sin aliasing/truncamiento, identidad de stash/WIP y correspondencia de minimapa completo/muestra. Fixtures generados y un oracle independiente; no comparar únicamente dos implementaciones que compartan el mismo error.
  EVIDENCE: pending
- [ ] E3: Distinguir commits alcanzables desde referencias remotas conocidas, solo locales, sin upstream y divergentes; mostrar remoto/upstream y antigüedad del último fetch. Un tracking ref local no demuestra el estado instantáneo del servidor.
  EVIDENCE: pending
- [ ] E4: Presentación clara en cada tema, leyenda y ayudas contextuales; publicar rama con destino explícito y estados de progreso/error/reintento; pruebas UI/teclado, Git aislado y rendimiento sin eliminar información.
  EVIDENCE: pending
