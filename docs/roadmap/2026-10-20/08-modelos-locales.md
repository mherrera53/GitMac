# Uso de modelos locales y control de calidad

## Ejecución

La primera pasada usa `qwen3-coder:30b` por Ollama en `127.0.0.1:11434`. Se comprobó que existe un modelo instalado con pesos, tamaño coherente y ausencia de `remote_host`/`remote_model`. El equipo tiene 36 GB de memoria; se ejecutaron dominios en serie para evitar cargar varias inferencias grandes simultáneamente. No se descargaron modelos nuevos.

Los siete dominios fueron procesos/Git, estado/staging, recuperación/rebase, grafo, macOS, build/tests e interfaces de PR. Sus resultados están en `evidence/local/01-*.json` a `07-*.json`, con manifest agregado. Suman 96,618 tokens de entrada y 11,855 de salida según las métricas de Ollama, en unos 626 segundos de solicitudes. Estas cifras no incluyen el trabajo de síntesis y verificación del agente principal ni equivalen a una factura o a un porcentaje calculado de ahorro.

Una segunda pasada usa pesos locales `devstral:latest`, revisa worktrees, patches, prevención de conflictos y almacenamiento de credenciales, y recibe advertencias explícitas sobre los falsos positivos anteriores. Su resultado y métricas independientes quedan en `08-second-review.json`. El runner libera el modelo de la primera pasada antes de cargar el segundo y pide descargar este último de memoria al completar.

Las ocho revisiones sumaron 115,383 tokens de entrada y 12,730 de salida, unos 815.5 segundos de solicitudes locales. Ambas generaciones terminaron normalmente; el validador agrega sus resultados y las dependencias/enlaces del paquete. Los modelos iniciados para esta auditoría quedaron descargados de memoria al terminar.

No se usaron los alias instalados que apuntan a modelos remotos, aunque su nombre sugiera otro proveedor. La investigación de documentación oficial se hizo mediante web/HTTP; eso es distinto de enviar código a un modelo cloud. Los prompts de revisión se mandaron únicamente al endpoint local comprobado. La planificación y adjudicación final se realizaron en esta sesión, de modo que no se afirma un proceso enteramente local ni cero tokens de sesión.

## Cobertura y límites de contexto

El manifest registra por archivo qué líneas se solicitaron, cuántos caracteres se enviaron y si hubo recorte u omisión. La pasada de recuperación recortó el archivo de conflictos. El dominio de features agotó presupuesto en `PRListView` y no alcanzó worktrees/patches/conflict prevention; por eso se añadió la segunda pasada. Tampoco esta segunda pasada representa una lectura íntegra de cada módulo: sus recortes se registran.

El límite inicial fue 24,576 tokens de contexto y 3,200 tokens máximos de salida por dominio; temperatura 0.1. El segundo runner conserva contexto equivalente y acota salida. El modelo puede producir JSON válido con razonamiento incorrecto; la validez sintáctica nunca convierte un hallazgo en hecho.

## Adjudicación de resultados locales

El registro siguiente documenta por qué algunas afirmaciones del primer modelo no entraron como defectos en la auditoría. Los JSON crudos se conservan para trazabilidad, incluyendo sus etiquetas incorrectas de `confirmed`.

