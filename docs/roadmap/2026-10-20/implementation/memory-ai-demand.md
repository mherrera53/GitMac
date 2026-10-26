# Memoria, modelos bajo demanda y decisión de candidato

## Continuación: carga confirmada y compatibilidad

Las mediciones nuevas exigen señales de repositorio, al menos 100 commits del grafo y minimapa con el total exacto. El fixture 1k registra pico 253281384 bytes y el 100k pico 470811800; ambos fallan el presupuesto estricto. Logs `performance-memory-1000-ready-run.log` y `performance-memory-100000-ready-run.log`. Las dos primeras mediciones sin estas señales son provisionales y no acreditan carga completa. Los valores posteriores menores no anulan el pico.

Se intentaron descargar Qwen3.5:4b y su tag exacto 4b-q4_K_M; el Ollama instalado respondió HTTP 412 por versión insuficiente. La descarga de qwen2.5-coder:1.5b terminó por timeout de 180 segundos. No se presentan como modelos ensayados, ni se actualizó/reinició el servidor del usuario. El candidato Qwen3.5 continúa provisional, no «el mejor» probado en este Mac.

Una revisión local bajo demanda del bloque de watchers sí finalizó con qwen3-coder:30b y keep_alive:0; se observó `/api/ps` vacío después. Se probaron independientemente sus sugerencias sobre aliases/worktrees y ciclo de vida; la revisión no sustituye tests. La traza Allocations intentada falló al adjuntarse al proceso, sin cambiar permisos globales del sistema.

La reducción posterior de asignaciones del minimapa conserva los SHA completos y supera 80 DAGs nuevos. Debug/Release pasan; se repitieron mediciones con hash del ejecutable: 1k pico 364725328 bytes y 100k pico 374670488. Ambas fallan; la variación no acredita ganancia causal ni p95. No se apagan funciones para simular cumplimiento.

El ensayo adicional `performance-memory-detailed-run.log`, mismo ejecutable SHA-256 `5317afaf8998d1323f5b3c884840225302afd6a4ee68150d1af414842d4cc385`, registra 256001080 bytes observados y pico 258032696. La muestra máxima incluye **169164800 bytes** en `Owned physical footprint (unmapped) (graphics)` y 47693824 en `Malloc Small`. El componente dominante observado es gráfico, no pesos de IA ni solo copias de historial. No identifica por sí mismo qué Canvas, superficie o driver lo reserva. El siguiente diagnóstico debe aislar componentes de renderizado y escala Retina sin desactivar funciones en el producto ni atribuir causalidad a un componente todavía no medido.

## Resultado y presupuesto

El usuario exige un máximo de 150 MB. El gate usa **150 000 000 bytes**, no 150 MiB ni solo RSS. La app instalada abierta, PID 84387, midió 242435464 bytes de physical footprint y 690128336 de pico de vida. Por tanto, **no cumple**. Son seis observaciones breves del proceso instalado, no una medición del nuevo candidato ni una matriz de escenarios.

Evidencia: `memory-installed-baseline.json`, `memory-installed-baseline.log`, `memory-installed-vmmap.log` y `memory-installed-budget-result.json` (passed:false). Su RSS pequeño ocultaba memoria comprimida. `scripts/check-memory-budget.mjs` falla con exit 1 ante ese reporte; el validador tiene 11 casos que rechazan picos, lecturas ausentes, unidades incorrectas y falsos verdes por RSS.

La IA local pesada no puede compartir un límite total de 150 MB durante inferencia. Se solicitó aclaración sobre el alcance, sin asumir una excepción aceptada. Un backend externo separa el consumo del proceso GitMac, pero no elimina ese consumo del Mac. No se retiran funciones a escondidas para anunciar cumplimiento.

## Cambios implementados

- GitMac no inicia Ollama al arrancar ni al reactivar una ventana.
- Guardar proveedor/modelo ya no inicia el motor, descarga ni precarga MLX.
- Ollama conserva el nombre exacto solicitado: se eliminó la selección fuzzy y el fallback al primer modelo disponible.
- Antes de transmitir el prompt, `/api/show` recibe solo el nombre. Metadatos remotos, formatos desconocidos o modelos ausentes fallan con recuperación explícita. El catálogo descarta los aliases cloud identificados por metadata.
- La generación local admite solo loopback, sin credenciales/query/proxy-path, y su sesión no sigue redirects. No se usan credenciales ni se hace fallback cloud para una petición local fallida.
- Una lease compartida limita la inferencia pesada entre instancias del servicio. Contexto Ollama 4096, salida máxima 1024 tokens y entrada máxima 12 000 bytes, con error en vez de truncamiento propio adicional. La cota de bytes no es un conteo exacto del tokenizer ni garantiza el comportamiento interno de truncamiento del backend.
- Ollama usa `keep_alive:0`; MLX libera referencias al modelo y caché al finalizar, fallar o cancelar, con caché de buffers acotada a 16 MiB. No se usa un temporizador de tres minutos para mantener pesos ociosos.
- La configuración explica la descarga inicial y el consumo de inferencia. Un fallo al guardar proveedor deja de anunciar éxito.

