# Specs de implementación

Todas están en estado `propuesta`. Los símbolos y archivos citados son puntos de partida observados, no una obligación de concentrar toda la implementación allí. Los tipos de contrato nuevos que se describen son propuestas. Antes de editar, leer completos los archivos objetivo y sus relaciones. Cada tarea debe entregar código revisable, pruebas del comportamiento y actualización de documentación aplicable.

Los rangos incluyen implementación y verificación directa. No son fechas comprometidas ni sustituyen la descomposición durante refinamiento. Los criterios de rendimiento remiten a presupuestos propuestos, pendientes de baseline en hardware acordado.

## GM-001 — Build reproducible y CI honesta

Prioridad: P0 | Hito: M0 | Rol: Release | Esfuerzo: 3–5 días | Depende de: ninguna.

Problema: A01/A15/A20. Hay tres definiciones de proyecto divergentes y el pipeline puede aceptar errores. Inventariar qué manifiesto gobierna el artefacto distribuido, qué se genera y qué targets/productos necesita realmente cada backend. Elegir el entrypoint de aplicación y documentar si SPM queda para módulos/tests o también debe producir una app instalable.

Aceptación:

- Un checkout limpio, con versiones fijadas de Xcode/SDK, Git y paquetes, construye Debug y Release por el procedimiento documentado.
- Error de compilación, enlace, firma cuando aplique y ejecución incompleta devuelven fallo del job. Conservar exit code al usar pipes; exigir marcador y artefacto válidos.
- `project.yml`, `.pbxproj` y SPM tienen una relación explícita y comprobable. Regenerar no elimina MLX, editor, terminal ni tests sin intención.
- Listar fuentes de tests faltantes/referenciadas/ignoradas y resolver cada caso. No cambiar paquetes o el entorno para esconder errores.

Pruebas: tres fallos deliberados en rama/fixture de CI; build limpio sin caché y otro con caché; inspección de producto y bundle. Entrega: guía de build, matriz de toolchain y logs/resultados. Activación: pipeline nuevo en paralelo durante una ejecución, luego convertirlo en gate. El problema local de CoreDevice/SDK se diagnostica aparte antes de interpretar fallos de compilación.

## GM-002 — Tests contra producción y fixtures Git

Prioridad: P0 | Hito: M0 | Rol: QA + Git | Esfuerzo: 4–7 días | Depende de: GM-001.

Problema: A04/A19. Retirar del target de validación las copias de modelos que enmascaran el producto. Definir módulos importables o un test host según la arquitectura elegida; inventariar además el parser de diff con pruebas Swift Testing existentes.

Aceptación:

- Un cambio intencionalmente incorrecto en un modelo/parser de producción rompe su test; no basta modificar el modelo duplicado del test.
- Fixtures deterministas cubren empty/unborn, detached, merge, rename+modify, conflicto y worktree. Los fixtures futuros con commits usan identidades de prueba explícitas fuera de repos de usuario.
- Suite de smoke UI versionada cubre abrir→seleccionar→stage→commit y el gate publica `xcresult`, logs y evidencia de fallos.
- Se distingue test no ejecutado, skip justificado, fallo y éxito. Ningún resultado vacío cuenta como aprobado.

Pruebas: matriz de [verificación](07-verificacion.md), destrucción intencional del comportamiento y recuperación. Entrega: factory de repos aislados y guía para reproducir un caso sin red. Activación: sustituir gradualmente tests sombra, sin inflar cobertura con getters triviales.

## GM-003 — Estado Git único y rutas sin pérdida

Prioridad: P1 | Hito: M1 | Rol: Git | Esfuerzo: 4–7 días | Depende de: GM-002.

Problema: A05/A06. Centralizar status en un parser de formato máquina NUL; v1 solo si se justifica por la versión Git soportada. Preservar index/worktree/conflicto, tipo, ruta original, nombre exacto y estado de submodule. La representación de bytes no UTF-8 requiere decisión explícita: soporte reversible o limitación visible; nunca sustitución silenciosa de rutas.

Aceptación:

- Pasan los cinco casos de `status-reproduction.json` tras la corrección y una matriz de espacios, tabs, newline, comillas, Unicode, flecha literal y prefijo `-`.
- Rename `RM` aparece staged y unstaged, con `oldPath` correcto; conflictos AA/DD/UU no desaparecen ni se presentan como cambios ordinarios operables.
- Empty/unborn funciona, incluyendo unstage sin asumir HEAD existente. Stats usan framing seguro y no confunden un binario con cero cambios.
- Engine, RepositoryContext, staging y refresh optimizado producen el mismo snapshot para el mismo estado de repo.

