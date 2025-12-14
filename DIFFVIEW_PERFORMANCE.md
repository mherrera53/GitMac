# DiffView: rendimiento y archivos gigantes

Objetivo
- Ofrecer un visor de diffs fluido y estable incluso con archivos inmensos (50k–500k+ líneas) y parches muy fragmentados.
- Mantener uso de memoria acotado y latencias predecibles, con degradación progresiva (“Large File Mode”, LFM).

Alcance
- Diff unificado (por defecto) y side‑by‑side para tamaños medianos.
- Plegado de hunks, navegación entre cambios, búsqueda básica, copiar selección.
- Intraline (word‑diff) y syntax highlight solo bajo demanda.

Fuera de alcance (por ahora)
- Editor de texto completo.
- Renderizado WYSIWYG o word‑diff global en archivos gigantes.

Estado actual del repo (resumen)
- Modelos: FileDiff, DiffHunk, DiffLine, DiffStats (OK).
- Falta motor/parseo (streaming de `git diff`) y la UI del DiffView.
- Infra referenciada pero no en este repo: ShellExecutor, GitEngine/GitService, AppState.

Requisitos no funcionales
- Scroll p95 < 16 ms/frame (60 FPS) en archivos grandes.
- Carga inicial visible < 1.5 s para ~100k líneas (muestra estructura y hunks).
- Memoria dedicada al diff < 100 MB (configurable), sin OOM.

---

## Large File Mode (LFM)

Umbrales por defecto (configurables):
- Tamaño del archivo > 8 MB, o
- Líneas estimadas > 50k, o
- Longitud máxima de línea > 2k caracteres, o
- Hunks > 1k.

Comportamiento en LFM:
- Desactivar word‑diff global y syntax highlight global.
- Desactivar soft wrap; usar fuente monoespaciada y altura de línea constante.
- Plegar hunks por defecto; mostrar contexto mínimo (p.ej. 3 líneas).
- Vista unificada (side‑by‑side solo si NO está activo LFM).
- Materialización on‑demand: convertir a String solo las líneas visibles/expandidas.

Configuración (UserDefaults/Settings):
- Umbrales LFM (MB, líneas, longitud de línea, hunks).
- Activar/desactivar LFM manual por archivo.
- Líneas de contexto por defecto.
- Word‑diff/syntax highlight on‑demand (sí/no).

---

## Pipeline de datos

Preflight (rápido):
- `git diff --numstat -- <path>` para additions/deletions y tamaño aproximado del patch.
- Si supera umbrales → activar LFM antes de cargar el patch completo.

Carga del patch (skeleton):
- `git diff --no-color --no-ext-diff --unified=3 --no-renames -- <path>`
- Leer por streaming (Process + Pipe + FileHandle) en chunks (64–256 KB).

Parser en streaming (state machine):
- Detectar encabezados `@@ -a,b +c,d @@`.
- Clasificar líneas por prefijo: “+”, “-”, “ ”, línea especial `\ No newline at end of file`.
- Emitir DiffHunk incrementalmente (AsyncSequence/AsyncStream).
- En LFM, almacenar offsets/rangos sobre el buffer de bytes; no materializar todas las líneas.

Materialización on‑demand:
- Al expandir un hunk o entrar al viewport, convertir solo ese rango a `DiffLine`.
- Aplicar intraline/word‑diff solo si la línea es “corta” (< 1k) y dentro del presupuesto de tiempo.

Cache (LRU por coste):
- Cachear hunks materializados por archivo (20–50 MB por defecto).
- Evitar retener Strings gigantes; preferir bytes + offsets.
- Evict por “costo en bytes” y LRU.

---

## Arquitectura de UI (macOS)

Opción recomendada (LFM): NSView “tiled” (dibujo directo)
- NSScrollView + NSView que dibuja líneas con CoreGraphics/CoreText.
- Altura de línea constante → cálculo de rects O(1), scroll suave.
- Ruler para números de línea y marcadores (+/−).
- Sin subviews por línea (evitar miles de vistas).

Alternativa viable: NSTableView altura constante
- Celdas sin subviews (NSTableRowView custom dibuja contenido).
- Side‑by‑side usando dos columnas solo fuera de LFM.
- Integración con SwiftUI vía NSViewRepresentable.

Interacciones
- Expandir/plegar hunks.
- Ir a siguiente/anterior cambio.
- Buscar (texto simple; en LFM, buscar solo en hunks materializados o materializar por tramos).
- Copiar selección; abrir en editor externo.

Accesibilidad
- VoiceOver: describir hunk, tipo de cambio y rangos.
- Alto contraste: colores configurables, no depender únicamente del color.

---

## Flags de git recomendadas

Comunes:
- `--no-color --no-ext-diff --unified=3`

Preflight:
- `--numstat`