## Comparación local y recomendación

Se probaron **qwen2.5:3b** y **phi4-mini:latest**, ya instalados y con pesos locales verificados. Tres entradas sintéticas idénticas, temperatura 0, seed 42, contexto 4096 y salida máxima 160. `local-model-comparison-isolated.json` conserva respuestas, digest y tiempos; no hubo descargas ni envío externo. Se repitió sin compilación ni revisión local simultáneas.

| Caso | qwen2.5:3b | phi4-mini | Revisión independiente |
| --- | --- | --- | --- |
| Subject de corrección | 1,557 s | 2,192 s | Qwen escribe `Fix:` en vez de `fix:`; Phi etiqueta incorrectamente una corrección como `feat:` |
| Subject de ayuda nueva | 0,942 s | 1,246 s | Qwen omite el prefijo Conventional Commit; Phi produce un subject adecuado |
| Explicación breve de stash | 2,919 s | 1,880 s | Ambos distinguen las tres acciones, pero su redacción es imperfecta y omiten el matiz de conflicto de pop; no sustituyen la ayuda revisada |

Los seis casos observaron al modelo fuera de `/api/ps` aproximadamente 104–110 ms después de responder. Eso es granularidad del polling, no latencia exacta de liberación física del sistema. El primer ensayo consultaba demasiado pronto (`unloadedAfterResponse:false`); se conserva en `local-model-comparison.json` como evidencia del error de medición. El ensayo v2 solapado con una revisión se canceló y se excluye. No se mataron motores del usuario.

**Decisión:** ninguno de los dos queda aprobado como el mejor para todas las funciones. Para calidad/tamaño, el candidato principal a ensayar es [Qwen3.5-4B](https://huggingface.co/Qwen/Qwen3.5-4B), mediante un tag exacto de [Ollama](https://ollama.com/library/qwen3.5): sus variantes publicadas ocupan varios GB de pesos, no 150 MB. Es una recomendación provisional basada en documentación del fabricante, no un benchmark hecho en este Mac. Para borradores de commit de menor coste, [Qwen2.5-Coder:1.5b Q4_K_M](https://ollama.com/library/qwen2.5-coder:1.5b) publica 986 MB de pesos; también necesita validación local. No se cambiaron modelos/preferencias ni se descargaron esos candidatos solo por investigarlos.

No se recomienda elegir Qwen3.5-0.8B únicamente por tamaño: su [ficha oficial](https://huggingface.co/Qwen/Qwen3.5-0.8B) orienta ese tamaño a prototipos y adaptación específica. Los benchmarks de otros modelos o cuantizaciones no acreditan exactitud en GitMac. La política `keep_alive:0` se contrastó con la [API oficial de Ollama](https://docs.ollama.com/api/generate).

## Pruebas y límites

Debug final y Release pasan (`ai-demand-tests-final-debug.log`, `ai-demand-release.log`). Las suites enlazan AIService real: loopback adversario, cloud preflight sin prompt, request exacta, límites, respuesta incompleta, lease compartida y recuperación después de error. `production-suites-current.log` registra 62 Swift Testing y 11 XCTest. En el módulo headless se sustituye únicamente la frontera GPU/MLX y plantillas: **no valida la descarga física de MLX, inferencia nativa ni cancelación del proceso Ollama**. Los procesos reales de Git y sus pruebas no se sustituyen.

La revisión local de MLX con qwen2.5:3b devolvió JSON truncado; `local-ai-demand-review.log` conserva el fallo y no se usa como aprobación. El primer Debug falló por tipos auxiliares aún ausentes, y el primer test de transporte asumía `httpBody` en vez de `httpBodyStream`; ambos fallos se conservaron y corrigieron antes de repetir los checks.

El audit por archivo/línea está en `verification.json`, `changes.csv` y el visor actualizado `mapping/graph.html`. Ese audit comprueba los cambios y siete checks, no el presupuesto global ni todas las funciones. `task-closure-audit.json` enumera los 40 criterios: 4 verificadas, 17 en curso y 19 pendientes; allTasksVerified:false. Quedan, entre otros, la matriz UI/AX, GPU/cancelación real, fixtures completos, recuperación/rebase, integraciones, benchmark de todos los flujos y distribución en Mac limpio.

## Candidato técnico

`candidate-Yn60GL` contiene el Release de este bloque: Developer ID, Apple Accepted `67ad2724-6299-4c4a-b21e-6e5514d7849d`, stapling y Gatekeeper aprobados en `distribution-ai-demand-final.log`. SHA-256 final del ZIP: `2ab8441be6941d1ece2f5a99bf13bed2c2a1ab61d98b2b263b8d5eda5973f747`. No se cerró ni reemplazó la app instalada. No se presenta este candidato como aprobado visualmente o bajo 150 MB.
