# Implementación y cierre del roadmap

Contrato: ejecutar las 40 tareas existentes sin convertirlas en completadas por una validación documental. Preservar cambios previos, no hacer commits, no publicar ni escribir en cuentas/remotos de usuario. Cada modificación de aplicación exige lectura íntegra del archivo y relacionados, prueba proporcional y revisión del diff.

La ejecución se divide en hojas con gates. Se trabajan secuencialmente cuando comparten archivos; los modelos locales apoyan revisión y casos, pero no pueden autoaprobar cambios. Las herramientas disponibles no incluyen un despachador general de subagentes, por lo que la integración y verificación permanecen en esta sesión.

Árbol de trabajo:

1. Build/CI/tests y fixtures: T01–T06, T38.
2. Procesos, status, aislamiento y secretos: T07–T13.
3. Recuperación y rebase: T14–T15.
4. Comandos, ventanas, AX y diseño: T16–T19.
5. Grafo, búsqueda, staging y diff: T20–T26.
6. Remotos e integraciones: T27–T35.
7. Rendimiento, resistencia y candidato: T36–T40.

Contratos compartidos: identidad de repo/worktree/generación antes de publicar tras await; argv para Git; errores de salida no cero explícitos; cursor confirmado después de éxito; orden topológico independiente de authorDate; metadata de ref tipada; pruebas contra implementación real; disponibilidad visible para capacidades que no se hayan verificado.

Los modelos Git y los archivos del proyecto se modifican en una sola hoja a la vez. Tests, CI y consumidores se verifican juntos cuando cambie un contrato. El mapa/hash anterior queda como evidencia de baseline; se regenerará al integrar cambios y no se presentará como vigente si sus hashes difieren.

## Estado

- Inicio: HEAD 33bcb5739356ae133b8812159fde991700a56273; cambio previo en CLAUDE.md, docs/roadmap y graphify-out sin versionar. Ninguna modificación de aplicación previa según git status.
- Hoja cerrada: baseline/build local y primer bloque de correcciones con pruebas de regresión; ver gates/build.md y RESULTADOS.md.
- Debug y Release compilan con Xcode 27.1 tras instalar Metal Toolchain y corregir dos incompatibilidades de ContentBuilder, sin elevar el mínimo macOS 14.
- Diez tareas tienen avances, treinta permanecen pendientes. Ninguna de las 40 está cerrada integralmente.
- Siguiente hoja: T03/T05/T06 (reconciliar targets/manifiestos, incorporar todas las suites y fixtures); luego T07/T09/T10/T13. Persisten límites de CoreDevice/CoreSimulator, validación UI/AX y distribución firmada.

## Checkpoint posterior: contratos y candidato técnico

- Estado anterior conservado arriba como histórico. Estado actual: T01/T05/T09/T10 verificadas; 11 tareas en curso y 25 pendientes. No es cierre de las 40 tareas.
- Todas las suites actuales de producción se ejecutan, incluido núcleo de diff y credenciales sintéticas. T13 y T24 siguen parciales con límites documentados.
- Perfil GITMAC_NOTARY localizado sin exportar secretos. Acuerdo del equipo SRVK53YUSF confirmado por el usuario; el acceso a Apple quedó restablecido. Se envió únicamente la copia técnica para notarización, sin publicación ni cambios en remotos Git.
- Candidato candidate-Yzctwc firmado, Apple Accepted, stapling y Gatekeeper pasan. T39 integral permanece abierto por Mac limpio, matriz y upgrade/rollback. No se abrió la app con repositorios o secretos del usuario.
- Se mantienen pendientes paridad completa del grafo, undo/rebase, comandos/ventanas/AX, integraciones y benchmarks reales. RESULTADOS.md y execution-tasks.csv son el estado vigente, no los contadores históricos de este archivo.

## Prioridad añadida por el usuario: tamaño Retina/responsive

- El usuario añadió «no cabe en la pantalla» durante la reconciliación del proyecto. Se priorizó esa incidencia sin eliminar las 40 tareas.
- 40 Swift Testing y 11 XCTest pasan, incluido control negativo/positivo del resizer nativo. Release actual compila; se prepara un candidato separado. La app del usuario no se ha cerrado ni reemplazado. Se solicitó permiso para relanzarla después de guardar borradores.
- T17 y T19 tienen avance parcial; estado actual: 4 verificadas, 13 en curso y 23 pendientes. La revisión visual no está aprobada.
- El proyecto original permanece intacto. project.yml conserva estructura del producto y el checker valida determinismo; build-for-testing del nuevo target se sigue verificando antes de sustituirlo. El manifiesto SPM original aún requiere reconciliación.