Pruebas: comparar con Git CLI y árboles de index, no con strings visuales; fixtures sin `core.quotepath` dependiente del equipo. Entrega: contrato del parser y migración de consumidores. Activación: comparación paralela en debug sobre fixtures; no ejecutar ambos comandos indefinidamente en producción.

## GM-004 — Contrato de procesos, cancelación y progreso

Prioridad: P1 | Hito: M1 | Rol: Git | Esfuerzo: 4–7 días | Depende de: GM-002.

Problema: A16 y divergencia entre execute/streaming. Definir un resultado tipado que distinga éxito, exit no cero, timeout, cancelación y error de arranque. Incluir cwd/operationID/repositorio y redacción de datos sensibles. Mantener argumentos como argv; una shell requiere un motivo explícito.

Aceptación:

- stdout y stderr se drenan sin bloqueo con volúmenes grandes; decodificación incremental no pierde caracteres entre chunks.
- Cancelación detiene el proceso y los descendientes que la app creó, con política documentada; no mata procesos externos del usuario. Timeout se informa como tal.
- Memoria del stream está acotada con una estrategia que no descarta silenciosamente salida Git necesaria; el parámetro de buffering tiene efecto real.
- Cada operación completa exactamente una vez y libera handlers, pipes y temporales en éxito/error/cancelación.

Pruebas: proceso stub que satura ambos pipes, falla al arrancar, entrega UTF-8 partido, ignora TERM o termina durante cancelación. Entrega: adaptadores graduales para las tres variantes y métricas de procesos activos. Activación: migrar lecturas antes de escrituras; comprobar journaling y recuperación antes de cancelar escrituras de historia.

## GM-005 — Aislamiento por ventana, repositorio y worktree

Prioridad: P1 | Hito: M1 | Rol: macOS + Git | Esfuerzo: 5–8 días | Depende de: GM-003, GM-004.

Problema: A07/A08. Conservar el diseño de `RepositoryContext`, definir identidad canónica de repo/worktree y exigir que cada publicación valide identidad y generación de la solicitud. Compartir cachés solo donde el common git dir lo permite; index/working tree/selección permanecen por worktree/contexto.

Aceptación:

- Secuencia A lenta→B rápida→A termina no publica listas, minimap, stash, error ni selección de A sobre B.
- Refresh coalescido no pierde invalidaciones ocurridas durante await; una nueva escritura invalida los snapshots pertinentes.
- Cerrar tab/ventana cancela sus tareas y watchers sin interrumpir otra vista válida del mismo repo.
- Operaciones de escritura incompatibles se coordinan por ámbito correcto; errores de index lock se muestran sin borrar locks externos.

Pruebas: scheduler controlado, dos repos, dos worktrees del mismo repo y dos ventanas; cambios externos por CLI. Entrega: diagrama de ownership y tabla de invalidación. Activación: generaciones primero, consolidación de servicios después; comprobar si `AppState.shared` y la instancia de App se usan con propósitos distintos antes de unificarlas.

## GM-006 — Undo/redo verificable y recuperación

Prioridad: P0 | Hito: M1 | Rol: Git + macOS | Esfuerzo: 6–10 días | Depende de: GM-003, GM-004, GM-005.

Problema: A03 y gestor sin conexión. Modelar journal por repo/operación con ref y SHA anteriores/posteriores, estado relevante de index/working tree y material de recuperación cuando exista destrucción. Nunca inferir el estado previo de un merge fast-forward como `HEAD~1`.

Aceptación:

- Undo solo se habilita para operaciones registradas y soportadas; comprobar precondiciones actuales antes de revertir. Una modificación externa bloquea la inversión insegura y explica por qué.
- Commit inicial, commit normal, amend, merge fast-forward/no-ff, branch delete y discard tienen política explícita; no prometer redo donde no se puede reconstruir el resultado.
- Cambios nuevos del working tree no se pierden al deshacer historia; el test compara contenido, index y refs, además de exit codes.
- Edición de texto conserva undo nativo. El comando Git expone nombre/alcance y afecta solo al contexto activo. Reinicio y limpieza del journal tienen política visible.

Pruebas: historial y snapshots antes/después, cambios externos, operación parcial y crash entre operación/registro. Entrega: matriz operación→precondición→compensación→redo. Activación: mantener UI deshabilitada para tipos sin contrato; integrar un tipo seguro a la vez. No habilitar el gestor actual completo mediante un simple botón.

## GM-007 — Rebase interactivo que ejecuta el plan

Prioridad: P0 | Hito: M1 | Rol: Git + macOS | Esfuerzo: 5–9 días | Depende de: GM-004, GM-005, GM-006.

