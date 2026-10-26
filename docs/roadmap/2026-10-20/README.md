# GitMac: auditoría y roadmap de producto

Fecha de corte: 20 de octubre de 2026. Base revisada: `33bcb57` (`fix: sidebar branches refresh after checkout`). Estado: propuesta de ingeniería; no certifica una versión lista para publicar.

El objetivo es acercar GitMac al máximo a los flujos y a la organización visual de GitKraken Desktop, con comportamiento nativo de macOS. Los hallazgos describen el baseline previo a los cambios. Estado de ejecución: **4 verificadas, 13 en curso, 23 pendientes**. Status y procesos están verificados; rebase, undo, paridad completa del grafo y otras áreas siguen abiertos. Debug/Release compilan y un candidato técnico pasa notarización/Gatekeeper; ese candidato anterior no acredita automáticamente cambios posteriores. La incidencia de tamaño de pantalla tiene correcciones y pruebas, con validación visual todavía pendiente. No significa que las 40 tareas estén terminadas ni que el producto esté completamente optimizado. Ver [resultados de implementación](implementation/RESULTADOS.md).

El paquete contiene 22 hallazgos clasificados y 28 specs en siete hitos. El esfuerzo inicial suma 143–244 días-persona; se debe recalibrar con throughput real después de M0/M1. No es una promesa de calendario ni presupone que todas las funciones avanzadas entren en una sola versión.

## Cómo leer este paquete

| Documento | Decisión que permite tomar |
| --- | --- |
| [Resultados y límites de implementación](implementation/RESULTADOS.md) | Estado actual, pruebas reales, artefacto técnico notarizado, controles negativos y pendientes |
| [Cambios por archivo/líneas](implementation/changes.csv) | Rangos antes/después y hashes de cada fuente modificada |
| [Verificación ejecutable](implementation/verification.json) | Integridad del inventario vigente y exit codes de tests/controles negativos |
| [Auditoría](01-auditoria.md) | Qué está comprobado, qué es un riesgo y qué falta reproducir |
| [Mapping y auditoría trazable](mapping/README.md) | Baseline histórico de 411 archivos y 33 registros; el inventario vigente está en implementation/mapping |
| [Visor del worktree actual](implementation/mapping/graph.html) | Hashes, símbolos, relaciones candidatas y cambios aplicados; separado del baseline |
| [Visor de grafos del baseline](mapping/graph.html) | Archivos, símbolos, relaciones candidatas, notificaciones y hallazgos anteriores a la implementación |
| [Auditoría con fragmentos](mapping/AUDIT.md) | Evidencia con hashes, rangos exactos, cambio y aceptación; incluye patch candidato sin aplicar |
| [Paridad con GitKraken](02-paridad-gitkraken.md) | Qué reutilizar y qué falta para completar cada flujo |
| [Convenciones de Apple](03-convenciones-apple.md) | Qué debe sentirse y comportarse como una app de Mac |
| [Roadmap](04-roadmap.md) | Orden, dependencias, responsables, esfuerzo y puertas de salida |
| [Plan de trabajo auditado](10-plan-trabajo-auditado.md) | 40 tareas ordenadas, prácticas vigentes y controles de rapidez/seguridad para las 28 specs |
| [Registro de ejecución CSV](execution-tasks.csv) | Dependencias, aceptación, responsable, estado y evidencia por tarea |
| [Specs ejecutables](05-specs.md) | 28 unidades de trabajo con alcance y aceptación |
| [Diseño de la experiencia](06-experiencia.md) | Composición, navegación, estados y revisión visual |
| [Verificación y entrega](07-verificacion.md) | Fixtures, matriz de pruebas y condiciones de lanzamiento |
| [Uso de modelos locales](08-modelos-locales.md) | Modelo, trazabilidad, límites y revisión de falsos positivos |
| [Fuentes](09-fuentes.md) | Documentación primaria de Apple, Git y GitKraken |
| [Backlog CSV](backlog.csv) | Importar las 28 specs con prioridad, hito, rol, esfuerzo y dependencias |
| [Validación del paquete](evidence/package-validation.json) | Resultado estructural y métricas de ejecución local |

## Qué se hizo y qué no está demostrado

Se inspeccionaron código, manifiestos, workflows y tests; se consultó el grafo existente y documentación primaria; se ejecutó revisión por dominios con pesos locales de Ollama; y se preparó un arnés aislado para los parsers de estado. Las salidas del modelo son propuestas sin verificar, conservadas separadamente en `evidence/local/`.

La fase inicial solo produjo auditoría y specs. La implementación posterior sí modificó aplicación, tests y CI; los cambios están enumerados con hashes y líneas. No se hizo commit en este repositorio, no se publicaron mensajes ni se modificaron remotos de usuario. `CLAUDE.md` y `graphify-out/` ya tenían cambios y se preservaron. Algunos fixtures crean commits exclusivamente en repositorios temporales aislados con identidad sintética. Se envió a Apple únicamente el candidato técnico de notarización.

No hay recorrido visual aprobado, VoiceOver, comparación de screenshots ni benchmarks completos. El intento inicial con Xcode encontró problemas de CoreDevice/CoreSimulator; después se usó la caché de paquetes, se instaló Metal Toolchain y se corrigieron dos incompatibilidades de vistas. Ahora Debug y Release terminan correctamente para macOS/arm64 sin firma de distribución. Las advertencias de CoreDevice/CoreSimulator permanecen; no se presentan como reparadas.

## Decisiones de producto propuestas

1. La unidad de calidad es el flujo completo: abrir repo, entender estado, elegir cambios, operar, ver resultado y recuperarse. Una vista existente no cuenta como paridad terminada.
2. Mantener la estructura reconocible de GitKraken: referencias a la izquierda, grafo central, inspección/staging a la derecha, acciones Git visibles y pestañas de repositorio. Adoptar ventanas, menús, foco, accesibilidad y atajos de macOS.
3. Reutilizar primero `GitEngine`, `RepositoryContext`, el motor de grafo y el sistema de temas. Elegir una implementación activa por responsabilidad a partir del mapa de llamadas; no borrar variantes solo por su nombre.
4. Mantener funcionalidades avanzadas detrás de capacidades explícitas cuando el flujo no esté verificado. Mostrar una limitación es preferible a comunicar un éxito que no corresponde al resultado.
5. Evaluar paridad por escenarios aprobados y evidencia, sin publicar un porcentaje subjetivo de parecido.

El siguiente trabajo debe reconciliar configuraciones/targets y completar fixtures; después cerrar aislamiento, secretos, recuperación y funciones pendientes del grafo. Las suites actuales de producción ya se ejecutan. Las mediciones p50/p95, memoria y resistencia siguen sin acreditarse; no hay base para afirmar «full optimizado».