## Continuación: todas las tareas y presupuesto estricto

- El usuario volvió a exigir las 40 tareas y comprobación final, añadiendo máximo de 150 MB e IA on-demand. No se reduce el roadmap al bloque visual. Se mantiene el árbol y sus dependencias; no hay despachador de subagentes, por lo que se continúa secuencialmente con revisión local acotada.
- Nuevo contrato: 150 000 000 bytes de physical footprint, no solo RSS residente. La app instalada PID 84387 mide 242435464 bytes y peak 690128336; es un fallo de presupuesto, no una aprobación del candidato. Pendiente aclarar presupuesto durante inferencia local pesada.
- Hoja inmediata: gates/memory-ai-demand.md. Quitar precarga al seleccionar proveedor y arranque/activación; acotar solicitudes y descargar modelos tras uso; contrastar candidatos pequeños con fuentes primarias. Después se retoman fixtures/aislamiento/recuperación y las dependencias restantes. El límite no se alcanza desactivando funciones en silencio.
- Candidato UX candidate-ckmitO: Release, firma, Apple Accepted 4b83fc94-e6df-4efe-a6fc-6b642f152293, stapling/Gatekeeper pasan. No se cerró ni sustituyó la app instalada; validación visual y de recursos pendiente.

## Continuación: aislamiento y medición con carga confirmada

- Estado estructural actual: 4 verificadas, 18 en curso y 18 pendientes. Se abrió T11 con identidad local gitdir/common probada, sin declarar cerrado ownership de ventanas, operaciones o locks.
- AppState/GitService invalidan refresh obsoleto, cierre y aperturas superadas; 12 comprobaciones positivas y seis fallos del refresh anterior. Los watchers ya no cierran un descriptor reasignado ni se reactivan después de stop definitivo.
- 66 Swift Testing + 11 XCTest pasan. Debug y Release de diagnóstico pasan. La app instalada no se reemplazó. Las mediciones de Release exigen repositorio, grafo y minimapa cargados.
- El límite de 150 MB falla: fixture 1k pico 253281384 bytes; fixture 100k pico 470811800 bytes. El retorno posterior a menor memoria no elimina el incumplimiento del pico.
- Revisión bajo demanda con qwen3-coder:30b completada y motor vacío después; propuestas conservadas, no autoaprobación. La compatibilidad de Qwen3.5 con el Ollama instalado bloquea ese candidato concreto, no el resto de tareas.

## Continuación: tests firmados, watchers y amenazas

- T07 queda verificada como artefacto de threat model de 16 fronteras; sus controles abiertos siguen abiertos. Estado: 5 verificadas, 19 en curso y 16 pendientes.
- UI tests ya compilan y ejecutan con Apple Development autorizado, bundle privado y repositorios Git temporales. Dos pruebas pasan; ambas capturas se leyeron. Se detectó y corrigió No Branch en la carga de fixture; 13 comprobaciones de sesión pasan.
- FileWatcher rearma tras reemplazo atómico, observa creación tardía/primer stash y mantiene propiedad del fd; 71 Swift Testing + 11 XCTest pasan, con ráfaga de 80 reemplazos.
- Las mediciones previas no incluyen inicialización del gestor lateral de ramas. El profiler ahora la exige; presupuesto de 150 MB y optimización integral continúan sin aprobar. No se sustituyó ni cerró la app instalada.

## Continuación 2026-10-25: ventanas, reutilización y temas

- El usuario pide continuar el pulido de todas las ventanas y rendimiento, añade redundancias/componentes reutilizables y una línea gráfica simple, moderna, elegante y respetuosa de temas, con Ajustes nativo de macOS.
- Hoja actual: gates/windows-performance-2026-10-25.md. Inventario léxico sobre los 394 Swift de aplicación: 2 escenas, 9 construcciones nativas, 136 presentaciones y 291 frames literales grandes; son candidatos de revisión, no aprobación de todas las ventanas ni 291 defectos.
- Contrato: conservar escena Settings y controles nativos; no tocar las columnas que corrigieron el crash. SettingsPage reutiliza DSScrollView/DSVStack para General, IA y Atajos, sin anidar scroll en los paneles Form. Un panel activo, IDs de accesibilidad contenidos y temas por colores semánticos.
- Medición base Release con ramas cargadas: windows-memory-baseline-1000.log, pico 252593232 bytes. Falla el presupuesto, independientemente del trabajo visual. Ningún modelo permanece precargado; no se modificó la aplicación instalada ni sus preferencias.
- La revisión local qwen3-coder:30b produjo propuestas en local-windows-reuse-review.json. No se aceptan sus supuestas referencias a PaneRegistry en producción ni su afirmación de que no se varían tamaños en el harness: son fixtures explícitos y Workflows usa 3000x4000. VoiceOver integral sigue pendiente.

