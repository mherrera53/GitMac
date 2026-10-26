# Cambios implementados y verificación

## Ejecución del 26 de octubre de 2026

[RAM: reducción comprobada](ram-2026-10-26.md): el build 6 firmado conserva todo el índice y pasa 1k (98829392), 10k (107398248) y 100k (148456600/148341888) bytes de pico en la ventana real. Los builds firmados 2/3 fallaron y no se entregaron. Modelos descargados y sin trabajo pesado concurrente. No es una garantía de todos los flujos ni inferencia.

Pasan 1.145 comparaciones del parser, 76 Swift Testing, 12 XCTest y 47 verificaciones. `ram-final-ui.xcresult` pasa tres recorridos: extremos de minimapa, visor de stash y comando terminal. Capturas inspeccionadas y hashes registrados. El control de carriles reproduce 124 fallos; las revisiones locales no autoaprueban cambios. Las referencias de controles históricos se fijan al commit original para seguir siendo válidas después del commit.

El usuario autorizó posteriormente commit y Release, y confirmó GitHub y app del Mac para 4.1.0: [gates de entrega](gates/release-4.1.0.md). Se entrega una versión acotada; el registro mantiene cinco tareas verificadas, veintiuna en curso y catorce pendientes, con los 206 pasos conservados. El candidato público exige Developer ID/notarización propios y no hereda los del checkpoint anterior.

## Ejecución del 25 de octubre de 2026

La ejecución está autorizada y en curso sobre las 40 tareas del [plan específico](PLAN-DETALLADO-2026-10-25.md). Se conserva la política híbrida elegida por el usuario; este bloque utilizó únicamente modelos locales. El [informe nuevo de temas, controles y confirmaciones](theme-audit-2026-10-25.md) enlaza código, capturas, controles negativos y límites de cobertura.

Se corrigieron los colores custom realmente dibujados, persistencia/reset/JSON y contraste/geometría de controles compartidos. La matriz ampliada `conflict-theme-final-ui.xcresult` pasa siete pruebas y registra 126 capturas: nueve presets por catorce estados. El caption del análisis fallaba contraste en los nueve; `conflict-caption-primary-after.log` pasa nueve tras la corrección local. Se inspeccionaron contactos y originales, incluidos claro/oscuro corregidos. No equivale a todas las interfaces/estados. Las confirmaciones del motor tienen exclusión, cancelación y UUID por decisión: siete escenarios pasan; el control original falla cinco, con dos SIGTRAP. La UI de ejecución de workflows sigue pendiente.

El render nativo redujo el pico del fixture 1k frente a Canvas en el mismo Release (76,6/76,4 MB frente a 367,8/368,0 MB); el fixture 100k aún falló con 168,0 MB en `native-graph-memory-comparison.json`. El experimento de tres pasadas del minimapa alcanzó 184878232 bytes y se retiró; su equivalencia no demuestra ahorro. Las mediciones del nuevo Release se registran con hash/log propios, sin heredar aprobación. El preflight de Foundation Models devuelve available, sin inferencia. Configuración/workflows por repo, conectores, atajos/context menus, drag & drop e IA Apple conservan trabajo pendiente.

`terminal-wire-ui.xcresult` pasa el comando real con input literal, bytes, directorio de trabajo e input vacío tras envío. `terminal-runtime-audit.md` registra los ocho checks del writer, 35 contratos y controles negativos. Se corrigió un retorno prematuro introducido durante esta ejecución: el control que lo repone reproduce cinco fallos. La revisión local no lo detectó; no es aprobación del modelo ni de todos los comandos. El resolver tiene 43 checks del núcleo, flujo UI de merge de dos padres y conservación de nota local; binarios/renames y concurrencia integral siguen pendientes.

La validación de redimensionado del producto permanece sin aprobar: el usuario eligió habilitar Accesibilidad después. No se modificó TCC ni se cuentan skips como aprobación. El mapa y la auditoría nuevos se consultan en sus JSON con fecha/hash; los contadores y candidatos del checkpoint siguiente corresponden a verificaciones históricas. No se instaló ni publicó una app nueva.

