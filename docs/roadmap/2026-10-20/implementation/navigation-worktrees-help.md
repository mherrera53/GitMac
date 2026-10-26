# Navegación, worktrees y ayuda contextual

Alcance: mejoras implementadas en el worktree; no equivalen a completar las 40 tareas ni a certificar toda la UX. El aislamiento geométrico de las columnas que corrigió el crash permanece intacto. El usuario confirmó estabilidad del recorrido stash → archivo → visor en candidate-lv8hVz.

## Qué cambió

- Pestañas: selección y cierre son botones independientes, nombre acotado, ruta completa en ayuda, pestaña activa desplazada a la vista, botón de apertura siempre fuera del scroll. El menú permite seleccionar repositorios abiertos y abrir recientes directamente.
- Configuración: Ajustes de la aplicación mediante SettingsLink nativo; opciones del grafo separadas en un menú con estados. Toolbar compacta y botones con etiquetas de accesibilidad y ayuda.
- Minimapa: consulta el historial local de la revisión congelada del grafo, identifica cada commit por SHA y respeta sus carriles. Conserva el índice completo y dibuja como máximo 4096 muestras. Arrastrar previsualiza; soltar solicita un salto, no un proceso Git por píxel. El salto limpia filtros para mostrar el destino y puede cancelarse al cambiar de repositorio. No hace fetch/deepen ni pretende incluir todas las refs.
- Worktrees: Abrir visible con un clic, ruta y rama claras, protección/bloqueo y acciones de Finder. Creación en dos pasos: tarea/rama y carpeta nueva; abrir en pestaña es una elección explícita. El formulario conserva los datos y explica el error si Git rechaza crear. La operación usa el repositorio capturado al abrir el formulario.
- Retirar worktrees: confirmación con ruta exacta y aviso de que se elimina la carpeta, no su rama, sin usar Papelera. La interfaz no ofrece forzar; el manager vuelve a consultar pertenencia y rechaza principal, actual, bloqueado, detached o con cambios. Git realiza la comprobación final. No se retiraron worktrees del usuario.
- Ayuda: botón «?» en la barra principal, grafo y flujos de worktrees; guía en español buscable sin conexión con 31 temas, explicaciones breves, riesgos y enlaces oficiales. Buscar/leer no ejecuta comandos. La guía no sustituye todas las opciones del manual. Drop de stash requiere confirmación; Apply/Pop explican la diferencia.

## Evidencia reproducible

- `contextual-final-debug.log`: compilación Debug del bloque final.
- `contextual-release.log`: resultado de la compilación Release, separado de aprobación visual.
- `production-suites-current.log`: suites enlazadas a las fuentes reales; 55 Swift Testing y 11 XCTest, si el audit final está verde.
- `core-regressions-and-models.log`: 21 comprobaciones y 11 XCTest. Tres comprobaciones nuevas demuestran salto por lotes de 1000/100, cursor exacto y continuación normal sin huecos.
- `MinimapLayoutTests`: historial sintético de 100 000 commits, identidad completa, presupuesto de dibujo, extremos, carriles, geometría y filtrado de filas auxiliares. No es un benchmark p95 de la app completa.
- `WorktreeHelpTests`: parser NUL con rutas Unicode/newline, bare sin HEAD, motivos de bloqueo, búsqueda y enlaces del catálogo. Git real aislado: crear, bloquear, rechazar retirada bloqueada/sucia y retirar limpio conservando rama y carpeta principal.
- `help-documentation-links.json`: los 31 enlaces del catálogo respondieron HTTP 200; es una comprobación puntual de acceso, no garantía de disponibilidad futura ni revisión de cada opción del manual.
- `verification.json` y `changes.csv`: hashes, rangos por archivo/línea, comprobaciones positivas y controles negativos. `mapping/graph.html`: visor actualizado tras finalizar el audit, no mientras se genera.

## Revisión local

`local-worktree-safety-review.json`: qwen3-coder:30b con pesos locales, remote:false, 13 668 tokens de entrada y 1154 de salida. Las propuestas no se aceptaron como hechos: las razones son opcionales en el formato de Git; removeWorktree comprueba pertenencia en una lista recién obtenida del repositorio capturado; UUID identifica la generación bajo MainActor, no es un lock; un cwd inválido produce un error propagado; el parser sí reconoce bare y tiene test. La revisión no ejecutó pruebas por sí misma. El coste de esta sesión principal no está incluido en esas cifras.

## Validación que falta

Pendiente comprobar la nueva UI con interacción real en Retina y LG, teclado y VoiceOver. No hay permiso de captura ni accesibilidad para automatizar esa revisión; no se presenta el build como prueba visual. Tampoco se certifican concurrencia de todas las ventanas, cada acción Git, rendimiento p50/p95 o todas las integraciones. La distribución técnica se registra por separado; no sustituye esos controles.

## Base documental

Flujos contrastados con [git-worktree](https://git-scm.com/docs/git-worktree), [tutorial de Git](https://git-scm.com/docs/gittutorial), [stash](https://git-scm.com/docs/git-stash), [reset](https://git-scm.com/docs/git-reset) y [catálogo completo](https://git-scm.com/docs/git). Controles nativos, jerarquía y ayudas se orientan por [toolbars de Apple](https://developer.apple.com/design/human-interface-guidelines/toolbars), [botones](https://developer.apple.com/design/human-interface-guidelines/buttons) y [accesibilidad](https://developer.apple.com/design/human-interface-guidelines/accessibility). Son criterios de diseño aplicados, no una certificación de cumplimiento total.
