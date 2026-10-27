# GitMac 4.1.2: notificaciones, sesiones y acciones

## Resultado y alcance

Esta entrega corrige la legibilidad de ambos sistemas de toast, conserva sesiones de terminal entre pestañas, hace visibles las acciones de worktrees y protege la selección staged durante Pull. No cierra las 206 tareas del roadmap ni certifica todas las acciones o repositorios posibles. La autorización OAuth real sigue necesitando la aprobación del usuario en el navegador; este cambio conserva el arreglo de persistencia de 4.1.1.

## Archivo, ubicación y cambio

- `GitMac/Core/Services/NotificationManager.swift`, `ToastAppearance` y `ToastNotificationView`: superficie opaca incluso con un tema custom translúcido, contraste mínimo de texto 4.5:1, texto multilínea, cierre accesible y errores con recuperación persistentes. El gestor limita la cola a cinco y cancela sus tareas al retirar notificaciones. Un error genérico ya no hereda una acción antigua ajena.
- `GitMac/UI/Components/ContextMenus.swift`, `ToastView` y `ToastManager`: el toast anterior reutiliza la misma vista y cancela el temporizador anterior; no oculta una notificación nueva por una cuenta atrás vieja.
- `GitMac/Features/Terminal/Views/TerminalInputBar.swift`, `body`: botón Run visible, ayuda de teclado y menú de comandos de consulta. Insertar requiere un editor vacío y nunca ejecuta el comando. Sugerencias solo bajo petición; tareas canceladas al ocultarse. `git clean` sugerido usa dry run.
- `GitMac/Features/BottomPanel/Views/UnifiedBottomPanel.swift`, `TerminalSessionVisibility`: identidad estable para terminales visitadas; pestañas restauradas ocultas no crean un PTY hasta abrirlas. Ocultar el panel conserva la sesión; cerrarla la libera.
- `GitMac/Features/BottomPanel/Views/BottomPanelContent.swift`, `GhosttyWithAIInput` y `GhosttyPureNSView`: cambiar repositorio no inyecta `cd` en un shell activo. El usuario elige abrir otra terminal o cambiar de carpeta. Las superficies ocultas dejan de renderizar; liberar se hace en `dismantleNSView`.
- `GitMac/Features/BottomPanel/Views/BottomPanelTabBar.swift` y `GitMac/UI/Components/Xcode/XcodeBottomBarTab.swift`: identificadores, estado seleccionado y ayudas accesibles para abrir, seleccionar, cerrar y ocultar.
- `GitMac/Features/Worktrees/WorktreeListView.swift`, `actionsMenu`: búsqueda y acciones compartidas entre menú visible y contextual, abrir con doble clic y terminal en el worktree elegido. Las mutaciones se deshabilitan mientras otra operación está en curso.
- `GitMac/Core/Services/WorktreeManager.swift`, `beginOperation`: exclusión de mutaciones independiente del refresco, liberada también ante error.
- `GitMac/Core/Git/GitOperationHandler.swift`, `execute`: exclusión compartida por repositorio entre handlers efímeros, resultados tardíos limitados a su repositorio y reintento explícito únicamente para Fetch. Las mutaciones no se repiten desde un toast antiguo.
- `GitMac/Core/Git/Remote.swift:135`: autostash deja de ser implícito; el opt-in explícito permanece. Prueba con dos clones y remoto bare verifica bytes, índice staged y rechazo seguro de divergencias.
- `GitMac/Features/CommitGraph/Models/GraphNode.swift`, `MinimapObjectID` y `MinimapLayout`: identidades SHA-1 de 160 bits inline, fallback literal exacto para otros formatos, índices compactos y escaneo sin arrays temporales de filas. Mantiene padres, lanes, índices globales, merges e identidades; no recorta el historial para cumplir RAM.

## Validación reproducible

Los logs locales con prefijo `interaction-` están en este directorio; imágenes, xcresult y paquetes están bajo `build/` y no se versionan.

| Prueba | Resultado |
| --- | --- |
| `node scripts/test-toast-interactions.mjs` | 145 comprobaciones, cero fallos; 36 tarjetas, nueve paletas y contraste/tema custom |
| `node scripts/test-worktree-interactions.mjs` | 13 comprobaciones, cero fallos; frontera de proceso simulada explícitamente |
| `node scripts/test-git-action-coordination.mjs` | 11 comprobaciones, cero fallos; coordinación real con I/O aislado |
| `node scripts/test-terminal-command-contracts.mjs` | 35 comprobaciones, cero fallos |
| `node scripts/test-native-terminal-wire.mjs` | 18 comprobaciones, cero fallos; bytes y visibilidad nativa |
| `node scripts/test-production-suites.mjs` | 89 tests Swift Testing, 14 suites aprobadas; incluye remoto Git real aislado |
| `node scripts/test-minimap-allocation.mjs --parser-edge-cases` | 1.145 casos equivalentes a referencia, cero fallos |
| Control `--parent-lane-control` | 124 fallos de comportamiento de 130 casos; confirma sensibilidad |
| Control `--autostash-control` | Detecta pérdida de selección staged; fallo esperado |

Las hojas de contacto de toasts fueron inspeccionadas. `qwen2.5vl:7b` realizó una revisión visual local, con `keep_alive:0`; se verificaron pesos locales, ausencia de host remoto y descarga al finalizar. Su comentario genérico sobre contraste no identifica una paleta ni sustituye las mediciones de color.

## RAM y distribución

Release 4.1.2, build 12. El ejecutable firmado tiene SHA-256 `2b12b612be86b95a10153bdd2dbdac144cf267f65a8ade7cbd91fab80def8010`.

El perfil sin instrumentación de 100.000 commits, grafo nativo y minimapa cargados pasó: máximo físico y pico de vida **144.114.864 bytes**, 21 muestras, presupuesto **150.000.000 bytes**. La copia perfilada contiene exactamente el mismo ejecutable firmado que la distribución; se separó para completar el stapling sin ejecutar la copia distribuible. No incluye pesos de IA, procesos auxiliares, todas las acciones ni una garantía universal. Se conservan las mediciones anteriores fallidas de 156.337.328 y 151.209.136 bytes; no fueron instaladas.

Apple aceptó la entrega `9f3c5e2b-8063-4f53-aa92-64f66f6da27a`. Firma estricta, hardened runtime, ticket y Gatekeeper se validan en `interaction-distribution.json`. La prueba nativa final pasó en 61,799 segundos: Run y Enter envían los bytes al shell real y el estado del shell sobrevive al cambio de pestaña. Resultado: `build/interaction-final-ui.xcresult`; ambas capturas exportadas se inspeccionaron.

Instalada y abierta `/Applications/GitMac.app`, versión 4.1.2 build 12, con el mismo SHA-256 firmado y validaciones de firma/ticket/Gatekeeper aprobadas. `interaction-installation.json` registra el respaldo completo, PID y comparación del archivo cifrado antiguo antes/después: intacto, sin importarlo ni descifrarlo. El usuario mantiene su checkout master; los cambios están aislados en `fix/readable-toasts-and-action-usability`.