Estado actual: **5 tareas verificadas, 21 en curso y 14 pendientes** de las 40 del [registro de tareas](../execution-tasks.csv), con 206 pasos conservados. No es un roadmap terminado ni un producto completamente optimizado. `/Applications/GitMac.app` permanece intacta y tiene backup verificado en `installed-app-backup.json`; su reemplazo autorizado depende de `gates/installed-app-replacement.md`. No se hicieron commits ni publicaciones; los repositorios remotos del usuario no se modificaron. La notarización histórica corresponde a candidatos anteriores. Los cambios previos de `CLAUDE.md` se preservaron.

Verificación actual del bloque: `verification.json` pasa 45 checks sobre 115 archivos; mapa de 462 archivos, 15344 símbolos y 140467 relaciones sintácticas candidatas, con 25 límites del parser conservados. `terminal-wire-release.log` compila. El mismo Release, SHA256 `b55fa41e900be624ca62c880f2ab0c520a89954fa96fa534c2475b3f3bdbf5ad`, registra picos 1k **77022264**, 10k **88376424** y 100k **168543384** bytes: el tercero falla. `terminal-wire-memory-comparison.json` conserva señales de carga/dibujo, muestras y límites. Se midió sin modelos cargados, builds ni auditorías concurrentes. No se reemplazó la app instalada.

## Checkpoints anteriores: no sustituyen la evidencia fechada del bloque nuevo

- Auditoría final de este bloque: verification.json pasa, 72 archivos y 14 checks con códigos esperados, incluidos controles negativos de fixtures UI y modelo de amenazas. Mapa vigente: 443 archivos, 15.141 símbolos, 137.599 aristas candidatas y 25 límites del parser; visor regenerado después del audit. El gate --require-all falla correctamente: solo 5/40 tareas verificadas.

- Release de este bloque pasa en performance-branches-release.log, con bundle com.gitmac.performance separado de la app instalada. No se ha medido todavía este binario con el nuevo contrato branches-loaded; el presupuesto permanece sin aprobar.
- Las fuentes Swift de GitMacUITests dejan de estar excluidas por .gitignore. El checker de fixtures ahora comprueba git check-ignore; no se agregó ningún archivo al index. SnapshotHelper y GitMacComprehensiveScreenshots deben incluirse cuando el usuario versione el bloque.

- Tests UI firmados con Apple Development autorizado: ui-fixture-branches-build.log y ui-fixture-branches-tests.log pasan, dos pruebas sin fallos sobre com.gitmac.validation.GitMac. Capturas de ventana exportadas y leídas en ui-fixture-branches-captures/. Main aparece tanto en cabecera como en la lista lateral; Ajustes abre. No es aprobación visual integral ni VoiceOver.
- Regresión detectada visualmente y corregida: el fixture mostraba No Branch porque no configuraba BranchStateManager. session-isolation-branches.log pasa 13 comprobaciones; el profiler exige ahora branches-loaded. Las mediciones previas de memoria tenían repo/grafo/minimap pero no gestor lateral inicializado; mantienen ese alcance, no acreditan la nueva carga completa.
- Watchers: creación tardía, primer stash, borrado/recreación y rearme tras sustituciones atómicas; watcher-rearming-after.log pasa 71 Swift Testing + 11 XCTest, incluida ráfaga de 80 reemplazos. El control anterior conserva fallos de comportamiento.
- T07 verificada como documento: [modelo de amenazas](threat-model.md), 16 fronteras y checks positivo/negativo. No significa que sus controles pendientes estén implementados. La documentación conserva formato local del repositorio conforme a la skill write-page.

Las cifras del bloque siguiente corresponden al checkpoint anterior y no sustituyen el estado actual ni los reportes regenerados.