Problema: A02. Construir y validar el plan que se entrega al sequence editor de Git. Preferir editor auxiliar controlado con archivo temporal privado, argv/escaping correcto y semántica exacta; no interpolar mensajes arbitrarios en scripts de shell. Usar rutas obtenidas por Git para soportar worktrees.

Aceptación:

- Pick, reorder, reword, squash, fixup y drop soportados producen el DAG/árbol esperado; cualquier acción no soportada se deshabilita.
- El primer elemento inválido para squash/fixup se rechaza antes de iniciar. Definir comportamiento para merges, commits públicos y refs protegidas.
- UI representa running/stopped-conflict/stopped-edit/completed/aborted/failed. Continue/skip/abort tienen contexto y salida real.
- Cancelar el diálogo antes de empezar no cambia refs. Reiniciar la app con rebase en progreso recupera la sesión, y éxito solo aparece tras comprobar el estado final.

Pruebas: tres a diez commits, mensajes multilínea, conflicto en medio, worktree y abort con cambios protegidos. Entrega: plan serializado y diff de historial esperado. Activación: capability flag hasta aprobar el conjunto; luego reemplazar la ruta `GIT_SEQUENCE_EDITOR=cat`.

## GM-008 — Keychain y migración sin pérdida de credenciales

Prioridad: P1 | Hito: M1 | Rol: macOS | Esfuerzo: 4–7 días | Depende de: GM-001, GM-002.

Problema: A14. Usar Keychain Services para secretos; separar cuenta/proveedor/host y entorno de app. Diseñar migración idempotente desde el archivo cifrado actual, verificando lectura después de guardar. No borrar el origen hasta confirmar integridad y disponer de recuperación acordada.

Aceptación:

- Guardado/actualización/borrado devuelven errores reales. Disco lleno, Keychain bloqueado/denegado y falta de firma no se comunican como éxito.
- Migración interrumpida se reintenta sin duplicar ni perder cuentas; credenciales no aparecen en logs, métricas o screenshots.
- Cerrar sesión elimina únicamente los secretos de esa cuenta. Varias cuentas del mismo host permanecen aisladas.
- Builds firmados y de desarrollo tienen política documentada; no derivar una clave de cifrado de un identificador público o fallback constante.

Pruebas: almacén de prueba y credenciales sintéticas, bloqueo/denegación y migración parcial. Entrega: plan de migración/rollback y prueba con identidad firmada. Activación: migrar mediante feature flag y registrar únicamente códigos de resultado, nunca valores de tokens.

## GM-009 — Registro de comandos, atajos y first responder

Prioridad: P1 | Hito: M2 | Rol: macOS | Esfuerzo: 4–7 días | Depende de: GM-005.

Problema: A12/A13. Un registro de acciones debe alimentar menú, toolbar, palette, ayuda y presets. Cada acción declara nombre, ámbito, disponibilidad y atajo. Conservar los comandos estándar de macOS y resolver atajos por foco antes que por listener global.

Aceptación:

- Ayuda y bindings coinciden; ninguna combinación se resuelve a dos acciones en el mismo ámbito. Detectar también conflictos con comandos estándar.
- ⌘W cierra el contexto acordado; ⌘Z edita texto cuando corresponde; terminal/editor conservan navegación y shortcuts propios.
- Recorder captura combinaciones, permite Escape/cancelar/reset y muestra conflictos antes de persistir. El preset sobrevive relanzamiento.
- Comandos Git se deshabilitan sin repo y durante estados incompatibles; notifican su resultado al contexto originario.

Pruebas: UI por menú/teclado/palette, layouts de teclado y dos ventanas; regresión específica Push vs Unstage All. Entrega: tabla única de comandos exportable. Activación: migración de preferencias con versión y fallback a valores por defecto sin perder personalizaciones válidas.

## GM-010 — Ventanas, navegación y restauración

Prioridad: P1 | Hito: M2 | Rol: macOS + UX | Esfuerzo: 4–7 días | Depende de: GM-005, GM-009.

Definir sesión de app, de ventana y de repo: qué se comparte y qué conserva foco/selección. Reutilizar tabs y paneles existentes; cerrar la distancia entre `WindowGroup`, AppState y gestores de paneles.

Aceptación:

- Abrir/clone/init, nueva ventana, cerrar/reabrir repo y volver/avanzar tienen resultados estables y menú estándar.
- Restaurar selecciona repos válidos, recupera proporciones y explica carpetas movidas o inaccesibles. No dispara mutaciones Git o descargas por restaurar.
- Resize/fullscreen y pantalla externa no ocultan acciones críticas ni dejan paneles sin acceso; el título o contexto identifica el repo.
- Cambiar tab conserva selección, scroll, filtros y draft de commit por repo; comandos de una ventana no actúan en otra.

