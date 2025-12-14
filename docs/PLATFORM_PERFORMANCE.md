# GitMac Platform Performance Guide

## Principios Arquitectónicos

1. **Serializar y centralizar** todo acceso a Git en un único actor por repositorio (RepositoryContext), con coalescing de refresh y cancelación. Evita spawns redundantes y estados inconsistentes.

2. **Comandos plumbing y formatos compactos**: porcelain v2 `-z`, `for-each-ref -z`, `rev-list`, `cat-file --batch`. Menos I/O y parsing.

3. **UI virtualizada real**: NSTableView/NSCollectionView o NSView "tiled" (dibujo directo) para scroll 60 FPS; altura constante y sin subviews por línea.

4. **Observabilidad y backpressure**: AsyncSequence para flujos largos (log/diff), buffers limitados, `os_signpost` en parse/render. Degradación progresiva (Large File Mode) para archivos gigantes.

5. **File watching real** (FSEvents) sobre `.git` y working dir para refrescos incrementales (status/HEAD/refs) en lugar de recargar todo.

---

## Estado Actual y Cuellos de Botella

### Capa Git (ShellExecutor, GitEngine, GitService)

#### ShellExecutor (`Core/Utils/ShellExecutor.swift`)

**Actual:**
- Ejecuta con `waitUntilExit` (bloquea hilo hasta terminar)
- Timeout genérico de 60s para todos los comandos
- Environment básico (GIT_PAGER, LANG)

**Mejoras necesarias:**
- [ ] Añadir `GIT_OPTIONAL_LOCKS=0` (evita locks en lecturas)
- [ ] Añadir `GIT_TERMINAL_PROMPT=0` (evita cuelgues de credenciales)
- [ ] Timeouts adaptados por comando:
  - `status`: 5s
  - `fetch/pull`: 60-600s (según red)
  - `diff streaming`: sin límite (usa cancelación)
- [ ] Kill escalado: SIGTERM → esperar 2s → SIGKILL
- [ ] Preferir `executeWithStreaming` para log/diff
- [ ] Exponer variante con `AsyncThrowingStream<String>` y backpressure

#### GitEngine (`Core/Git/GitEngine.swift`)

**getStatus (línea 378):**
- Actual: `--porcelain=v1` + dos diffs `--numstat` extra
- Problema: Separadores ambiguos con nombres de archivo raros
- [ ] Cambiar a `git status --porcelain=v2 -b -z` (más completo, robusto con NUL)
- [ ] Calcular stats bajo demanda o con `-z` para nombres con tabs

**getCommits (línea 293):**
- Actual: Parsea con separador `|` (riesgo si aparece en mensaje)
- [ ] Usar `%x00` como separador y `-z` para nombres
- [ ] Añadir `--topo-order --date-order` para orden topológico
- [ ] Considerar `rev-list` con pretty y NUL separators

**getDiff (línea 976):**
- Actual: Devuelve `String` completo (peligroso en archivos gigantes)
- [ ] Usar `executeWithStreaming` + parser streaming
- [ ] Ver estrategia en `DIFFVIEW_PERFORMANCE.md`

**getCommitFiles (línea 1013):**
- Actual: Múltiples invocaciones (name-status + numstat)
- [ ] Unificar con una sola invocación usando `-z` y parseo único
- [ ] Considerar `diff-tree` con formato combinado

#### GitService (`Core/Services/GitService.swift`)

**Actual:**
- `@MainActor` con un único `currentRepository` para toda la app
- Caches TTL no "scoped" por repositorio
- Watcher único que se reconfigura al cambiar de repo

**Problemas:**
- Con múltiples tabs, obliga a reconfigurar watcher y caches al cambiar
- Posible contaminación de caches entre repositorios

**Solución:**
- [ ] Crear `RepositoryContext` (actor) por repositorio
- [ ] GitService se convierte en orquestador de contexts por path
- [ ] Cada context tiene: watcher propio, caches TTL por path, ShellExecutor propio

### Watchers (`Core/Utils/FileWatcher.swift`)

**Actual (GitRepositoryWatcher):**
- FSEvents para working dir con exclusiones
- FileWatcher (DispatchSource) para HEAD, index, .git
- Debounce de 100-300ms
- `hasChanges` flag que dispara refresh completo

**Mejoras necesarias:**
- [ ] Emitir señales diferenciadas por tipo de cambio:
  - `status` → cambios en index/working dir
  - `refs` → cambios en `.git/refs/`
  - `head` → cambios en HEAD (checkout)
  - `stash` → cambios en stash reflog