| Salida local | Decisión | Motivo comprobado |
| --- | --- | --- |
| `01/F001`: matar procesos prueba corrupción | Reclasificar como riesgo/prueba | Hay timeout y escalado, pero eso no demuestra corrupción; hay que probar operaciones y recuperación |
| `01/F004`: renombrar `stage` por HIG | Rechazar | HIG no prescribe ese nombre interno; la función ya tiene argumento `files` |
| `01/F005`: nombre temporal predecible | Rechazar | La ruta incorpora UUID; pueden revisarse permisos/creación atómica, pero no esa afirmación |
| `01/F006`: incompatibilidad v2 en versión Git indicada | No adoptar | El umbral afirmado no se verificó; fijar versión mínima con documentación y pruebas reales |
| `02/F001-F002`: data race por usar actor/cache | Rechazar como confirmado | El actor serializa acceso aislado; una carrera lógica entre awaits requiere un camino concreto y prueba distinta |
| `02/F003`: refresh de otro repo | Retener como riesgo A07 | La publicación tras await no compara identidad/generación en `loadStatus`; reproducción determinista pendiente |
| `02/F005`: temporal sin cleanup en error | Rechazar | `discardHunk` ya tiene `defer` de limpieza |
| `03/undo-commit-redo` | Retener con alcance | `executeRedo(.commit)` devuelve false, pero no se encontró integración externa del gestor; no afirmar que un flujo accesible ya falla |
| `03/rebase-interactive-view`: cat significa que no hay rebase | Corregir a A02 | Git sí puede ejecutar su plan por defecto; el defecto es que se descarta el plan elegido en UI |
| `03/rebase-drop-action`, `merge-conflict-ai` | No adoptar como confirmado | Faltó demostrar la ruta concreta y el resultado; quedan escenarios de verificación |
| `04/F001`: log en /tmp es crítico | Rechazar severidad | Un fallo de diagnóstico no prueba un fallo crítico de datos; logging se aborda en GM-027 |
| `04/F007`: todos los parents deben cargarse | Reformular | Un grafo paginado puede representar fronteras; no requiere cargar historia completa antes de renderizar |
| `05/F001`: /usr/bin/env no es portable en macOS | Rechazar | No sustenta un defecto para la plataforma soportada; selección de Git/PATH se prueba por contrato |
| `05/F003`: ⌘, no es estándar | Rechazar | Es el atajo estándar de Settings; la respuesta del modelo se contradice |
| `05/F005`: título opaco implica incompatibilidad | No adoptar | No se aportó una incompatibilidad concreta por disponibilidad ni reproducción |
| `06/F001`: MLX no usado en targets | Rechazar | `Package.swift` referencia productos MLX explícitamente |
| `06/F002`: entitlements vacíos impiden Git | Rechazar como conclusión | El proyecto tiene sandbox desactivado; permisos/canal y firma deben evaluarse en conjunto |
| `06/F005`: strict concurrency minimal reduce rendimiento multicore | Rechazar | Confunde diagnóstico/aislamiento de concurrencia con capacidad de cómputo |
| `06/F006`: firma ad hoc limita distribución | Retener con alcance | Se observa configuración ad hoc; canal, notarización e identidad de release deben definirse, no reemplazarse automáticamente por firma automática |
| `07/F004`: labelsHidden elimina AX | Rechazar | Ocultar label visual no prueba pérdida de semántica accesible; verificar con Inspector |
| `07/F005`: selector de base hardcodeado | Retener como A21 | `PRListView.swift:1115` define solo main/master/develop; se agrega carga de ramas reales a GM-021 |
| `08`: interpolación en applyPatch | Retener como A22 | Existe `bash -c` con rutas entre comillas simples sin escape; se exige argv y validar exitCode. No se ejecutó una explotación |
| `08`: inyección en getChangedFiles | Rechazar | El servicio pasa `git` y argumentos separados al ejecutor; no hay evaluación de shell en el fragmento señalado |
| `08`: credenciales guardadas en texto plano en disco | Rechazar | `saveGitCredentials` delega a `save`, que cifra el archivo con AES-GCM. La debilidad comprobada es la derivación de clave y el error silenciado, A14 |
| `08`: removeWorktree no informa resultado | Rechazar | `WorktreeManager.swift:198` publica notificaciones tanto de éxito como de error; el modelo no recibió ese archivo relacionado |
| `08`: borrar worktree activo demuestra corrupción | Mantener como prueba, no defecto confirmado | El manager usa Git sin force por defecto; Git aplica sus propias precondiciones. Verificar dirty/lock/abierto en GM-020 |
| Otras advertencias de estilo/AX genéricas | Mantener sin confirmar | Requieren call sites, jerarquía AX/render y reproducción; no justifican tickets de bug por sí solas |

El registro no convierte todos los demás resultados en aceptados. Solo los hallazgos de `01-auditoria.md`, con su estado específico, sustentan las prioridades de defectos. Las otras capacidades del roadmap se identifican como objetivos de producto o verificaciones pendientes.

## Procedimiento económico para continuar

1. Recuperar hechos de código, schema/documentación y mapa de llamadas con herramientas deterministas; construir un paquete por spec con rutas y líneas reales.
2. Enviar al modelo local solo ese paquete y criterios de aceptación; exigir separación de hechos/hipótesis y evidencia. Recortar por responsabilidad, registrando lo omitido.
3. Revisar propuestas contra código y reproducir el comportamiento importante antes de implementar. Una etiqueta del modelo no sustituye la prueba.
4. Usar el modelo local para borradores y cambios acotados; revisar el diff, compilar y ejecutar las pruebas pertinentes. No darle autorización implícita para ejecutar comandos destructivos ni publicar.
5. Registrar modelo/digest, contexto, tokens, tiempo, tests y decisión. Medir tasa de propuestas aceptadas y costo total; un modelo pequeño que produce muchos falsos positivos puede costar más revisión.

El valor de los modelos locales aquí fue ampliar la lectura y producir candidatos a bajo costo de inferencia externa. La revisión independiente evitó convertir errores del modelo en trabajo innecesario o en acusaciones falsas de incumplimiento Apple.
