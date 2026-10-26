# Plan específico de implementación de GitMac

Fecha: 2026-10-25. Ejecución reanudada por solicitud del usuario con agentes locales; inferencias pesadas en serie y revisión antes de integrar.

Estado de ejecución: [primer bloque local verificado](local-agent-execution.json), [gates](gates/local-agents-workflows.md) y [adjudicación de propuestas](local-agent-review-adjudication.json). Esta evidencia no certifica todo el roadmap ni el presupuesto de memoria.

Este desglose conserva los 40 tickets y sus aceptaciones originales. Las subtareas siguientes son trabajo concreto; no cambian el estado de ejecución por estar planificadas.

## Política de modelos

Política híbrida elegida expresamente por el usuario: local por defecto y Ollama Cloud con fragmentos revisados. El endpoint localhost no demuestra que un alias use pesos locales.

- local-coder: qwen3-coder:30b instalado: proponer diffs por una responsabilidad; no ejecutar sus comandos ni aceptar sus conclusiones sin comprobación.
- local-light: qwen2.5:3b o phi4-mini instalados: inventarios, clasificación y borradores mecánicos; no decidir operaciones Git destructivas ni cambios de credenciales.
- review: Revisión independiente del agente y pruebas deterministas. Un segundo modelo puede ayudar, en serie, sin autoaprobar al primero.
- cloud-optional: Ollama Cloud autorizado dentro de la política híbrida para fragmentos revisados y necesarios; excluir secretos, credenciales, código no necesario y contenido de repositorios del usuario ajenos a GitMac. No cambiar a otro proveedor cloud implícitamente.

## Contratos de implementación

- Mantener T01–T40 y sus dependencias originales. Las tareas ya verificadas no se reabren por añadir documentación; sí se repiten sus regresiones al cambiar un contrato compartido.
- Una tarea cerrada necesita comportamiento esperado, observado, comando, fixture, fuente/hash, control negativo, seguridad y presupuesto aplicable; compilar o tener un botón no basta.
- Repo, common directory, worktree, ventana, pestaña, cuenta y operación tienen identidades distintas. Capturar origen y generación antes de await; no tomar el repositorio activo al finalizar.
- Configuración por repositorio como alcance inicial visible, con herencia global explícita; secretos por cuenta/host en Keychain y solo referencias en configuración.
- Git usa argv/cwd y resultados comprobados. No force, reset hard, abort, push, publicación ni escritura de tickets implícitos.
- Una biblioteca de comandos y componentes activos; eliminar duplicados solo tras localizar consumidores y comparar sus contratos.
- Apariencia simple: tipografía del sistema, SF Symbols, colores semánticos, espacio coherente y estados de error/espera/disabled legibles. Claro, oscuro, sistema y custom claro/oscuro tienen pruebas propias.
- Presupuesto solicitado: 150000000 bytes de physical footprint y pico de vida del proceso de GitMac. Registrar además procesos/modelos auxiliares; no ocultarlos ni afirmar que una inferencia local pesada cabe sin medir.
- No modificar repositorios, remotos, tickets, permisos del sistema o facturación del usuario para probar. Fixtures aislados y acciones externas solo por intención expresa.
- Sin commits automáticos, reemplazo de la app instalada, publicación ni actualización global de toolchains/modelos.

## Criterios apple-design para GitMac nativo

