# Molecules Guide - Atomic Design System

## Fase 3: Molecules - Componentes compuestos reutilizables

Esta guía documenta todos los molecules creados en el sistema de diseño atómico de GitMac.

---

## 📦 Display Molecules

Componentes para mostrar estados y información.

### 1. DSEmptyState

**Composición:** Icon + Title + Description + Action Button

```swift
DSEmptyState(
    icon: "tray",
    title: "No Items",
    description: "There are no items to display.",
    actionTitle: "Create Item",
    action: { print("Create tapped") }
)
```

**Casos de uso:**
- Listas vacías (no commits, no branches)
- Repositorios sin contenido
- Búsquedas sin resultados

---

### 2. DSLoadingState

**Composición:** Spinner + Message

```swift
DSLoadingState(
    message: "Loading commits...",
    style: .standard  // .inline, .standard, .large
)
```

**Casos de uso:**
- Carga de commits/branches
- Fetch/pull operations
- Cloning repositories

---

### 3. DSErrorState

**Composición:** Error Icon + Title + Message + Retry Button

```swift
DSErrorState(
    title: "Push Failed",
    message: "Could not push to remote repository.",
    retryTitle: "Retry",
    onRetry: { await retryPush() }
)
```

**Casos de uso:**
- Errores de red (push/pull failed)
- Conflictos de merge
- Permisos denegados

---

### 4. DSStatusBadge

**Composición:** Icon + Text Badge

```swift
DSStatusBadge(
    "Modified",
    icon: "pencil",
    variant: .warning,  // .success, .warning, .error, .info, .neutral, .primary
    size: .md           // .sm, .md, .lg
)
```

**Casos de uso:**
- Estado de archivos (M/A/D)
- Tags y branches
- Categorías y estados

---

### 5. DSHeader

**Composición:** Icon + Title + Subtitle + Actions

```swift
DSHeader(
    title: "Commits",
    subtitle: "156 commits in total",
    icon: "clock.arrow.circlepath"
) {
    DSButton(variant: .primary) {
        print("Action")
    } label: {
        Text("New Commit")
    }
}
```

**Casos de uso:**
- Headers de secciones (Commits, Branches, PRs)
- Paneles con acciones
- Encabezados de listas

---

## 📊 List Molecules

Componentes para listas y colecciones.

### 1. DSListItem

**Composición:** Leading View + Title + Subtitle + Trailing View

```swift
DSListItem(
    title: "main",
    subtitle: "Current branch"
) {
    DSIcon("arrow.triangle.branch", size: .md)
} trailing: {
    DSIcon("checkmark.circle.fill", size: .sm, color: .green)
} action: {
    print("Branch tapped")
}
```

**Casos de uso:**
- Lista de archivos
- Lista de branches/commits
- Lista de remotes/tags

---

### 2. DSExpandableItem

**Composición:** Expandable Row + Chevron + Badge + Content

```swift
DSExpandableItem(
    title: "Local Branches",
    subtitle: "12 branches",
    icon: "arrow.triangle.branch",
    badge: "12",
    isExpanded: true
) {
    VStack {
        DSListItem(title: "main")
        DSListItem(title: "develop")
    }
}
```

**Casos de uso:**
- Grupos de archivos (Modified/Staged)
- Categorías de branches (Local/Remote)
- Commits agrupados por autor

---

### 3. DSDraggableItem

**Composición:** Drag Handle + Title + Content

```swift
DSDraggableItem(
    id: "commit-123",
    title: "Fix authentication bug",
    subtitle: "a3f5b2c - John Doe"
) {
    DSStatusBadge("pick", variant: .success)
} onMove: { id in
    print("Reordered: \(id)")
}
```

**Casos de uso:**
- Interactive rebase (reorder commits)
- Reorder tasks/todos
- Custom list ordering

---

### 4. DSDropZone

**Composición:** Drop Area + Icon + Message

```swift
DSDropZone(
    title: "Stage Files",
    subtitle: "Drag files here to add them to staging area",
    icon: "plus.square.dashed",
    acceptedTypes: [.fileURL]
) { providers in
    stageFiles(providers)
    return true
}
```

**Casos de uso:**
- Stage/unstage files (drag & drop)
- Upload files
- Move items between categories

---

## 🎨 Design Tokens Used

Todos los molecules usan consistentemente:

- **Spacing:** `DesignTokens.Spacing` (.xs, .sm, .md, .lg, .xl)
- **Typography:** `DesignTokens.Typography` (.body, .caption, .headline, etc.)
- **Colors:** `AppTheme.*` (textPrimary, textSecondary, accent, etc.)
- **Corner Radius:** `DesignTokens.CornerRadius` (.sm, .md, .lg)
- **Animations:** `DesignTokens.Animation` (fastEasing, spring)

---

## 📝 Previews

Todos los molecules incluyen múltiples previews:

- **Total Previews:** 23 previews
- **Display Molecules:** 20 previews
- **List Molecules:** 18 previews

Para ver los previews, abre cualquier archivo en Xcode y presiona `Option + Cmd + Enter`.

---

## 🔄 Next Steps: Organisms (Fase 4)

Los molecules se combinarán para crear organisms:

1. **FileListOrganism** = DSHeader + DSExpandableItem + DSListItem
2. **CommitHistoryOrganism** = DSHeader + DSListItem + DSLoadingState
3. **StagingAreaOrganism** = DSHeader + DSDropZone + DSExpandableItem
4. **BranchManagerOrganism** = DSHeader + DSExpandableItem + DSListItem

---

## 📊 Statistics

- **Total Files:** 9 molecules
- **Total Lines:** 1,590 lines of code
- **Display Molecules:** 5 components (621 lines)
- **List Molecules:** 4 components (969 lines)
- **Previews:** 23 previews total
- **ViewBuilders:** Generic and flexible
- **Animations:** Smooth and native
- **Drag & Drop:** Full macOS support

---

**Created:** December 28, 2025
**Atomic Design Phase:** Level 3 (Molecules)
**Next Phase:** Level 4 (Organisms)
