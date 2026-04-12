# Fix: Push After Commit & Checkout Real-time Bugs

**Fecha:** 2025-01-18
**Estado:** IMPLEMENTADO

---

## Resumen Ejecutivo

Dos bugs relacionados con la sincronización de estado en GitMac:

1. **Push no funciona después de commit** - El `aheadCount` no se actualiza después del commit, causando que push no suba nada
2. **Checkout no actualiza UI con real-time** - Race condition entre refresh manual y file watcher

---

## Bug 1: Push No Funciona Después de Commit

### Causa Raíz

`StagingViewModel.commit()` solo llama `loadStatus()` que actualiza archivos staged/unstaged, pero NO actualiza `branch.upstream.ahead`. El push se ejecuta pero git dice "Everything up-to-date".

### Solución

Agregar notificación `.branchDidChange` después del commit y crear método ligero `refreshBranchStatus()`.

### Archivos a Modificar

#### 1. `GitMac/Core/Extensions/Notification.Name+Extensions.swift`

Agregar nueva notificación:

```swift
extension Notification.Name {
    // ... existentes ...

    /// Posted when a branch's ahead/behind status may have changed (after commit, pull, etc.)
    static let branchDidChange = Notification.Name("branchDidChange")
}
```

#### 2. `GitMac/Core/Services/GitService.swift`

Agregar método ligero para refresh de branch info:

```swift
// MARK: - Lightweight Refresh

/// Refresh solo ahead/behind del branch actual (~50ms vs ~500ms full refresh)
func refreshBranchStatus() async throws {
    guard var repo = currentRepository else { return }
    guard let path = repo.path else { return }

    // Recargar solo el branch actual con su upstream info
    let branches = try await engine.getBranches(at: path)
    if let currentBranch = branches.first(where: { $0.isHead }) {
        repo.currentBranch = currentBranch
        currentRepository = repo
    }

    // Invalidar cache de branches para que la próxima lectura sea fresca
    branchesCache.invalidate()

    // Notificar a las vistas
    NotificationCenter.default.post(name: .repositoryDidRefresh, object: path)
}
```

#### 3. `GitMac/App/ViewModels/StagingViewModel.swift`

Modificar `commit()` y `commitAsync()`:

```swift
func commit(message: String, onSuccess: @escaping () -> Void) {
    guard let path = currentPath, !message.isEmpty else { return }
    Task {
        do {
            let commit = try await engine.commit(message: message, at: path)
            let shortSHA = String(commit.sha.prefix(7))
            await loadStatus(at: path)

            // NEW: Notificar que el branch cambió (ahead count incrementó)
            NotificationCenter.default.post(name: .branchDidChange, object: path)

            onSuccess()
            NotificationManager.shared.success("Commit completed", detail: "SHA: \(shortSHA)")
        } catch {
            NotificationManager.shared.error("Commit failed", detail: error.localizedDescription)
        }
    }
}

func commitAsync(message: String) async -> Bool {
    guard let path = currentPath, !message.isEmpty else { return false }
    do {
        let commit = try await engine.commit(message: message, at: path)
        let shortSHA = String(commit.sha.prefix(7))
        await loadStatus(at: path)

        // NEW: Notificar que el branch cambió
        NotificationCenter.default.post(name: .branchDidChange, object: path)

        NotificationManager.shared.success("Commit completed", detail: "SHA: \(shortSHA)")
        return true
    } catch {
        NotificationManager.shared.error("Commit failed", detail: error.localizedDescription)
        return false
    }
}
```

#### 4. `GitMac/App/ContentView.swift`

Agregar listener en `GitOperationListeners`:

```swift
struct GitOperationListeners: ViewModifier {
    @EnvironmentObject var appState: AppState

    func body(content: Content) -> some View {
        content
            // ... existentes ...

            // NEW: Refresh branch status cuando cambia (después de commit)
            .onReceive(NotificationCenter.default.publisher(for: .branchDidChange)) { notification in
                guard let path = notification.object as? String,
                      path == appState.currentRepository?.path else { return }
                Task {
                    try? await appState.gitService.refreshBranchStatus()
                }
            }
    }
}
```

---

## Bug 2: Checkout No Actualiza UI con Real-time

### Causa Raíz

`performCheckout()` en `SidebarComponents.swift` usa `ShellExecutor` directamente y luego llama `appState.refresh()`. Pero el file watcher también detecta el cambio en HEAD y dispara otro refresh. Los dos refreshes compiten (race condition).

### Solución

Coordination layer que pausa el watcher durante operaciones manuales.

### Archivos a Modificar

#### 1. `GitMac/Core/Services/GitService.swift`

Agregar coordinación de operaciones:

```swift
// MARK: - Operation Coordination

/// Flag para indicar que hay una operación manual en progreso
private var isManualOperationInProgress = false

/// Ejecutar operación con watcher temporalmente ignorado
/// Evita race conditions entre refresh manual y watcher
func withSuspendedWatcher<T>(_ operation: () async throws -> T) async rethrows -> T {
    isManualOperationInProgress = true
    defer { isManualOperationInProgress = false }
    return try await operation()
}

// Modificar handleChangeSignal existente:
private func handleChangeSignal(_ signal: GitRepositoryWatcher.ChangeSignal) async {
    // Ignorar señales del watcher durante operaciones manuales
    guard !isManualOperationInProgress else { return }

    // ... resto del código existente sin cambios ...
}
```

#### 2. `GitMac/Core/Services/GitService.swift`

Agregar/modificar método checkout:

```swift
// MARK: - Branch Operations

/// Checkout a branch with proper watcher coordination
func checkout(branch: String) async throws {
    guard let path = currentRepository?.path else {
        throw GitServiceError.noRepository
    }

    try await withSuspendedWatcher {
        try await engine.checkout(branch: branch, at: path)
        try await refresh()
    }
}

/// Checkout con auto-stash si hay cambios
func checkoutWithAutoStash(branch: String) async throws {
    guard let path = currentRepository?.path else {
        throw GitServiceError.noRepository
    }

    try await withSuspendedWatcher {
        // Verificar si hay cambios
        let status = try await engine.getStatus(at: path)
        let hasChanges = !status.staged.isEmpty || !status.unstaged.isEmpty

        if hasChanges {
            _ = try await engine.stash(at: path)
        }

        try await engine.checkout(branch: branch, at: path)

        if hasChanges {
            try await engine.stashPop(at: path, index: 0)
        }

        try await refresh()
    }
}
```

#### 3. `GitMac/App/Panels/Left/SidebarComponents.swift`

Modificar `performCheckout` y `performCheckoutWithAutoStash` para usar GitService:

```swift
// Reemplazar el código existente de performCheckout (~línea 233-274)

private func performCheckout(branch: Branch) {
    Task {
        do {
            try await appState.gitService.checkout(branch: branch.name)
            NotificationManager.shared.success(
                "Switched to \(branch.name)",
                detail: "Checkout completed"
            )
        } catch {
            NotificationManager.shared.error(
                "Checkout failed",
                detail: error.localizedDescription
            )
        }
    }
}

private func performCheckoutWithAutoStash(branch: Branch) {
    Task {
        do {
            try await appState.gitService.checkoutWithAutoStash(branch: branch.name)
            NotificationManager.shared.success(
                "Switched to \(branch.name)",
                detail: "Changes stashed and restored"
            )
        } catch {
            NotificationManager.shared.error(
                "Checkout failed",
                detail: error.localizedDescription
            )
        }
    }
}
```

**Eliminar:** El código que usa `ShellExecutor` directamente para checkout (~líneas 240-270).

---

## Orden de Implementación

1. **Notification.Name+Extensions.swift** - Agregar `.branchDidChange`
2. **GitService.swift** - Agregar `refreshBranchStatus()` y `withSuspendedWatcher()`
3. **GitService.swift** - Agregar/modificar `checkout()` y `checkoutWithAutoStash()`
4. **StagingViewModel.swift** - Modificar `commit()` y `commitAsync()`
5. **ContentView.swift** - Agregar listener para `.branchDidChange`
6. **SidebarComponents.swift** - Refactorizar checkout para usar GitService

---

## Testing

### Bug 1 - Push después de commit
1. Hacer cambios en un archivo
2. Stage los cambios
3. Commit
4. Verificar que el badge de "1 commit ahead" aparece inmediatamente
5. Push
6. Verificar que el commit se sube al remote

### Bug 2 - Checkout con real-time
1. Abrir repo con real-time habilitado (file watcher activo)
2. Hacer checkout a otra branch
3. Verificar que la UI muestra la nueva branch inmediatamente
4. Verificar que no hay parpadeos ni estados inconsistentes

---

## Performance Esperado

| Operación | Antes | Después |
|-----------|-------|---------|
| Commit → Push ready | ~500ms (full refresh) o nunca | ~50ms (branch refresh) |
| Checkout → UI update | Variable (race condition) | ~200ms (determinístico) |

---

## Riesgos y Mitigaciones

| Riesgo | Mitigación |
|--------|------------|
| `withSuspendedWatcher` podría dejar el flag activo si hay error | Usar `defer` para garantizar reset |
| Notificación `.branchDidChange` podría disparar múltiples veces | El listener verifica que el path coincida |
| `refreshBranchStatus()` podría fallar silenciosamente | Usar `try?` es aceptable, no es crítico |
