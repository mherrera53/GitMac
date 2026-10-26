# Plan de verificación y entrega

## Evidencia conseguida en esta auditoría

| Comprobación | Resultado | Límite |
| --- | --- | --- |
| Repositorio y cambios previos | Base `33bcb57`; `CLAUDE.md` modificado y `graphify-out/` sin versionar antes de empezar | Se preservaron; no se hizo commit |
| Modelo local | Ollama detectó pesos locales `qwen3-coder:30b`, sin metadata remota | El uso local no garantiza exactitud de los hallazgos |
| Revisión por dominios | Salidas y métricas en `evidence/local/` | Inputs y truncamientos constan en cada run |
| Parsers status | Tres rutas v1 reales y dos verificaciones de un registro v2 sintético fallan con el código extraído | No ejecuta la app completa ni su suite; v2 no usa un repo con rename real |
| Compilador aislado | Arnés compilado con CLT, target macOS 14 y SDK 26.4 explícitos | No demuestra compatibilidad del proyecto completo |
| Xcode/project listing | CoreDevice/CoreSimulator incompatibles; se detuvo durante paquetes | No se certificó build ni tests de aplicación |
| Visual y AX | Casos definidos | Pendiente de ejecutar con app instalada y fixture equivalente |

La primera compilación del arnés usó el target por defecto `macosx28.0` y no pudo cargar la librería estándar. Se resolvió fijando target soportado y SDK instalado, sin modificar el código de GitMac. Regla preventiva: registrar y fijar compiler/target/SDK antes de atribuir un fallo de toolchain al código bajo prueba.

## Catálogo de fixtures

| Fixture | Contenido | Oracle / aserción |
| --- | --- | --- |
| F01 unborn | Repo sin commits, archivo nuevo y staged | HEAD inexistente tratado explícitamente; stage/unstage seguro |
| F02 rutas | Espacios, tab, newline, Unicode, comillas, ` -> ` y prefijo `-` | Bytes/ruta exacta en porcelain y operación; sin convertir ruta en opción |
| F03 index/working tree | MM, AM, RM, cambios de tipo, delete | Mostrar ambos lados y preservar oldPath; tree del index correcto |
| F04 DAG | Divergencia local/remota, tags y refs coincidentes, octopus, fechas no topológicas | Parentesco contra `rev-list --parents`; alcance definido |
| F05 paginación | Historial mediano y grande, cambios durante carga | No duplicar/omitir dentro de snapshot; ancla estable |
| F06 rebase | Pick/reorder/reword/squash/fixup/drop y conflicto intermedio | DAG/trees y mensajes contra plan; abort recupera snapshot |
| F07 undo | Commit inicial/normal/amend, ff/no-ff merge, reset/discard | Ref/index/working tree antes/después; cambio externo bloquea undo inseguro |
| F08 conflictos | Texto, diff3/zdiff3 cuando soportados, modify/delete, rename, binario | Resultado correcto y estado Git de operación; no solo desaparición de marcadores |
| F09 worktrees | Dos worktrees, branch ocupada, lock, rutas externas | Estado aislado y common git dir correcto |
| F10 patches/diff | CRLF, EOF sin newline, líneas largas, binario, imagen, diff grande | Árbol exacto y fallback visible sin datos omitidos silenciosamente |
| F11 red/auth | Remoto local/servidor controlado, auth expirada, offline, corte y rechazo | Tipos de error y reintento sin duplicar mutación |
| F12 proveedores | Payloads reales sanitizados por capacidad/host | Contratos de paginación, permisos y error; escritura solo en cuenta de prueba autorizada |
| F13 procesos | Ambos pipes llenos, UTF-8 partido, arranque fallido, descendiente y TERM ignorado | Sin bloqueo; completar una vez; liberar solo recursos propios |
| F14 cuentas/migración | Keychain de prueba, secreto sintético y almacenamiento previo | Persistencia confirmada; repetir migración no duplica ni pierde |
| F15 sesión | Dos ventanas, dos repos, A lenta/B rápida y relanzamiento | Ninguna publicación ajena; drafts/foco/restauración correctos |

Los generadores deben aislar configuraciones Git del equipo y usar directorios temporales explícitos. No ejecutar reset/rebase/discard ni limpieza recursiva en el repo del usuario para preparar casos. Los fixtures con commits pertenecen al entorno de prueba, nunca al historial de GitMac.

## Niveles de prueba

Unitarias: parsers, serialización de planes, construcción de patches, decisiones de disponibilidad y topología. Prueban lógica de producción y casos que podrían romper comportamiento; no duplican implementaciones.

