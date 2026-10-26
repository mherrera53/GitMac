# Gates: compilación y aislamiento de pruebas de interfaz

Scope: reparar el tipo ScreenshotEngine ausente y preparar fixtures privados para todas las entradas de UI tests. No acredita visual/VoiceOver por compilar.

- [x] G1: Ninguna entrada de UI tests restaura repositorios reales ni depende de /Users/mario/gitmac-demo-repo; cada fixture usa Git sin config/hooks globales.
  CHECK: node scripts/test-ui-test-foundation.mjs
  EXPECT: UI_FIXTURE_CHECKS_PASSED
  EVIDENCE: ui-foundation-fixture-tests.log pasa y ui-foundation-fixture-negative.log rechaza modo inseguro con Git real.
- [x] G2: ScreenshotEngine existe, registra errores de captura y solo captura una ventana existente; todos los targets de tests compilan en proyecto generado sin sustituir el original.
  EVIDENCE: ui-foundation-project.json y ui-fixture-branches-build.log; proyecto original preservado, TEST BUILD SUCCEEDED con certificado Apple Development autorizado por usuario.
- [x] G3: El producto UI de validación tiene bundle ID diferente de la app instalada; no se termina la sesión de usuario. Registrar ejecución/capturas o el bloqueo real.
  EVIDENCE: com.gitmac.validation.GitMac; ui-fixture-branches-tests.log: dos tests sin fallos; capturas de ventana exportadas y leídas en ui-fixture-branches-captures/. No reemplaza la app instalada ni aprueba la matriz visual completa.
