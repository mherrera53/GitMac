# Pull con cambios locales: recuperación y caso onboardings

## Repositorio del usuario: resuelto

El Pull bloqueado por `src/modules/public/Timeline.vue` se resolvió mediante avance directo hasta la rama remota. El ajuste local ya estaba íntegro en la versión remota; se comprobó con el patch invertido antes y después de actualizar.

Se guardaron fichero y patch fuera del repositorio y un stash limitado al archivo afectado. Se compararon los diffs de los demás archivos, el índice completo y la lista de archivos sin seguimiento: iguales antes/después. No se crearon commits ni se hizo Push en ese proyecto. Las rutas y hashes de este caso privado están únicamente en `onboardings-pull-receipt.json` y en el respaldo local, excluidos de Git y de los paquetes de distribución.

## Corrección preparada en GitMac 4.1.3 build 14

- `GitMac/Core/Git/GitOperationHandler.swift:98`: el rechazo por cambios locales ofrece **Save changes and Pull**, sin guardar nada silenciosamente. La acción conserva repositorio y rama originales; una selección distinta la rechaza. Los errores de red/divergencia no ofrecen stash. Una restauración incompleta abre la lista real de Stashes y no genera un aviso de éxito.
- `GitMac/Core/Git/GitEngine.swift:2113`: flujo compartido que incluye cambios sin seguimiento, verifica la copia por mensaje único, conserva su SHA, aplica `--index` e impide aplicar sobre merge/rebase pendiente. La copia nunca se elimina automáticamente. Ante fallo del Pull solo intenta restaurar sobre la misma rama y HEAD intactos, con working tree limpio. Ante conflictos conserva la copia y pide revisión.
- `GitMac/Core/Git/Remote.swift:147`: `--no-autostash` explícito evita que la configuración de Git reactive autostash implícito y pierda la selección staged.
- `GitMac/Core/Services/GitService.swift:37`: exclusión de Pull por identidad del worktree entre instancias. `pullWithAutoStash` delega en el mismo motor y refresca el repositorio correcto ante éxito o fallo.
- `GitMac/Core/Utils/ShellExecutor.swift:195`: stash deja de heredar `GIT_LITERAL_PATHSPECS=1`; ese valor rompía su limpieza interna de archivos sin seguimiento pese a exit 0. La política literal de las demás operaciones se conserva.
- `GitMac/Features/PullRequests/PullSheet.swift`: explica la operación, conserva la copia, elimina el antiguo `try?` que anunciaba éxito sin verificar y distingue restauración incompleta.

El diseño sigue [git-stash](https://git-scm.com/docs/git-stash): `apply --index` intenta restaurar también el índice y puede fallar por conflictos. Por ello no se promete resolución automática ni se borra la copia. [git-pull](https://git-scm.com/docs/git-pull) documenta que cambios locales solapados impiden integrar.

## Validación

- 91 tests Swift Testing en 15 suites aprobadas. La prueba de recuperación ejecuta 11 escenarios con Git real aislado: restauración, conflicto tracked, colisión untracked, fallo de remoto, rama distinta, solo untracked, autostash configurado, linked worktree, operación pendiente, conflicto de merge y conflicto de rebase. Verifica por separado contenido staged, unstaged y copia persistente.
- Core adicional: 0 fallos y los 12 XCTest de modelos aprobados después de separar el motor de los modelos.
- 18 comprobaciones del controlador real aprobadas con frontera I/O simulada: acción explícita, selección obsoleta, fallos de red y ausencia de éxito engañoso.
- Controles negativos: retirar `--index` reproduce pérdida de selección staged; restablecer el entorno literal anterior reproduce archivos sin retirar después del stash. Sus fallos se conservan.
- Release final 4.1.3 build 14 compilado y candidata firmada. SHA-256 del ejecutable: `beba2d4e71086fd88970a314d22c9910dc021ad517f898593695728e025785dd`. El motor de recuperación reside en GitEngine.swift; los modelos siguen compilando por separado.
- RAM sin instrumentación de esta candidata: máximo físico y pico de vida **143,705,264 bytes**, 20 muestras, 100.000 commits con grafo nativo/minimapa cargados. Presupuesto 150.000.000. La sesión estaba bloqueada: demuestra carga/dibujo y footprint del proceso de fixture, sin aprobación interactiva. No certifica todos los repositorios, procesos auxiliares o modelos IA.

## Pendiente de sesión desbloqueada

El test nativo `PullRecoveryUITests.testExplicitRecoveryButtonPreservesWorkingAndStagedChanges` está implementado y compilado, pero no se ejecutaron sus acciones: XCTest no pudo activar la app en segundo plano y el sistema informó `CGSSessionScreenIsLocked=Yes`. Se interrumpió el reintento propio al comprobar el bloqueo. No cuenta como aprobación visual.

La consulta de notarización también devolvió `No Keychain password item found for profile: GITMAC_NOTARY`. Se consultaron metadatos de los llaveros disponibles sin imprimir ni extraer secretos. Falta volver a consultar con la sesión desbloqueada y completar notarización, instalación y publicación. Sigue instalada la 4.1.2 notarizada; no se reemplazó por una copia sin esa validación.
