# Plan de trabajo auditado: rápido, seguro y completo

Fecha de revisión: 20 de octubre de 2026. Complementa las [28 specs](05-specs.md), los [22 hallazgos](01-auditoria.md) y los [presupuestos iniciales](07-verificacion.md). El plan está revisado contra evidencia y fuentes; la aplicación todavía no está optimizada ni certificada por este documento.

## Qué cambia respecto al roadmap inicial

Se convierte el roadmap en 40 tareas con dependencia, prueba y evidencia de cierre. Se añade una matriz que exige corrección, rendimiento y seguridad a las 28 specs, y un criterio para adoptar tecnología nueva solo cuando resuelva un problema medido. Ninguna funcionalidad pasa a terminada por verse bien o por responder rápido en un caso pequeño.

Los esfuerzos de 143–244 días-persona del paquete original siguen siendo una referencia inicial, no una nueva estimación comprometida. Las tareas son descomposición de esas specs, no días adicionales que deban sumarse otra vez. La ampliación de controles de cadena de suministro y medición debe refinarse al arrancar T01/T07; puede modificar el rango.

## Prácticas vigentes contrastadas

| Práctica / fuente primaria | Evidencia consultada | Decisión para GitMac | Condición de adopción |
| --- | --- | --- | --- |
| [Swift 6.3, publicado en marzo de 2026](https://www.swift.org/blog/swift-6.3-released/) | Release estable documentada con mejoras de lenguaje e interoperabilidad C | Evaluar toolchain compatible con MLX/editor/Ghostty y macOS mínimo; no introducir sintaxis nueva solo por actualidad | Build y matriz de dependencias aprobados; no afirmar que esta es necesariamente la última versión de todo canal |
| [Concurrencia de Swift 6.2](https://www.swift.org/blog/swift-6.2-released/) | Opciones de aislamiento y ejecución async, con concurrencia explícita | Escribir una decisión de aislamiento por módulo; auditar cada escape `@unchecked Sendable` o `nonisolated(unsafe)` | Pruebas de estado obsoleto y diagnóstico del compilador; `async` no demuestra ejecución fuera de MainActor |
| [Instruments, WWDC26](https://developer.apple.com/videos/play/wwdc2026/268/) | Perfilado Release, análisis de CPU, esperas y ejecutores | Capturar trazas reproducibles antes/después de optimizaciones | Usar herramientas disponibles; reparar la incompatibilidad local de Xcode antes de exigir Instruments 27 |
| [SwiftUI performance](https://developer.apple.com/documentation/xcode/understanding-and-improving-swiftui-performance) | Diagnóstico de actualizaciones y trabajo de vistas | Medir invalidaciones, identidades y cálculos de layout; acotar actualizaciones observadas | Elegir mejoras por traza; no cambiar toda la app a un patrón de estado nuevo sin prueba |
| [NIST SSDF](https://csrc.nist.gov/Projects/ssdf/publications) | 1.1 figura final; 1.2 figura draft en el listado consultado | Usar 1.1 como marco de prácticas; rastrear 1.2 como borrador, sin presentarlo como estándar final | Threat model, revisión, pruebas y respuesta a vulnerabilidades con evidencia |
| [SLSA 1.2](https://slsa.dev/spec/v1.2/) | Especificación aprobada de seguridad y procedencia de fuentes/builds | Vincular artefacto, fuentes, build y dependencias; planificar provenance y verificación | Definir controles logrados; no declarar un nivel SLSA sin evaluación de sus requisitos |
| [Seguridad de GitHub Actions](https://docs.github.com/en/actions/reference/security/secure-use) | Permisos mínimos, manejo de secretos, checkout no confiable y acciones fijadas | Fijar actions a SHA revisados, limitar permisos por job y separar validación de publicación | SHA obtenido del upstream real y verificado; no inventarlo ni dar secretos a código no confiable |
| [Apple Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility) | Interacción perceptible y adaptable, con ayudas del sistema | Teclado/AX, texto, contraste y movimiento forman parte de cada entrega | Inspector y recorrido real, no conteo de modificadores SwiftUI |

La sesión WWDC26 se aplica como método de medición. No exige elevar la versión mínima del producto. Las mejoras de C de Swift 6.3 son candidatas para puentes nativos solo si reducen problemas comprobados. Mantener módulos dentro del monolito actual con límites claros es la arquitectura inicial; no hay evidencia que justifique microservicios para este cliente macOS.

## Regla de cierre de una tarea

Cada tarea necesita dueño nominal, fecha de inicio, commit, fixture, resultado esperado y resultado observado. Su entrega es un cambio pequeño revisable o un artefacto de diagnóstico con decisión concreta. Estado inicial de todas las tareas: `pendiente`. La auditoría de este plan no las marca implementadas.

El ticket se cierra con comportamiento correcto, presupuesto de rendimiento aplicable y revisión de seguridad. Una prueba no ejecutada se registra como no ejecutada; una falla de infraestructura se separa de un defecto del producto. Los ejemplos de pruebas indican qué demostrar; no autorizan escrituras a cuentas o repos externos.

## Secuencia de trabajo punto por punto

La columna depende de expresa condiciones de arranque; no obliga a serializar tareas independientes. Git/macOS, UX y QA pueden trabajar en paralelo cuando los contratos estén fijados. El responsable y rango de esfuerzo del ticket padre están en las specs originales.

| ID | Trabajo concreto | Specs | Depende de | Aceptación y evidencia de cierre |
| --- | --- | --- | --- | --- |
| T01 | Congelar baseline: commit, cambios ajenos, escenarios y equipo de referencia; definir unidades de medición | GM-001, GM-027 | ninguna | Inventario y ficha de benchmark; conservar cambios previos; no hay números de rendimiento inventados |
| T02 | Diagnosticar toolchain y fijar compiler/SDK/target compatibles | GM-001 | T01 | Build mínimo y carga del proyecto sin fallo CoreDevice/SDK; registrar solución local antes de atribuir errores a GitMac |
| T03 | Reconciliar proyecto Xcode, XcodeGen y SPM; decidir fuente de verdad | GM-001 | T02 | Build limpio de Debug y Release; regeneración controlada conserva productos/targets; matriz documentada |
| T04 | Hacer que CI falle correctamente y limite permisos | GM-001 | T03 | Fallos deliberados de Swift, enlace y test dejan CI roja; resultado vacío falla; permissions mínimos por job |
| T05 | Conectar tests a modelos y parsers de producción | GM-002 | T04 | Mutación deliberada del código real rompe la prueba; retirar modelos sombra del camino de validación |
| T06 | Construir catálogo de fixtures aislados y oracle Git | GM-002 | T05 | Fixtures F01–F15 reproducibles; validar refs/index/blobs, sin depender de configuración global del usuario |
| T07 | Hacer threat model y asignar controles a cada frontera | GM-004, GM-008, GM-026, GM-028 | T01 | Tabla entrada/activo/amenaza/mitigación/prueba/dueño; incluir repo malicioso, shell, tokens, red y release |
| T08 | Cerrar interpolación shell y falsos éxitos de patches | GM-004, GM-026 | T06, T07 | `git apply` usa argv/cwd, soporta apóstrofos; exitCode no cero falla; contenido adversario no ejecuta órdenes |
| T09 | Unificar status NUL y preservar ambos estados XY y oldPath | GM-003 | T06 | Pasan las cinco regresiones reproducidas y F02/F03; snapshot igual en staging, context y refresh |
| T10 | Unificar ejecución, streaming, progreso, buffering y cancelación | GM-004 | T06, T07 | F13 sin deadlock, pérdida de UTF-8 ni buffers ilimitados; resultado una vez y recursos liberados |
| T11 | Definir identidad de repo, worktree, ventana y operación | GM-005 | T09, T10 | Documento de ownership/locks/cachés; distinguir working tree y common git dir; adopción en una ruta vertical |
| T12 | Impedir publicaciones obsoletas y ordenar invalidaciones | GM-005 | T11 | A lenta/B rápida y tareas auxiliares no cruzan estado; cierre de tabs elimina recursos propios |
| T13 | Migrar secretos a Keychain con verificación y recuperación | GM-008 | T06, T07 | Credenciales sintéticas sobreviven migración interrumpida; bloqueo/denegación/persistencia fallida dan error real |
| T14 | Implementar journal y undo por operación con precondiciones | GM-006 | T09, T10, T12 | F07 conserva cambios nuevos y compara snapshots; tipos sin recuperación quedan deshabilitados |
| T15 | Ejecutar exactamente el plan de rebase y recuperar sesiones | GM-007 | T14 | Pick/reorder/reword/squash/fixup/drop aprobados en F06; continue/abort/reinicio correctos |
| T16 | Unificar comandos, ayuda, presets y recorder de teclado | GM-009 | T12 | Resolver Push/Unstage; proteger atajos estándar y first responder; recorder funcional y persistente |
| T17 | Cerrar navegación, tabs, multiventana y restauración | GM-010 | T16 | F15 y rutas movidas aprobados; draft, selección y foco no saltan de repo; restore no muta Git |
| T18 | Auditar y corregir teclado, VoiceOver y ajustes del sistema | GM-011 | T16, T17 | Flujo central completo con Inspector/VoiceOver; nombres/estados/foco probados y evidencia registrada |
| T19 | Consolidar tokens/componentes activos y baseline visual | GM-012 | T18 | Escenas claras/oscuras/ampliadas revisadas; diferencias con GitKraken justificadas; ninguna variante retirada sin referencias |
| T20 | Corregir alcance/topología de grafo y múltiples refs por SHA | GM-013 | T09, T12 | F04 coincide con oracle de parents; local/remoto/tag/HEAD correctos; límites shallow visibles |
| T21 | Optimizar paginación, lanes, minimap y scans del historial | GM-013, GM-027 | T20 | F05 y fixture 100k con p95/footprint; no cargar todo para abrir; evitar fetch deepen repetido/implícito |
| T22 | Afinar búsqueda/filtros, selección, compare y drag del grafo | GM-014 | T16, T18, T19, T21 | Flujo equivalente GitKraken/GitMac documentado; origen/destino antes de mutar y alternativa por teclado |
| T23 | Verificar staging de archivo/hunk/línea y patches obsoletos | GM-015 | T09, T12, T14 | F03/F10 producen index/tree exactos; cambios concurrentes invalidan la selección insegura |
| T24 | Consolidar renderer de diff, búsqueda, historia y blame | GM-016 | T10, T18, T23 | Unified/split equivalentes; grandes/binarios con fallback visible; benchmark sin bloquear MainActor |
| T25 | Completar commit/amend y resultados parciales commit→push→PR | GM-015, GM-018, GM-021 | T23 | No doble commit; fallo posterior conserva lo ya hecho y reintenta solo el paso necesario |
| T26 | Unificar conflictos, continue/abort y límites de predicción | GM-017 | T15, T24 | F08 y reinicio aprobados; base/current/incoming precisos; predicción no se presenta como garantía |
| T27 | Cerrar auth Git, red, progreso y autofetch controlado | GM-018 | T10, T12, T13 | F11 verifica offline/rechazo/token/SSH/cancelación; backoff acotado y sin force automático |
| T28 | Completar branches, tags, stash, reset y cherry-pick | GM-019 | T14, T26, T27 | Preview/ref revalidada; stash por identidad estable; operaciones parciales recuperables |
| T29 | Completar worktrees, submodules y LFS | GM-020 | T11, T20, T27, T28 | F09/locks/dirty/auth; WIP por worktree correcto, capacidades ausentes visibles y eliminación segura |
| T30 | Verificar Gitflow, hooks y firmas GPG/SSH | GM-023 | T13, T27, T28 | Feature/release/hotfix reales; hook fallido visible; claves sintéticas, sin bypass ni cambio global implícito |
| T31 | Entregar vertical PR GitHub y matriz de capacidades multihost | GM-021 | T13, T25, T27, T28 | Base/head dinámicos, paginación/permisos/checks; contratos por host y escritura solo con intención explícita |
| T32 | Completar workspaces, Launchpad e issue→branch→PR | GM-022 | T17, T31 | Cuenta/repo correctos, snapshot offline con edad y error parcial; plugins solo con endpoints comprobados |
| T33 | Consolidar terminal y ciclo de vida de sesiones/procesos | GM-024 | T10, T12, T16 | Backend soportado, IME/resize/clipboard/foco; refresh tras CLI y recursos propios liberados |
| T34 | Optimizar IA local opt-in con límites de contexto y memoria | GM-025 | T10, T13, T23 | Red exterior bloqueada, aliases cloud rechazados, cancelación y recursos medidos; ninguna operación automática sobre Git |
| T35 | Completar compartir patches, expiración y colaboración | GM-026 | T08, T13, T23, T31 | Metadata round-trip, semántica real de acceso/revocación y apply seguro; no prometer privacidad/caducidad inexistentes |
| T36 | Perfilar todos los flujos en Release y resolver cuellos medidos | GM-027 | T19, T21, T22, T24, T26, T27, T29, T30, T32, T33, T34, T35 | Trazas antes/después, p50/p95 y memoria por función; no optimización aceptada sin corrección preservada |
| T37 | Validar concurrencia, resistencia y entradas adversarias | GM-002, GM-004, GM-005, GM-008, GM-026, GM-027 | T36 | Sesiones largas, cancelación/churn, fuzz de parsers, fallos de disco/red y sanitizers aplicables; ningún fallo crítico sin resolver |
| T38 | Endurecer dependencias, CI, artefactos y procedencia | GM-001, GM-028 | T04, T07 | Versiones y SHAs upstream verificados, inventario/licencias/vulnerabilidades, permisos mínimos, checksums/provenance verificable |
| T39 | Probar app distribuida, instalación, upgrade y recuperación | GM-028 | T37, T38 | Mac limpio y matriz de OS/arquitectura; firma/notarización por canal, migración/rollback y datos preservados |
| T40 | Auditoría final por escenario y decisión de candidato | GM-028 | T39 | Matriz de 28 specs completa con evidencia; cero P0, decisiones P1 explícitas; candidato separado de publicación |

## Rapidez y seguridad para todas las funcionalidades

Cada fila debe cerrar las tres columnas y enlazar la ejecución. `No aplica` requiere motivo y revisión, no es un valor por defecto. Los límites propuestos de tiempo están en [verificación](07-verificacion.md); las métricas de proveedor/red se separan del procesamiento local.

| Spec | Corrección que no se negocia | Optimización a medir | Control de seguridad y prueba |
| --- | --- | --- | --- |
| GM-001 | Build/test realmente fallan cuando deben | Tiempo limpio/incremental y caché con identidad correcta | Build sin secretos en PR no confiable; dependencia y artefacto rastreables |
| GM-002 | Test ejecuta producción y detecta regresión | Suites pequeñas por cambio; medir duración/flake rate | Fixtures aislados; no ejecutar destructivos en repos reales |
| GM-003 | Ruta/XY/oldPath/estado exactos | Parser lineal, menos subprocesses y stats por demanda | Fuzz de delimitadores/rutas; argv y pathspec sin reinterpretación |
| GM-004 | Completar una vez, preservar salida y resultado | Buffers acotados, I/O concurrente y cancelación | Sin inyección ni procesos propios huérfanos; no matar externos |
| GM-005 | Contexto/generación correctos | Coalescing, invalidación específica y watchers acotados | A/B/worktrees aislados; escrituras incompatibles coordinadas |
| GM-006 | Recuperar ref/index/contenido previsto | Journal incremental; coste y retención medidos | Precondiciones y snapshot; no reset hard ciego |
| GM-007 | Plan seleccionado equivale al DAG final | Preview incremental; progreso sin bloquear UI | Sequence editor controlado, worktree y abort probados |
| GM-008 | Persistencia y migración verificadas | Lectura de Keychain fuera del camino bloqueante; cache limitada | Control de acceso por identidad/cuenta; errores no silenciados |
| GM-009 | Una acción por atajo y contexto | Lookup simple; no listeners/handlers duplicados | First responder protegido; disponibilidad y permisos revalidados |
| GM-010 | Tabs/drafts/ventanas restauran estado propio | Carga diferida, sesiones y vistas liberadas | No mutar repo por restore; rutas movidas y permisos claros |
| GM-011 | Flujo completo por teclado/VoiceOver | Árbol AX útil y actualizaciones no ruidosas | Acciones destructivas identificables; foco/confirmación accesibles |
| GM-012 | Estados y temas legibles | Invalidaciones de tema/layout y materiales medidos | Contraste y redundancia; no ocultar destructive/error |
| GM-013 | DAG/alcance/refs correctos | Paginación, layout fuera de UI y minimap incremental | Sin fetch/deepen automático ilimitado; límites explícitos |
| GM-014 | Selección y destino precisos | Filtrado/búsqueda indexados solo si la traza lo justifica | Preview y alternativa por teclado; revalidar ref antes de escribir |
| GM-015 | Index/tree exacto de selección | Patch/diff por demanda; menos refresh globales | Snapshot/versionado; doble submit y patch obsoleto bloqueados |
| GM-016 | Diff unificado/split equivalentes | Virtualización y fallback por tamaño; caché por identidad/opciones | Datos grandes/encoding adversario, sin truncado silencioso |
| GM-017 | Resultado guardado y operación final real | Parseo por archivo y edición incremental | Continue/abort seguros; IA nunca aplica sola; predicción limitada |
| GM-018 | Fetch/pull/push y upstream precisos | Batch/coalescing, backoff y pausa de autofetch | Auth por host; lease para force; sin retry ciego de escritura |
| GM-019 | Refs y stash identificados correctamente | Consultas por refs y detalles bajo demanda | Revalidar SHAs/locks, proteger trabajo sucio y recuperación |
| GM-020 | Estado aislado de cada worktree/submodule/LFS | Refresh dirigido y concurrencia limitada | Dirty/lock/branch ocupada y rutas .git resueltas por Git |
| GM-021 | Capacidad/permiso/base/head reales | Pagination/ETag cuando soporte el servicio; cancelar UI obsoleta | Tokens por cuenta/host; revisar antes de enviar review/merge |
| GM-022 | Issue y PR abren repo correcto | Agregación incremental y caché con antigüedad | Aislar cuentas; deep links validados y plugins con capacidades |
| GM-023 | Workflow, hook y firma dan resultado real | No repetir firmas/hooks innecesariamente | Nunca bypass silencioso; claves privadas fuera de logs/export |
| GM-024 | Terminal interactivo, cwd y foco correctos | Rendering y output acotados; medir sesiones simultáneas | Procesos propios, paste/clipboard y redacción; comandos solo por intención |
| GM-025 | Sugerencia revisable, app funcional sin IA | Una inferencia pesada inicial; contexto y KV/memoria presupuestados | Comprobar pesos locales, sin fallback cloud ni ejecución autónoma |
| GM-026 | Patch y metadata sobreviven round-trip | Streaming/tamaño/caché limitada de contenido | argv, validación de base, privacidad real y revocación demostrada |
| GM-027 | Benchmark representa flujos reales | p50/p95, frame hitches, RSS/footprint, CPU/energía | Logs sin secretos/código por defecto; límites contra agotamiento |
| GM-028 | Artefacto instalado equivale al revisado | Arranque/instalación/upgrade medidos en Mac limpio | Firma/canal/notarización, provenance, migración y rollback probados |

## Cómo se optimiza sin degradar seguridad

Para cada cuello: reproducir con fixture y build Release; medir CPU, esperas de I/O, número de procesos, invalidaciones de UI y memoria; formular una hipótesis; hacer un cambio; comparar el mismo caso; repetir las pruebas de corrección/seguridad. Registrar ganancia absoluta y dispersión, además del porcentaje relativo.

Antes de introducir caché, definir clave, ámbito, presupuesto, invalidación y comportamiento offline/stale. Una caché que acelera el panel pero muestra estado de otro repo es un fallo. La identidad debe incluir repo/worktree y, según consulta, refs/index/opciones; un TTL no sustituye invalidaciones de operaciones propias.

Concurrencia acotada por recurso: lecturas Git independientes pueden agruparse si no saturan procesos/disco; mutaciones compatibles se coordinan por common-dir/index; red tiene backoff y límite; IA tiene su propio presupuesto. No usar `Task.detached` como sustituto de diseñar cancelación y ownership.

Seguridad se incorpora antes de conectar UI: eliminar shell interpolada, verificar exit codes, proteger credenciales, modelar precondiciones de historia y mantener controles accesibles. Sanitizers y fuzzing complementan las pruebas; no sustituyen revisión de semántica Git ni certifican ausencia de vulnerabilidades.

## Contrato de medición y gate

Usar al menos un Mac de referencia representativo, además del equipo de desarrollo. Registrar OS, arquitectura, RAM, energía, temperatura aproximada si hay throttling, toolchain y versión Release. Separar caché fría/caliente y red local/remota; medir con y sin IA. Hacer al menos 30 observaciones comparables para estimaciones exploratorias de p95, y aumentar muestras cuando la variación no permita decidir. No presentar ese tamaño de muestra como garantía estadística universal.

Objetivos iniciales heredados: selección/filtro local p95 ≤100 ms; repo pequeño caliente ≤1 s; primer contenido de 100k commits ≤3 s; status mediano tras operación ≤1 s. Confirmarlos o revisarlos con evidencia en T01/T21, antes de convertirlos en un compromiso comercial. Medir bloqueos y frame hitches en la pantalla realmente soportada, sin asumir que 60 fps agota todos los casos.

Una regresión de corrección o seguridad bloquea la entrega aunque mejore latencia. Una regresión de rendimiento superior al umbral acordado se investiga y se bloquea si se reproduce; el umbral inicial sugerido es 10% sobre baseline estable, con tolerancia al ruido documentada. No disminuir controles de Keychain, validación o firma para cumplir un benchmark.

## Auditoría de completitud y evidencia

El [registro CSV](execution-tasks.csv) permite asignar cada T01–T40 a un responsable y actualizar su estado; inicialmente no marca trabajo de implementación completado. El [validador](tools/validate-execution-plan.mjs) comprueba secuencia, referencias, dependencias sin ciclos y cobertura de GM-001 a GM-028; esto audita estructura, no comportamiento de la app.

La evidencia de ejecución se registra por tarea: commit, responsable, fixture, comando, esperado, observado, métricas, prueba adversaria, revisión y riesgo residual. Una captura o traza debe poder abrirse y relacionarse con ese commit. La validación general del paquete sigue separada de este nuevo registro.

Se conservan las limitaciones de la auditoría inicial: no hay build completo, recorrido visual, AX ni benchmarks de producto aprobados. El cambio de asociación de Markdown en el Mac se comprobó por separado mediante LaunchServices y resolución efectiva de aplicación; no cuenta como prueba de GitMac.

## Uso de modelos locales durante la ejecución

Reutilizar el proceso local documentado: paquete pequeño de hechos y archivos, revisión local por tarea, verificación del código propuesto y pruebas. El output de un modelo no demuestra que una función esté implementada, sea rápida o sea segura. Registrar errores rechazados para no convertirlos en trabajo recurrente. El agente principal conserva las decisiones y la validación final; el plan no promete cero tokens de sesión.

El primer bloque de implementación es T01–T08: baseline, herramientas, build, CI, tests y frontera de ejecución. T09–T15 cierran los contratos de datos/estado/recuperación. Después se avanza hacia la experiencia visual y las integraciones sin abandonar los gates anteriores.

## Protocolos concretos añadidos tras revisión local

La revisión local de este documento está en `evidence/execution-plan-local-review.json`. Es una revisión de consistencia, no una inspección adicional del código ni una validación de los enlaces. Sus cinco observaciones piden concretar T01/T07/T10/T36/T37. Parte de las métricas ya estaba en el contrato anterior; los protocolos siguientes hacen explícito cómo recoger la evidencia. Las tareas continúan pendientes.

### T01 y T36: casos de benchmark

| Caso | Fixture / acción | Qué cronometrar y registrar | Decisión |
| --- | --- | --- | --- |
| B01 | F04 pequeño, 10k commits: abrir repo | Apertura→primer contenido utilizable; frío/caliente separados; CPU y footprint pico/estable | Comparar contra objetivo de 1 s caliente y baseline antes/después |
| B02 | F05 grande, 100k commits: abrir, paginar y buscar | Primera página; página siguiente; latencia de filtro local; subprocesses y memoria | Objetivo inicial 3 s de primer contenido y 100 ms de interacción local; no cargar historia completa |
| B03 | F03 con 1k archivos cambiados: stage y refresh | Inicio de operación→index correcto y snapshot publicado; incluir costo de stats | Objetivo inicial 1 s de actualización; mismo resultado exacto de Git |
| B04 | F10: diff texto pequeño, grande y binario | Selección→contenido/fallback; scroll/hitches, CPU y tamaño de caché | Fallback visible y recursos acotados; fijar umbral de tamaño con medición |
| B05 | F15: cambiar A/B y cerrar/reabrir 30 tabs | Tiempo de respuesta, tareas/watchers/procesos y footprint después de estabilizar | Ningún dato cruzado ni crecimiento monotónico no explicado por caché acotada |
| B06 | Terminal e IA activados por separado y juntos | Latencia de UI, memoria por backend/modelo, CPU/energía, cancelación | No exceder presupuesto acordado ni producir OOM; publicar límites por modelo |

Para cada caso guardar al menos las observaciones crudas, p50/p95, configuración, commit y traza. Cargar el mismo fixture y opciones en cada comparación. La ganancia debe sobrevivir repeticiones y no depender de haber cambiado tamaño de repo, caché, validaciones o calidad de resultado. La tabla de 28 funciones sigue obligando a medir las integraciones no cubiertas por estos seis benchmarks centrales; T36 registra un escenario específico por fila, además de B01–B06.

### T07: probar mitigaciones, no solo describirlas

Para cada amenaza, el control necesita una prueba positiva y una adversaria con resultado explícito. Ejemplos: una ruta normal y otra con apóstrofo se procesan como datos sin órdenes adicionales; una cuenta autorizada lee su secreto y otra identidad/denegación produce error controlado; una snapshot vigente se publica y una respuesta antigua no cambia el repo activo; un artefacto esperado verifica contra su procedencia y uno alterado es rechazado. Usar datos sintéticos y transporte/almacén de prueba.

Registrar el payload o generador, activo protegido, acción, observado y riesgo residual. Una prueba adversaria que solo compruebe que no hubo crash no basta: debe verificar también archivos, refs, secretos y efectos externos según el caso. Cambiar permisos o publicar una nueva attestation exige el flujo de implementación/autorización correspondiente.

### T10: límites comprobables de streaming

F13 debe generar, como caso inicial, al menos 64 MiB de stdout y 64 MiB de stderr simultáneos; partir caracteres UTF-8 multibyte entre chunks; pausar el consumidor; cancelar durante la lectura; y probar arranque fallido. Verificar igualdad de bytes o digest y texto final contra el generador, sin pérdida ni reemplazos silenciosos. Los bytes inválidos necesitan política explícita y una prueba propia.

Definir el techo configurable de cada cola antes de probar; 8 MiB por stream es una propuesta inicial que debe ajustarse al diseño. Medir el máximo de bytes pendientes y el footprint del proceso. El diseño puede aplicar backpressure o spool seguro con cuota, pero no descartar datos de un comando cuyo resultado necesita parsearse. Un timeout del test detecta deadlock; sus límites de tiempo se fijan con margen sobre la baseline del fixture. Cada resultado terminal debe emitirse exactamente una vez.

### T37: resistencia y fallos repetibles

Ejecutar inicialmente una sesión de 60 minutos con dos repos y dos worktrees: al menos 300 ciclos de seleccionar/cambiar/refrescar, 30 aperturas/cierres de tab y cancelaciones controladas. Registrar cada minuto footprint, CPU, procesos propios, tareas/watchers y cola pendiente. Repetir sin IA y con el modelo/backend soportado; el benchmark con IA no comparte el mismo presupuesto de memoria que el caso sin IA.

Inyectar fallo de red, lectura de repo desaparecido, lock externo, denegación de almacenamiento y fallo de persistencia durante operaciones apropiadas. Verificar recuperación y ausencia de cambios no solicitados en ref/index/working tree, no solo la presencia de una notificación. La sesión falla ante estado cruzado, salida perdida, proceso propio huérfano, corrupción del journal o crecimiento sin límite. Fuzzing y sanitizers reportan configuración, corpus, duración y hallazgos; nunca se presentan como prueba de ausencia total de fallos.