Pruebas: múltiples ventanas, app relanzada, repos renombrados y dimensiones de [experiencia](06-experiencia.md). Entrega: mapa de navegación y política de persistencia. Activación: versionar estado guardado y disponer de reset de layout sin perder datos Git.

## GM-011 — Accesibilidad de los flujos centrales

Prioridad: P1 | Hito: M2 | Rol: macOS + QA + UX | Esfuerzo: 5–9 días | Depende de: GM-009, GM-010.

Problema: A17. Auditar acciones reales con Accessibility Inspector, teclado y VoiceOver. Extender átomos para requerir nombres de acción donde no pueda inferirse un nombre útil. Conservar las etiquetas existentes y corregir hints propios de otra plataforma cuando no describan la interacción Mac.

Aceptación:

- Abrir repo, seleccionar commit, stage/unstage, commit y resolver un conflicto son posibles sin pointer.
- Nombre/rol/valor/estado y orden de navegación son útiles; acciones secundarias aparecen como acciones accesibles o menú equivalente.
- Foco visible y retorno al disparador tras sheet/popover; cambios de loading/resultado se anuncian sin inundar VoiceOver.
- Texto ampliado y ajustes de movimiento/transparencia/contraste no rompen el flujo. Color nunca es la única diferencia entre ramas/status/errores.

Pruebas: guion manual grabado y assertions AX de semántica estable; no basarse solo en contar `.accessibilityLabel`. Entrega: inventario de controles y evidencia por flujo. Activación: gates de accesibilidad en cada nueva spec; no esperar a una limpieza final.

## GM-012 — Sistema visual coherente y nativo

Prioridad: P1 | Hito: M2 | Rol: UX + macOS | Esfuerzo: 4–7 días | Depende de: GM-010, GM-011.

Mapear componentes DS activos, wrappers y variantes; reconciliar contradicciones entre `STANDARDS.md` y `DESIGN_SYSTEM.md`. Los tokens representan decisiones semánticas, no una prohibición universal de valores numéricos en todo código.

Aceptación:

- Escala de texto, espacio, superficies, selección/foco y estados Git coherente en grafo, staging, diff y Settings.
- Temas sistema/claro/oscuro y selección inactiva legibles; evitar chrome personalizado donde controles nativos ya resuelven el comportamiento.
- Set de referencia incluye normal/hover/focus/pressed/disabled/loading/error/destructive y muestra nombre accesible.
- Screenshots de baseline comparables a GitKraken y revisión humana anotada de densidad/jerarquía; todos los desvíos aceptados tienen motivo.

Pruebas: estados y temas a dos escalas; inspeccionar imágenes generadas antes de aprobar. Entrega: catálogo pequeño y guía de uso. Activación: migrar superficies principales; retirar componentes solo después de confirmar referencias y equivalencia.

## GM-013 — Grafo completo, topología y paginación

Prioridad: P1 | Hito: M3 | Rol: Git + macOS | Esfuerzo: 6–10 días | Depende de: GM-003, GM-005.

Problema: A09/A10/A11. Especificar alcance all refs/current branch/selección y orden topológico. Tratar fronteras de páginas y parents ausentes como continuidad pendiente, no como conexiones inventadas. Cada SHA puede asociar múltiples refs con tipo/nombre/remote.

Aceptación:

- Ramas locales/remotas divergentes, tags coincidentes, detached HEAD, merges octopus y commits con fechas desordenadas mantienen parentesco correcto.
- Paginación no duplica/omite commits dentro de la snapshot acordada; preservar selección/ancla y estabilidad razonable de lanes.
- Shallow/offline muestra límite real. Profundizar requiere acción/configuración explícita, valida exit status y tiene límite de intentos; no vuelve a activar otro repo.
- Minimap y grafo usan el mismo alcance. El modelo no necesita cargar toda la historia en memoria para abrir el repo.

Pruebas: DAG generado con oracle `rev-list/parents`, snapshots de layout y fixture de historia grande. Entrega: invariantes del grafo y baseline de performance. Activación: comparar motores en fixtures antes de cambiar el renderer; no sostener dos pipelines activos sin plazo de retiro.

## GM-014 — Interacción del grafo y contexto de referencias

Prioridad: P1 | Hito: M3 | Rol: macOS + UX | Esfuerzo: 5–8 días | Depende de: GM-009, GM-011, GM-013.

Acercar selección, filtros, búsqueda, badges y acciones al flujo de GitKraken. Definir click/doble click/context menu/drag y equivalente por teclado. La selección debe ser una identidad SHA/ref, no un índice visual transitorio.

Aceptación:

- Buscar y limpiar búsqueda, hide/solo y focus muestran su alcance; no hacen desaparecer el estado activo sin explicación.
- Mostrar múltiples labels, HEAD, upstream y WIP sin tapar mensaje/autor; truncamiento reversible con detalle accesible.
- Drag muestra intención origen→destino y tipo de operación antes de ejecutar; Escape cancela y los menús permiten lo mismo.
- Selección única/múltiple, comparación y navegación atrás sobreviven refresh/paginación; menu actions validan que SHA/ref aún existen.

Pruebas: guiones equivalentes GitKraken/GitMac con el mismo fixture y comparación de pasos/errores. Entrega: tabla de gestos/comandos y screenshots. Activación: completar lectura/selección antes de mutaciones por drag.

## GM-015 — Staging y commit con contenido exacto

Prioridad: P1 | Hito: M3 | Rol: Git + macOS | Esfuerzo: 6–10 días | Depende de: GM-003, GM-005, GM-006.

Consolidar las rutas activas de staging y `PatchManipulator`. El contrato debe distinguir archivo/hunk/selección de líneas, index y working tree; validar que el patch todavía corresponde al contenido seleccionado.

Aceptación:

- Stage/unstage por archivo, hunk y líneas produce exactamente el tree/index esperado; CRLF, no-newline, rename y archivo borrado tienen casos.
- Refrescar un archivo durante una selección invalida/reconcilia la operación con explicación; no aplica un hunk por índice a contenido diferente.
- Empty/unborn y commit inicial funcionan; amend advierte contexto; doble clic/submit no crea commits duplicados.
- Commit→push→PR informa cada paso; si falla push se conserva el commit y se ofrece reintentar ese paso, no repetir toda la secuencia.

Pruebas: comparación `write-tree`, contenido de blobs y refs; selección parcial que mezcla adiciones y borrados. Entrega: contrato de patches y UI de resultados parciales. Activación: validar una ruta principal antes de retirar variantes.

## GM-016 — Diff, historia y blame profesionales

Prioridad: P1 | Hito: M3 | Rol: macOS + Git | Esfuerzo: 6–10 días | Depende de: GM-003, GM-004, GM-011, GM-015.

Inventariar vistas activas y elegir renderer/modelo común por tamaño/capacidad. Conservar vistas especializadas solo cuando tengan un contrato distinto. Definir diff working tree/index/commit/merge y manejo explícito de binarios.

Aceptación:

- Unified y split muestran el mismo cambio con números/EOF/contexto correctos; word diff no altera líneas ni selección para patch.
- Búsqueda, siguiente/anterior hunk, copiar, wrap y scroll sincronizado respetan foco y atajos; navegación vuelve al archivo/commit anterior.
- Archivo grande entra en degradación documentada: carga por demanda, límites y acceso a contenido completo; nunca pantalla vacía o truncamiento sin aviso.
- Historia sigue renames cuando se elige; blame identifica commit/rango y permite saltar al grafo. Imagen/binario explica qué comparación se soporta.

Pruebas: golden diffs de repos sintéticos, archivos grandes y patrones patológicos de líneas. Entrega: tabla formato/tamaño→renderer y métricas. Activación: feature flag del renderer y comparación de contenido antes de retiro.

## GM-017 — Conflictos, continue/abort y prevención

Prioridad: P1 | Hito: M3 | Rol: Git + macOS | Esfuerzo: 6–10 días | Depende de: GM-005, GM-007, GM-016.

Unificar estado de operación conflictiva y editor base/current/incoming/result. Una predicción de conflicto es una estimación; los solapamientos de archivos no prueban conflictos de contenido. No invocar merge que modifique el repo para una simple vista previa sin un contrato de aislamiento.

Aceptación:

- Conflictos texto, add/add, modify/delete, rename y binarios tienen resolución o limitación explícita. Los términos current/incoming describen la operación real, especialmente en rebase.
- Elegir bloques o editar resultado marca cambios sin resolver y requiere guardar antes de stage/continue. Se detectan marcadores restantes y errores de escritura.
- Continue/abort y recuperación tras reinicio preservan archivos y contexto; no declarar éxito mientras Git siga en estado de operación activa.
- Una sugerencia de IA se presenta como propuesta y se revisa antes de aplicar. Predicciones muestran base/refs y se comparan con fixtures reales.

Pruebas: merge y rebase con conflictos intermedios; encoding/CRLF y merge tools externos. Entrega: máquina de estados y guion de recuperación. Activación: priorizar resolución manual confiable antes de sugerencias automáticas.

## GM-018 — Remotos, autenticación y errores de red

Prioridad: P1 | Hito: M4 | Rol: Git + macOS | Esfuerzo: 5–9 días | Depende de: GM-004, GM-005, GM-008, GM-015.

