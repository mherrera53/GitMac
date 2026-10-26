# Temas, controles y confirmaciones: cambios comprobados

Este bloque corrige comportamiento real del producto. No cierra las 40 tareas: el registro conserva cinco verificadas, veintiuna en curso y catorce pendientes. Los hitos M0–M6, el plan detallado y el antiguo IMPLEMENTATION_ROADMAP remiten al mismo registro; no se suman como proyectos distintos ni se marcan terminados por generar documentos.

## Revisión ampliada: resolver y análisis

`conflict-theme-final-ui.xcresult` pasa siete pruebas, incluyendo nueve presets × catorce estados = 126 capturas, WIP con solo un conflicto, resolver real, persistencia custom, minimapa y visor de stash. `conflict-theme-ui-candidate.json` conserva fuentes y hashes tanto del ejecutable como de su debug dylib. El bloque posterior de terminal tiene candidato y pruebas propios; no hereda aprobación automática de este binario.

Se inspeccionaron las nueve hojas de contacto y originales del WIP, resolución preparada, visor de stash, análisis GitHub Dark/Dracula y editor Monokai. `conflict-theme-account-contrast.log` pasa nueve controles de glifos del botón GitHub sobre estas capturas nuevas. La suite del motor alcanzó 92 controles; los 80 citados abajo pertenecen al checkpoint anterior.

Qwen2.5VL local produjo nueve salidas completas sobre las hojas y quedó descargado. De sus 18 observaciones, dos orientaron a un problema de contraste en el caption del análisis; la inspección del original y `conflict-caption-before.log` demostraron nueve fallos entre 2.391 y 3.647. Las otras 16 no justificaron cambios: confundían celdas con ventanas superpuestas, el borrador con el tema aplicado o describían ausencia de problemas.

El primer cambio a texto secundario pasó ocho presets, pero Solarized Light quedó en 4.381. El cambio local a texto primario pasa los nueve en `conflict-caption-primary-after.log`, entre 10.062 y 17.985, sin cambiar las paletas globales. `terminal-literal-input-ui.xcresult` confirma el recorrido de nueve análisis; su prueba de terminal falló antes por asumir un panel cerrado, de modo que ese bundle completo no se presenta como verde. Las capturas corregidas están en `terminal-literal-input-captures` y la adjudicación en `conflict-theme-visual-adjudication.json`.

La inspección sigue limitada a los tamaños capturados y no certifica todas las interfaces, todos los estados ni VoiceOver. Accesibilidad para redimensionar continúa aplazada por el usuario. Las 126 imágenes del primer candidato no son una nueva matriz de terminal ni una aprobación de memoria.

## Evidencias del checkpoint anterior conservadas

## Cambios y ubicación

| Archivo / entrada | Cambio | Prueba |
| --- | --- | --- |
| `GitMac/UI/Theme/ThemeManager.swift:19` | Preferencias inyectables para pruebas; paleta custom determina apariencia nativa clara/oscura | Nueve presets y suite de UserDefaults aislada |
| `ThemeManager.swift:60` y `:69` | Aplicar notifica a las vistas; reset elimina la paleta persistida | Reset y relanzamiento no resucitan colores anteriores |
| `ThemeManager.swift:129` y `:321` | Importación JSON conserva texto elegido y colores explícitos de diff | Round-trip, compatibilidad y fallo sin modificar el tema activo |
| `GitMac/UI/Components/AppTheme.swift:20` | Los componentes usan fondos/textos/accent/estados Git custom; antes seguían dibujando colores nativos | Motor real y comprobación de píxeles de ventanas |
| `AppTheme.swift:216` | Contraste de texto según superficie real, incluyendo transparencia | Oracle sRGB independiente del cálculo de producción |
| `GitMac/UI/Components/Atoms/Buttons/DSButton.swift:23` | Una política compartida con DSIconButton para seis variantes y tres tamaños; carga conserva geometría | 999 checks; código anterior falla 255 |
| `GitMac/Features/Settings/Tabs/AccountsSettingsTab.swift` | La etiqueta GitHub hereda el foreground del botón | Ocho presets fallaban en píxeles; nueve pasan después |
| `GitMac/Features/Settings/Tabs/WorkflowSettingsTab.swift` | Retirado el título duplicado dentro de Ajustes | Recorrido y capturas de los nueve presets |
| `GitMacUITests/SnapshotHelper.swift:79` | Git aislado también durante el lanzamiento de la app, no solo al construir el fixture | Config e identidad sintéticas; checker de todos los lanzamientos |
| `SnapshotHelper.swift:96` | Activar y verificar el PID privado antes/después de capturar; no relanzar un candidato caído | Capturas verificadas; el intento contaminado se conserva como inválido |
| `GitMac/Core/Services/WorkflowEngine.swift` | Una ejecución activa, continuación consumida antes de resume, cancelación y UUID por ejecución/decisión | Siete escenarios reales; originales fallan cinco, incluidos dos SIGTRAP |