## Plan primero y ejecución híbrida

- El usuario pide primero el plan específico de todas las tareas. Se pausan los cambios de aplicación y se conserva el lote parcial de ventanas/conflictos con sus fallos de validación.
- Fuente del nuevo desglose: specific-plan-2026-10-25.json; lectura humana: PLAN-DETALLADO-2026-10-25.md. El validador conserva las 40 aceptaciones y comprueba archivos existentes; no certifica implementación.
- El usuario eligió explícitamente «Híbrido: local y Cloud con fragmentos revisados». Los paquetes de revisión del plan contienen contratos/tareas/pruebas, no código fuente ni credenciales. La futura generación de parches tendrá allowlist, hashes, revisión y tests antes de apply_patch.
- Los artefactos de la revisión inicial truncada se conservan; su JSON incompleto no se presenta como aprobación. Los gates de esta petición están en gates/specific-plan-2026-10-25.md.

## Ejecución local autorizada

- El usuario solicita ejecutar el plan con modelos locales y multiagente. Se reanuda implementación: scripts/local-agents.mjs coordina contextos independientes por rol y propiedad de archivo, con inferencias pesadas en serie. No hay subagentes nativos disponibles; los agentes Ollama proponen y esta sesión revisa, integra y verifica.
- Primera hoja: T30.03 (errores Git, pathspec y recuperación de rebase), sin declarar T30 completa. Gates: gates/local-agents-workflows.md. Implementación y diseño de pruebas reciben archivos completos; el revisor recibe el resultado final y su evidencia. No se usa Cloud en esta ejecución.
- Resultado de la hoja: runner local con 16 controles de seguridad; 37 comprobaciones de workflows pasan frente a 22 fallos del código anterior; Debug firmado pasa. Tres roles locales completaron propuestas; sus límites y falsos positivos se adjudican en local-agent-review-adjudication.json. T30 pasa a en_curso, no a verificada. Próxima hoja: confirmaciones/cancelación y exclusión de ejecuciones simultáneas, antes de persistencia por repo.

## Continuación: paletas dibujadas, decisiones y render del grafo

- Las 40 aceptaciones siguen vigentes: cinco verificadas, veinte en curso y quince pendientes. No se sustituye la implementación por el plan ni se declara cerrado un hito con criterios pendientes.
- AppTheme consume los colores custom, los botones e iconos comparten contraste y geometría de carga; Accounts dejó de anular su foreground. Nueve presets recorrieron once estados (99 capturas); nueve comprobaciones de píxeles pasan frente a ocho fallos anteriores. Las nuevas capturas del renderer aún no sustituyen ese baseline.
- WorkflowEngine exige identidad por ejecución y por pregunta: siete escenarios pasan frente a cinco fallos originales, incluidos dos SIGTRAP. Persistencia por repositorio y UI de ejecución siguen abiertas. Las respuestas de los modelos locales fueron revisadas y sus falsos positivos rechazados; no se usó Cloud.
- La barra principal respetaba mal los temas custom claros: 92 comprobaciones actuales pasan; usar el getter anterior reproduce dos fallos. Se corrigió también el recorte de Apply/Pop/Drop con una alternativa compacta, conservando ayudas y nombres accesibles. Su prueba UI final no se cuenta aprobada: el último runner agotó el tiempo al habilitar automatización antes de ejecutar los tests.
- Hoja activa: gates/native-graph-rendering.md. Se contrasta CGContext con Canvas usando los mismos paths/estilos y un control restringido al fixture; 37 comprobaciones de dibujo pasan y omitir dash produce cuatro fallos. Conservar el renderer depende de la medición Release, las interacciones y la revisión visual, no de esta compilación. El presupuesto de 150 MB continúa sin aprobar.

## Precisión, publicación y worktrees: aclaraciones del usuario

