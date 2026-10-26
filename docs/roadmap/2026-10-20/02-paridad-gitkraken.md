# Matriz de paridad con GitKraken Desktop

La referencia es GitKraken Desktop, no GitLens. Las capacidades se contrastan con la documentación primaria listada en [fuentes](09-fuentes.md). La UI puede estar disponible solo para ciertos proveedores o licencias; no se presume que una función exista de la misma manera en todas las cuentas.

`Parcial`: hay implementación relevante, pero falta completar o validar el flujo. `Defecto`: existe evidencia concreta de una brecha. `Por verificar`: no se obtuvo evidencia suficiente para determinar paridad. No se asigna un porcentaje por contar archivos.

| Capacidad objetivo | Evidencia de GitMac / estado | Trabajo para paridad verificable | Specs |
| --- | --- | --- | --- |
| Layout con referencias, grafo e inspector | `App/ContentView.swift`, paneles Left/Center/Right; parcial | Validar jerarquía, proporciones, redimensionado y persistencia; una selección sincronizada | GM-010, GM-012 |
| Pestañas de repositorio | `AppState.openTabs`, `UI/Components/Navigation/RepositoryTabsView.swift`; parcial | Aislamiento real de estado, navegación y foco; arrastrar/reabrir sin mezclar repos | GM-005, GM-010 |
| Grafo de ramas locales y remotas | `CommitGraphView`, `GraphViewModel`, `GraphLayoutEngine`; defecto de alcance | Consultar refs explícitas, DAG completo del alcance y fronteras de paginación | GM-013 |
| Labels de ramas/tags y HEAD | Un solo `branchHeads[sha]` en la carga; parcial | Múltiples refs por commit, relación local/remota y estado HEAD legibles | GM-013, GM-014 |
| WIP y stashes en el grafo | `UncommittedChangesRow`, `StashNode`; parcial | Estado consistente con staging; stash identifica su objeto y repo; WIP de worktrees | GM-005, GM-014, GM-020 |
| Búsqueda y filtros de commits | `SearchSyntaxParser`, `GraphSettings`; parcial | Search/focus/solo/hide predecibles, filtros visibles, resultados y reset claros | GM-014 |
| Minimap y navegación de historia | Minimap y carga de datos propios; parcial | Usar el mismo alcance/topología; preservar ancla al paginar y evitar scans repetidos | GM-013, GM-014, GM-027 |
| Drag and drop de refs/commits | `GraphTransferables`, context menus; por verificar | Preview de merge/rebase/cherry-pick, confirmación y equivalente por teclado | GM-014, GM-019 |
| Stage/unstage por archivo | `GitEngine.stage`, `StagingViewModel`; defecto de rutas | Misma fuente de status, selección estable y estados XY completos | GM-003, GM-015 |
| Stage por hunk y líneas | `PatchManipulator`, métodos de `GitService`; parcial | Verificar index/tree resultante, CRLF, no-newline, rename y cambios concurrentes | GM-015 |
| Commit, amend y flujo commit/push/PR | ViewModels y componentes de commit; parcial | Gates previos, resultado verificable y recuperación; acciones separadas en fallos parciales | GM-006, GM-015, GM-018, GM-021 |
| Diffs unificados y lado a lado | Múltiples vistas y motores; parcial | Elegir ruta principal; equivalencia de contenido, selección y scroll; fallback grande/binario | GM-016 |
| Historia y blame de archivo | `Features/History`, `Features/Blame`; parcial | Seguir renames, saltar al commit, navegación atrás y rango verificable | GM-016 |
| Merge y resolución de conflictos | `ConflictResolverView`, merge sheets; parcial | Base/current/incoming/result con guardado, validación y continue/abort | GM-017 |
| Rebase interactivo visual | Plan de UI no aplicado; defecto | Ejecutar exactamente el plan seleccionado y recuperar sesión tras conflicto | GM-007 |
| Cherry-pick de varios commits | `CherryPickView`; por verificar | Orden estable, conflictos y abort; estado visible entre pasos | GM-019, GM-017 |
| Undo/redo de operaciones Git | Gestor sin llamadas externas encontradas; defecto de integración | Journal por repo, snapshots y precondiciones; nunca confundir con undo de edición | GM-006, GM-009 |
| Fetch, pull y push con estado | Engine, `AutoFetchService`, tracker; parcial | Progreso, cancelación, credenciales, upstream, divergencia y force-with-lease | GM-004, GM-018 |
| Worktrees | Engine y `WorktreeListView`; parcial | Common git dir, branch ocupada, locks, dirty state, WIP y eliminación segura | GM-020 |
| Submodules y LFS | Módulos propios; parcial | Estados ausente/no-inicializado, auth, locks y progress; error de dependencia explícito | GM-020 |
| PR/MR de proveedores Git | Vistas/servicios, con fuerte presencia GitHub; parcial | Inventario por proveedor; capacidades reales de listar/crear/revisar/mergear, paginación y permisos | GM-021 |
| Launchpad y workspaces | `LaunchpadView`, RepoGroups, servicios de equipo; parcial | Agregación útil con cuentas reales, offline, filtros y deep links a repo/ref | GM-022 |
| Issue trackers | Plugins Jira, Linear, Taiga, Notion, Planner; parcial | Seleccionar issues, crear branch y volver al contexto; limitar promesas a endpoints validados | GM-021, GM-022 |
| Gitflow, hooks y firma | `WorkflowsView`, `GitHooksView`, `GPGSSHManagementView`; parcial | Mapear presets vs Gitflow real; firma y hooks con errores explicables y sin bypass silencioso | GM-023 |
| Terminal integrado | Ghostty y otras variantes; parcial | Definir backend soportado, foco/clipboard/IME y refresh tras comandos externos | GM-024 |
| Conflict prevention | Actor existente; parcial | Distinguir solapamiento de archivos de conflicto real; comparar contra merge fixture | GM-017 |
| IA y asistencia Git | Servicios Ollama/MLX y proveedores; parcial | Offline real, presupuesto de recursos, cancelación y revisión humana de acciones | GM-025 |
| Cloud patches y colaboración | Gists y servicios CloudKit/presencia; parcial | Contrato de privacidad, caducidad y capacidades; separar sharing de sincronización/presencia | GM-026 |
| Instalación y actualización | Release workflow y DMG existente; por verificar | Firma, notarización, actualización/migración y prueba en Mac limpio | GM-028 |