Aplicar [apple-design](https://github.com/emilkowalski/skills/blob/main/skills/apple-design/SKILL.md), leído el 25 de octubre de 2026. Es una guía comunitaria orientada a web; adaptar sus principios a SwiftUI/AppKit y contrastar APIs con documentación oficial Apple.

- T16/T17/T18: componentes compartidos, tipografía del sistema, jerarquía clara y navegación predecible; materiales medidos, compatibles con temas y preferencias de accesibilidad.
- T19/T20/T22: feedback inmediato al presionar, arrastre continuo desde el punto de agarre y transiciones interrumpibles. Conservar controles y gestos nativos; no introducir librerías web.
- T17/T18/T38: probar movimiento reducido, transparencia reducida, contraste aumentado, teclado y VoiceOver; revisar estados claro/oscuro/custom y Retina.
- T22/T36: medir latencia y hitches al arrastrar pestañas, ramas y minimapa; cancelar o invertir durante la transición sin saltos ni acciones Git accidentales.
- Evidencia: prototipo funcional, capturas inspeccionadas y recorrido grabado por interacción; ningún efecto visual exime del presupuesto de memoria.

## Resolución de las revisiones de modelos

Las propuestas locales y Cloud revisaron el paquete previo a incorporar apple-design. La revisión Cloud completa llegó cercada como Markdown y falló el parser JSON: se conserva como tal y sus observaciones se valoran manualmente; no se considera una aprobación automática. Ver [adjudicación](specific-plan-review-adjudication.json).

Antes de implementar restricciones comerciales de T32, elaborar una matriz proveedor × capacidad × nivel propuesto y mantenerla sin activar hasta resolver la decisión comercial de T40. Medir cada backend IA y sus procesos auxiliares en T34/T36, conservando el límite principal. Para cerrar T40, cada P1 debe tener prueba de corrección o exclusión explícita del candidato con alcance y responsable; una excepción no cierra una tarea ni permite declarar todo terminado.

## Cómo genera y valida cambios el modelo

1. Preparar por subtarea un paquete con archivos reales completos de su alcance, hashes, dependencias, documentación pertinente, reproducción y criterios de aceptación; dividir la responsabilidad si no cabe, sin truncar a ciegas.
2. Resolver modelo/digest y comprobar pesos locales, remote_host/remote_model y alias. Una sola inferencia pesada a la vez; keep_alive=0 y comprobar /api/ps vacío al terminar.
3. Pedir JSON con unified diff, archivos afectados, razones, supuestos, pruebas propuestas y riesgos. El modelo no recibe autorización para ejecutar shell, Git, publicar ni cambiar permisos.
4. Guardar propuesta cruda fuera de fuentes; validar tamaño, rutas permitidas y hashes vigentes. Rechazar rutas externas, borrados amplios, cambios ajenos, tests debilitados y comandos embebidos.
5. Revisar el diff completo; aplicar con apply_patch solo después de leer todos los objetivos y relacionados. Comparar contra el worktree previo, no contra una copia desactualizada de HEAD.
6. Compilar el lote Swift y ejecutar pruebas reales, control negativo y revisión de seguridad; revertir únicamente el cambio propio mediante un parche si no cumple, nunca resetear cambios del usuario.
7. Revisar con independencia, registrar modelo/digest/tokens/tiempo/aceptación y actualizar la tarea solo si pasan todos sus gates. No es un flujo de cero tokens de supervisión.
8. Antes de cada uso de Ollama Cloud, revisar y registrar el paquete mínimo que sale del Mac, proveedor/modelo y finalidad. Mantenerse dentro de la política híbrida elegida; registrar coste observado sin prometer ahorro no medido.

Runner disponible: scripts/local-agents.mjs, con roles/contextos separados, fuentes completas dentro del límite del paquete, rutas/hashes comprobados, propuestas conservadas e inferencias locales en serie. Propone cambios sobre archivos existentes; la integración es supervisada y exige pruebas. No aplica diffs automáticamente.

## Orden de trabajo

Las fases agrupan trabajo; las dependencias de cada ticket son las condiciones de cierre. Correcciones P0 acotadas pueden adelantarse con sus pruebas sin declarar cerrado su ticket padre.

- P0 Congelar estado y asegurar herramientas: T01, T02, T03, T04, T05, T06, T07, T38.
- P1 Seguridad de datos y recuperación Git: T08, T09, T10, T11, T12, T13, T14, T15.
- P2 Comandos, ventanas y sistema gráfico: T16, T17, T18, T19, T20, T21, T22.
- P3 Staging, diff, conflictos y operaciones: T23, T24, T25, T26, T27, T28, T29, T30.
- P4 GitHub, gestores de tickets, terminal e IA: T31, T32, T33, T34, T35.
- P5 Presupuestos, resistencia y distribución: T36, T37, T39, T40.

## Desglose de los 40 tickets

### T01 Congelar baseline: commit, cambios ajenos, escenarios y equipo de referencia; definir unidades de medición

Estado del registro: verificada. Specs: GM-001, GM-027. Depende de: ninguna.

Modelo para el borrador: local-light; revisión e integración independientes.

Archivos existentes que revisar:

- [docs/roadmap/2026-10-20/implementation/task-state.json](../../../../docs/roadmap/2026-10-20/implementation/task-state.json) — SHA256 e15393875198c100a4d87c4ff9aa023bbfadb1c4b800cab1733181bcd2326b9c.
- [scripts/check-memory-budget.mjs](../../../../scripts/check-memory-budget.mjs) — SHA256 8809f1f790c7cc414f2842605dd5923444954fa9d9f748f9c7877ac0af9a5955.

Pasos y entregables:

- [ ] T01.01 Congelar HEAD, diff actual, hashes y cambios ajenos antes de retomar implementación.
- [ ] T01.02 Separar evidencia del 21 y del 25 de octubre; conservar fallos de UI y pruebas parciales, sin convertirlos en aprobaciones.
- [ ] T01.03 Fijar fixtures, pantallas, escalado, unidades y modos frío/caliente; usar la misma carga en cada comparación.
- [ ] T01.04 Asignar responsable de implementación y revisión al iniciar cada subtarea; las fechas de entrega se estiman después de la baseline.

Pruebas que deben demostrar el resultado:

- El inventario vuelve a producir los mismos hashes si no cambia el worktree.
- El validador conserva los 40 IDs y el estado real, sin cerrar tareas por documentación.

Cierre del ticket: Inventario y ficha de benchmark; conservar cambios previos; no hay números de rendimiento inventados.

### T02 Diagnosticar toolchain y fijar compiler/SDK/target compatibles

Estado del registro: en_curso. Specs: GM-001. Depende de: T01.

Modelo para el borrador: local-coder; revisión e integración independientes.

Archivos existentes que revisar:

- [project.yml](../../../../project.yml) — SHA256 228dc69190fbb07551fef565625411cebb57d5bbe9f07d70466f56acd6578085.
- [Package.swift](../../../../Package.swift) — SHA256 7fc6ecdcfd745eefcb55b19f89a90ffac59ccf954efe8ff7601df1d2183bfc23.
- [scripts/verify-xcodebuild.sh](../../../../scripts/verify-xcodebuild.sh) — SHA256 d8c37ba229388188d934fabeda9f03f8259c4c3d6a730bee1cf0598c84d488fa.

Pasos y entregables:

- [ ] T02.01 Registrar Xcode, Swift, SDK, macOS mínimo y dependencias MLX/editor/Ghostty reales.
- [ ] T02.02 Separar incompatibilidad CoreDevice/CoreSimulator de fallos de compilación de GitMac.
- [ ] T02.03 Reproducir build mínimo y enlace de paquetes; definir combinación soportada antes de actualizar nada.
- [ ] T02.04 Documentar reparación o ruta de build soportada; no rebajar concurrencia ni elevar deployment target para ocultar errores.

Pruebas que deben demostrar el resultado:

- Debug, Release y build-for-testing completan con marcador correcto.
- La prueba de fallo deliberado del toolchain no produce un verde vacío.

Cierre del ticket: Build mínimo y carga del proyecto sin fallo CoreDevice/SDK; registrar solución local antes de atribuir errores a GitMac.

### T03 Reconciliar proyecto Xcode, XcodeGen y SPM; decidir fuente de verdad

Estado del registro: en_curso. Specs: GM-001. Depende de: T02.

Modelo para el borrador: local-coder; revisión e integración independientes.

Archivos existentes que revisar:

- [project.yml](../../../../project.yml) — SHA256 228dc69190fbb07551fef565625411cebb57d5bbe9f07d70466f56acd6578085.
- [Package.swift](../../../../Package.swift) — SHA256 7fc6ecdcfd745eefcb55b19f89a90ffac59ccf954efe8ff7601df1d2183bfc23.
- [scripts/check-project-generation.rb](../../../../scripts/check-project-generation.rb) — SHA256 aeca58a4134a2620c20268a1641323e8099c865eacd515fa6a25b7c6ac6bfd38.

Pasos y entregables:

- [ ] T03.01 Comparar targets, fuentes, recursos, bridging headers, paquetes y schemes de proyecto original, XcodeGen y SPM.
- [ ] T03.02 Decidir y documentar la fuente de verdad; conservar el proyecto original hasta validar la sustitución.
- [ ] T03.03 Resolver discrepancias reales de SPM, incluyendo recursos y dependencias del target de tests.
- [ ] T03.04 Garantizar que UI tests y helpers no queden ignorados ni fuera del target al regenerar.
- [ ] T03.05 Adoptar el proyecto generado solo tras build limpio y pruebas; no reemplazarlo solo porque el YAML sea válido.

Pruebas que deben demostrar el resultado:

- Regeneración determinista y comparación de productos/settings.
- Todos los targets de tests compilan y el scheme ejecuta los tests solicitados.

Cierre del ticket: Build limpio de Debug y Release; regeneración controlada conserva productos/targets; matriz documentada.

### T04 Hacer que CI falle correctamente y limite permisos

Estado del registro: en_curso. Specs: GM-001. Depende de: T03.

Modelo para el borrador: local-coder; revisión e integración independientes.

Archivos existentes que revisar:

- [.github/workflows/swift.yml](../../../../.github/workflows/swift.yml) — SHA256 ea73334d686bdc85894ac9b6129d7588e365229e5edfe3143599cb3305f39bb5.
- [.github/workflows/release.yml](../../../../.github/workflows/release.yml) — SHA256 c01241ebef5e30c4732d63e6c77455e1efeb829ad93a3bae4d3d027afee37234.
- [scripts/verify-xcodebuild.sh](../../../../scripts/verify-xcodebuild.sh) — SHA256 d8c37ba229388188d934fabeda9f03f8259c4c3d6a730bee1cf0598c84d488fa.
- [scripts/test-xcodebuild-gate.mjs](../../../../scripts/test-xcodebuild-gate.mjs) — SHA256 4e12a0921995e648fb0e5b349d87a2027e65dda37ec570fcfdf042e47e7a5fa2.

Pasos y entregables:

- [ ] T04.01 Conservar contratos distintos para build, build-for-testing, test y test-without-building.
- [ ] T04.02 Propagar fallos de Swift, enlace, firma, tee y tests sin aceptar solo un marcador de texto.
- [ ] T04.03 Reducir permisos y exposición de secretos por job; aislar PR no confiable de distribución.
- [ ] T04.04 Verificar ejecución alojada cuando el usuario habilite el workflow; no hacer push para conseguirla implícitamente.

Pruebas que deben demostrar el resultado:

- Todos los escenarios positivos y negativos del wrapper.
- Una ejecución alojada roja por fallo deliberado y otra válida, con logs del mismo source hash.

Cierre del ticket: Fallos deliberados de Swift, enlace y test dejan CI roja; resultado vacío falla; permissions mínimos por job.

### T05 Conectar tests a modelos y parsers de producción

Estado del registro: verificada. Specs: GM-002. Depende de: T04.

Modelo para el borrador: review; revisión e integración independientes.

Archivos existentes que revisar:

- [Tests/GitMacTests/GitMacTests.swift](../../../../Tests/GitMacTests/GitMacTests.swift) — SHA256 e811f11a8dd5f6546f8b98c529214200b5f39305d1441334f9bdcc88d597a01f.
- [scripts/test-production-suites.mjs](../../../../scripts/test-production-suites.mjs) — SHA256 e8900e871245ced2022621559dfb8314f9db25978d6b49bbefd64e3ed0027626.
- [scripts/test-core-regressions.mjs](../../../../scripts/test-core-regressions.mjs) — SHA256 1b5a6c9fb38894cd39b4abd2ca73b7341b47e5d6342fe30f076f4e251183c04e.

Pasos y entregables:

- [ ] T05.01 Mantener suites enlazadas a código de producción y eliminar nuevas definiciones sombra.
- [ ] T05.02 Registrar qué dependencias son fixtures y qué archivos se compilan sin cambios.
- [ ] T05.03 Añadir cada regresión nueva antes o junto al fix, incluida la matriz de conflictos y repositorios.
- [ ] T05.04 Conservar controles negativos que fallen por comportamiento, no por compilación o formato del runner.

Pruebas que deben demostrar el resultado:

- Mutación controlada de un modelo real rompe exactamente el contrato esperado.
- Las suites actuales se repiten después de cualquier cambio de contrato compartido.

Cierre del ticket: Mutación deliberada del código real rompe la prueba; retirar modelos sombra del camino de validación.

### T06 Construir catálogo de fixtures aislados y oracle Git

Estado del registro: en_curso. Specs: GM-002. Depende de: T05.

Modelo para el borrador: local-coder; revisión e integración independientes.

Archivos existentes que revisar:

- [Tests/CoreRegressions/GitIntegrationMain.swift](../../../../Tests/CoreRegressions/GitIntegrationMain.swift) — SHA256 11e3f830e769e1bbf084df669f487faf7492a73090ef7a7b066964652fe3d5f0.
- [GitMacUITests/SnapshotHelper.swift](../../../../GitMacUITests/SnapshotHelper.swift) — SHA256 f7d5e6b7c9e81f6f114bf1ccde71bdae591bea5201369f4fb7056446662b48e7.
- [scripts/test-git-integration.mjs](../../../../scripts/test-git-integration.mjs) — SHA256 9272ef94947b2c63add3b96b9a2b77f7f080737a31bbb08eb32d153a3d4da901.

Pasos y entregables:

- [ ] T06.01 Completar F01–F15 con repositorios temporales y oracle Git; enumerar cobertura y huecos.
- [ ] T06.02 Aislar config, templates, hooks, identidad, remotos y variables GIT_/DYLD_ heredadas.
- [ ] T06.03 Añadir texto LF/CRLF, Unicode, nombres con guion, add/delete, rename, binarios, locks y worktrees vinculados.
- [ ] T06.04 Distinguir fixtures de rendimiento lineal de DAGs reales y de la matriz funcional.
- [ ] T06.05 Limpiar solo recursos propios después de terminar procesos; ninguna prueba restaura proyectos del usuario.

Pruebas que deben demostrar el resultado:

- Repetición determinista y cleanup de fixtures.
- Control negativo detecta una ruta de arranque que restaure sesiones reales.

Cierre del ticket: Fixtures F01–F15 reproducibles; validar refs/index/blobs, sin depender de configuración global del usuario.

### T07 Hacer threat model y asignar controles a cada frontera

Estado del registro: verificada. Specs: GM-004, GM-008, GM-026, GM-028. Depende de: T01.

Modelo para el borrador: review; revisión e integración independientes.

Archivos existentes que revisar:

- [docs/roadmap/2026-10-20/implementation/threat-model.md](../../../../docs/roadmap/2026-10-20/implementation/threat-model.md) — SHA256 e8e78bfbfb345549f47a53ea033cc7f7a285032583975cc9fbffe481cedb6722.
- [scripts/check-threat-model.mjs](../../../../scripts/check-threat-model.mjs) — SHA256 0700021ed91d1a879c568f2754ae42ea04709190a69a2b0023192a0a2ef2cbc0.

Pasos y entregables:

- [ ] T07.01 Mantener el inventario verificado de amenazas y actualizar fronteras de tickets custom, drag & drop e IA Apple.
- [ ] T07.02 Asignar cada control pendiente a una tarea y una prueba adversaria concreta.
- [ ] T07.03 Incluir confusión de repos/cuentas, payloads externos, redirecciones y filtración de secretos.
- [ ] T07.04 No interpretar el cierre documental de T07 como hardening de todas las funciones.

Pruebas que deben demostrar el resultado:

- Checker positivo y omisión deliberada de una frontera.
- Cada control nuevo aporta observado y riesgo residual, no solo ausencia de crash.

Cierre del ticket: Tabla entrada/activo/amenaza/mitigación/prueba/dueño; incluir repo malicioso, shell, tokens, red y release.

### T08 Cerrar interpolación shell y falsos éxitos de patches

Estado del registro: en_curso. Specs: GM-004, GM-026. Depende de: T06, T07.

Modelo para el borrador: local-coder; revisión e integración independientes.

Archivos existentes que revisar:

- [GitMac/Features/CloudPatches/CloudPatchService.swift](../../../../GitMac/Features/CloudPatches/CloudPatchService.swift) — SHA256 4922c2b54b1be63e4038537029ca614aa6095a3727a52f99cb408dbe42f9a847.
- [GitMac/Core/Utils/ShellExecutor.swift](../../../../GitMac/Core/Utils/ShellExecutor.swift) — SHA256 50433984b926fe011b31198b1c405719590f345f6431fb9a4aeb6c09ac6ceadb.

Pasos y entregables:

- [ ] T08.01 Mantener applyPatch sin shell interpolada, con cwd, temporales propios y exit status comprobado.
- [ ] T08.02 Barrido de ejecutores de hooks, workflows, terminal y helpers para distinguir argv de shell intencionada.
- [ ] T08.03 Tratar rutas, refs y tickets como datos; añadir separador -- cuando el contrato Git lo permita.
- [ ] T08.04 Rechazar patches obsoletos/adversarios y mostrar recuperación, sin reset ni reapply ciego.

Pruebas que deben demostrar el resultado:

- Rutas con apóstrofos, espacios, Unicode y guiones no ejecutan órdenes ni amplían el pathspec.
- Fallo de apply devuelve error y conserva ref/index/working tree esperado.

Cierre del ticket: `git apply` usa argv/cwd, soporta apóstrofos; exitCode no cero falla; contenido adversario no ejecuta órdenes.

### T09 Unificar status NUL y preservar ambos estados XY y oldPath

Estado del registro: verificada. Specs: GM-003. Depende de: T06.

Modelo para el borrador: review; revisión e integración independientes.

Archivos existentes que revisar:

- [GitMac/Core/Git/GitEngine.swift](../../../../GitMac/Core/Git/GitEngine.swift) — SHA256 1927aca9ca14e94c6600a399bfcd41f5116e721b017ccfde12eb1727c716e91b.
- [GitMac/Core/Git/Repository.swift](../../../../GitMac/Core/Git/Repository.swift) — SHA256 7990bb7d242da03bccf8e7b9d59475fdc267b660de8389134884969ead0c23d9.

Pasos y entregables:

- [ ] T09.01 Mantener parser NUL único con XY, origen de rename y estadísticas asociadas por identidad.
- [ ] T09.02 Contrastar staging, grafo, contexto y refresh contra la misma snapshot.
- [ ] T09.03 Ampliar casos unborn, ignored, untracked, submodules y todos los estados unmerged.
- [ ] T09.04 Acotar buffers sin truncar una salida que determine el estado del repositorio.

Pruebas que deben demostrar el resultado:

- Oracle porcelain/numstat -z con nombres adversarios.
- Una mutación de delimitadores o XY rompe la prueba de producción.

Cierre del ticket: Pasan las cinco regresiones reproducidas y F02/F03; snapshot igual en staging, context y refresh.

### T10 Unificar ejecución, streaming, progreso, buffering y cancelación

Estado del registro: verificada. Specs: GM-004. Depende de: T06, T07.

Modelo para el borrador: review; revisión e integración independientes.

Archivos existentes que revisar:

- [GitMac/Core/Utils/ShellExecutor.swift](../../../../GitMac/Core/Utils/ShellExecutor.swift) — SHA256 50433984b926fe011b31198b1c405719590f345f6431fb9a4aeb6c09ac6ceadb.
- [Tests/CoreRegressions/ProcessIntegrationMain.swift](../../../../Tests/CoreRegressions/ProcessIntegrationMain.swift) — SHA256 e3e8d4433ef78a1f1efb28c80a98e5e7e1c0e22e6216f19774a57ccc0bcaaf44.

Pasos y entregables:

- [ ] T10.01 Conservar un resultado terminal por proceso, captura stdout/stderr y backpressure acotados.
- [ ] T10.02 Verificar cancelación del grupo propio, timeout, hijos y liberación de pipes/FDs.
- [ ] T10.03 Evitar nuevos ejecutores duplicados en integraciones, workflows y terminal.
- [ ] T10.04 Registrar límites de salida y política de bytes inválidos; no silenciar exit codes no cero.

Pruebas que deben demostrar el resultado:

- F13 con streams simultáneos de 64 MiB, UTF-8 fragmentado y consumidor lento.
- Cancelación no mata procesos ajenos ni deja hijos/FDs propios abiertos.

Cierre del ticket: F13 sin deadlock, pérdida de UTF-8 ni buffers ilimitados; resultado una vez y recursos liberados.

### T11 Definir identidad de repo, worktree, ventana y operación

Estado del registro: en_curso. Specs: GM-005. Depende de: T09, T10.

Modelo para el borrador: local-coder; revisión e integración independientes.

Archivos existentes que revisar:

- [GitMac/Core/Utils/FileWatcher.swift](../../../../GitMac/Core/Utils/FileWatcher.swift) — SHA256 897fb1654732090407b632ab56107e11030c661405dabbffc29246ceb042326f.
- [GitMac/App/GitMacApp.swift](../../../../GitMac/App/GitMacApp.swift) — SHA256 e82f387175bd981f502ca0a68fa4e867080bdb153d20b97f4862b5da5704bf2b.
- [GitMac/Core/Services/WorkspaceSettings.swift](../../../../GitMac/Core/Services/WorkspaceSettings.swift) — SHA256 8fd405dcd5df81af754b99619df87d03d545ee9e797709f8a280ee6c955e96a7.

Pasos y entregables:

- [ ] T11.01 Adoptar identidades de working tree y common dir en configuración, drag & drop, cachés y operaciones.
- [ ] T11.02 Definir ownership por ventana, pestaña, cuenta y operationID; un UUID de refresh no es un journal durable.
- [ ] T11.03 Coordinar escrituras incompatibles por recurso Git, sin serializar lecturas independientes innecesariamente.
- [ ] T11.04 Resolver alias, rutas movidas y worktrees con .git como archivo; diseñar migración de configuraciones por ruta.
- [ ] T11.05 Conservar rearme nativo y creación tardía ya probados.

Pruebas que deben demostrar el resultado:

- Dos worktrees comparten common identity, no HEAD/index ni WIP.
- A/B concurrentes y aliases no cruzan configuración ni cierran FD ajenos.

Cierre del ticket: Documento de ownership/locks/cachés; distinguir working tree y common git dir; adopción en una ruta vertical.

### T12 Impedir publicaciones obsoletas y ordenar invalidaciones

Estado del registro: en_curso. Specs: GM-005. Depende de: T11.

Modelo para el borrador: local-coder; revisión e integración independientes.

Archivos existentes que revisar:

- [GitMac/App/GitMacApp.swift](../../../../GitMac/App/GitMacApp.swift) — SHA256 e82f387175bd981f502ca0a68fa4e867080bdb153d20b97f4862b5da5704bf2b.
- [GitMac/Core/Services/GitService.swift](../../../../GitMac/Core/Services/GitService.swift) — SHA256 046b6b94169b8f1462ec60abe321c6d05467aeafac238bfd901a6cb5f1cd237e.
- [scripts/test-session-isolation.mjs](../../../../scripts/test-session-isolation.mjs) — SHA256 b9a23db9f874b2d0fd421effc24860a9a0331da986d50cebfc8121cba87cf688.

Pasos y entregables:

- [ ] T12.01 Extender guardas de ruta/generación a PR trackers, tickets, diffs, clones y operaciones pendientes.
- [ ] T12.02 Capturar repositorio/cuenta de origen antes de await y revalidar antes de publicar o escribir.
- [ ] T12.03 Cancelar recursos de pestaña/ventana cerrada sin invalidar trabajos de otras sesiones.
- [ ] T12.04 Coalescer invalidaciones por recurso y eliminar refresh globales duplicados.
- [ ] T12.05 Conservar las 13 comprobaciones actuales como base, no como aprobación multiventana integral.

Pruebas que deben demostrar el resultado:

- A lenta/B rápida, cierre, reapertura, cambio de cuenta y error tardío.
- No crecen watchers/tareas por ciclos repetidos de abrir/cerrar.

Cierre del ticket: A lenta/B rápida y tareas auxiliares no cruzan estado; cierre de tabs elimina recursos propios.

### T13 Migrar secretos a Keychain con verificación y recuperación

Estado del registro: en_curso. Specs: GM-008. Depende de: T06, T07.

Modelo para el borrador: local-coder; revisión e integración independientes.

Archivos existentes que revisar:

- [GitMac/Core/Utils/KeychainManager.swift](../../../../GitMac/Core/Utils/KeychainManager.swift) — SHA256 77112e17ae014aadec4f68f3a21c5e071aa77ff881c19d10e64062fab85e9831.
- [Tests/GitMacTests/CredentialStorageTests.swift](../../../../Tests/GitMacTests/CredentialStorageTests.swift) — SHA256 eca7f8388f99f05709e3d56149768f89acc33df940628b7ad4437dce69cfcc49.

Pasos y entregables:

- [ ] T13.01 Completar namespaces por cuenta/host/proveedor y almacenar solo referencias en la configuración de repo.
- [ ] T13.02 Diseñar aprobación y recuperación de migración de credenciales, manteniéndola deshabilitada por defecto.
- [ ] T13.03 Tratar denegación, bloqueo y persistencia fallida como errores reales; no convertirlos en cuenta desconectada silenciosa.
- [ ] T13.04 No enviar claves, cookies, llaveros, .env ni contenido sensible a modelos locales o cloud.
- [ ] T13.05 Validar el flujo firmado de la app y revocación/logout sin borrar secretos de otra cuenta.

Pruebas que deben demostrar el resultado:

- Migración sintética interrumpida y recuperación posterior.
- Cuenta A no lee ni revoca las credenciales de B.

Cierre del ticket: Credenciales sintéticas sobreviven migración interrumpida; bloqueo/denegación/persistencia fallida dan error real.

### T14 Implementar journal y undo por operación con precondiciones

Estado del registro: pendiente. Specs: GM-006. Depende de: T09, T10, T12.

Modelo para el borrador: local-coder; revisión e integración independientes.

Archivos existentes que revisar:

- [GitMac/Core/Services/UndoManager.swift](../../../../GitMac/Core/Services/UndoManager.swift) — SHA256 2b6ceddd3fe233205219bcc0437e187fe3767adcbeadc8f6c515721703b81ef3.
- [GitMac/Core/Git/GitEngine.swift](../../../../GitMac/Core/Git/GitEngine.swift) — SHA256 1927aca9ca14e94c6600a399bfcd41f5116e721b017ccfde12eb1727c716e91b.

Pasos y entregables:

- [ ] T14.01 Inventariar acciones undo realmente conectadas y deshabilitar capacidades sin recuperación segura.
- [ ] T14.02 Definir journal por operación con refs, index, contenido y precondiciones mínimas.
- [ ] T14.03 Sustituir reset hard ciego por recuperación que preserve cambios posteriores del usuario.
- [ ] T14.04 Añadir confirmación legible, preview, expiración/cuota y recuperación tras reiniciar.
- [ ] T14.05 Probar interferencia de comandos externos y trabajo nuevo antes de undo/redo.

Pruebas que deben demostrar el resultado:

- F07 compara snapshots exactos y conserva cambios nuevos.
- Precondición alterada bloquea undo con recuperación visible, sin pérdida de datos.

Cierre del ticket: F07 conserva cambios nuevos y compara snapshots; tipos sin recuperación quedan deshabilitados.

### T15 Ejecutar exactamente el plan de rebase y recuperar sesiones

Estado del registro: pendiente. Specs: GM-007. Depende de: T14.

Modelo para el borrador: local-coder; revisión e integración independientes.

Archivos existentes que revisar:

- [GitMac/Features/Rebase/InteractiveRebaseView.swift](../../../../GitMac/Features/Rebase/InteractiveRebaseView.swift) — SHA256 a491e057b2b6ffea97fe2b0f5a167510778044e15d537a9468be936bb30c852a.
- [GitMac/Core/Git/GitEngine.swift](../../../../GitMac/Core/Git/GitEngine.swift) — SHA256 1927aca9ca14e94c6600a399bfcd41f5116e721b017ccfde12eb1727c716e91b.

Pasos y entregables:

- [ ] T15.01 Materializar exactamente el todo aprobado y retirar el camino que descarta el plan elegido.
- [ ] T15.02 Validar pick/reorder/reword/squash/fixup/drop antes de mutar historia.
- [ ] T15.03 Usar sequence editor controlado y temporales propios; no interpolar shell.
- [ ] T15.04 Detectar sesión rebase real y soportar continue/abort/reinicio con journal.
- [ ] T15.05 Drag & drop de reordenamiento tiene alternativa por teclado y no ejecuta rebase por hover.

Pruebas que deben demostrar el resultado:

- F06 compara DAG, mensajes y árbol finales con el plan aprobado.
- Conflicto, cancelación y reinicio preservan la sesión y permiten recuperación.

Cierre del ticket: Pick/reorder/reword/squash/fixup/drop aprobados en F06; continue/abort/reinicio correctos.

### T16 Unificar comandos, ayuda, presets y recorder de teclado

Estado del registro: en_curso. Specs: GM-009. Depende de: T12.

Modelo para el borrador: local-coder; revisión e integración independientes.

Archivos existentes que revisar:

- [GitMac/App/GitMacApp.swift](../../../../GitMac/App/GitMacApp.swift) — SHA256 e82f387175bd981f502ca0a68fa4e867080bdb153d20b97f4862b5da5704bf2b.
- [GitMac/UI/Components/KeyboardShortcuts.swift](../../../../GitMac/UI/Components/KeyboardShortcuts.swift) — SHA256 0d964581e2d74413a3efc7a45dd6d8b79ba0b33a13f9788974bd7ad80d0b44a6.
- [GitMac/Features/Staging/StagingAreaView.swift](../../../../GitMac/Features/Staging/StagingAreaView.swift) — SHA256 71670dc0723a50341334eac6739ca9812f8364e0dd166dbb803a33f85c3e42d4.

Pasos y entregables:

- [ ] T16.01 Crear un registro único de comandos con ID, alcance, título, disponibilidad y acción.
- [ ] T16.02 Resolver la colisión Command-Shift-U entre Push y Unstage All y generar ayuda desde el mismo registro.
- [ ] T16.03 Proteger edición de texto, first responder y atajos nativos como Command-comma.
- [ ] T16.04 Conectar menús contextuales a acciones verificadas, no solo notificaciones sin consumidor.
- [ ] T16.05 Implementar presets/recorder con conflicto detectado, persistencia y restauración.
- [ ] T16.06 Cada acción destructiva muestra repo, destino, precondición y confirmación según riesgo.

Pruebas que deben demostrar el resultado:

- Un atajo dispara una única acción en repo/foco correctos.
- Cada item contextual visible tiene recorrido positivo, disabled justificado y fallo recuperable.

Cierre del ticket: Resolver Push/Unstage; proteger atajos estándar y first responder; recorder funcional y persistente.

### T17 Cerrar navegación, tabs, multiventana y restauración

Estado del registro: en_curso. Specs: GM-010. Depende de: T16.

Modelo para el borrador: local-coder; revisión e integración independientes.

Archivos existentes que revisar:

- [GitMac/App/ContentView.swift](../../../../GitMac/App/ContentView.swift) — SHA256 5753e0275d3ff6b8953e65810bfc0415b61df30350b234da95864a582e2b55a3.
- [GitMac/App/GitMacApp.swift](../../../../GitMac/App/GitMacApp.swift) — SHA256 e82f387175bd981f502ca0a68fa4e867080bdb153d20b97f4862b5da5704bf2b.
- [GitMac/UI/Components/Navigation/RepositoryTabsView.swift](../../../../GitMac/UI/Components/Navigation/RepositoryTabsView.swift) — SHA256 358a3196cba90c475dcce9d2de5d9828df6cfbe8f5cb6d8aa92edeb6249e122c.
- [GitMac/Features/Settings/SettingsView.swift](../../../../GitMac/Features/Settings/SettingsView.swift) — SHA256 47fe8c8bf81a1eaa9cb1d64e200a430a6b659e1f85ce10eb66b7ddeae80376d3.

Pasos y entregables:

- [ ] T17.01 Terminar pestañas, historial, foco, drafts y restauración por ventana sin restaurar mutaciones Git.
- [ ] T17.02 Mantener el aislamiento de columnas que corrigió el crash stash→archivo.
- [ ] T17.03 Ajustar ventanas al visibleFrame del monitor contenedor en puntos, también al moverlas entre pantallas.
- [ ] T17.04 Usar escena Settings nativa, categorías accesibles y carga del panel seleccionado.
- [ ] T17.05 Validar redimensionado mediante el sistema operativo; el error AX -25211 requiere permiso del usuario, no desactivar protecciones.
- [ ] T17.06 Conservar fallos de automatización por separado de límites nativos comprobados.

Pruebas que deben demostrar el resultado:

- F15 y recorridos stash/archivo/visor sin abort ni mínimo oscilante.
- Pantallas Retina 1x/2x, ventana compacta, ruta movida y dos ventanas aisladas.

Cierre del ticket: F15 y rutas movidas aprobados; draft, selección y foco no saltan de repo; restore no muta Git.

### T18 Auditar y corregir teclado, VoiceOver y ajustes del sistema

Estado del registro: pendiente. Specs: GM-011. Depende de: T16, T17.

Modelo para el borrador: local-coder; revisión e integración independientes.

Archivos existentes que revisar:

- [GitMac/Features/Settings/Components/ThemeButton.swift](../../../../GitMac/Features/Settings/Components/ThemeButton.swift) — SHA256 cb56846ecf7325fdbfdb95ac2eb6ef152a4523444d263cc55224e535d63d6c88.
- [GitMac/UI/Components/Atoms/Buttons/DSButton.swift](../../../../GitMac/UI/Components/Atoms/Buttons/DSButton.swift) — SHA256 ebc27feb3cae3db8878c1ed4eaccc80b4d08b9b79dd5ee84e9a4f6f60bf8ce32.
- [GitMac/UI/Components/KeyboardShortcuts.swift](../../../../GitMac/UI/Components/KeyboardShortcuts.swift) — SHA256 0d964581e2d74413a3efc7a45dd6d8b79ba0b33a13f9788974bd7ad80d0b44a6.

Pasos y entregables:

- [ ] T18.01 Recorrer abrir repo, navegar, staging, commit, conflictos y Ajustes solo con teclado.
- [ ] T18.02 Auditar nombres, roles, selección, disabled, foco, orden y anuncios con Inspector/VoiceOver.
- [ ] T18.03 Comprobar Reduce Motion, Reduce Transparency, contraste y tamaño de texto.
- [ ] T18.04 No usar un identifier raíz que sobrescriba IDs de descendientes ni grupos AX vacíos.
- [ ] T18.05 Distinguir ajustes propios de funciones OS reales: Open at login y menú de barra necesitan implementación nativa, no solo AppStorage.

Pruebas que deben demostrar el resultado:

- Recorrido accesible grabado por escenario y estado.
- Los controles fuera de vista son alcanzables mediante scroll y foco sin trampas.

Cierre del ticket: Flujo central completo con Inspector/VoiceOver; nombres/estados/foco probados y evidencia registrada.

### T19 Consolidar tokens/componentes activos y baseline visual

Estado del registro: en_curso. Specs: GM-012. Depende de: T18.

Modelo para el borrador: local-coder; revisión e integración independientes.

Archivos existentes que revisar:

- [GitMac/UI/Theme/DesignTokens.swift](../../../../GitMac/UI/Theme/DesignTokens.swift) — SHA256 325add7e7c776c17b0ef0dfd1a4b8c586837b48a23a5aafbd14829d8ce556a7b.
- [GitMac/Features/Settings/Components/SettingsSection.swift](../../../../GitMac/Features/Settings/Components/SettingsSection.swift) — SHA256 f0ea385cc2d1ddc6056356ad4c26ec61974c1d1ced849e3140c746d46940f4ea.
- [GitMac/UI/Theme/ThemeManager.swift](../../../../GitMac/UI/Theme/ThemeManager.swift) — SHA256 857f099f0872cb4a82e7f8f63c6ecbfd04cd12c52bc77daf56e3acc16caad488.
- [GitMac/Features/Settings/SettingsView.swift](../../../../GitMac/Features/Settings/SettingsView.swift) — SHA256 47fe8c8bf81a1eaa9cb1d64e200a430a6b659e1f85ce10eb66b7ddeae80376d3.

Pasos y entregables:

- [ ] T19.01 Inventariar ventanas, componentes activos, variantes y duplicaciones antes de retirar nada.
- [ ] T19.02 Definir línea visual simple con jerarquía, densidad, tipografía de sistema, SF Symbols y colores semánticos.
- [ ] T19.03 Reutilizar DSScrollView/DSVStack y SettingsPage; extender reutilización solo a contratos realmente iguales.
- [ ] T19.04 Consolidar patrones de toolbar, secciones, empty/loading/error, confirmaciones y ayuda contextual.
- [ ] T19.05 Probar sistema, claro, oscuro y custom claro/oscuro; no forzar custom claro a oscuro ni hardcodear colores.
- [ ] T19.06 Comparar todas las ventanas inventariadas con baseline visual compacta y amplia; ninguna se aprueba por muestreo silencioso.

Pruebas que deben demostrar el resultado:

- Capturas leídas de cada ventana/estado/tema exigido y revisión de contraste.
- Cambio de tema no reconstruye sesiones ni provoca scans completos sin necesidad.

Cierre del ticket: Escenas claras/oscuras/ampliadas revisadas; diferencias con GitKraken justificadas; ninguna variante retirada sin referencias.

### T20 Corregir alcance/topología de grafo y múltiples refs por SHA

Estado del registro: en_curso. Specs: GM-013. Depende de: T09, T12.

Modelo para el borrador: local-coder; revisión e integración independientes.

Archivos existentes que revisar:

- [GitMac/Features/CommitGraph/Services/GraphLayoutEngine.swift](../../../../GitMac/Features/CommitGraph/Services/GraphLayoutEngine.swift) — SHA256 b4cc8f4a79b27ad496ea688a9cdae11edce1c2d0b182bec8f97a4e5b49406edc.
- [GitMac/Features/CommitGraph/ViewModels/GraphViewModel.swift](../../../../GitMac/Features/CommitGraph/ViewModels/GraphViewModel.swift) — SHA256 0398842d56a678825ef42576684dc09c7ea75a70e2c815554ed44d5db8262200.

Pasos y entregables:

- [ ] T20.01 Definir scope de refs consultadas y orden topológico explícito, independiente de authorDate.
- [ ] T20.02 Representar múltiples refs tipadas por SHA: local, remota, tag y HEAD.
- [ ] T20.03 Modelar fronteras shallow/paginadas sin padres fantasma ni fetch implícito.
- [ ] T20.04 Mantener orden de entrada y separar WIP/stashes sin interrumpir el DAG.
- [ ] T20.05 Contrastar merges, octopus y ramas paralelas con oracle Git.

Pruebas que deben demostrar el resultado:

- F04 y DAGs generados comparan parents, intervalos, refs y carriles.
- Filtrar/cambiar refs no mezcla repos ni deja conexiones fantasma.

Cierre del ticket: F04 coincide con oracle de parents; local/remoto/tag/HEAD correctos; límites shallow visibles.

### T21 Optimizar paginación, lanes, minimap y scans del historial

Estado del registro: en_curso. Specs: GM-013, GM-027. Depende de: T20.

Modelo para el borrador: local-coder; revisión e integración independientes.

Archivos existentes que revisar:

- [GitMac/Features/CommitGraph/ViewModels/GraphViewModel.swift](../../../../GitMac/Features/CommitGraph/ViewModels/GraphViewModel.swift) — SHA256 0398842d56a678825ef42576684dc09c7ea75a70e2c815554ed44d5db8262200.
- [GitMac/Features/CommitGraph/Components/GraphMinimapView.swift](../../../../GitMac/Features/CommitGraph/Components/GraphMinimapView.swift) — SHA256 cadc41398ab6ba3c704ab1fbc5753fe8c9c47a813b619773f05857bb1bd32870.
- [GitMac/Features/CommitGraph/Models/GraphNode.swift](../../../../GitMac/Features/CommitGraph/Models/GraphNode.swift) — SHA256 84eada3d361655953d70434628bc6a40e90fcf4bb32bc857e5dd800114a919e6.

Pasos y entregables:

- [ ] T21.01 Conservar cursor confirmado tras éxito, generaciones y SHA de anclaje de paginación.
- [ ] T21.02 Mantener minimapa completo por identidad con dibujo acotado, sin confundir índices de filas y commits.
- [ ] T21.03 Reducir scans/copias y ejecutar layout pesado fuera del camino bloqueante solo cuando la traza lo justifique.
- [ ] T21.04 Añadir progreso/límites visibles y navegación por SHA que revele destinos filtrados.
- [ ] T21.05 Medir 1k, 10k y 100k con todos los paneles necesarios cargados, no una pantalla vacía.

Pruebas que deben demostrar el resultado:

- Oracle de identidad/topología y fixture 100k con controles negativos.
- p50/p95, CPU, hitches, physical footprint y pico sobre el mismo Release.

Cierre del ticket: F05 y fixture 100k con p95/footprint; no cargar todo para abrir; evitar fetch deepen repetido/implícito.

### T22 Afinar búsqueda/filtros, selección, compare y drag del grafo

Estado del registro: pendiente. Specs: GM-014. Depende de: T16, T18, T19, T21.

Modelo para el borrador: local-coder; revisión e integración independientes.

Archivos existentes que revisar:

- [GitMac/Features/CommitGraph/Models/GraphTransferables.swift](../../../../GitMac/Features/CommitGraph/Models/GraphTransferables.swift) — SHA256 6f435e950a9fd153838f1e9d0f695dd9c2846432ba9c4724dc7138d1912d68be.
- [GitMac/Features/CommitGraph/Components/BranchBadge.swift](../../../../GitMac/Features/CommitGraph/Components/BranchBadge.swift) — SHA256 779b960135d9f815e90840cd15f15aeece11d2ffea1c107a6b72dafbe713935e.
- [GitMac/UI/Components/Rows/BranchRow.swift](../../../../GitMac/UI/Components/Rows/BranchRow.swift) — SHA256 c5adb885046057c9209a4c0d89e8012ba1da6b98e8728b50673042f8cfad79cc.
- [GitMac/UI/Components/Navigation/RepositoryTabsView.swift](../../../../GitMac/UI/Components/Navigation/RepositoryTabsView.swift) — SHA256 358a3196cba90c475dcce9d2de5d9828df6cfbe8f5cb6d8aa92edeb6249e122c.

Pasos y entregables:

- [ ] T22.01 Unificar búsqueda/filtros, selección, compare y deep links por identidad estable.
- [ ] T22.02 Inventariar onDrag/onDrop/draggable/dropDestination y sus contratos antes de consolidar componentes.
- [ ] T22.03 Definir payload tipado/versionado con repo/worktree, SHA/ref y operación; no aceptar texto arbitrario como una acción Git.
- [ ] T22.04 Rechazar payload malformado, demasiado grande, externo o de otro repo antes de mutar.
- [ ] T22.05 Preview, destino claro, confirmación, cancelación, drop múltiple/duplicado y cambio de tab durante el drag.
- [ ] T22.06 Usar APIs Transferable del SDK con availability/fallback soportado y alternativa por teclado.

Pruebas que deben demostrar el resultado:

- Matriz origen/destino del mismo repo, otro repo, worktree, externo y stale.
- Hover/cancel/reorder no ejecutan merge, cherry-pick, reset, push ni PR.

Cierre del ticket: Flujo equivalente GitKraken/GitMac documentado; origen/destino antes de mutar y alternativa por teclado.

### T23 Verificar staging de archivo/hunk/línea y patches obsoletos

Estado del registro: pendiente. Specs: GM-015. Depende de: T09, T12, T14.

Modelo para el borrador: local-coder; revisión e integración independientes.

Archivos existentes que revisar:

- [GitMac/App/ViewModels/StagingViewModel.swift](../../../../GitMac/App/ViewModels/StagingViewModel.swift) — SHA256 5e26ef92d04bc22502219d764812483408b79675bfa6765f978fc7430b2d2d85.
- [GitMac/Features/Staging/StagingAreaView.swift](../../../../GitMac/Features/Staging/StagingAreaView.swift) — SHA256 71670dc0723a50341334eac6739ca9812f8364e0dd166dbb803a33f85c3e42d4.
- [GitMac/App/Panels/Right/RightStagingPanel.swift](../../../../GitMac/App/Panels/Right/RightStagingPanel.swift) — SHA256 b3a33c4e144fbd870365b8a28707c0cb8185f8c82cea028a88231621428fe9b6.

Pasos y entregables:

- [ ] T23.01 Verificar stage/unstage por archivo, hunk y línea contra index/tree reales.
- [ ] T23.02 Capturar identidad y versión del diff al seleccionar, invalidando patches obsoletos.
- [ ] T23.03 Preservar espacios, Unicode, renames, archivo vacío y líneas sin newline final.
- [ ] T23.04 Eliminar handlers y refresh redundantes usando el registro de comandos y un único servicio de staging.
- [ ] T23.05 Bloquear doble submit y mostrar errores, permisos y recuperación sin force.

Pruebas que deben demostrar el resultado:

- F03/F10 comparan blob de index y working tree tras cada acción.
- Edición concurrente o cambio de repo rechaza la selección insegura sin actuar sobre B.

Cierre del ticket: F03/F10 producen index/tree exactos; cambios concurrentes invalidan la selección insegura.

### T24 Consolidar renderer de diff, búsqueda, historia y blame

Estado del registro: en_curso. Specs: GM-016. Depende de: T10, T18, T23.

Modelo para el borrador: local-coder; revisión e integración independientes.

Archivos existentes que revisar:

- [GitMac/Core/Git/DiffEngine.swift](../../../../GitMac/Core/Git/DiffEngine.swift) — SHA256 68f38ab03b1dac560ea2c62501f27925a1ad1f7076b307729d2debfd416881b4.
- [GitMac/Features/Diff/DiffView.swift](../../../../GitMac/Features/Diff/DiffView.swift) — SHA256 e667748c963bf75ed13af29ce27285b8103d24bf0d18eea3b8dc7bf552458caa.
- [GitMac/Features/Diff/DiffCache.swift](../../../../GitMac/Features/Diff/DiffCache.swift) — SHA256 698c5dc87191d05fc4c144845703bb727168fc086c258e8c1f00d6e772e2c7f8.

Pasos y entregables:

- [ ] T24.01 Consolidar parsers/renderers solo tras mapear consumidores y equivalencia de opciones.
- [ ] T24.02 Asegurar unified/split, búsqueda, historia y blame sobre la misma representación.
- [ ] T24.03 Añadir fallback explícito para binarios, encoding no soportado y archivos grandes.
- [ ] T24.04 Virtualizar filas y acotar caché por repo/objeto/opciones con invalidación real.
- [ ] T24.05 Medir parseo, selección y scroll; ninguna normalización silenciosa de contenido.

Pruebas que deben demostrar el resultado:

- Golden/oracle de texto, binario, rename, CRLF y falta de newline final.
- MainActor sin trabajos largos repetidos al hacer scroll o cambiar tema.

Cierre del ticket: Unified/split equivalentes; grandes/binarios con fallback visible; benchmark sin bloquear MainActor.

### T25 Completar commit/amend y resultados parciales commit→push→PR

Estado del registro: pendiente. Specs: GM-015, GM-018, GM-021. Depende de: T23.

Modelo para el borrador: local-coder; revisión e integración independientes.

Archivos existentes que revisar:

- [GitMac/App/ViewModels/StagingViewModel.swift](../../../../GitMac/App/ViewModels/StagingViewModel.swift) — SHA256 5e26ef92d04bc22502219d764812483408b79675bfa6765f978fc7430b2d2d85.
- [GitMac/Features/Staging/StagingAreaView.swift](../../../../GitMac/Features/Staging/StagingAreaView.swift) — SHA256 71670dc0723a50341334eac6739ca9812f8364e0dd166dbb803a33f85c3e42d4.
- [GitMac/Features/PullRequests/PRListView.swift](../../../../GitMac/Features/PullRequests/PRListView.swift) — SHA256 f6efea9211021039b4ba1ed9b24b542171fda7f5629b2c7f76a99e76576c935d.

Pasos y entregables:

- [ ] T25.01 Modelar commit, push y PR como pasos con resultados independientes y trazables.
- [ ] T25.02 Verificar amend, firma, hooks, mensaje y snapshot de index antes de commit.
- [ ] T25.03 Impedir doble commit y conservar draft/selección por repo.
- [ ] T25.04 Si falla push o PR, reintentar solo el paso pendiente sin rehacer el commit.
- [ ] T25.05 Mostrar SHA, remoto y rama reales en el resultado y recuperación.

Pruebas que deben demostrar el resultado:

- Commit correcto + push fallido + retry no añade otro commit.
- Cambio de repo durante el flujo no publica ni escribe en el nuevo repo.

Cierre del ticket: No doble commit; fallo posterior conserva lo ya hecho y reintenta solo el paso necesario.

### T26 Unificar conflictos, continue/abort y límites de predicción

Estado del registro: en_curso. Specs: GM-017. Depende de: T15, T24.

Modelo para el borrador: local-coder; revisión e integración independientes.

Archivos existentes que revisar:

- [GitMac/Features/MergeConflict/ConflictResolverView.swift](../../../../GitMac/Features/MergeConflict/ConflictResolverView.swift) — SHA256 5d1fe791dce5641e231131311c51a0a9943ac21c4035e90efc7dba78102a47ce.
- [GitMac/Features/ConflictPrevention/ConflictPreventionService.swift](../../../../GitMac/Features/ConflictPrevention/ConflictPreventionService.swift) — SHA256 df10494bf1ab259d9cc2fc11843d079293458055eb2a0b4f2d827bec50196855.
- [scripts/test-conflict-staging.mjs](../../../../scripts/test-conflict-staging.mjs) — SHA256 256bb3692b12435f771a20a02fb427fa992924a96b699361f419aa5f7cccb6ff.

Pasos y entregables:

- [ ] T26.01 Conservar el fix de staging fallido, pathspec con -- y preservación LF/CRLF; revisar el diff antes de integrar.
- [ ] T26.02 Unificar el staging de la resolución y retirar doble git add solo con prueba del callback real.
- [ ] T26.03 No permitir guardar contenido vacío tras fallo de carga/binario; retry de staging no marca éxito prematuro.
- [ ] T26.04 Resolver metadata mediante Git y detectar merge/rebase/cherry-pick/revert para continue/abort apropiados.
- [ ] T26.05 Capturar repo/archivo/generación y detectar cambios externos antes de sobrescribir.
- [ ] T26.06 Completar texto, add/delete, rename, binario, worktree vinculado y reinicio; la IA solo propone una resolución revisable.

Pruebas que deben demostrar el resultado:

- Nueve checks actuales y control con código anterior; ampliar a F08 completo.
- Un fallo de git add o almacenamiento conserva conflicto visible y trabajo del usuario.

Cierre del ticket: F08 y reinicio aprobados; base/current/incoming precisos; predicción no se presenta como garantía.

### T27 Cerrar auth Git, red, progreso y autofetch controlado

Estado del registro: pendiente. Specs: GM-018. Depende de: T10, T12, T13.

Modelo para el borrador: local-coder; revisión e integración independientes.

Archivos existentes que revisar:

- [GitMac/Core/Git/GitEngine.swift](../../../../GitMac/Core/Git/GitEngine.swift) — SHA256 1927aca9ca14e94c6600a399bfcd41f5116e721b017ccfde12eb1727c716e91b.
- [GitMac/Core/Services/AutoFetchService.swift](../../../../GitMac/Core/Services/AutoFetchService.swift) — SHA256 293571be3f776b81e23d13f22b98ed94d5ab391541c46ae702430a8cef01fbe2.
- [GitMac/Core/Services/GitHubService.swift](../../../../GitMac/Core/Services/GitHubService.swift) — SHA256 750570de580c76639b3743b0ad96a4d61ade6da50b9ee81495938fdbced149d3.

Pasos y entregables:

- [ ] T27.01 Cerrar auth Git por host/cuenta para HTTPS y SSH sin persistir secretos en logs.
- [ ] T27.02 Distinguir offline, token expirado, permisos, host key, rechazo remoto y cancelación.
- [ ] T27.03 Mostrar progreso y upstream reales; autofetch opt-in con pausa/backoff acotado.
- [ ] T27.04 No reintentar escrituras a ciegas ni convertir force-with-lease en opción implícita.
- [ ] T27.05 Separar latencia de proveedor del coste local al perfilar.

Pruebas que deben demostrar el resultado:

- F11 con remoto local/servidor fixture, rechazos y cancelaciones.
- Proceso y credential prompt terminan limpiamente sin perder resultados parciales.

Cierre del ticket: F11 verifica offline/rechazo/token/SSH/cancelación; backoff acotado y sin force automático.

### T28 Completar branches, tags, stash, reset y cherry-pick

Estado del registro: pendiente. Specs: GM-019. Depende de: T14, T26, T27.

Modelo para el borrador: local-coder; revisión e integración independientes.

Archivos existentes que revisar:

- [GitMac/Core/Git/GitEngine.swift](../../../../GitMac/Core/Git/GitEngine.swift) — SHA256 1927aca9ca14e94c6600a399bfcd41f5116e721b017ccfde12eb1727c716e91b.
- [GitMac/App/Panels/Right/StashDetailPanel.swift](../../../../GitMac/App/Panels/Right/StashDetailPanel.swift) — SHA256 edda4517f6b3a7bcef244156907e4e00943e58701372a1829a01043d3bae9143.
- [GitMac/UI/Components/Rows/BranchRow.swift](../../../../GitMac/UI/Components/Rows/BranchRow.swift) — SHA256 c5adb885046057c9209a4c0d89e8012ba1da6b98e8728b50673042f8cfad79cc.

Pasos y entregables:

- [ ] T28.01 Verificar crear/renombrar/borrar branches y tags, stash apply/pop/drop, reset y cherry-pick.
- [ ] T28.02 Revalidar ref/SHA y estado sucio tras preview y antes de escribir.
- [ ] T28.03 Usar identidad estable de stash, no índice que cambie tras refrescar.
- [ ] T28.04 Integrar journal/undo y recuperación de secuencias parcialmente completadas.
- [ ] T28.05 Menus contextuales y drag & drop reutilizan estas mismas acciones comprobadas.

Pruebas que deben demostrar el resultado:

- Operaciones con refs cambiadas, locks, WIP y conflictos.
- Stash→archivo→visor mantiene estabilidad nativa y no pierde contenido.

Cierre del ticket: Preview/ref revalidada; stash por identidad estable; operaciones parciales recuperables.

### T29 Completar worktrees, submodules y LFS

Estado del registro: en_curso. Specs: GM-020. Depende de: T11, T20, T27, T28.

Modelo para el borrador: local-coder; revisión e integración independientes.

Archivos existentes que revisar:

- [GitMac/Core/Services/WorktreeManager.swift](../../../../GitMac/Core/Services/WorktreeManager.swift) — SHA256 3e64cc139ceee87cd4345ec772000a838df577e549b42f9aa72405661cd2c835.
- [GitMac/Features/Worktrees/WorktreeListView.swift](../../../../GitMac/Features/Worktrees/WorktreeListView.swift) — SHA256 6b56c534a009e845fca1ac2f885b7cb4105bd299bf0306abc59fe113e92683e8.
- [GitMac/Features/Submodules/SubmoduleManager.swift](../../../../GitMac/Features/Submodules/SubmoduleManager.swift) — SHA256 2c70b5ce200c8a1c92a47e26d8a29d91cb9c5d46ed7c4074fc2ff989205e9836.
- [GitMac/Features/LFS/LFSManager.swift](../../../../GitMac/Features/LFS/LFSManager.swift) — SHA256 7a38869aeddab5079d5705e77b1dd51f74c63ed91c24a4ad5b631207ba4a4719.

Pasos y entregables:

- [ ] T29.01 Hacer crear/abrir/cambiar/proteger/retirar worktree comprensible y con explicación contextual.
- [ ] T29.02 Separar WIP/index/HEAD/config de common storage; soportar locks, dirty y branch ocupada.
- [ ] T29.03 Revalidar destino y actividad antes de retirar, sin force por defecto.
- [ ] T29.04 Completar submodules y LFS con auth/cancelación/progreso y capacidades ausentes visibles.
- [ ] T29.05 No confundir eliminación de un worktree con borrado del repositorio común.

Pruebas que deben demostrar el resultado:

- F09 con Git real, nombres adversarios y worktrees vinculados.
- A/B muestran estado propio y una eliminación rechazada no borra datos.

Cierre del ticket: F09/locks/dirty/auth; WIP por worktree correcto, capacidades ausentes visibles y eliminación segura.

### T30 Verificar Gitflow, hooks y firmas GPG/SSH

Estado del registro: en_curso. Specs: GM-023. Depende de: T13, T27, T28.

Modelo para el borrador: local-coder; revisión e integración independientes.

Archivos existentes que revisar:

- [GitMac/Core/Services/WorkflowEngine.swift](../../../../GitMac/Core/Services/WorkflowEngine.swift) — SHA256 6901184bbf2c1c90ff88bc6d97baef4929e4510f6ca29c5eb320c9aca10aaca8.
- [GitMac/Features/Settings/Tabs/WorkflowSettingsTab.swift](../../../../GitMac/Features/Settings/Tabs/WorkflowSettingsTab.swift) — SHA256 01cf77d99a72aee079eca0e4d871d98a9d5cb9f7d24a39fba688183c6899e7b4.
- [GitMac/Features/GitFlow/GitFlowManager.swift](../../../../GitMac/Features/GitFlow/GitFlowManager.swift) — SHA256 1defcea5e6d4477aa022c938e557c410a424beaeb8a3bc231a45b944a64ce078.
- [GitMac/Core/Services/GitHooksService.swift](../../../../GitMac/Core/Services/GitHooksService.swift) — SHA256 01c9c1041f9528e90dada21fd23f152a1e193bbd81b6e9f73a7371b8c43c0d29.

Pasos y entregables:

- [ ] T30.01 Añadir workflows por repo con herencia global explícita, duplicar/reset/import/export sin secretos.
- [ ] T30.02 Capturar repo/cuenta de origen al editar y ejecutar; no usar el activo al terminar una sheet.
- [ ] T30.03 Comprobar cada exit code de fetch/checkout/stage/push y detener la secuencia tras fallo.
- [ ] T30.04 Consumir confirmaciones una vez, manejar cancelación y evitar dos ejecuciones incompatibles.
- [ ] T30.05 No abortar rebase automáticamente ni ocultar fallos de hook/firma; mostrar recuperación.
- [ ] T30.06 Validar Gitflow feature/release/hotfix y firmas con claves sintéticas y contrato de comandos común.

Pruebas que deben demostrar el resultado:

- A/B con workflows diferentes y herencia/reset sin cruce.
- Paso fallido no ejecuta pasos siguientes ni emite completed; cancelación libera la continuación.

Cierre del ticket: Feature/release/hotfix reales; hook fallido visible; claves sintéticas, sin bypass ni cambio global implícito.

### T31 Entregar vertical PR GitHub y matriz de capacidades multihost

Estado del registro: pendiente. Specs: GM-021. Depende de: T13, T25, T27, T28.

Modelo para el borrador: local-coder; revisión e integración independientes.

Archivos existentes que revisar:

- [GitMac/Core/Services/GitHubService.swift](../../../../GitMac/Core/Services/GitHubService.swift) — SHA256 750570de580c76639b3743b0ad96a4d61ade6da50b9ee81495938fdbced149d3.
- [GitMac/Features/PullRequests/PRListView.swift](../../../../GitMac/Features/PullRequests/PRListView.swift) — SHA256 f6efea9211021039b4ba1ed9b24b542171fda7f5629b2c7f76a99e76576c935d.

Pasos y entregables:

- [ ] T31.01 Completar vertical GitHub repo→branch→push→PR con base/head dinámicos y permisos reales.
- [ ] T31.02 Respetar branch protection, reviews y checks; no ofrecer merge cuando el host lo prohíbe.
- [ ] T31.03 Añadir paginación, expiración/auth, conflictos HTTP y cancelación de respuestas obsoletas.
- [ ] T31.04 Diferenciar capacidades por host y no simular equivalencia de GitHub/GitLab/Bitbucket.
- [ ] T31.05 Toda escritura de PR/review/merge requiere intención explícita y cuenta/repo visibles.

Pruebas que deben demostrar el resultado:

- Contrato de API con fixtures oficiales/versionados y errores de permisos.
- Sandbox autorizado para prueba final; ninguna escritura en cuentas del usuario por defecto.

Cierre del ticket: Base/head dinámicos, paginación/permisos/checks; contratos por host y escritura solo con intención explícita.

### T32 Completar workspaces, Launchpad e issue→branch→PR

Estado del registro: pendiente. Specs: GM-022. Depende de: T17, T31.

Modelo para el borrador: local-coder; revisión e integración independientes.

Archivos existentes que revisar:

- [GitMac/Core/Services/WorkspaceSettings.swift](../../../../GitMac/Core/Services/WorkspaceSettings.swift) — SHA256 8fd405dcd5df81af754b99619df87d03d545ee9e797709f8a280ee6c955e96a7.
- [GitMac/Features/Settings/Tabs/WorkspaceSettingsTab.swift](../../../../GitMac/Features/Settings/Tabs/WorkspaceSettingsTab.swift) — SHA256 828fd0d8d2c66903eb89d603e4fee23ac56b43a26e2ecd511fe000a6925006d2.
- [GitMac/Core/PluginSystem/IntegrationPlugin.swift](../../../../GitMac/Core/PluginSystem/IntegrationPlugin.swift) — SHA256 0978883503f7dfab522306d889325b66952d87d6418cf532a6336f89f5df6147.
- [GitMac/Core/PluginSystem/IntegrationViewModel.swift](../../../../GitMac/Core/PluginSystem/IntegrationViewModel.swift) — SHA256 5369e307af74ceeb58859cc7503f5ea4ecc23bdc7c955c4ce82d033100d8f347.
- [GitMac/Core/PluginSystem/PluginRegistry.swift](../../../../GitMac/Core/PluginSystem/PluginRegistry.swift) — SHA256 2ec877cb499c4a10e0ea59b23505efb482c0575d6e893d7e1ac66740e3ca0938.
- [GitMac/Features/Launchpad/LaunchpadView.swift](../../../../GitMac/Features/Launchpad/LaunchpadView.swift) — SHA256 91cda866d16c71ae5f869f3057e4af2834f1c63122874a95691256b0b31f758b.

Pasos y entregables:

- [ ] T32.01 Separar configuración de app, repo, worktree y cuenta; aplicar realmente identidad, firma y remoto configurados, mostrando herencia y origen.
- [ ] T32.02 Definir contrato común de tickets con capacidades de auth/listar/leer/escribir separadas; reutilizar el sistema de plugins existente.
- [ ] T32.03 Auditar y completar Linear con GraphQL, paginación y errors aunque HTTP sea 200.
- [ ] T32.04 Auditar y completar Jira con autenticación y permisos documentados para el canal de distribución.
- [ ] T32.05 Auditar y completar Microsoft Planner con cuentas/permisos soportados y concurrencia de actualizaciones.
- [ ] T32.06 Implementar Asana y Trello como conectores reales, no enums disponibles sin backend.
- [ ] T32.07 Auditar Notion contra la versión API elegida y su modelo de datos/permisos actual.
- [ ] T32.08 Implementar gestor custom mediante contrato HTTPS, mapping explícito, allowlist/redirecciones, paginación y lectura por defecto; nunca shell arbitraria.
- [ ] T32.09 Persistir asociación repo→cuenta→proyecto/board/plan/data source y restaurar caché offline con edad/error.
- [ ] T32.10 Completar ticket→branch→commit→PR con IDs trazables, sin duplicar tickets ni escribir sin confirmación.

Pruebas que deben demostrar el resultado:

- Por cada uno de los siete proveedores: auth denegada/expirada, 429, paginación, cancelación, campo ausente y cambio A/B.
- Pruebas contractuales offline y, después, sandbox autorizado por proveedor; no declarar E2E por un mock verde.

Cierre del ticket: Cuenta/repo correctos, snapshot offline con edad y error parcial; plugins solo con endpoints comprobados.

### T33 Consolidar terminal y ciclo de vida de sesiones/procesos

Estado del registro: pendiente. Specs: GM-024. Depende de: T10, T12, T16.

Modelo para el borrador: local-coder; revisión e integración independientes.

Archivos existentes que revisar:

- [GitMac/Features/Terminal/TerminalView.swift](../../../../GitMac/Features/Terminal/TerminalView.swift) — SHA256 262f2783309e9a75f8bcbadefc2a0a04108868019d699db393be5f7cb2ec0333.
- [GitMac/Features/Terminal/GhosttyTerminalView.swift](../../../../GitMac/Features/Terminal/GhosttyTerminalView.swift) — SHA256 93b2db617d457291323bb9d774cbd2a6f3768ce5f59c96a4c6cd9f8907e6d4ee.
- [GitMac/Features/Terminal/Enhanced/GhosttyEnhancedTerminalView.swift](../../../../GitMac/Features/Terminal/Enhanced/GhosttyEnhancedTerminalView.swift) — SHA256 76d73d7385dd4798640404dc6b02134ca33eda882c9e9f45d0937c1856aad5f5.

Pasos y entregables:

- [ ] T33.01 Elegir y consolidar backend terminal soportado conservando alternativas justificadas.
- [ ] T33.02 Verificar cwd por repo, IME, clipboard, foco, resize Retina y sesiones simultáneas.
- [ ] T33.03 Acotar historial/render/output y liberar procesos/sesiones propios al cerrar.
- [ ] T33.04 Refrescar estado Git después de CLI sin scans globales continuos.
- [ ] T33.05 Ayuda/IA no ejecuta sugerencias ni pega secretos automáticamente.

Pruebas que deben demostrar el resultado:

- Terminal A no cambia cwd ni sesión B; close no deja procesos propios.
- Output grande, Unicode/IME, cancelación y resize no bloquean la UI.

Cierre del ticket: Backend soportado, IME/resize/clipboard/foco; refresh tras CLI y recursos propios liberados.

### T34 Optimizar IA local opt-in con límites de contexto y memoria

Estado del registro: en_curso. Specs: GM-025. Depende de: T10, T13, T23.

Modelo para el borrador: local-coder; revisión e integración independientes.

Archivos existentes que revisar:

- [GitMac/Core/Services/AIService.swift](../../../../GitMac/Core/Services/AIService.swift) — SHA256 d6854b98650ab32ee5e86502b7dd1931c48a67f33c1bef7876ef023414dfcb9b.
- [GitMac/Core/Services/AI/MLXProvider.swift](../../../../GitMac/Core/Services/AI/MLXProvider.swift) — SHA256 3ec15a380ea1022fe294d5cf8920bb365e56aadcf7911e9fa5ef9c9750ae8a0f.
- [GitMac/Features/Settings/Tabs/AISettingsTab.swift](../../../../GitMac/Features/Settings/Tabs/AISettingsTab.swift) — SHA256 b80ea5271d92d91cc0df5055b2420fae3bbeb95617f2dc6e2d47aa1926bef6da.
- [scripts/benchmark-local-ai.mjs](../../../../scripts/benchmark-local-ai.mjs) — SHA256 3d82f0873ed65c355f1b781b02c66cfa713fa555c217d155a7559b3229d4530f.

Pasos y entregables:

- [ ] T34.01 Distinguir modelos de desarrollo que generan parches de los proveedores IA dentro de GitMac.
- [ ] T34.02 Implementar proveedor Apple Foundation Models con canImport/availability sin elevar macOS mínimo; el preflight actual da available, no valida generación.
- [ ] T34.03 Crear LanguageModelSession bajo demanda, sin prewarm al abrir app/Ajustes; límites de contexto, exclusión mutua y cancelación.
- [ ] T34.04 Usar sugerencias tipadas/validadas, errores de guardrails/contexto/idioma y fallback explícito, nunca ejecución Git automática.
- [ ] T34.05 Conservar loopback/modelo exacto y unload para Ollama/MLX; cloud requiere configuración y consentimiento distintos.
- [ ] T34.06 Comparar calidad, frío/caliente, latencia y memoria real de Apple, MLX y Ollama con corpus representativo.
- [ ] T34.07 Mantener el gate de 150 MB abierto si falla; no culpar a modelos descargados ni esconder memoria del proceso auxiliar.

Pruebas que deben demostrar el resultado:

- Unavailable/deviceNotEligible/modelNotReady, cancelación, contexto excedido y salida malformada.
- Inferencia real opt-in con red/privacidad verificadas y footprint por proceso/backend.

Cierre del ticket: Red exterior bloqueada, aliases cloud rechazados, cancelación y recursos medidos; ninguna operación automática sobre Git.

### T35 Completar compartir patches, expiración y colaboración

Estado del registro: pendiente. Specs: GM-026. Depende de: T08, T13, T23, T31.

Modelo para el borrador: local-coder; revisión e integración independientes.

Archivos existentes que revisar:

- [GitMac/Features/CloudPatches/CloudPatchService.swift](../../../../GitMac/Features/CloudPatches/CloudPatchService.swift) — SHA256 4922c2b54b1be63e4038537029ca614aa6095a3727a52f99cb408dbe42f9a847.
- [GitMac/Features/CodeReview/CodeReviewService.swift](../../../../GitMac/Features/CodeReview/CodeReviewService.swift) — SHA256 ef81a41a5c172de2283bf1772ce96a8bf4907204e2ea25b47d7490960fe83b99.

Pasos y entregables:

- [ ] T35.01 Completar round-trip de patch y metadata/base sin pérdida ni shell interpolada.
- [ ] T35.02 Distinguir compartir archivo de publicar contenido remoto y pedir intención acorde.
- [ ] T35.03 Definir semántica real de acceso, expiración y revocación; no prometer privacidad que el backend no da.
- [ ] T35.04 Validar tamaño, origen, base obsoleta y aplicación parcial con recuperación.
- [ ] T35.05 No incluir tokens o datos de otros repos en exports, logs o solicitudes a modelos.

Pruebas que deben demostrar el resultado:

- Patch adversario, base cambiada, metadata incompleta y revocación real.
- Permiso denegado o red caída no se presenta como enlace publicado.

Cierre del ticket: Metadata round-trip, semántica real de acceso/revocación y apply seguro; no prometer privacidad/caducidad inexistentes.

### T36 Perfilar todos los flujos en Release y resolver cuellos medidos

Estado del registro: en_curso. Specs: GM-027. Depende de: T19, T21, T22, T24, T26, T27, T29, T30, T32, T33, T34, T35.

Modelo para el borrador: local-coder; revisión e integración independientes.

Archivos existentes que revisar:

- [scripts/profile-release-memory.mjs](../../../../scripts/profile-release-memory.mjs) — SHA256 ece08e46904f2cbcc6d47a5d21ac9279d2e56154a94c577643d3fc1582cc24fd.
- [scripts/check-memory-budget.mjs](../../../../scripts/check-memory-budget.mjs) — SHA256 8809f1f790c7cc414f2842605dd5923444954fa9d9f748f9c7877ac0af9a5955.
- [GitMac/Core/Utils/MemoryPressureHandler.swift](../../../../GitMac/Core/Utils/MemoryPressureHandler.swift) — SHA256 627d268dd87b9124a4e759e8c6d4d51bc9815f7a6ce0418942f7aed0c81f8ff6.

Pasos y entregables:

- [ ] T36.01 Construir Release con log que corresponda al ejecutable y registrar hash.
- [ ] T36.02 Exigir repo, ramas, grafo y minimapa cargados; añadir escenarios de Ajustes, conflictos, terminal, worktrees y tickets.
- [ ] T36.03 Medir 1k/10k/100k, frío/caliente, p50/p95, hitches, CPU/energía y physical footprint/pico.
- [ ] T36.04 Separar categorías gráficas, heap, caché y backend IA antes de atribuir causa; la baseline actual 1k tiene pico 252593232 bytes.
- [ ] T36.05 Atacar un cuello medido por cambio y comparar misma carga/calidad; no aceptar porcentajes de ruido.
- [ ] T36.06 Cumplir 150000000 bytes y pico en la matriz acordada o mantener el gate fallido, sin excepciones silenciosas.

Pruebas que deben demostrar el resultado:

- Al menos 30 observaciones comparables para exploración de p95 y ampliación si el ruido lo exige.
- Cambios de performance repiten corrección, seguridad y controles negativos aplicables.

Cierre del ticket: Trazas antes/después, p50/p95 y memoria por función; no optimización aceptada sin corrección preservada.

### T37 Validar concurrencia, resistencia y entradas adversarias

Estado del registro: pendiente. Specs: GM-002, GM-004, GM-005, GM-008, GM-026, GM-027. Depende de: T36.

Modelo para el borrador: local-coder; revisión e integración independientes.

Archivos existentes que revisar:

- [scripts/test-production-suites.mjs](../../../../scripts/test-production-suites.mjs) — SHA256 e8900e871245ced2022621559dfb8314f9db25978d6b49bbefd64e3ed0027626.
- [scripts/test-session-isolation.mjs](../../../../scripts/test-session-isolation.mjs) — SHA256 b9a23db9f874b2d0fd421effc24860a9a0331da986d50cebfc8121cba87cf688.
- [Tests/GitMacTests/RepositoryScopeWatcherTests.swift](../../../../Tests/GitMacTests/RepositoryScopeWatcherTests.swift) — SHA256 261e40db37d2d0535f595411f0ece7161fef1e9b898a64d16aa894b82423c022.

Pasos y entregables:

- [ ] T37.01 Sesión de resistencia de 60 minutos con dos repos y worktrees, churn y cancelaciones.
- [ ] T37.02 Registrar cada minuto footprint, CPU, procesos, FD/watchers, tareas y colas.
- [ ] T37.03 Inyectar red/disk/lock/Keychain/permisos y snapshots obsoletas sin mutar datos reales.
- [ ] T37.04 Fuzz de parsers, payloads drag & drop, tickets custom y patches; sanitizers aplicables.
- [ ] T37.05 Comparar refs/index/blobs y journal antes/después, no solo ausencia de crash.

Pruebas que deben demostrar el resultado:

- 300 ciclos de selección/refresh y 30 cierres/aperturas como mínimo inicial.
- Ningún proceso propio huérfano, estado cruzado, pérdida de salida o crecimiento sin límite.

Cierre del ticket: Sesiones largas, cancelación/churn, fuzz de parsers, fallos de disco/red y sanitizers aplicables; ningún fallo crítico sin resolver.

### T38 Endurecer dependencias, CI, artefactos y procedencia

Estado del registro: en_curso. Specs: GM-001, GM-028. Depende de: T04, T07.

Modelo para el borrador: local-coder; revisión e integración independientes.

Archivos existentes que revisar:

- [.github/workflows/swift.yml](../../../../.github/workflows/swift.yml) — SHA256 ea73334d686bdc85894ac9b6129d7588e365229e5edfe3143599cb3305f39bb5.
- [.github/workflows/release.yml](../../../../.github/workflows/release.yml) — SHA256 c01241ebef5e30c4732d63e6c77455e1efeb829ad93a3bae4d3d027afee37234.
- [project.yml](../../../../project.yml) — SHA256 228dc69190fbb07551fef565625411cebb57d5bbe9f07d70466f56acd6578085.
- [Package.swift](../../../../Package.swift) — SHA256 7fc6ecdcfd745eefcb55b19f89a90ffac59ccf954efe8ff7601df1d2183bfc23.

Pasos y entregables:

- [ ] T38.01 Verificar versiones/pins upstream, licencias e inventario de dependencias.
- [ ] T38.02 Auditar vulnerabilidades y separar código no confiable de jobs con secretos.
- [ ] T38.03 Generar checksums y procedencia vinculados a source/build/artefacto exactos.
- [ ] T38.04 Asegurar que el candidato contiene los archivos revisados y que la regeneración no incorpora basura local.
- [ ] T38.05 No declarar nivel SLSA o compliance sin cumplir sus requisitos verificables.

Pruebas que deben demostrar el resultado:

- Artefacto alterado o pin no permitido se rechaza.
- Build reproducible/controlado y auditoría de permisos por job.

Cierre del ticket: Versiones y SHAs upstream verificados, inventario/licencias/vulnerabilidades, permisos mínimos, checksums/provenance verificable.

### T39 Probar app distribuida, instalación, upgrade y recuperación

Estado del registro: en_curso. Specs: GM-028. Depende de: T37, T38.

Modelo para el borrador: review; revisión e integración independientes.

Archivos existentes que revisar:

- [scripts/prepare-distribution.mjs](../../../../scripts/prepare-distribution.mjs) — SHA256 7665bcc3eff37921b2e177d0a34e54ca22b13b9980ffffe3a36d75f2800f0167.
- [scripts/finish-distribution.mjs](../../../../scripts/finish-distribution.mjs) — SHA256 1009eab714a18a115a5b8db1973b7f71be7f27ae7a766bfc5096a63a6635dbc9.

Pasos y entregables:

- [ ] T39.01 Preparar candidato separado con Developer ID, hardened runtime, notarización y stapling por el canal elegido.
- [ ] T39.02 Verificar Gatekeeper y arranque en Mac limpio y matriz de OS/arquitectura acordada.
- [ ] T39.03 Probar instalación, actualización, migración y rollback preservando repositorios y preferencias.
- [ ] T39.04 La firma de un candidato anterior no aprueba un nuevo binario ni su funcionalidad.
- [ ] T39.05 No reemplazar app instalada ni publicar sin petición explícita.

Pruebas que deben demostrar el resultado:

- Upgrade/rollback con datos sintéticos y permisos reales del canal.
- Hash instalado coincide con artefacto firmado y auditado.

Cierre del ticket: Mac limpio y matriz de OS/arquitectura; firma/notarización por canal, migración/rollback y datos preservados.

### T40 Auditoría final por escenario y decisión de candidato

Estado del registro: pendiente. Specs: GM-028. Depende de: T39.

Modelo para el borrador: review; revisión e integración independientes.

Archivos existentes que revisar:

- [docs/roadmap/2026-10-20/implementation/task-state.json](../../../../docs/roadmap/2026-10-20/implementation/task-state.json) — SHA256 e15393875198c100a4d87c4ff9aa023bbfadb1c4b800cab1733181bcd2326b9c.
- [docs/roadmap/2026-10-20/tools/audit-task-closure.mjs](../../../../docs/roadmap/2026-10-20/tools/audit-task-closure.mjs) — SHA256 1559dadc2d56e1370d5f8097d58104c58f917ab2ebcfd20da04164d8f01cd7d4.
- [GitMac/Core/StoreKit/StoreManager.swift](../../../../GitMac/Core/StoreKit/StoreManager.swift) — SHA256 0b1daf7758dccd7d58eaa4d66f6b1b85d2047995b8a4abf70ecbf27e70e35056.
- [GitMac/Core/Services/SubscriptionService.swift](../../../../GitMac/Core/Services/SubscriptionService.swift) — SHA256 e4388cfd03d032aea79ca17875bee6b3754b6f2efe69069daf6697a199c0a4dd.

Pasos y entregables:

- [ ] T40.01 Revisar cada aceptación T01–T40 y cada spec GM-001–GM-028 contra evidencia actual.
- [ ] T40.02 Conciliar catálogo premium declarado y entitlements duplicados; separar funciones existentes, propuestas y no verificadas.
- [ ] T40.03 Proponer Free/Pro/Teams sin retirar seguridad, accesibilidad o Git básico ni cambiar precios/cobro sin decisión comercial.
- [ ] T40.04 Exigir cero P0, decisiones explícitas para P1, presupuesto aprobado y UX/AX/distribución verificadas.
- [ ] T40.05 Entregar auditoría final por archivo/línea, mapa vigente, riesgos residuales y decisión de candidato; publicar es una acción posterior.

Pruebas que deben demostrar el resultado:

- audit-task-closure --require-all solo pasa cuando todas las aceptaciones están verificadas.
- Compra/restauración/expiración se prueban en sandbox autorizado; una etiqueta premium no prueba enforcement.

Cierre del ticket: Matriz de 28 specs completa con evidencia; cero P0, decisiones P1 explícitas; candidato separado de publicación.

## Estado al preparar el plan

- ledger: 5 verificadas, 19 en curso, 16 pendientes; no equivale a 40 implementadas.
- currentNewChanges: Pulido de Settings y fixes de conflictos realizados antes de pedir plan primero; Debug firmado compila. La revisión integral y Release de este lote siguen pendientes.
- conflicts: conflict-safety-after-final.log: nueve checks pasan; control anterior en conflict-safety-negative.log falla como se esperaba.
- nativeResize: La ventana real informó resizable=true, mínimo 660x400 y máximo no acotado. La automatización por borde no cambió frame; acceso AX directo fue denegado con -25211. No está aprobada la validación de resize en producto.
- memory: windows-memory-baseline-1000.log: physical máximo 251577424, pico 252593232 bytes; presupuesto fallido.
- appleAI: apple-foundation-models-preflight.log: available; sin inferencia ni prewarm.
- remainingRequestScope: Repos/config/workflows, siete proveedores, menús/shortcuts, drag & drop, Apple IA y catálogo premium están incorporados al trabajo pendiente; no se declaran implementados por este plan.

## Fuentes oficiales

- [Configuración local y por worktree](https://git-scm.com/docs/git-config).
- [Identidad y configuración de worktrees](https://git-scm.com/docs/git-worktree.html).
- [Conflictos en GitHub](https://docs.github.com/en/pull-requests/reference/merge-conflicts).
- [Resolver conflictos desde Git](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/resolving-a-merge-conflict-using-the-command-line).
- [Ventanas SwiftUI](https://developer.apple.com/documentation/swiftui/windowresizability).
- [Drag & drop tipado](https://developer.apple.com/documentation/swiftui/drag-and-drop).
- [Foundation Models octubre de 2026](https://developer.apple.com/documentation/updates/foundationmodels).
- [Disponibilidad del modelo Apple](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel).
- [Linear GraphQL](https://linear.app/developers/graphql).
- [Autenticación Jira](https://developer.atlassian.com/cloud/jira/platform/security-for-other-integrations/).
- [Microsoft Planner](https://learn.microsoft.com/en-us/graph/planner-concept-overview).
- [Asana OAuth](https://developers.asana.com/docs/oauth).
- [Trello API](https://developer.atlassian.com/cloud/trello/guides/rest-api/api-introduction/).
- [Notion autenticación](https://developers.notion.com/reference/authentication).

## Puerta para empezar la implementación

Ejecución autorizada por el usuario con modelos locales. Preparar el paquete de la siguiente subtarea y comprobar sus hashes. Cada lote termina con diff revisado, build, pruebas positivas/negativas y evidencia. El primer bloque no cierra T30; confirmaciones/concurrencia y configuración por repositorio permanecen pendientes.
