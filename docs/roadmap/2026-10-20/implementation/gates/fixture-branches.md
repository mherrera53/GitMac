# Gates: carga completa del fixture

- [x] G1: La sesión de fixture configura el BranchStateManager de su pestaña, sin restaurar proyectos ni credenciales del usuario.
  EVIDENCE: session-isolation-branches.log, 13 comprobaciones; ui-fixture-branches-build.log TEST BUILD SUCCEEDED.
- [x] G2: La UI muestra la rama real y deja de presentar No Branch; captura leída después de ejecutar la prueba.
  EVIDENCE: ui-fixture-branches-tests.log, dos tests sin fallos; build/UIFixtureBranches-20261021.xcresult. Ambas capturas de ui-fixture-branches-captures/ se leyeron: cabecera main y lista lateral main; Ajustes abre. No acredita toda la UI/AX.
- [x] G3: El profiler exige señal de ramas locales además de repo/grafo/minimap. Las mediciones anteriores mantienen su alcance anterior.
  EVIDENCE: scripts/profile-release-memory.mjs requiere branches-loaded con local >= 1. El Release medido anteriormente no inicializaba el gestor lateral; sus cifras no acreditan esta nueva carga completa.