Integración: CLI real sobre fixtures aislados. Comparar refs, blobs, index y estado operativo. Para servicios, contratos HTTP sanitizados antes de cuentas de prueba. La prueba de un método mock no demuestra que la app conecta correctamente sus controles.

UI: abrir/seleccionar/stage/commit/push controlado y volver; teclado, ventanas y comandos. Una suite smoke pequeña por PR; recorridos de conflictos, rebase, worktrees e integraciones al integrar su spec y antes de candidato.

AX/visual: Accessibility Inspector, VoiceOver, foco y texto ampliado en escenas de [experiencia](06-experiencia.md). Adjuntar observaciones humanas; screenshots generados se leen antes de aprobar.

Rendimiento: Instruments/signposts con repos y hardware definidos. Medir sin IA y con el modelo local soportado. Hacer repeticiones y registrar variación para no convertir ruido de CI en fallo del producto.

## Presupuestos iniciales de calidad

Estos son objetivos de producto propuestos, no mediciones actuales ni promesas de Apple. M0/GM-027 deben afinarlos con baseline y un Mac de referencia de menor capacidad que el equipo de desarrollo.

| Métrica | Objetivo inicial | Condición |
| --- | --- | --- |
| Primer contenido útil de repo pequeño | p95 ≤ 1 s en apertura caliente | Hasta 10k commits, sin red ni IA |
| Primer contenido útil de repo grande | p95 ≤ 3 s | Fixture 100k commits; carga por demanda |
| Respuesta visual a selección/filtro local | p95 ≤ 100 ms | Snapshot ya cargada; separar I/O de Git |
| Actualizar estado tras una operación local | p95 ≤ 1 s en fixture mediano | Hasta 1k archivos cambiados; definir costo de stats |
| Fluidez del grafo | Sin trabajo bloqueante sostenido en MainActor; objetivo cercano a 60 fps | Medir frame time y hitches, no juzgar a ojo |
| Cancelación de lectura | Reconocimiento UI ≤ 100 ms; proceso propio termina según política ≤ 2 s objetivo | Excepciones de red/proceso documentadas; escrituras requieren recuperación |
| Memoria de app sin IA | Banda estable definida tras baseline; objetivo inicial < 600 MB en fixture medio | RSS/footprint y dependencias nativas medidos; no certificado hoy |
| Cierre/reapertura de 30 tabs | Sin crecimiento monotónico de procesos/watchers/tareas; memoria retorna a banda definida | Cachés acotadas y medidas antes/después |
| IA local | Pico de memoria y latencia por modelo publicados | No sumarlos a la promesa de memoria sin IA; no OOM ni fallback cloud |

Un objetivo incumplido abre trabajo concreto y una decisión de alcance; no se cambia el benchmark para ocultar la regresión. Los objetivos de 60 fps y de latencia no implican que una operación Git de red deba completar en ese tiempo.

## Gate por PR y por release

Por PR: build del entrypoint acordado, unit/integration pertinentes, lint/reglas existentes aplicables, invariantes de datos y smoke del flujo modificado. Ejecutar pruebas amplias adicionales cuando el contrato cambie o aparezca una falla, no repetir todo por cada cambio documental.

Por candidato: build Release limpio; artefacto firmado/notarizado según canal; todas las suites aplicables con resultados; matriz macOS mínimo/actual y arquitecturas soportadas; escena clara/oscura/texto grande; instalación y upgrade; cero P0 abiertos y aceptación explícita de cualquier P1 restante. UX, QA y Release firman evidencia de sus áreas.

Cada reporte registra commit, OS, compiler/SDK, versiones de dependencias, fixture, comandos, fecha, duración, resultados y limitaciones. Un paso no ejecutado no es verde. Si la infraestructura falla, reportar `bloqueado por entorno` y conservar el fallo original, sin convertirlo en test passed.

## Reproducir y validar este paquete

```sh
node --check docs/roadmap/2026-10-20/tools/local-audit.mjs
node --check docs/roadmap/2026-10-20/tools/reproduce-status.mjs
node docs/roadmap/2026-10-20/tools/validate-roadmap.mjs
```

El validador comprueba 28 specs, dependencias declaradas, enlaces locales del paquete y JSON de evidencia; exporta backlog y suma de esfuerzos. No valida comportamiento de la aplicación. Volver a ejecutar el arnés de status después de cambiar parsers para convertir los fallos aquí observados en regresiones cubiertas por la suite real.
