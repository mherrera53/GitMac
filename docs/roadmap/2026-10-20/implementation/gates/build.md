# Gates: baseline y build

Scope: verificar herramientas, configuración y pipeline real antes de cerrar T01–T06/T38.

- [x] G1: Baseline y cambios previos registrados.
  CHECK: git rev-parse HEAD
  EXPECT: 33bcb5739356ae133b8812159fde991700a56273
  EVIDENCE: implementation/PLAN.md; HEAD permanece sin commits creados; CLAUDE.md preservado.
- [x] G2: Build Debug y Release terminan sin errores.
  EVIDENCE: implementation/debug-final.log y implementation/release-fixed.log, ambos BUILD SUCCEEDED y exit 0. CODE_SIGNING_ALLOWED=NO; no certifica distribución.
- [x] G3: Pipeline falla con error de compilación, enlace o test incompleto.
  EVIDENCE: scripts/test-xcodebuild-gate.mjs, 9 casos; implementation/ci-gate.log. Prueba local del wrapper, no ejecución alojada de GitHub Actions.
- [x] G4: Tests importan producción y cubren regresiones de Git/grafo.
  EVIDENCE: implementation/core-regressions-and-models.log, 18 comprobaciones y 11 XCTest; implementation/production-model-mutation.log falla exactamente un XCTest al mutar una copia temporal de Commit. El contenedor/engine de las cuatro funciones extraídas del VM son fixtures; no es toda la suite del producto.

Estos gates cierran esta hoja acotada, no T01–T06/T38 completos ni el roadmap de 40 tareas.
