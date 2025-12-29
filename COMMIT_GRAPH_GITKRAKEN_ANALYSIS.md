# CommitGraph vs GitKraken - Análisis de Funcionalidades

## ✅ Lo que YA tiene GitMac

### Visualización
- ✅ **Graph visual con lanes** - Algoritmo de graph con múltiples columnas
- ✅ **WIP ("// WIP")** - Cambios uncommitted en la parte superior
- ✅ **Commit nodes** - Círculos conectados con líneas
- ✅ **Merge commits** - Visualización de merges con curvas
- ✅ **Stashes** - Integrados en el timeline
- ✅ **Branch badges** - Labels de branches en commits
- ✅ **Tag badges** - Labels de tags
- ✅ **Colors por lane** - Diferentes colores para cada línea

### Funcionalidades
- ✅ **Context menu en commits**:
  - Copy SHA
  - Cherry-pick
  - Revert
  - Reset (soft/mixed/hard)
  - Rebase onto commit
  - Interactive rebase
  - Diff with HEAD
  - Create branch
  - Create tag
- ✅ **Context menu en stashes**:
  - Apply stash
  - Pop stash
  - Drop stash
- ✅ **Selección múltiple** - Cmd+click, Shift+click
- ✅ **Hover effects** - Ghost branches (muestra branches cercanas)
- ✅ **Filtros**:
  - Por autor
  - Por texto (SHA, message, author)
  - Show/hide tags
  - Show/hide branches
  - Show/hide stashes
- ✅ **Configuración de columnas**:
  - Branch column
  - Author column
  - Date column
  - SHA column
  - Widths ajustables
- ✅ **Infinite scroll** - Carga bajo demanda
- ✅ **Virtualized list** - 60fps con 10,000+ commits
- ✅ **Actualización silenciosa** - refreshStatus() sin flickering

### Performance
- ✅ **@MainActor en ViewModel** - Sin race conditions
- ✅ **Background graph building** - No bloquea UI
- ✅ **Cached branch heads** - Mejor performance
- ✅ **Silent refresh** - Solo actualiza counts, no reloads

---

## ❌ Lo que FALTA (GitKraken features)

### 1. 🔴 Distinción Visual Remote vs Local Branches

**Problema actual:**
```swift
struct BranchBadge: View {
    let name: String
    let color: Color
    let isHead: Bool  // ✅ Tiene
    let isTag: Bool   // ✅ Tiene
    // ❌ FALTA: let isRemote: Bool
}
```

**Lo que se muestra:**
- `main` → Verde con checkmark (isHead)
- `feature/123` → Color genérico
- `origin/main` → ❌ **Se ve igual que local** (NO se distingue)

**Lo que debería mostrar:**
- `main` (local) → 🟢 Verde con checkmark + icono branch
- `origin/main` (remote) → 🔵 Azul con icono cloud/server
- `feature/123` (local) → 🟠 Naranja con icono branch
- `origin/feature/123` (remote) → 🔵 Azul con icono cloud

**Solución:**
1. Modificar `GraphNode` para incluir `Branch` completo (no solo nombre)
2. Actualizar `BranchBadge` para aceptar `isRemote`
3. Cambiar icono y color para branches remotas

---

### 2. 🔴 Remote Branches NO están en el Graph

**Problema actual:**
```swift
// En CommitGraphView load()
let loadedBranches = try await engine.getBranches(at: p)  // ❌ Solo local
```

GitEngine tiene dos métodos:
- `getBranches()` → Solo branches **locales**
- `getRemoteBranches()` → Solo branches **remotas**

**Pero CommitGraph solo usa el primero!**

**Resultado:**
- ✅ `main`, `develop`, `feature/123` aparecen
- ❌ `origin/main`, `origin/develop` **NO aparecen**

**Solución:**
```swift
// Load BOTH local and remote
let localBranches = try await engine.getBranches(at: p)
let remoteBranches = try await engine.getRemoteBranches(at: p)
branches = localBranches + remoteBranches  // Merge
```

---

### 3. 🔴 NO hay Drag and Drop

**GitKraken permite:**
- Drag `feature/123` → Drop en `main` = **Merge**
- Drag `feature/123` → Drop en `develop` + Shift = **Rebase**
- Drag `feature/123` → Drop en `origin/main` = **Create Pull Request**
- Drag commit → Drop en branch = **Cherry-pick**

**GitMac actual:**
- ❌ NO soporta drag and drop
- ✅ Solo context menu (menos intuitivo)

