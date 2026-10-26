# Gates: rearme nativo de archivos Git

- [x] G1: Detectar archivos ausentes creados después del inicio, incluso en directorios nuevos; observar escrituras posteriores.
  EVIDENCE: watcher-rearming-before.log contiene siete fallos antes de la corrección; watcher-rearming-after.log pasa creación tardía bajo late/refs inexistentes.
- [x] G2: Detectar varias sustituciones atómicas, borrado/recreación y detener callbacks tras stop, sin polling ni cerrar descriptores ajenos.
  EVIDENCE: watcher-rearming-after.log: tres reemplazos, borrado/recreación, stop y archivo vecino sin señal espuria; cancel handler conserva propiedad del fd. No hay timers de polling.
- [x] G3: Stash creado por primera vez con Git real emite señal stash; los eventos en HEAD de un worktree no se atribuyen a otro.
  EVIDENCE: firstRealStashEmitsItsOwnSignal y actualGitWorktreesShareCommonIdentityButNotIndexOrHeadDirectory usan Git real aislado, verifican common config y HEAD separado.
- [x] G4: Pruebas antes/después sobre producción, control negativo y build real; no degradar la corrección de sesión ya probada.
  EVIDENCE: watcher-rearming-after.log, 71 Swift Testing + 11 XCTest, incluyendo ráfaga de 80 sustituciones atómicas y escritura posterior; watcher-rearming-negative.log conserva fallos de comportamiento anterior; ui-fixture-branches-build.log TEST BUILD SUCCEEDED. La integración de todos los servicios de sesión sigue en T12.
