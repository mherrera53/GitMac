# Release 4.1.0: commit, GitHub y Mac

Autorización posterior y explícita: «commit y deploy pls release version»; destino confirmado «GitHub Release y app del Mac», con versión propuesta 4.1.0. Ejecutar esta entrega acotada no verifica los 40 criterios del roadmap. Se conservan los resultados y límites abiertos; no se requiere otra confirmación para las acciones autorizadas.

- [x] R1: Completar regresiones, UI relevante y matriz de RAM; fijar fuentes y notas con límites explícitos.
  EVIDENCE: 47 verificaciones, 76 Swift Testing/12 XCTest, 1145 comparaciones y cuatro perfiles firmados pasan; UI extremos/stash y terminal por reintento pasan. Notas 4.1.0 conservan límites.
- [x] R2: Commit de implementación, pruebas y documentación seleccionada; preservar CLAUDE.md y artefactos previos ajenos. No subir dumps/capturas ni claves.
  EVIDENCE: Commit ff3d825817926d0290e2a1927995cbf27c092677 y tag v4.1.0 subidos. Código/pruebas/documentación seleccionados; CLAUDE.md y build_dictionary.py preexistentes preservados. Sin autores ni trailers de AI. El control histórico después del commit reproduce seis fallos esperados.
- [x] R3: Release arm64 4.1.0, Developer ID, hardened runtime, Apple Accepted, stapling, Gatekeeper y ZIP/checksum concordantes.
  EVIDENCE: candidate-final-j32k5b4p/distribution.json, versión 4.1.0 (6), Apple Accepted 609eb250-e46b-45d6-8252-2f2d19db20d3; stapling/firma/Gatekeeper pasan; ZIP SHA256 68339f52a36304239b1da227229e30e4f6e0601abee38502dd3a3010a3d4a13a.
- [x] R4: Publicar commit/tag/Release y verificar en GitHub los hashes de los assets descargados; CI no reemplaza el ZIP notarizado con uno ad hoc.
  EVIDENCE: https://github.com/mherrera53/GitMac/releases/tag/v4.1.0 publicado con ZIP, checksum y provenance. ZIP descargado de GitHub y SHA256 verificado: 68339f52a36304239b1da227229e30e4f6e0601abee38502dd3a3010a3d4a13a. CI no tiene publicación de assets ad hoc.
- [x] R5: Salida normal de instancia previa si existe; backup verificable, reemplazo local y lanzamiento/smoke sin modificar repositorios ni preferencias del usuario. Registrar ruta/hash/versión y conservar rollback.
  EVIDENCE: release6-installation.json: /Applications/GitMac.app versión 4.1.0 (6), binario c9712a30788159b47ec301890d3e15ce0d829c9fa302dc91d47c0dc07d8da574, firma/ticket/Gatekeeper pasan; salida normal de instancia anterior, backup verificado pre-4.1.0-o0lzcl3a, reemplazo atómico y lanzamiento normal vivo después de ocho segundos. Sin force-kill ni reset de preferencias.