- Nuevo bloque: [ownership de sesión](session-ownership.md). AppState completo pasa 12 comprobaciones; volver solo al refresh anterior produce seis fallos de comportamiento. Se corrigen publicaciones tardías entre pestañas, cierres, historial y aperturas superadas. GitService conserva generación/ruta y watcher propios. T11/T12 siguen abiertos por ownership integral, locks y otros servicios.
- Watchers/identidad: device:inode para gitdir y common, worktrees vinculados y bare; el cancel handler no cierra descriptores reasignados. Pruebas nativas positivas y cuatro assertions negativas con código anterior. [Gate y límites](gates/repository-watchers.md).
- Minimapa: menos copias temporales de SHA/parents y eliminación de arrays intermedios al indexar. 80 DAGs adicionales contrastan identidad, carriles y edges. `minimap-allocations-tests.log`: **67 Swift Testing + 11 XCTest** pasan; Debug real pasa. [Gate de asignaciones](gates/minimap-allocations.md).
- Release aislado anterior a esa reducción: repositorio, grafo y minimapa cargados mediante señales verificables. 1k commits: máximo observado 252445800 bytes, pico 253281384; 100k: máximo observado 361530520, pico 470811800. **No cumplen 150 MB**. Son fixtures de historia lineal, no la matriz completa. La traza de Allocations no pudo adjuntarse; su log se conserva como fallo, no como evidencia válida.
- Repetición con la reducción: Release pasa; 1k pico **364725328 bytes**, 100k pico **374670488 bytes**; ambos fallan. `performance-memory-1000-optimized-run.log` y `performance-memory-100000-optimized-run.log` incluyen hash del ejecutable y señales de carga. La variación no acredita ganancia causal/p95. Audit actual: **65 archivos, 10 checks**, mapa de 441 archivos/15101 símbolos/137092 aristas candidatas, 25 límites del parser. El cierre integral ejecutable falla correctamente: 4/40 verificadas.
- Diagnóstico adicional por categorías: `performance-memory-detailed-run.log`, pico 258032696 bytes. En la muestra máxima, 169164800 bytes son memoria gráfica no mapeada; Malloc Small 47693824. Se localiza la categoría dominante, no aún el componente causante. El presupuesto sigue fallando y T36 queda abierto.
- Revisión local bajo demanda: `local-watcher-review.json`, qwen3-coder:30b, 7620 tokens de entrada/1174 de salida. Sus advertencias genéricas no demuestran defectos nuevos; las rutas bare/worktree y restart/deinit se probaron independientemente. `/api/ps` vacío después. No se tocó la app instalada; el candidato firmado siguiente es anterior a este bloque.

## Checkpoint anterior: IA y UX

- [IA bajo demanda, presupuesto de 150 MB y comparación de modelos](memory-ai-demand.md): precarga retirada, preflight de pesos locales, sin fallback fuzzy/cloud, límites y descarga tras uso. Debug/Release pasan; audit vigente de 58 archivos y siete checks, con 62 Swift Testing + 11 XCTest. El backend GPU nativo es una frontera de fixture en los tests headless, no una inferencia real aprobada.
- Presupuesto **no cumplido** en la app instalada PID 84387: physical footprint 242435464 bytes y peak 690128336. `memory-installed-budget-result.json` es false. El candidato nuevo no está medido; pasar tests del validador no significa cumplir 150 MB. `task-closure-audit.json` conserva los 40 criterios y allTasksVerified:false.
- Candidato técnico vigente `candidate-Yn60GL`: Apple Accepted `67ad2724-6299-4c4a-b21e-6e5514d7849d`, firma estricta, stapling y Gatekeeper pasan en distribution-ai-demand-final.log. La instalada permanece intacta; no hay aprobación visual ni de memoria del nuevo candidato.

- Bloque de UX: [pestañas, minimapa, worktrees y guía contextual](navigation-worktrees-help.md). Implementación y pruebas separadas de aprobación visual; 31 temas offline, navegación por SHA y worktrees sin forzar eliminación. No está todo terminado.
- Debug y Release del bloque contextual pasan: contextual-final-debug.log y contextual-release.log. Audit vigente: 49 archivos cambiados, seis checks con códigos esperados, 55 Swift Testing y 11 XCTest. Mapa actualizado: 432 archivos, 413 Swift, 14 974 símbolos y 135 021 aristas sintácticas/candidatas, con 25 límites del parser conservados. Revisión visual/teclado/VoiceOver de la nueva UX pendiente.