- [ ] Refresh incremental según el tipo de cambio
- [ ] Observar `.git/logs/HEAD` para ahead/behind

### UI (SwiftUI + AppKit)

#### CommitGraphView (`Features/CommitGraph/CommitGraphView.swift`)

**Problemas detectados:**
- VM usa GitEngine directamente, saltándose GitService y su caching
- Para listas muy largas (>5000 commits), LazyVStack puede tener jank

**Solución:**
- [ ] Usar GitService/RepositoryContext para unificar serialización y caches
- [ ] Considerar NSTableView para listas muy largas
- [ ] Mantener altura fija y Equatable para filas

#### DiffView

**Estado:** Parcialmente implementado (ver `DIFFVIEW_PERFORMANCE.md`)
- [ ] Implementar parser streaming (state machine)
- [ ] NSView "tiled" o NSTableView con altura constante
- [ ] Large File Mode (LFM) y materialización on-demand

#### MermaidDiagramView (`Features/Markdown/MermaidDiagramView.swift`)

**Problema:** `updateNSView` recarga todo el HTML en cada actualización

**Solución:**
- [ ] Reusar WKWebView
- [ ] Re-render mermaid vía `evaluateJavaScript` para evitar recargas completas

### Red y Servicios Externos

#### GitHubService (`Core/Services/GitHubService.swift`)

**Actual:**
- Usa `URLSession.shared` sin cache configurada
- Sin ETag/If-None-Match
- Sin backoff en rate limit

**Mejoras:**
- [ ] Configurar `URLSession` con `URLCache` (20 MB RAM / 200 MB disco)
- [ ] Implementar ETag/If-None-Match y manejo de 304
- [ ] Backoff exponencial con jitter en 403/429
- [ ] Reusar `JSONDecoder` (singleton)
- [ ] Limitar concurrencia de peticiones

#### AvatarService (`Core/Services/AvatarService.swift`)

**Actual (excelente base):**
- Actor con LRU bounded
- Coalescing de requests pendientes
- Preload con límite

**Mejoras:**
- [ ] Throttle de escrituras a disco (`saveCachedMappings`) con debounce 1-2s
- [ ] TTL para mappings en disco
- [ ] Límite de concurrencia en preload

---

## Presupuestos de Rendimiento

### Tiempos Objetivo

| Operación | Frío | Caliente |
|-----------|------|----------|
| status + refs | <150ms | <60ms |
| primer snapshot grafo (1000 commits) | <600ms | - |
| scroll p95 | - | <16ms |
| diff 100k líneas (estructura visible) | <1.5s | - |
| expandir hunk (±50 líneas) | - | <200ms |

### Memoria

- Diff extra: <100 MB por archivo gigante
- Cache de avatares: máx 200 URLs en memoria
- Cache de branches/tags: scoped por repo, TTL-based

---

## Arquitectura Objetivo

### Flujo Ideal

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   ContentView   │────▶│    GitService    │────▶│RepositoryContext│
│   (SwiftUI)     │     │  (Orquestador)   │     │    (Actor)      │
└─────────────────┘     └──────────────────┘     └─────────────────┘
                                                         │
                              ┌───────────────┬──────────┴──────────┬───────────────┐
                              ▼               ▼                     ▼               ▼
                        ┌──────────┐   ┌───────────┐         ┌───────────┐   ┌──────────┐
                        │GitEngine │   │  Watcher  │         │  Caches   │   │Snapshots │
                        │(Commands)│   │(FSEvents) │         │(TTL/LRU)  │   │(Estado)  │
                        └──────────┘   └───────────┘         └───────────┘   └──────────┘
```

### RepositoryContext (Actor)

Cada repositorio abierto tiene su propio contexto con:
- `ShellExecutor` propio
- Caches TTL por path (branches, tags, remotes, stashes)
- Watcher propio
- Snapshot incremental (head, refs, status, stashes, commits paginados)

### API de Alto Nivel

```swift
actor RepositoryContext {
    // Estado
    func snapshot() async throws -> RepositorySnapshot
    func status() async throws -> RepositoryStatus
    func refs() async throws -> RepositoryRefs

    // Paginación
    func commits(page: Int, limit: Int) async throws -> [Commit]

    // Streaming
    func diff(file: String, staged: Bool) -> AsyncThrowingStream<DiffHunk, Error>
}
```

### Refresh Incremental

| Cambio detectado | Refresh |
|------------------|---------|
| `.git/index`, working dir | Solo status |
| `.git/HEAD`, `.git/refs/` | ahead/behind + commits nuevos (prepend) |
| `.git/refs/stash` | Solo stashes |

---

## Instrumentación

### os_signpost Points

```swift
import os.signpost

