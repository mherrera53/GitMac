# Gates: identidad local y ciclo de vida de watchers

Alcance: archivos Git de repositorios, worktrees vinculados y bare; descriptor nativo y callbacks de actividad. No certifica bloqueo entre ventanas ni todas las operaciones Git.

- [x] G1: Un worktree comparte identidad del directorio común, no la de HEAD/index; validar con Git real, aliases, Unicode y saltos de línea internos.
  EVIDENCE: repository-scope-final-tests.log; Git rev-parse como oracle por device:inode; incluye bare y alias simbólico.
- [x] G2: Punteros .git corruptos, NUL o mayores de 16 KiB se rechazan.
  EVIDENCE: malformedAndOversizeGitPointersFailClosed en repository-scope-final-tests.log.
- [x] G3: Reiniciar y liberar un watcher cierra solo su descriptor; valores iniciales de publishers no simulan cambios y un watcher detenido no revive al activar la app.
  EVIDENCE: dos tests nativos positivos; repository-watchers-negative.log reproduce cuatro assertions fallidas del código anterior, sin fallo de compilación.
- [x] G4: Pruebas positivas sobre producción, control negativo de comportamiento anterior y build real. Documentar límites de atomic replace y archivos aún inexistentes.
  EVIDENCE: baseline de 66 Swift Testing + 11 XCTest en repository-scope-final-tests.log. El gate watcher-rearming.md añade creación tardía, primer stash y reemplazo atómico con 71 Swift Testing + 11 XCTest; no se declara T11/T12/T29 completo.
