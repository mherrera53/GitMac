# Gates: validación local de distribución

Scope: T39, candidato técnico de arm64; no publicación ni instalación sobre una aplicación existente. No implica cierre funcional del roadmap.

- [x] G1: El perfil existente permite consultar el servicio sin exponer credenciales.
  EVIDENCE: notarization-preflight.md, consulta 2026-10-21T02:03:55.017Z, salida 0.
- [x] G2: Release actual compila y sus binarios, bibliotecas y entitlements se inventarían antes de firmar.
  EVIDENCE: release-credentials.log BUILD SUCCEEDED; build/DistributionCandidates/candidate-Yzctwc/inventory-before-signing.json registra los tres Mach-O arm64; entitlements originales vacíos, sin excepciones añadidas.
- [x] G3: Copia separada firmada Developer ID con hardened runtime y verificación estricta de código anidado.
  EVIDENCE: distribution-prepare.log, equipo SRVK53YUSF, com.gitmac.app, hardenedRuntime true y codesign --verify --deep --strict sin fallos. El producto original se conserva.
- [x] G4: Apple acepta exactamente el artefacto verificado; identificador, digest y registro conservados.
  EVIDENCE: notarization-info.json Accepted, envío 89df8d53-1614-4496-92d1-84c9c12c4f2f; notary-log.json de candidate-Yzctwc enlaza jobId y SHA-256 e0bd7235b40fe056ae000c2d499de96816f3c20650b1251585d463681dad28d3 con el ZIP enviado.
- [x] G5: Stapling y Gatekeeper aprueban; zip final se reempaqueta y tiene SHA-256 registrado.
  EVIDENCE: distribution-final.log, stapler validate y firma estricta pasan, Gatekeeper accepted/source=Notarized Developer ID; ZIP final SHA-256 dfff18c18e0ca0b6a0943fb39a374c75ee1b82c0512911641ba2f8fd2543be26.

No cierra T39 integralmente: faltan Mac limpio, matriz de OS/arquitectura, lanzamiento/upgrade/rollback y preservación de datos. El candidato temprano en distribution-prepare-early.log fue solo una prueba de preparación y no se envió; el candidato aceptado es exclusivamente candidate-Yzctwc.