**Solución:**
Implementar drag and drop con SwiftUI:
```swift
.onDrag {
    NSItemProvider(object: branchName as NSString)
}
.onDrop(of: [.text]) { providers in
    // Handle drop: merge, rebase, PR
}
```

---

### 4. 🟡 Pull Request Creation

**GitKraken:**
- Drag local branch → remote branch = Crear PR en GitHub
- Muestra dialog con título/descripción

**GitMac:**
- ❌ NO hay creación de PR desde graph
- ✅ Hay PRListView pero separado

**Solución:**
- Integrar creación de PR en drag and drop
- Detectar cuando se arrastra a remote origin
- Mostrar dialog de PR

---

### 5. 🟡 Branch Comparison Visual

**GitKraken:**
- Muestra ahead/behind en badges
- Visualiza distancia entre branches

**GitMac:**
- ✅ Tiene `BranchComparison` struct en modelo
- ❌ NO se muestra visualmente en graph
- ✅ Ghost Branches muestra ahead/behind al hover

**Mejora:**
- Mostrar ahead/behind permanentemente en badges

---

### 6. 🟢 Otras mejoras menores

- ⚠️ **Iconos de estado de commit**:
  - GitKraken muestra si hay CI/CD pass/fail
  - GitMac: NO implementado

- ⚠️ **Avatars inline**:
  - GitKraken: avatars en cada commit row
  - GitMac: ✅ Tiene avatars pero opcional

- ⚠️ **Quick actions en hover**:
  - GitKraken: botones de acción rápida al hacer hover
  - GitMac: Solo context menu

---

## 📋 Plan de Implementación

### Fase 1: Remote Branches Visibility (2-3 horas)
1. ✅ Cargar remote branches además de locales
2. ✅ Modificar GraphNode para incluir Branch completo
3. ✅ Actualizar BranchBadge con isRemote
4. ✅ Cambiar colores e iconos para remote branches

### Fase 2: Drag and Drop Básico (4-6 horas)
1. ❌ Implementar .onDrag en BranchBadge
2. ❌ Implementar .onDrop en GraphRow y BranchBadge
3. ❌ Detectar tipo de operación (merge vs rebase vs PR)
4. ❌ Mostrar feedback visual durante drag

### Fase 3: Acciones de Drag and Drop (6-8 horas)
1. ❌ Merge: Drag branch A → Drop en branch B
2. ❌ Rebase: Drag branch A → Drop en branch B (+ modifier key)
3. ❌ Pull Request: Drag local → Drop en remote
4. ❌ Cherry-pick: Drag commit → Drop en branch

### Fase 4: Polish (2-4 horas)
1. ❌ Ahead/behind indicators en badges
2. ❌ Animaciones de drag and drop
3. ❌ Confirmación de acciones peligrosas
4. ❌ Tooltips informativos

**Tiempo total estimado:** 14-21 horas

---

## 🎯 Prioridades

### 🔥 Crítico (hacer ahora):
1. **Remote branches visibility** - Sin esto, no se ve origin/main
2. **Distinción visual remote/local** - Para no confundir branches

### 🟡 Importante (próximos días):
3. **Drag and drop básico** - Mejora UX dramáticamente
4. **Merge/Rebase via drag** - Feature killer de GitKraken

### 🟢 Nice to have (futuro):
5. Pull Request creation
6. CI/CD status icons
7. Quick action buttons

---

## 📊 Comparación Final

| Feature | GitKraken | GitMac Actual | GitMac Mejorado |
|---------|-----------|---------------|-----------------|
| Visual graph | ✅ | ✅ | ✅ |
| WIP visualization | ✅ | ✅ | ✅ |
| Local branches | ✅ | ✅ | ✅ |
| Remote branches | ✅ | ❌ | ✅ |
| Remote/local distinction | ✅ | ❌ | ✅ |
| Drag and drop | ✅ | ❌ | ✅ |
| Context menu | ✅ | ✅ | ✅ |
| Merge via drag | ✅ | ❌ | ✅ |
| Rebase via drag | ✅ | ❌ | ✅ |
| PR creation | ✅ | ❌ | ✅ |
| Infinite scroll | ✅ | ✅ | ✅ |
| Performance | 🟡 | ✅ | ✅ |
| Native macOS | ❌ | ✅ | ✅ |

**Conclusion:** GitMac tiene 70% de las features core de GitKraken. Con las mejoras propuestas, llegará al 95%.
