# Spec de experiencia y revisión visual

## Composición objetivo

La referencia espacial es el flujo de GitKraken: repositorios y acciones arriba, referencias a la izquierda, grafo en el centro y contenido de la selección a la derecha. En GitMac, esa estructura debe usar el comportamiento de ventanas, foco y comandos del Mac. Este es un diseño propuesto; no una descripción de screenshots ya revisados.

```text
┌ controles de ventana · nombre/contexto del repositorio ──────────────┐
│ pestañas de repositorios · nueva pestaña · navegación                │
├ referencias ┬ acciones Git / rama activa / estado de operación ┬─────┤
│ buscar     │ buscar commits · filtros activos                 │     │
│ locales    │                                                  │ WIP │
│ remotas    │ grafo · refs · mensaje · autor · fecha            │ o   │
│ tags       │                                                  │ SHA │
│ stashes    │ selección/compare · carga incremental             │     │
│ worktrees  │                                                  │     │
├────────────┴──────────────────────────────────────────────────┴─────┤
│ panel inferior opcional: terminal / actividad                       │
└ estado del repositorio · rama/upstream · progreso/errores ───────────┘
```

Evitar duplicar una acción primaria en tres toolbars simultáneas. El inspector tiene dos modos centrales: WIP para staging/commit y commit seleccionado para metadata/archivos/diff. Los modos avanzados abren un workspace contextual o sheet según necesiten conservar comparación y navegación. El terminal es opcional y no debe desplazar el camino principal de staging.

## Jerarquía y densidad

Valores iniciales para prototipo, no requisitos de las HIG:

| Elemento | Propuesta inicial | Verificación |
| --- | --- | --- |
| Ventana de comparación | 1440×900 y 1280×800 pt | Capturas a la misma escala y mismo repo en ambos productos |
| Layout compacto | 1024×700 pt | Collapse/overflow; todas las acciones siguen alcanzables |
| Sidebar | 220–300 pt, ajustable | Labels largos, remotos y grupos; scroll/ellipsis con detalle |
| Inspector de WIP/commit | 300–420 pt, ajustable | Mensaje multilínea, selección de archivos y acciones visibles |
| Área de grafo | Flexible, prioridad de espacio central | Mensajes legibles y badge overflow; navegación horizontal si hace falta |
| Fila compacta de historial | 28–32 pt inicialmente | Foco y targets cómodos a escala normal; crecer con texto ampliado |
| Texto de contenido | Tipografía del sistema, base próxima a 13 pt | Legibilidad en pantallas reales y ampliación del usuario |
| Código/diff | Monoespaciada configurable | No confundir alineación con tamaños rígidos; 100/150/200% |
| Espaciado | Escala semántica compatible con tokens existentes | Revisar jerarquía, no reemplazar números masivamente |

Probar también la dimensión mínima actualmente permitida por la app; el layout compacto propuesto no demuestra que su minimum size ya sea correcto. Si hace falta colapsar, mostrar cómo recuperar paneles con menú y atajo. No reducir texto hasta volverlo ilegible para mantener una proporción visual.

## Estados por superficie

| Superficie | Normal | Vacío / sin datos | Error / parcial | Operación activa |
| --- | --- | --- | --- | --- |
| Inicio | Recientes/grupos y Open/Clone/Init | Acciones locales claras sin login obligatorio | Ruta movida, Git ausente o permisos con recuperación | Progreso de clone y cancelar |
| Sidebar | Refs jerárquicas y actual marcada | Repo unborn explica ausencia de branches/commits | Refresh fallido conserva último snapshot con antigüedad | Acción deshabilitada solo donde haya conflicto |
| Grafo | Selección y HEAD visibles | Sin commits distinto de filtro sin resultados | Shallow/límite/timeout distintos; retry específico | Carga incremental conserva ancla |
| WIP | Staged/unstaged y draft | Working tree limpio con branch/upstream | Conflicto separado; patch obsoleto no se aplica | Stage/commit muestra acción y evita doble submit |
| Diff | Origen/destino, hunks y navegación | Sin diferencias según opciones activas | Binario, tamaño, encoding y contenido omitido explícitos | Carga/cancelación sin bloquear resto de ventana |
| Operación Git | Estado base y acciones contextuales | Sin operación pendiente | Rejected/conflict/partial con siguiente acción válida | Progreso, fase, elapsed y cancelación si soportada |
| PR/integración | Cuenta, host y capacidad | No hay resultados distinto de cuenta no conectada | Expiración/rate limit/permiso/offline distintos | Mostrar qué acción se envía y el destino |

No borrar datos visibles y mostrar un spinner genérico por cada refresh. La UI debe distinguir snapshot anterior de datos actuales y evitar habilitar operaciones destructivas sobre información ya obsoleta.

## Contratos de interacción

Selección de un commit abre su detalle conservando el grafo. Selección WIP abre staging. Selección de archivo abre diff con origen/destino explícitos. Escape cierra el elemento transitorio y devuelve foco; no descarta drafts ni cancela una operación Git iniciada sin explicar el efecto.

Stage/unstage por línea requiere selección identificable y resultado exacto. Hover puede revelar un acceso rápido, pero la misma acción está disponible por botón enfocable, menú o comando. Un gesto drag de una branch a otra muestra antes qué significa: merge/rebase/crear PR no deben depender de una interpretación invisible del gesto.

Undo de texto pertenece al editor activo. Undo Git tiene nombre de operación y precondiciones, y no aparece disponible por el mero hecho de existir un historial en memoria. Reset/discard/delete especifican repo, archivos o refs afectados; la confirmación usa verbos concretos. No afirmar recuperación de archivos que nunca se guardaron.

Los menús contextuales agrupan acciones de lectura, navegación, operaciones Git y destrucción. Las acciones no disponibles explican la causa cuando sea útil. La misma operación usa el mismo nombre en menú, ayuda, palette y notificación.

## Temas y accesibilidad visual

Usar colores de superficie/texto/selección/foco semánticos y verificar los pares realmente renderizados en cada tema soportado. Los colores de lanes tienen redundancia de recorrido/label; los cambios Git usan signos y texto. La selección de ventana inactiva se distingue sin aparentar que desapareció.

Respetar apariencia de sistema, contraste, reducción de transparencia y movimiento. Los materiales nuevos se usan con availability para mantener macOS 14. La app necesita una preferencia de lectura de código que no cambie el tamaño global de controles inesperadamente.

## Baseline comparativa y revisión

Crear las siguientes escenas en ambos productos con el mismo fixture: repo limpio; WIP con 20 archivos; staging parcial; merge complejo con varias refs en un SHA; conflicto texto; rebase planificado; worktrees; PR abierto; tema claro y oscuro. Capturar ventana, escala, sistema y versión de cada app.

Para cada escena registrar: jerarquía, densidad, legibilidad, alineación, selección/foco, feedback, pasos necesarios y errores encontrados. Registrar diferencias deliberadas por convención Mac. Un diff de píxeles ayuda a detectar regresiones de GitMac contra su propia baseline; no decide automáticamente si se parece a GitKraken.

Toda captura de una modificación debe abrirse y revisarse. La aprobación debe incluir imágenes efectivamente inspeccionadas, no solo rutas de archivos generados. Esta auditoría deja preparada la matriz; no afirma haber capturado ni aprobado esas escenas.