Evitar en LFM:
- `--word-diff` (costoso y verboso)

Opcional (para reducir costo):
- `--no-renames` en parches masivos.

---

## Concurrencia, cancelación e instrumentación

Concurrencia
- Parser como AsyncSequence/AsyncStream.
- Trabajo pesado en Task.detached(priority: .userInitiated).
- Respetar Task.isCancelled; cancelar al cambiar de archivo o cerrar diff.

Backpressure
- Buffer de stream limitado (p.ej. 10 hunks).
- Pausar producción si la UI no consume a tiempo.

Métricas (os_signpost)
- Tiempos: parseo total y por hunk; render/frame p95/p99; materialización por rango.
- Memoria: cache de hunks/materializaciones.
- Eventos: activación LFM, abortar intraline, desactivar highlight.

Presupuestos
- Apertura (100k líneas): < 1.5 s visible.
- Expandir hunk (±50 líneas): < 200 ms.
- Scroll p95 < 16 ms/frame; p99 < 33 ms.

---

## Contratos de API (propuestos)

DiffEngine (actor)
- `diff(file: String, at repoPath: String, options: DiffOptions) -> AsyncThrowingStream<DiffHunk, Error>`
- `materialize(hunk: DiffHunk, rangeInHunk: Range<Int>?) async throws -> [DiffLine]`
- `stats(file: String, at repoPath: String) async throws -> DiffStats`

DiffOptions
- `contextLines: Int`
- `enableWordDiff: Bool`
- `enableSyntaxHighlight: Bool`
- `largeFileMode: LargeFileMode` (auto/manual on/off)
- `sideBySide: AutoFlag` (auto/on/off)

Tipos a reutilizar
- FileDiff, DiffHunk, DiffLine, DiffStats.

Extensiones sugeridas
- DiffHunk: `byteOffsets: (start: Int, end: Int)?`, `estimatedLineCount`, `isCollapsed`.
- DiffLine: `intralineRanges` opcional (para marcar adiciones/borrados dentro de la línea).

---

## Plan de implementación

M1 — Infra y LFM
- Parser streaming de `git diff` (state machine).
- DiffEngine + DiffOptions + DiffCache (LRU por coste).
- UI base (NSView “tiled” o NSTableView) con altura constante, plegado de hunks y navegación básica.
- Métricas con os_signpost.

M2 — UX y side‑by‑side
- Buscar, saltos next/prev, copiar selección.
- Side‑by‑side para tamaños medianos (fuera de LFM).
- Barra de estado con métricas y degradaciones activas.

M3 — Detalle y preferencias
- Intraline on‑demand (viewport) con presupuesto por línea.
- Syntax highlight on‑demand (viewport) con cancelación.
- Preferencias de usuario (umbrales LFM, toggles de word‑diff/highlight).

---

## Checklist de aceptación

Funcional
- Abre diffs de 100k líneas en < 1.5 s mostrando estructura y hunks.
- Scroll fluido; sin bloqueos visibles.
- Plegado/expandido de hunks estable; navegación next/prev funciona.
- Búsqueda encuentra términos en hunks materializados; en LFM, materializa por tramos si es necesario.
- Side‑by‑side desactivado en LFM; activable en archivos medianos.

Calidad
- Memoria bajo umbrales configurados; sin OOM.
- Intraline se aplica solo en viewport y respeta presupuesto; aborta si excede.
- Accesibilidad básica (VoiceOver, alto contraste).
- Métricas disponibles para diagnósticos.

---

## Integración con el repo actual

Reutilizar
- Modelos: FileDiff, DiffHunk, DiffLine, DiffStats.

Requerido (no presente en los archivos compartidos)
- ShellExecutor (ejecutar `git`), GitEngine/GitService (si centralizan diffs), AppState (selección de archivo/opciones).

Puntos de extensión
- Preferencias (UserDefaults/Settings) para umbrales y toggles.
- Hooks de cancelación al cambiar de archivo o pestaña.

---

## Riesgos y mitigación

- OOM por Strings grandes → almacenar bytes + offsets; materializar on‑demand; LRU estricta.
- UI con miles de subviews → dibujo directo (NSView/NSTableView) y altura constante.
- Parser lento en extremos → LFM/Extreme Mode; limitar intraline; cancelar tareas.
- Renames/copies caros → `--no-renames` en LFM.

---

## Pruebas

Funcionales
- Encabezados de hunk, líneas con UTF‑8 multibyte en límites de chunk, “No newline at end of file”.
- Binarios: detección y tratamiento.
- Parches con miles de hunks.

Rendimiento
- Datasets sintéticos (100k/500k líneas, líneas largas, JSON/minificados).
- Reales (logs, vendored code).
- Medición automatizada con signposts y asserts de presupuestos.