Definir fetch/pull/push, upstream, credenciales, progreso y política de autofetch. Distinguir autenticación Git de OAuth de APIs del host; una cuenta conectada no prueba que SSH/HTTPS de Git funcione.

Aceptación:

- Crear upstream, divergencia, no-fast-forward, pull merge/rebase/ff-only, remoto ausente y branch protegida tienen decisiones visibles.
- Force usa lease y revisión del alcance; nunca sustituir rechazo por force automático. Operaciones no idempotentes no se reintentan a ciegas.
- Offline, proxy/certificado inválido, token expirado y SSH agent ausente producen diagnóstico y reintento concreto sin mostrar secretos.
- Autofetch tiene control, backoff y pausa; cerrar repo cancela lectura propia sin interrumpir operaciones ajenas.

Pruebas: remotos locales y HTTP/SSH controlados, auth simulada y cortes de conexión. Entrega: tabla de error→recuperación y progreso. Activación: no enviar cambios a remotos reales como parte de smoke automático.

## GM-019 — Branches, tags, stash y cherry-pick

Prioridad: P1 | Hito: M4 | Rol: Git + macOS | Esfuerzo: 5–8 días | Depende de: GM-005, GM-006, GM-017, GM-018.

Completar acciones de referencias y operaciones de historia con las mismas precondiciones que el grafo. Mantener identidad de stash por objeto/ref comprobada, sin depender solo de un índice que cambia.

Aceptación:

- Create/rename/delete local/remote valida nombres, refs protegidas, branch ocupada y trabajo sin guardar; los errores no se silencian.
- Tags ligeros/anotados/firmados, push y borrado muestran objetivo y alcance real.
- Stash tracked/untracked, apply/pop/drop, conflictos y cambios en la pila se manejan sin aplicar un stash diferente del seleccionado.
- Cherry-pick de rango preserva orden y permite continuar/abortar; reset soft/mixed/hard explica cambios en refs/index/working tree y recuperación.

Pruebas: cambios externos entre preview/confirmación y stash index desplazado; merge ff/no-ff/squash. Entrega: matriz de operaciones con preview y journal. Activación: un contrato común para menú, toolbar y drag.

## GM-020 — Worktrees, submodules y LFS

Prioridad: P1 | Hito: M4 | Rol: Git | Esfuerzo: 6–10 días | Depende de: GM-005, GM-013, GM-018, GM-019.

Tratar worktree como contexto con index y working tree propios. Resolver gitdir/common-dir mediante Git; `.git` puede ser archivo. Alinear listado, grafo WIP y navegación con el modelo de GitKraken.

Aceptación:

- Crear/abrir/lock/unlock/prune/remove worktree respeta ramas ocupadas y cambios sucios; force requiere alcance explícito y protección de datos.
- WIP por worktree muestra su branch y cambios correctos y abre ese contexto. Eventos de un worktree no sustituyen listas de otro.
- Submodule ausente/no inicializado/detached/nested identifica estado y permisos; update fallido no se presenta como repo limpio.
- LFS ausente, objetos pendientes, locks y fallos de descarga muestran estado y acción; progress/cancelación usan contrato común.

Pruebas: dos worktrees, rutas externas, submodules locales y fixture LFS controlado. Entrega: matriz de capacidades y dependencias opcionales. Activación: mostrar acciones no disponibles con razón verificable.

## GM-021 — PR/MR y proveedores con capacidades explícitas

Prioridad: P2 | Hito: M5 | Rol: macOS + Integraciones | Esfuerzo: 8–14 días | Depende de: GM-008, GM-018, GM-019.

Inventariar implementaciones existentes y endpoints en sus servicios antes de diseñar adaptadores. Primer vertical GitHub; extender GitLab, Bitbucket y Azure DevOps según capacidades observadas y documentación primaria vigente. Separar self-hosted de cloud por host/cuenta.

Aceptación:

- Listar/buscar/paginar/ver detalle y diff, crear draft/PR, revisar/comentar y mergear se habilitan solo donde estén implementados y permitidos.
- Base/head se cargan de las ramas reales del repo/host, incluyendo paginación; eliminar la lista fija main/master/develop observada en `PRListView.swift:1115`. CI/checks, conflictos, permisos y branch protections se revalidan antes de enviar una acción. Publicar un comentario o merge requiere intención explícita del usuario del producto.
- Branch local apunta al PR correcto; navegación entre grafo y PR conserva contexto. Templates y stacked PRs se especifican como subalcance separado por proveedor.
- Auth expirado, rate limit, red y capacidades no soportadas tienen estado visible; no inventar endpoints ni simular éxito.