## Qué copiar de la experiencia y cómo adaptarlo

Priorizar la lectura del grafo, la relación visible entre WIP y cambios, las acciones de refs cerca del contexto y la continuidad del flujo de commit. Cada acción del menú contextual debe explicar su destino: origen, objetivo, commits afectados y si reescribe historia. El inspector debe cambiar por selección, sin obligar a reconstruir el contexto en otra pantalla.

En Mac, adaptar los chrome y controles: menú de app/Archivo/Edición/Visualización/Ventana/Ayuda, cierre y restauración de ventanas, Settings estándar, teclado y first responder. La densidad de un Git GUI profesional puede coexistir con controles nativos. Los colores de ramas y diffs deben tener redundancia en texto, formas y labels.

El parecido visual exacto queda pendiente de una baseline comparativa. M2 debe producir screenshots emparejados de repos y estados equivalentes, con tamaños y escala iguales. No aceptar una afirmación de “idéntico” a partir del código o de memoria del producto.

## Cálculo futuro de paridad

Para cada fila, registrar escenarios `no evaluado / falla / pasa / no aplica con razón`. La cobertura será `escenarios aprobados / escenarios aplicables acordados`. Reportar por separado funcionamiento, experiencia visual, accesibilidad, rendimiento e integración. Una nota alta visual no compensa una operación Git incorrecta.
