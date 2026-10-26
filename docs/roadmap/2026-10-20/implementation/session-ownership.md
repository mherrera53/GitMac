# Sesiones, identidad y recursos: contrato actual

## Identidades y fronteras implementadas

| Entidad | Identidad | Propietario y caducidad |
| --- | --- | --- |
| Working tree | dispositivo:inode del gitDirectory resuelto | RepositoryFileLocations; distinto para worktrees vinculados, igual a través de symlinks |
| Repositorio común | dispositivo:inode de commonGitDirectory | Compartido por worktrees del mismo almacenamiento local; no es identidad portable entre volúmenes/copias |
| Pestaña | RepositoryTab.id, UUID de sesión | AppState conserva snapshots y BranchStateManager por pestaña; cerrar invalida refresh e historial |
| Solicitud de refresh | UUID por tabID + ruta capturada | Solo la generación más reciente puede publicar; no adquiere propiedad de la pestaña que esté activa después del await |
| Solicitud de apertura | UUID de apertura | La última intención gana; un resultado anterior no resucita pestañas ni finaliza loading ajeno |
| Servicio activo | ruta + activeGeneration | GitService.activateRepository cambia watcher y limpia cachés al cambiar de ruta; readRepository no activa sesiones |
| Descriptor nativo | fd capturado por su DispatchSource | El cancel handler cierra ese fd aunque la instancia desaparezca; nunca lee un fd reasignado |

HEAD e index se vigilan dentro del gitdir del worktree. Config, refs y reflog de stash se buscan en el directorio Git común. Los valores iniciales de los publishers no son eventos de filesystem. Un watcher suspendido por inactividad puede reanudarse; uno detenido definitivamente no debe revivir por esa notificación.

La comparación de identidad contra Git usa device:inode. `/var` y `/private/var`, symlinks y distintas normalizaciones Unicode pueden señalar al mismo objeto. No se recortan espacios ni saltos de línea internos de rutas.

## Verificación y límites abiertos

`session-isolation-current.log`: 12 comprobaciones sobre AppState completo extraído sin modificar; GitService y servicios accesorios son fronteras simuladas. El control anterior conserva seis fallos reales de comportamiento. `repository-scope-final-tests.log`: 66 Swift Testing y 11 XCTest; usa Git real aislado y descriptores nativos. `repository-watchers-negative.log` reproduce cuatro assertions con FileWatcher anterior.

No hay todavía lock compartido de escritura por commonRepositoryID ni journal por operationID. No se presenta un UUID de refresh como operación Git durable. AppState continúa compartido por WindowGroup; falta ownership de ventana y liberación integral de RepositoryContextManager/BranchPRTracker/otros servicios. La protección implementada cubre la ruta vertical indicada, no garantiza aislamiento multiventana completo.

Rearme y creación tardía ya tienen cobertura nativa en gates/watcher-rearming.md, incluido primer stash real y ráfaga de 80 sustituciones atómicas. La carga privada de fixture configura ahora su BranchStateManager; session-isolation-branches.log pasa 13 comprobaciones. Pendientes concretos: invalidación de todos los consumidores; recursos de pestaña y async clone; recuperación/journal de operaciones. T11/T12/T17/T29 siguen abiertos. No hay locks nuevos cuya ausencia pueda ocultarse en la documentación.