let gitLog = OSLog(subsystem: "com.gitmac", category: "git")
let uiLog = OSLog(subsystem: "com.gitmac", category: "ui")

// Puntos críticos:
os_signpost(.begin, log: gitLog, name: "git.spawn", "%{public}s", command)
os_signpost(.begin, log: gitLog, name: "git.parse", "commits")
os_signpost(.begin, log: gitLog, name: "git.snapshot")
os_signpost(.begin, log: uiLog, name: "diff.parse")
os_signpost(.begin, log: uiLog, name: "diff.render")
os_signpost(.begin, log: uiLog, name: "graph.build")
```

---

## Backlog Priorizado (MoSCoW)

### Must Have

- [ ] **RepositoryContext** (actor por repo) y GitService como orquestador multi-repo
- [ ] **GitEngine**: status porcelain v2 `-z`, commits con `%x00`/`-z`, diff streaming
- [ ] **GitRepositoryWatcher** con FSEvents + coalescing + señales diferenciadas
- [ ] **CommitGraphView** reencaminado a GitService/contexts (no GitEngine directo)
- [ ] Instrumentación `os_signpost` y límites de buffers en streams

### Should Have

- [ ] `URLCache` + ETag en GitHubService; throttling de AvatarService persistencia
- [ ] DiffView base (NSView/NSTableView) con LFM y materialización on-demand
- [ ] NSTableView para listas muy largas si se observa jank en SwiftUI

### Could Have

- [ ] Cache de metadatos de commits en disco para relanzados
- [ ] Búsqueda incremental y minimapa en DiffView
- [ ] Panel de rendimiento (debug) con métricas y degradaciones activas

### Won't Have (por ahora)

- Editor de texto completo en DiffView
- Word-diff global en archivos gigantes

---

## Riesgos y Mitigación

| Riesgo | Mitigación |
|--------|------------|
| OOM por Strings gigantes | Streaming + materialización on-demand + LRU por bytes |
| Bloqueos UI | NSTableView/NSView "tiled", altura fija, evitar subviews por línea |
| Parser lento en extremos | Large File Mode + "Extreme mode" (solo cabeceras) |
| Rate limit GitHub | ETag + URLCache + backoff exponencial |
| Mezcla de estados entre repos | RepositoryContext aislado por path |

---

## Tipos Faltantes (Referenciados)

Para cerrar el círculo de la arquitectura, estos tipos necesitan implementación o actualización:

- [x] `KeychainManager` - Implementado
- [x] `GitRepositoryWatcher` - Implementado (mejorar señales diferenciadas)
- [x] `CacheWithTTL<T>` - Implementado
- [x] `PatchManipulator` - Implementado
- [x] `Worktree` - Implementado
- [x] `NotificationManager` - Implementado
- [x] `GitKrakenTheme` y `Color(hex:)` - Implementado
- [ ] `RepositoryContext` - **Por implementar**
- [ ] `DiffEngine` (actor streaming) - **Por implementar**

---

## Checklist de Aceptación

### Funcional

- [ ] Abre repositorios grandes (>10k commits) sin bloqueos visibles
- [ ] Múltiples tabs con repositorios diferentes no mezclan estado
- [ ] Refresh incremental funciona (status/refs/commits)
- [ ] Diffs de 100k líneas cargan en <1.5s mostrando estructura

### Calidad

- [ ] Scroll fluido (p95 <16ms/frame) en listas largas
- [ ] Memoria bajo umbrales configurados
- [ ] Sin fugas de memoria al cambiar de repositorio/tab
- [ ] Métricas disponibles via os_signpost

---

## Referencias

- [WWDC 2018 - iOS Memory Deep Dive](https://developer.apple.com/videos/play/wwdc2018/416/)
- [Git Porcelain v2 Format](https://git-scm.com/docs/git-status#_porcelain_format_version_2)
- [FSEvents Programming Guide](https://developer.apple.com/library/archive/documentation/Darwin/Conceptual/FSEvents_ProgGuide/)
- `DIFFVIEW_PERFORMANCE.md` - Estrategia detallada para DiffView
