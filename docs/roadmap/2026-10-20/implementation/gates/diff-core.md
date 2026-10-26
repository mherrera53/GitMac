# Gates: tests de producción y contratos de diff

Scope: T05 y núcleo de T24: ejecutar suites reales, caché coherente, límites y materialización segura.

- [x] G1: Todas las suites en Tests/GitMacTests compilan e importan las APIs reales; ningún tipo/parser sombra.
  CHECK: node scripts/test-production-suites.mjs
  EXPECT: All tests passed
  EVIDENCE: credentials-tests-final.log: 29 Swift Testing en 4 suites y 11 XCTest sin fallos; runner enlaza fuentes reales. production-model-mutation.log demuestra fallo del modelo real mutado en temporal.
- [x] G2: Cambios de archivo/contexto/LFM invalidan resultados obsoletos; caché respeta presupuesto incluso con entradas grandes/coste cero.
  EVIDENCE: credentials-tests-final.log, cacheInvalidatesAfterWorkingTreeChanges, contextAndLargeFileModeAreNotStaleCacheKeys, coreCacheRejectsOversizedEntry y zeroCostEntriesStillConsumeBudget PASS; production-suites-before.log conserva los fallos anteriores.
- [x] G3: Unicode, hunk múltiple, prefijos de contenido y EOF sin newline se conservan; rangos inválidos fallan sin crash.
  EVIDENCE: credentials-tests-final.log, unicodeAndNoFinalNewline, multipleHunks, contentMustNotBeMistakenForFileHeaders, invalidMaterializationRangeIsRejected y lazyMaterialization PASS.
- [x] G4: Preferencias no modifican defaults del usuario; fallo de preflight no se convierte en éxito vacío.
  EVIDENCE: credentials-tests-final.log, isolatedPreferencesRoundTrip y preflightDoesNotHideProcessFailure PASS; defaults de suite UUID retirados por el fixture.
- [x] G5: Debug y suites Git/procesos/grafo siguen pasando.
  EVIDENCE: credentials-debug-final.log BUILD SUCCEEDED; contracts-git-process-current.log ambas suites PASSED; contracts-core-current.log 0 failures y 11 XCTest sin fallos.

No cierra T24: aún faltan flujo UI, binarios y archivos grandes, cancelación integrada y mediciones de memoria.
