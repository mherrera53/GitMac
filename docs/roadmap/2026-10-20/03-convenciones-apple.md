# Revisión frente a las convenciones de Apple

Las HIG orientan la interacción; no prescriben un número universal de puntos para cada fila ni prohíben una interfaz de Git densa. Los valores de diseño propuestos son decisiones de GitMac. Una interfaz personalizada no es automáticamente un incumplimiento. Se distingue recomendación de diseño de requisito de distribución.

| Área | Evidencia actual | Evaluación | Criterio de salida |
| --- | --- | --- | --- |
| Atajos estándar | La ayuda documenta ⌘W como word wrap; los bindings reales deben mapearse | Inconsistencia documental confirmada; captura efectiva pendiente | ⌘W cierra contexto/ventana según responder; ⌘Q, ⌘H, ⌘M, ⌘, y undo de texto conservan semántica estándar |
| Un solo vocabulario de comandos | Ayuda, menú y presets separados; ⌘⇧U se contradice | Defecto comprobado | Menú, ayuda, toolbar y palette provienen de un registro; la acción depende del contexto válido |
| Undo/redo | Gestor propio sin integración externa encontrada | Brecha funcional y riesgo si se activa tal como está | Comandos estándar en Edición; texto usa su UndoManager; Git opera con snapshots, nombre de acción y precondiciones |
| Recorder de atajos | TODO de captura de teclas | Funcionalidad incompleta | Graba, cancela con Escape, detecta colisiones y actualiza todos los puntos de presentación |
| Ventanas y título | `WindowGroup`, título oculto y configuración de primera ventana | Diseño permitido; falta verificación multiventana | Repo identificable, cerrar/reabrir/fullscreen/resize/restauración correctos; ninguna dependencia del orden de ventanas |
| Contexto de ventana | El estado `appState` se crea en App y se inyecta al WindowGroup | Verificar intención de compartir repos/tabs entre ventanas | Modelo explícito de sesión de app vs ventana vs repo; comandos afectan solo la ventana activa |
| Toolbar | Hay toolbar y botones propios | Requiere inspección visual y de accesibilidad | Acciones principales visibles, overflow a tamaños estrechos, labels/tooltips coherentes y disabled con razón |
| Sidebar | Componentes personalizados y múltiples paneles | No prueba incumplimiento | Jerarquía/selección/expansión claras, redimensionado y acciones por teclado; preferir APIs nativas cuando cubren el caso |
| Botones solo de icono | `DSIconButton` no exige action label | Riesgo sistemático; verificar call sites | Todo botón expone nombre de acción, role y estado; símbolo decorativo no sustituye el nombre |
| Grafo y staging accesibles | Existen labels/hints AX específicos | Base existente; calidad en ejecución pendiente | Se pueden seleccionar commits, leer refs, operar y volver al foco con VoiceOver y teclado |
| Gestos y hover | Ayudas de staging mencionan hover/doble clic; grafo incluye drag/context click | Requiere alternativa accesible | Stage, unstage, merge y rebase tienen acción de menú/teclado accesible sin ratón |
| Apariencia | ThemeManager soporta system/light/dark | No hay evidencia para afirmar que toda la app fuerza oscuro | Cambio de sistema en ejecución, selection/focus y controles legibles en todos los temas soportados |
| Contraste y color | Paletas de tema y status semánticos | No se midieron ratios en render final | Auditoría de contraste según contexto y ajustes; signos +/-/M/A/D, nombres y formas complementan color |
| Texto y escala | Tokens usan tamaños explícitos | No constituye por sí solo incumplimiento | Configuración de texto mayor sin cortar mensajes/acciones; probar 100/150/200% en flujos centrales |
| Movimiento/transparencia | Sin evidencia suficiente de adaptación en rutas revisadas | Pendiente de verificación | Respetar ajustes del sistema; reducir animaciones y material translúcido cuando se solicite |
| Alertas y destrucción | Acciones de discard/reset y comandos propios | Auditar cada ruta, no afirmar que todas carecen de confirmación | Nombre de acción y alcance precisos; cancelar predeterminado cuando corresponda; recuperación demostrada |
| Errores y progreso | Algunos errores solo se registran; ejecución por tres variantes | Inconsistencia comprobable, UX pendiente | Loading/error/stale/partial distintos; cancelación con resultado; errores Git accionables y no éxitos ambiguos |
| Credenciales | Archivo cifrado con clave derivada del hardware | Diverge del mecanismo recomendado para secretos de usuario | Migración verificable a Keychain; acceso por identidad de app; errores de persistencia visibles |
| Distribución | Release usa firma ad hoc; sandbox desactivado en proyecto | No equivale automáticamente a incumplir HIG | Definir canal directo/App Store, firma/notarización y entitlements mínimos para el canal; no exigir sandbox a toda distribución directa |

Apple recomienda mantener los atajos estándar y la interacción de undo en Edición. El contrato aquí exige además preservar el first responder para que una operación Git no intercepte el undo del editor. Véanse [teclados](https://developer.apple.com/design/human-interface-guidelines/keyboards) y [undo/redo](https://developer.apple.com/design/human-interface-guidelines/undo-and-redo).

La revisión de accesibilidad debe combinar [Accessibility Inspector y pruebas con ayudas del sistema](https://developer.apple.com/design/human-interface-guidelines/accessibility). El análisis de modificadores SwiftUI no sustituye ese recorrido. La propuesta usa nombre/rol/valor, orden de foco, ampliación de texto y alternativas de interacción como criterios verificables.

Para [ventanas](https://developer.apple.com/design/human-interface-guidelines/windows), [toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars) y [sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars), validar uso de espacio, jerarquía y controles en distintos tamaños. No imponer Liquid Glass ni una API de un sistema nuevo a la base macOS 14 sin disponibilidad y fallback.

El cambio de credenciales se fundamenta en [Keychain Services](https://developer.apple.com/documentation/security/keychain-services). La app debe probar lectura, actualización, borrado, bloqueo y migración. Esta auditoría no hizo pruebas de extracción de secretos ni leyó archivos de credenciales.
