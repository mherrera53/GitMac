# Pull con cambios locales

- [x] P1: Reproducir el rechazo con cambios tracked y untracked; recuperación conserva staged/unstaged y copia identificada por SHA.
  CHECK: rg -F '91 tests in 15 suites passed' docs/roadmap/2026-10-20/implementation/pull-recovery-production.log
  EXPECT: exit 0
  EVIDENCE: 11 escenarios reales parametrizados, incluidos merge/rebase en conflicto y fallo del remoto. El caso privado se resolvió mediante avance directo con respaldo y comparación del índice/diffs/archivos sin seguimiento.
- [x] P2: Unificar recuperación de toolbar y panel; validar repositorio/rama y no anunciar éxito ante conflictos o fallo de stash.
  CHECK: rg -F '18 checks, 0 failures' docs/roadmap/2026-10-20/implementation/pull-recovery-actions.log
  EXPECT: exit 0
  EVIDENCE: Controlador real con I/O simulado verifica recuperación explícita, selección obsoleta y aviso de copia sin falso éxito. Motor único de recuperación; el antiguo try? con éxito incondicional fue retirado. La prueba de interacción nativa está pendiente en P4.
- [x] P3: Release, pruebas reales de conflicto/fallo/red/copia existente y presupuesto RAM comprobados.
  CHECK: python3 -c "import json; m=json.load(open('docs/roadmap/2026-10-20/implementation/pull-recovery-memory.json')); assert m['passed'] and m['fixtureCommits']==100000 and m['maximumLifetimePeakBytes']<=150000000"
  EXPECT: exit 0
  EVIDENCE: Release build 14 aprobado, firma estricta y mismo SHA en perfil. Pico 143705264 bytes, 20 muestras; fixture dibujado con sesión bloqueada, sin aprobación interactiva. 12 XCTest y core pasan. Controles negativos reproducen 5 y 10 issues de comportamiento.
- [ ] P4: Validar el botón en la sesión nativa y completar notarización, instalación con respaldo y publicación.
  EVIDENCE: Bloqueado por CGSSessionScreenIsLocked=Yes. XCTest no pudo activar la app; reintento propio interrumpido. notarytool no encuentra el perfil mientras la sesión está bloqueada. Candidata firmada lista, app instalada 4.1.2 preservada; no se publicó una release sin notarización.

ABANDON: P4 Aplazado hasta que el usuario desbloquee su sesión de macOS y sea accesible el perfil de notarización. Se conservan implementación, test compilado, candidata y comandos de reanudación; no se declara esta entrega instalada ni el gate aprobado.
