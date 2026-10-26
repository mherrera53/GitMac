# Release 4.1.0: commit, GitHub y Mac

Autorización posterior y explícita: «commit y deploy pls release version»; destino confirmado «GitHub Release y app del Mac», con versión propuesta 4.1.0. Ejecutar esta entrega acotada no verifica los 40 criterios del roadmap. Se conservan los resultados y límites abiertos; no se requiere otra confirmación para las acciones autorizadas.

- [x] R1: Completar regresiones, UI relevante y matriz de RAM; fijar fuentes y notas con límites explícitos.
  EVIDENCE: 47 verificaciones, 76 Swift Testing/12 XCTest, 1145 comparaciones y cuatro perfiles firmados pasan; UI extremos/stash y terminal por reintento pasan. Notas 4.1.0 conservan límites.
- [ ] R2: Commit de implementación, pruebas y documentación seleccionada; preservar CLAUDE.md y artefactos previos ajenos. No subir dumps/capturas ni claves.
  EVIDENCE: pending
- [x] R3: Release arm64 4.1.0, Developer ID, hardened runtime, Apple Accepted, stapling, Gatekeeper y ZIP/checksum concordantes.
  EVIDENCE: candidate-final-j32k5b4p/distribution.json, versión 4.1.0 (6), Apple Accepted 609eb250-e46b-45d6-8252-2f2d19db20d3; stapling/firma/Gatekeeper pasan; ZIP SHA256 68339f52a36304239b1da227229e30e4f6e0601abee38502dd3a3010a3d4a13a.
- [ ] R4: Publicar commit/tag/Release y verificar en GitHub los hashes de los assets descargados; CI no reemplaza el ZIP notarizado con uno ad hoc.
  EVIDENCE: pending
- [ ] R5: Salida normal de instancia previa si existe; backup verificable, reemplazo local y lanzamiento/smoke sin modificar repositorios ni preferencias del usuario. Registrar ruta/hash/versión y conservar rollback.
  EVIDENCE: pending