Pruebas: contratos HTTP con fixtures sanitizados y cuentas de prueba autorizadas para validación final. Entrega: matriz proveedor/capacidad y pruebas. Activación: providers por feature flag, sin marcar paridad global por tener una lista de PRs.

## GM-022 — Workspaces, Launchpad e issues

Prioridad: P2 | Hito: M5 | Rol: macOS + UX | Esfuerzo: 6–10 días | Depende de: GM-005, GM-010, GM-021.

Consolidar RepoGroups/Launchpad e integraciones de issues en un flujo: encontrar trabajo, abrir repo/branch/PR y volver al conjunto. Separar agrupación local de recursos compartidos que exigen backend/cuenta.

Aceptación:

- Agrupar/favoritos/recientes y búsqueda abren rutas existentes o explican cómo recuperarlas; no crean duplicados por forma de ruta.
- Filtros assigned/review requested/status tienen semántica verificable por proveedor y paginación sin duplicación.
- Issue→crear branch→commit→PR conserva enlace y repo objetivo; slug/nombre se validan en Git y en la integración existente.
- Offline muestra snapshot con antigüedad; fallo de una cuenta no bloquea otras ni mezcla información entre hosts.

Pruebas: varios repos/cuentas, issue borrado y deep link inválido. Entrega: mapa de capacidades locales/remotas y prototipo validado. Activación: empezar por grupos locales y GitHub; ampliar plugins tras contrato real.

## GM-023 — Workflows, hooks y firma

Prioridad: P2 | Hito: M4 | Rol: Git | Esfuerzo: 5–8 días | Depende de: GM-008, GM-018, GM-019.

Definir qué parte de Workflows es plantilla de comandos y qué parte implementa Gitflow. Soportar feature/release/hotfix y configuración de branches cuando se reclame Gitflow. Hooks y firma son parte de la operación real, no un paso decorativo.

Aceptación:

- Init/start/finish de flujos soportados producen refs/tags previstos y explican historia reescrita o mergeada.
- Hook fallido conserva salida útil y estado del repo; no reintentar con bypass sin intención explícita.
- Firma GPG/SSH valida disponibilidad de herramienta, identidad y acceso al agente; estado de verificación distingue trusted/untrusted/expired/missing.
- Ninguna UI exporta claves privadas o altera configuración global del usuario de forma implícita.

Pruebas: hooks de éxito/fallo, claves sintéticas y repos de prueba con release/hotfix. Entrega: matriz configuración local/global y estrategias soportadas. Activación: presets que no estén verificados se presentan como comandos configurables, no Gitflow completo.

## GM-024 — Terminal soportado e integración con el repo

Prioridad: P2 | Hito: M5 | Rol: macOS | Esfuerzo: 5–9 días | Depende de: GM-004, GM-005, GM-009.

Mapear qué vistas usan Ghostty, SwiftTerm o alternativas y seleccionar backend soportado por plataforma. Conservar uno alternativo solo por necesidad documentada. Definir sesión por tab/repo y relación entre terminal, shell y watchers.

Aceptación:

- Sesión inicia en cwd correcto, respeta resize/IME/clipboard/selección/colores/foco y no captura atajos de app indebidamente.
- Cambios Git externos desde terminal actualizan la UI sin reabrir repo; no asumir que el cwd actual sigue siendo el repo inicial.
- Cerrar sesión termina únicamente procesos propios según política, con aviso si hay trabajo interactivo; relanzar no duplica shells.
- Build limpio incluye framework/dependencias y licencia requerida; modo no soportado explica el motivo y ofrece terminal externo.

Pruebas: escape sequences, salida extensa, comandos interactivos y dos sesiones en worktrees. Entrega: matriz de backend y recursos por sesión. Activación: no migrar backend y rediseñar IA de terminal en el mismo cambio.

## GM-025 — IA local controlada y opcional

Prioridad: P2 | Hito: M5 | Rol: macOS + IA | Esfuerzo: 5–9 días | Depende de: GM-004, GM-008, GM-015.

Reutilizar proveedores Ollama/MLX y comprobar que el modelo seleccionado ejecuta pesos locales. Un endpoint localhost puede representar un alias cloud. Hacer visible proveedor/modelo, límite de contexto, recursos y política de envío antes de usar datos.

Aceptación:

- Modo local rechaza metadata remota y cualquier fallback cloud; se valida con red exterior bloqueada y modelos ya instalados.
- Generar mensaje/sugerencia no ejecuta comandos ni aplica resolución automáticamente. El usuario revisa contenido y alcance.
- Cancelar libera recursos por política; errores de modelo/contexto/memoria mantienen intactos los cambios Git.
- Una sola inferencia pesada por política inicial, con presupuesto de contexto y salida; no cargar MLX y Ollama grandes simultáneamente sin medición.