- T01: baseline, máquina, escenarios y unidades registrados en [baseline-reference.json](baseline-reference.json).
- T05: todas las suites actuales de Tests/GitMacTests enlazan producción; [stash-panel-tests.log](stash-panel-tests.log) registra 43 Swift Testing en siete suites y 11 XCTest sin fallos. La mutación temporal del modelo real rompe exactamente un XCTest; el control negativo del inspector detecta su mínimo nativo inestable.
- T09: status NUL unificado, XY/oldPath/numstat, unborn y rutas especiales probados con Git real. [Gate de status](gates/status.md).
- T10: 20 comprobaciones de procesos reales, captura acotada, UTF-8, cancelación, hijos y backpressure. [Gate de procesos](gates/processes.md).
- T13 parcial: backend Keychain y migración sintética verificados, sin tocar credenciales reales. Migración de datos existentes deshabilitada por defecto; faltan cuentas/entornos y UX de aprobación. [Política y límites](credential-migration.md).
- T24 parcial: caché coherente, parser y materialización de diff corregidos y probados; no aprobación del flujo completo de grandes archivos/binarios. [Gate del núcleo de diff](gates/diff-core.md).
- Debug y Release actuales pasan: [credentials-debug-final.log](credentials-debug-final.log), [release-credentials.log](release-credentials.log).
- Candidato `candidate-Yzctwc`: Developer ID, hardened runtime, Apple Accepted, stapling y Gatekeeper aprobados. Envío `89df8d53-1614-4496-92d1-84c9c12c4f2f`. [Evidencia](distribution-final.log), [gate técnico](gates/distribution.md). No se instaló ni publicó; T39 sigue abierto por Mac limpio, matriz de sistemas y upgrade/rollback.
- [Visor del worktree actual](mapping/graph.html), [cobertura/hash](mapping/coverage.json), [cambios por archivo y línea](changes.csv), [verificación ejecutable](verification.json). El visor histórico y graphify-out no se sustituyeron.
- Incidencia «no cabe en la pantalla»: [corrección y límites](responsive-fix.md). Paneles/toolbar/visibleFrame adaptativos y resizer nativo corregidos. El candidato se abrió con autorización y su marco exterior cabe en LG; el usuario comunicó un crash al seleccionar un stash, por lo que no hay aprobación funcional.
- XcodeGen: project.yml ahora conserva 394 fuentes, 11 recursos, paquetes y settings del producto, y añade un target de tests. check-project-generation.rb verifica regeneración determinista preservando el proyecto original. T03 sigue abierto por build/test del proyecto generado y reconciliación SPM; no se ha sobrescrito GitMac.xcodeproj.
- Candidato responsive anterior: `candidate-drgWMH`, Apple Accepted en envío `c913187e-e430-4feb-ade7-e963e9c6d8be`, pero SIGABRT confirmado en PID 52533. No usar notarización como aprobación funcional. [Crash de stash, corrección, pruebas y límites](stash-crash.md): tamaño del panel aislado y una sola carga estructurada; Debug pasa. No se reemplazó la app instalada ni se modificaron stashes del usuario.
- El primer intento de crash `candidate-nk5Qa2` también sufrió SIGABRT (PID 62887) al abrir el visor de archivos. Los tests del hijo no bastaron. Se extendió el aislamiento geométrico a las columnas completas de MainLayout; pendiente validación del nuevo candidato. Ambos candidatos fallidos quedan documentados, no aprobados por tener firma/notarización.
- Candidato de columnas completas: `candidate-lv8hVz`, Apple Accepted `5382d3a9-af10-4508-9354-bb011cd61b2b`, firma/stapling/Gatekeeper válidos; abierto como PID 69666 sin reemplazar la instalada. viewer-crash-debug.log y viewer-crash-release.log pasan. Gate crash-layout: 4/4 para ese recorrido; el usuario confirmó «si permanece» después de stash → archivo → visor. Esto no aprueba automáticamente la nueva UX ni todos los flujos. [Evidencia y límites](stash-crash.md).

