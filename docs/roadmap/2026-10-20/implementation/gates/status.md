# Gates: estado Git único y fixtures de integración

Scope: T05/T06/T09, validar GitEngine de producción y ambos puntos de entrada sin parsers sombra.

- [x] G1: El runner compila GitEngine real e importa el módulo de producción.
  CHECK: node scripts/test-git-integration.mjs
  EXPECT: GIT INTEGRATION PASSED
  EVIDENCE: git-integration-after.log, 20 PASS y GIT INTEGRATION PASSED; compila los archivos reales del motor/modelos.
- [x] G2: F01/F02/F03 cubren unborn/unstage, rutas especiales, MM/AM/RM/type/conflict, oldPath y numstat NUL.
  EVIDENCE: GitIntegrationMain.swift; git-integration-before.log reproduce 12 fallos, git-integration-after.log pasa los 20 casos.
- [x] G3: getStatus y getStatusV2 entregan los mismos paths/tipos/stats, y los fallos no se convierten en estado vacío.
  EVIDENCE: git-integration-after.log, F03 both status entry points agree including stats y status process failure throws.
- [x] G4: Build Debug después del cambio y pruebas anteriores sin regresión.
  EVIDENCE: status-debug.log BUILD SUCCEEDED; status-core-regressions.log 18 comprobaciones y 11 XCTest sin fallos.