Pruebas: proveedor falso/local/cloud-alias, memoria limitada y prompt con contenido hostil dentro de un diff. Entrega: matriz de capacidades, política de red y mediciones. Activación: opt-in; la app funciona por completo en operaciones Git sin IA.

## GM-026 — Sharing, cloud patches y colaboración honesta

Prioridad: P2 | Hito: M5 | Rol: Integraciones + macOS | Esfuerzo: 6–10 días | Depende de: GM-008, GM-015, GM-021.

Problema: A18/A22. Separar transporte de patch, sincronización de preferencias y presencia. El servicio actual de patches usa gists; no prometer caducidad ni confidencialidad que el transporte no garantice. Definir metadata versionada y verificación del contenido recibido.

Aceptación:

- Antes de compartir se ve diff completo/archivos, destino, visibilidad y política real de acceso. La detección de secretos ayuda pero no garantiza ausencia.
- Crear→leer→listar conserva metadata soportada; expiración se cumple en el servidor o se etiqueta como recordatorio local, sin sugerir revocación inexistente.
- Aplicar patch comprueba repo/base y preview; cambios incompatibles no se fuerzan y no escriben fuera del repo permitido. Ejecutar `git apply` mediante argv/cwd, sin interpolación de rutas en `bash -c`; rutas con apóstrofos funcionan y exitCode no cero siempre es fallo.
- Revocación/borrado/fallo de red y cuentas separadas son verificables; sincronización/presencia no comparte código ni secretos implícitamente.

Pruebas: transporte mock, metadata ausente/antigua, patch malicioso y expiración; prueba remota solo con cuentas autorizadas. Entrega: contrato de privacidad y capacidades por transporte. Activación: deshabilitar promesas no soportadas antes de añadir backend nuevo.

## GM-027 — Rendimiento, diagnóstico y presupuestos

Prioridad: P1 | Hito: M6 | Rol: macOS + QA | Esfuerzo: 5–9 días | Depende de: GM-001, GM-013, GM-016, GM-024, GM-025.

Instrumentar desde M0 procesos Git, latencia de snapshots, layout/render, cachés, tareas/watchers y memoria. Los contratos iniciales de medición se acuerdan dentro de GM-001 y se usan durante grafo/IA; las dependencias anteriores son para la aprobación final de esta spec, sin bloquear su instrumentación inicial. Evitar logs ad hoc en `/tmp` con datos sin política; usar diagnóstico estructurado con redacción y exportación revisable.

Aceptación:

- Publicar baseline en hardware/OS/repo acordados y comparar p50/p95, memoria estable/pico y procesos/tareas activos, con/sin IA.
- Primer contenido, interacción de grafo y diff cumplen el presupuesto acordado en [verificación](07-verificacion.md), o documentan excepción con dueño y fecha.
- Cerrar/reabrir tabs repetidamente vuelve a una banda estable de recursos; grandes repos usan paginación/buffering/límites observables.
- Diagnóstico exportable incluye versiones y errores accionables sin tokens, URLs con credenciales ni contenido de código por defecto.

Pruebas: fixtures pequeño/medio/grande, Instruments y sesiones largas. Entrega: reporte reproducible y gates de regresión tolerantes al ruido. Activación: contratos desde M0; no esperar a M6 para descubrir límites arquitectónicos.

## GM-028 — Onboarding, distribución y candidato de entrega

Prioridad: P1 | Hito: M6 | Rol: Release + QA + UX | Esfuerzo: 6–10 días | Depende de: GM-001 a GM-027 aplicables al alcance de la versión.

Definir canal de distribución y capacidades incluidas. Revisar release workflow, firma ad hoc actual, entitlements y dependencias nativas. La versión distribuida debe corresponder a commit/tag verificado y a la matriz publicada.

Aceptación:

- Instalación en Mac limpio abre app, detecta Git, abre repo y completa el flujo básico sin rutas del desarrollador. Firma/notarización se verifican según canal.
- Onboarding permite trabajo local antes de conectar host o IA; permisos se solicitan cuando se necesitan y explican el beneficio.
- Actualización/migración de sesión, preferencias y secretos tiene prueba desde versión anterior y rollback compatible; no se pierden drafts.
- Release gate exige resultados reales de build/unit/integration/UI/AX/visual/performance, cero P0 abiertos y resolución explícita de P1 aceptados.

Pruebas: instalar/actualizar/desinstalar sin borrar repos, abrir desde Finder, deep link válido/inválido, Gatekeeper y máquina con dependencias ausentes. Entrega: artefacto, checksums, release notes y limitaciones. Publicación es un paso posterior al candidato verificado y requiere la autorización correspondiente.