- Se conserva el desglose de 206 pasos dentro de las 40 tareas; el usuario vuelve a exigir todos, sin reducción al pulido visual.
- gates/graph-exactness-publication.md concreta la petición de grafo exacto con oracles Git, continuidad y topología, además de estados local/publicado/divergente/sin upstream. Las referencias conocidas y su antigüedad no se presentan como lectura instantánea del servidor.
- gates/worktree-discovery-publish.md incorpora detectar cambios externos, identificar carpeta/rama/estado y publicar la rama con preview/upstream. La fuente actual enumera/crea/abre/protege/retira, pero no tiene una acción de publicar en el gestor. Ninguna prueba de publicación tocará remotos del usuario.
- native-graph-memory-comparison.json conserva seis mediciones del mismo SHA de Release: nativo 1k 76,6/76,4 MB, Canvas 1k 367,8/368,0 MB de pico; nativo 10k 87,6 MB; nativo 100k 168,0 MB, todavía falla el presupuesto. No son métricas de todos los flujos. La hoja minimap-allocation investigará las asignaciones sin truncar identidad o conexiones.

## Resolver, conservación local y sustitución condicionada

- T26 pasa a en_curso: cinco verificadas, veintiuna en curso y catorce pendientes; las 40 aceptaciones y 206 pasos siguen vigentes.
- El resolver ahora se abre desde el navegador de conflictos y distingue merge, rebase, cherry-pick, revert y conflictos de stash. Preview no escribe; Save and Stage valida HEAD, índice y archivo, guarda las versiones en el gitdir privado y solo entonces prepara el archivo. Continuar conserva hooks y la operación Git correspondiente; no inventa un commit para stash.
- conflict-empty-choice-after.log registra 43 comprobaciones del núcleo sin fallos. Se probaron guardas de cambios externos, índice bloqueado, conservación de versiones, marcadores malformados y elecciones vacías. Los controles anteriores reproducen fallos reales; no se presenta una compilación fallida como control negativo.
- conflict-live-ui.xcresult comprueba el flujo real aceptar ambas → staging → merge de dos padres y conserva keep-local.txt. Se encontraron después detalles visuales de estado y recuperación: la nueva versión requiere repetir esa prueba y la matriz de nueve temas antes de aprobarse.
- La retención de snapshots es perezosa: 32 conflictos permanecen visibles con una sola captura de contenido retenida inicialmente. Binarios, eliminaciones, renames, metadatos extendidos y garantías frente a escritores externos no cooperativos siguen pendientes.
- El usuario autorizó reemplazar la app instalada únicamente al verificar el resultado. gates/installed-app-replacement.md conserva esa condición: candidato final firmado/notarizado, comprobaciones, copia de seguridad y salida normal antes del cambio. El incumplimiento de memoria y los gates abiertos impiden hacerlo todavía; no se ha sustituido la app instalada.

## Continuación: terminal real y evidencia del candidato

- terminal-wire-ui.xcresult pasa el comando real, texto literal, bytes, directorio de trabajo e input vacío tras envío. El retorno prematuro introducido durante esta ejecución se corrigió; ocho checks del cuerpo real pasan y el control con ese retorno reproduce cinco fallos. Las 35 comprobaciones del controlador/quoting/escala no se presentan como prueba del writer. terminal-runtime-audit.md registra archivos, líneas y límites.
- El helper de XCTest conserva modificadores explícitos para las teclas que llegaban con Command; no cambia el teclado del usuario. El buffer experimental fue retirado al no corregir el problema. El modelo local tampoco detectó el retorno prematuro: sus propuestas no son una aprobación.
- conflict-theme-final-ui.xcresult pasa siete escenarios y 126 capturas de nueve presets. La corrección posterior del caption pasa nueve comprobaciones de contraste; originales claro/oscuro inspeccionados. No son todas las interfaces, estados ni accesibilidad.
- El experimento de tres pasadas del minimapa fue equivalente pero no demostró ahorro: pico 184878232 bytes en su Release. Se retiró conservando fuentes/medición. Las mediciones definitivas del nuevo Release se registran separadamente, sin inferencias a partir del experimento.
- /Applications/GitMac.app tiene backup verificado en build/InstalledAppBackups; no se cerró ni reemplazó. La asociación .md con iA Writer ya existía y fue verificada sin cambiar preferencias. Las 40 aceptaciones permanecen: cinco verificadas, veintiuna en curso y catorce pendientes.
- Candidato de cierre de este bloque: Debug firmado y Release compilan; 45 verificaciones/115 archivos pasan. terminal-wire-memory-comparison.json mide el mismo Release sin concurrencia pesada: picos 1k 77022264, 10k 88376424 y 100k 168543384 bytes. El tercero falla 150000000; no autoriza instalación. Las categorías señalan malloc dominante, sin atribuir aún su causa. Próxima investigación: asignaciones/retención con evidencia de propietario y comparación controlada antes/después; conservar identidades/parents y todas las funciones.