## Registro histórico del primer bloque

Las cifras y logs de las secciones siguientes corresponden al primer checkpoint y no sustituyen la última verificación anterior.

## Cambios terminados en este bloque

| Cambio acotado | Implementación | Evidencia |
| --- | --- | --- |
| Evitar falsos verdes de build/CI | Wrapper con pipefail, exit status y marcador de finalización; usado por build y release | 9 escenarios de éxito/fallo, incluidos enlace, codesign, tests incompletos y marcador engañoso |
| Ejecutar pruebas reales de modelos | Retiradas definiciones sombra de Tests/GitMacTests; `@testable import GitMac` | 11 XCTest pasan; mutar una copia temporal de Commit rompe exactamente un test |
| Aplicar patches sin shell interpolada | `git apply` con argv/cwd, estado de salida obligatorio, temporal UUID en directorio 0700 | Repos con apóstrofos y metacaracteres, ID adversario, fallo de proceso y reapply |
| Conservar el cursor tras error | loadMore/loadUpTo confirman página después de éxito | Retry solicita `[100,100]`, no `[100,200]` |
| Coordinar paginación | Guards de loading/hasMore, generación vigente y SHA inicial fijo | No consulta al agotarse, no se solapa y descarta resultados de un repo anterior |
| Evitar reordenamiento tras layout | Commits conservan su orden de entrada; WIP/stashes se agrupan antes | Fechas de autor invertidas no cambian child/parent; filas auxiliares no dividen conexiones |
| Eliminar líneas fantasma | Decrementar solo aristas previamente activadas | Caso adyacente y oracle independiente de intervalos sobre 80 DAGs |
| Reducir publicaciones obsoletas | Generación antes de publicar carga/status/stashes/minimap/email; tareas auxiliares canceladas al recargar | Build completo y pruebas de interleaving de los dos métodos de paginación; otros recorridos aún requieren tests integrados |
| Evitar fetch implícito del grafo | Abrir un clon superficial ya no ejecuta un deepen/reload automático | Inspección del flujo y build; no se ha añadido todavía una interacción explícita para profundizar |
| Recuperar build compatible | Retirados dos fallbacks inalcanzables con el mínimo macOS 14 en ContentView/AnalyticsDashboard | Debug y Release completos, sin elevar deployment target |
| Reducir riesgo en workflows | Versión de release por entorno validada; checkout sin persistir credenciales; actions fijadas a commits upstream | [Pins verificados](action-pins.json); no se presentan versiones antiguas fijadas como las más recientes |

Los rangos exactos antes/después y hashes están en [changes.csv](changes.csv). El [reporte verificable](verification.json) incluye cada archivo, rangos y procesos de prueba con exit code. No incluye en el listado el cambio previo de CLAUDE.md.

## Verificación ejecutada

- Debug: [debug-final.log](debug-final.log), exit 0 y BUILD SUCCEEDED.
- Release: [release-fixed.log](release-fixed.log), exit 0 y BUILD SUCCEEDED; binario arm64 en `build/Build/Products/Release/GitMac.app`.
- 18 comprobaciones de regresión y 11 XCTest: [core-regressions-and-models.log](core-regressions-and-models.log).
- 9 escenarios de CI: [ci-gate.log](ci-gate.log).
- Control negativo de modelo: [production-model-mutation.log](production-model-mutation.log). La mutación ocurre solo en un temporal; no se modifica Commit.swift.
- Control negativo histórico: [regressions-before.log](regressions-before.log), 17 de 18 comprobaciones fallan con fuentes de HEAD. Son 17 comprobaciones, no 17 defectos independientes; algunos escenarios comparten causa.
- Fixtures Git sin config global/sistema, templates ni hooks del usuario; los comandos adversarios solo pueden crear un marcador de prueba dentro de su fixture temporal.
- El nuevo mapping conserva 416 archivos, 403 Swift, 14,726 símbolos y 131,229 aristas sintácticas/candidatas. [Cobertura](mapping/coverage.json), [archivos/hashes](mapping/files.csv), [símbolos/líneas](mapping/symbols.csv), [grafo](mapping/source-graph.json).
- Los 25 límites del parser siguen visibles. No es un call graph resuelto por compilador ni cobertura semántica exhaustiva. El visor previo se conserva como baseline, no como representación vigente del worktree.