Los rangos completos, SHA256 anterior/actual y relaciones están en [changes.csv](changes.csv), [mapping/files.csv](mapping/files.csv), [mapping/symbols.csv](mapping/symbols.csv) y el [visor](mapping/graph.html). El mapa contiene relaciones candidatas de sintaxis y conserva sus errores de parser; no demuestra dispatch ni cobertura semántica completa.

## Qué se ejecutó

- `custom-theme-controls-final.log`: 80 comprobaciones del motor real, persistencia, JSON, nueve presets y tokens compartidos. `custom-theme-token-control.log` conserva 44 fallos con AppTheme anterior.
- `theme-controls-after.log`: 999 comprobaciones de botones e iconos, estados normal/hover/disabled y geometría durante carga. `theme-controls-negative.log` conserva 255 fallos del código anterior.
- `account-theme-ui.xcresult`: dos tests pasan, sin fallos; nueve presets × once ventanas/estados capturados = 99 PNG originales, más cinco capturas del recorrido funcional. Cada preset recorre editor, los nueve paneles de Ajustes y repositorio.
- `account-contrast-after.log`: nueve ventanas Accounts pasan; `account-contrast-before.log` registra ocho fallos. La prueba convierte el ICC a sRGB y verifica el foreground dibujado, no el indicador de tema seleccionado.
- `theme-controls-ui.xcresult`: tres tests pasan y uno se omite por AX. Incluye aplicar/restaurar Solarized Light y GitHub Dark tras relanzamiento, comprobando píxeles. Los archivos del motor/tema de esa prueba no cambiaron en la corrección posterior de Accounts.
- `workflow-decisions-after.log`: siete escenarios pasan. La respuesta tardía se reprodujo como fallo adicional en `workflow-stale-decision-before.log`. `workflow-decisions-negative.log` registra cinco fallos del código original, con un adaptador de firma explícito para que el control falle por comportamiento.
- `workflow-confirmations-git.log`: 37 checks de Git real en fixtures propios: fallos, pathspec, commits y push a bare local. La auditoría vuelve a ejecutarlos sobre el motor final.
- [verification.json](verification.json) registra la auditoría general y sus códigos esperados, incluidos negativos. El presupuesto de memoria y los UI tests se registran por separado; no se aprueban por pasar esa auditoría.

Los originales están en [account-theme-captures/manifest.json](account-theme-captures/manifest.json). Se inspeccionaron las nueve hojas de contacto finales, con procedencia/hash de sus 99 imágenes. El original Tokyo Night Accounts también se abrió a resolución completa. Las hojas reducen detalle y no sustituyen una inspección exhaustiva de cada PNG a tamaño original.

Las capturas se hicieron en el monitor LG externo a escala 2×, con Ajustes de 900 × 620 puntos. No acreditan el monitor integrado, todos los tamaños de ventana ni preferencias AX. El usuario eligió habilitar Accesibilidad después; no se alteró TCC ni se contó el skip como aprobación.

## Modelos locales y revisión independiente

Se usaron pesos instalados y API loopback de Ollama, con inferencias en serie y `keep_alive:0`:

