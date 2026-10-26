# Resolver de conflictos: implementación y límites verificables

T26 está en curso. Este informe no certifica todos los conflictos ni sustituye las 40 aceptaciones y los 206 pasos del roadmap.

| Archivo y entrada | Cambio | Evidencia |
| --- | --- | --- |
| `GitMac/Core/Utils/ShellExecutor.swift:175` | Captura binaria acotada en el executor compartido, sin reinterpretar bytes inválidos como UTF-8 | `conflict-lossless-executor-checks.log`; control con decodificación altera bytes y falla |
| `GitMac/Features/MergeConflict/ConflictResolverView.swift:137` | Detectar la operación real en el gitdir del worktree; etiquetas y comandos distintos para merge, rebase, cherry-pick y revert | `conflict-operation-matrix.log` |
| `ConflictResolverView.swift:173` | Snapshot con identidad, HEAD, índice NUL, contenido y permisos; invalidar antes de escribir si cambian | `conflict-preservation-before-fixed.log` reproduce pérdida de cambios; `conflict-empty-choice-after.log` pasa |
| `ConflictResolverView.swift:321` | Serializar operaciones propias por worktree; copias privadas de original/propuesta/índice/tres versiones antes de escribir; receipts accesibles | Fixtures Git y comprobaciones de bytes/permisos |
| `ConflictResolverView.swift:493` | Consultar Git en lugar del status UI obsoleto; capturar contenido solo del archivo seleccionado | 32 conflictos visibles y una sola captura inicial retenida |
| `ConflictResolverView.swift:817` | Parser estricto; conservar CRLF, regiones intactas y elecciones vacías; rechazar marcadores malformados/anidados | `conflict-current-negative.log`: 16 fallos de comportamiento del código anterior |
| `GitMac/App/Panels/Left/LeftSidebarPanel.swift:242` | Abrir el resolver real y separar el análisis orientativo en otra hoja | `conflict-live-ui.xcresult`; revisión de la versión posterior todavía pendiente |
| `GitMac/Features/CommitGraph/Models/GraphNode.swift:4` | El WIP incluye conflictos aunque no haya cambios ordinarios | `conflict-wip-production-fixed.log`: 73 Swift Testing y 11 XCTest pasan |
| `experiments/minimap-allocation/GraphNode.three-pass-measured.swift` | Experimento de tres pasadas retirado del producto al no demostrar ahorro | 130 casos equivalentes, pero `conflict-minimap-memory-100000.log` alcanza 184878232 bytes de pico; no se declara optimización |

Los números de línea corresponden a esta revisión. `changes.csv` y el mapa se regeneran al congelar las fuentes; consultar fecha y hashes antes de tratarlos como vigentes.

## Pruebas y conservación

`conflict-empty-choice-after.log` contiene 43 comprobaciones sin fallos sobre el núcleo real, Git y archivos temporales propios. Se incluyen errores de staging, lock existente, edición externa obsoleta, índice cambiado, CRLF, elecciones vacías, copias privadas, marcadores, hooks, operaciones y carga perezosa. El control anterior compila y reproduce 16 fallos reales; no se cuenta un error de compilación como demostración de comportamiento.

`conflict-live-ui.xcresult` recorrió aceptar ambas → guardar y preparar → continuar merge, verificando bytes, índice sin conflictos, dos padres y nota local preservada. La inspección detectó un estado visual obsoleto: se corrigieron igualdad del modelo, etiqueta Resolved, estado Saved and staged y acceso a recuperación. `conflict-theme-final-ui.xcresult` pasó siete tests y la matriz de 126 capturas con esos cambios; `terminal-regression-matrix-ui.xcresult` repitió el flujo de conflicto con éxito, aunque su terminal todavía fallaba. El candidato terminal posterior tiene su propio hash y prueba, sin aprobación automática del roadmap.

Las pruebas usan repositorios, identidades, configuración y hooks privados. No se modificaron repositorios, stashes ni remotos del usuario. El respaldo de un conflicto no es una copia completa del repositorio ni un mecanismo universal de undo.

## Límites abiertos

El editor inline admite texto UTF-8 sin NUL, hasta 2 MB, 20.000 líneas y 16.384 bytes por línea. Los casos no admitidos presentan fallback explícito; no se truncan ni sobrescriben silenciosamente. Falta completar binarios, delete/modify, rename/rename, modos especiales, ACL/xattrs, resolución externa, matriz de worktrees, cancelación y concurrencia completa. El pequeño intervalo entre validación y escritura no elimina todas las carreras posibles con herramientas externas no cooperativas.

El análisis de posibles solapamientos es orientativo: no garantiza ausencia de conflictos ni sustituye el merge real. El WIP distingue conflictos; no se presenta el repositorio como limpio por tener cero cambios ordinarios.

## Revisión local

`local-agents/conflict-preservation-adjudication.json` registra la evaluación de seis sugerencias de qwen3-coder:30b sobre hashes anteriores. Su propuesta no se aplicó automáticamente ni constituye revisión de la versión actual. `conflict-preservation-tests-1792981783729-unload.json` observó el modelo descargado; no se utilizó Cloud.

Fuentes primarias: [índice y conflictos de Git](https://git-scm.com/docs/git-merge), [ours/theirs durante rebase](https://git-scm.com/docs/git-checkout) y [operaciones de rebase](https://git-scm.com/docs/git-rebase). Las etiquetas de la UI explican las etapas 2/3, evitando asumir que ours siempre representa los cambios originales del usuario.

La app instalada permanece intacta. Su reemplazo autorizado depende de los gates de pruebas, memoria y distribución de `gates/installed-app-replacement.md`.