El wrapper falló ante las causas reales iniciales; no se ocultaron errores ni se rebajó SWIFT_STRICT_CONCURRENCY a minimal. Se instaló el componente Metal de Apple requerido por MLX. Siguen advertencias de incompatibilidad CoreDevice/CoreSimulator; que el destino macOS compile no repara esos componentes.

Para las incompatibilidades de builders se consultó la [nota técnica TN3211 de Apple](https://developer.apple.com/documentation/technotes/tn3211-resolving-swiftui-source-incompatibilities-for-state-and-contentbuilder). La corrección aplicada se comprobó con el SDK local y ambos builds; no se cambió todo el producto a APIs de macOS 26/27.

## Revisión con pesos locales

Revisión inicial del bloque con `qwen3-coder:30b` local: 13,833 tokens de entrada y 922 de salida, con unload al terminar. Digest, propuesta cruda y límites: [local-implementation-review.json](local-implementation-review.json). La revisión precede a las ampliaciones finales de tests/guards; no es una segunda aprobación local de todo el diff final. Estos números no incluyen la sesión principal, compilaciones ni revisiones locales de bloques anteriores.

Se rechazaron los dos supuestos defectos de CI: pipefail sí preserva fallos de compilador/enlace aunque haya marcador; nueve pruebas lo demuestran. La propuesta sobre layout no consideró el oracle de 80 DAGs. Las observaciones sobre cobertura de interleaving y rutas se atendieron ampliando tests. Los permisos 0700 se verifican en implementación, no por observación del temporal mientras Git está ejecutándose. El modelo no autoaprobó cambios.

## Pendientes del primer checkpoint, actualizados

T03/T06: reconciliar pbxproj/XcodeGen/SPM y completar fixtures F01–F15. T05 ya está verificada mediante suites de producción y control negativo; no equivale a validar UI. El esquema actual no contiene GitMacTests; CI ejecuta runners explícitos y la reconciliación del proyecto sigue pendiente.

T07: threat model documentado y comprobado; controles abiertos permanecen abiertos. T13: terminar migración/UX/aislamiento de cuentas. T09 y T10 ya están verificadas con sus gates. Undo/rebase, comandos, ventanas, accesibilidad e integraciones conservan sus tareas pendientes.

El grafo todavía necesita alcance de todas las refs, consulta topológica explícita, refs tipadas múltiples, resolución real de file:/change: y mediciones completas. El nuevo minimapa navega por SHA y limpia filtros para revelar su destino; tiene un fixture sintético de 100k, no un benchmark del producto. Congelar el SHA corrige desplazamientos durante paginación, pero no resuelve todas las funciones pendientes.

No se han acreditado VoiceOver, UI visual, p50/p95, consumo de memoria, resistencia prolongada, GitHub Actions alojado ni instalación/actualización. Firma Developer ID y notarización sí se acreditaron para el candidato técnico señalado arriba. Eso no certifica su corrección funcional ni la optimización completa. No se publicaron artefactos.

## Repetir

Desde el root del repo:

```sh
node scripts/test-xcodebuild-gate.mjs
node scripts/test-core-regressions.mjs
node scripts/test-core-regressions.mjs --mutate-model # debe fallar exactamente un XCTest
/Users/mario/.local/share/uv/tools/graphifyy/bin/python3 docs/roadmap/2026-10-20/tools/map-source-graph.py --output docs/roadmap/2026-10-20/implementation/mapping
node docs/roadmap/2026-10-20/implementation/audit-implementation.mjs
node docs/roadmap/2026-10-20/tools/validate-execution-plan.mjs
```