| Modelo | Digest | Alcance |
| --- | --- | --- |
| `qwen2.5vl:7b` | `5ced39dfa4bac325dc183dd1e4febaa1c46b3ea28bce48896c8e69c1e79611cc` | Nueve hojas de comparación y nueve Accounts originales de la versión corregida; la revisión inicial de veinte imágenes queda como baseline separado |
| `glm-ocr:latest` | `6effedd0dc8aec66ad86c94b8099395376e212f22c87a9d7147c422f7e447be4` | 33 salidas completas sobre General/Git/Atajos y aplicación/restauración custom; leyó la identidad sintética en los nueve paneles Git |
| `qwen3-coder:30b` | `06c1097efce0431c2045fe7b2e5108366e43bee1b4603a7aded8f21689e90bca` | Contextos separados para propuesta y revisión de confirmaciones; sin aplicación automática |

Se conservan hashes de entrada, salida cruda, tiempos, tokens y observación de descarga. No se usó Cloud en este bloque.

Qwen visual confundió celdas de contacto con ventanas superpuestas y repitió un falso solapamiento entre OAuth Client ID y Save en los originales. Acertó la apariencia en ocho de los nueve Accounts; GitHub Light fue clasificado erróneamente. Los 27 hallazgos de esos dos datasets se contrastaron y ninguno justificó un cambio de código. Los problemas de contraste sí se demostraron con componentes y píxeles. Véase [adjudicación visual](theme-visual-review-adjudication.json).

El modelo de código también produjo afirmaciones incorrectas sobre el actor y el tipo retornado. Se rechazaron, se revisó la fuente y se ejecutaron pruebas. [Adjudicación de confirmaciones](workflow-confirmations-adjudication.json). Una respuesta JSON válida o un modelo descargado no son una aprobación del producto.

## Memoria y pico de arranque

`theme-workflow-release.log` compila el Release aislado que se midió en `theme-workflow-memory-1000.log`. Con 1.000 commits y señales de repo/ramas/grafo/minimapa cargados: máximo observado **252593232 bytes** y pico de vida **362202216 bytes**, frente a **150000000 bytes** permitidos. El gate falla. La muestra posterior por categorías bajó a 78431336 bytes; eso no elimina el pico.

`startup-window-memory.log` repite el diagnóstico con un observador CGWindow del PID privado: ventana visible de 900 × 450 puntos desde su aparición, sin crecimiento grande observado a intervalos de 50 ms; una ventana de 500 × 500 permanece oculta. No respalda la hipótesis de una ventana inicial enorme. El nuevo pico, 362447976 bytes, sigue fallando. En las primeras muestras se observan unos 168,5 MB de memoria gráfica no mapeada, que bajan a unos 0,7 MB después. Esto identifica categoría y momento, no todavía el objeto que la reserva.

El observador registra solo geometría del PID creado para la prueba: sin títulos, capturas, datos de otras aplicaciones, Accesibilidad ni modificaciones del Mac. Este segundo run es diagnóstico; no acredita una mejora de rendimiento. El siguiente contraste es el coste de los Canvas del grafo frente a una implementación equivalente; no se ha ocultado el grafo ni aceptado un benchmark con funciones desactivadas.

## Lo que permanece abierto

T19 conserva diálogos secundarios, estados de error/carga/autorización, editor adaptable, preferencias del sistema, monitor integrado y revisión completa con VoiceOver. El JSON se comprobó en el motor; los diálogos nativos de importar/exportar no tienen aprobación integral y el editor aún conserva limitaciones de draft/errores.

T30 conserva persistencia/herencia por repositorio, interfaz de ejecución, Gitflow y firmas/hooks. No se encontró un caller de producción de `WorkflowEngine.execute`; corregir y probar el motor no entrega por sí mismo esa interfaz.

El resto de los criterios sigue en [task-closure-audit.json](task-closure-audit.json): undo/rebase, operaciones y conectores completos, atajos/context menus, drag & drop, aislamiento integral, rendimiento/resistencia y distribución del candidato actual. La app instalada no se sustituyó; no se publicaron artefactos ni se hicieron commits en GitMac.
