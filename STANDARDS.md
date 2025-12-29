# GitMac Development Standards

**Version:** 1.0
**Last Updated:** December 28, 2025

Este documento define los estándares de desarrollo para GitMac. Todo el código debe cumplir con estas reglas para mantener consistencia, performance y mantenibilidad.

---

## Table of Contents

1. [Design System Rules](#design-system-rules)
2. [Performance Guidelines](#performance-guidelines)
3. [Component Architecture](#component-architecture)
4. [Naming Conventions](#naming-conventions)
5. [Plugin System](#plugin-system)
6. [Code Review Checklist](#code-review-checklist)
7. [Anti-patterns](#anti-patterns)
8. [Resources](#resources)

---

## Design System Rules

### Regla #1: NUNCA Hardcodear Valores

Esta es la regla más importante. **Todos los valores visuales deben usar el Design System.**

#### ❌ INCORRECTO:

```swift
Text("Hello")
    .font(.system(size: 13))
    .padding(.horizontal, 12)
    .cornerRadius(6)
    .foregroundColor(.blue)
```

#### ✅ CORRECTO:

```swift
Text("Hello")
    .font(DesignTokens.Typography.body)
    .padding(.horizontal, DesignTokens.Spacing.md)
    .cornerRadius(DesignTokens.CornerRadius.md)
    .foregroundColor(AppTheme.accent)
```

### Design Tokens Reference

#### Typography: `DesignTokens.Typography.*`

**Scale Hierarchy:**
- `largeTitle` - 28px bold
- `title1` - 22px bold
- `title2` - 20px
- `title3` - 17px
- `headline` - 14px semibold
- `subheadline` - 15px
- `body` - 13px (base)
- `callout` - 12px
- `caption` - 11px
- `caption2` - 10px

**Git-Specific Semantic:**
- `commitMessage` - 13px
- `commitHash` - 11px monospaced
- `branchName` - 12px medium
- `diffLine` - 12px monospaced

#### Spacing: `DesignTokens.Spacing.*` (Grid 4pt)

- `xxs` - 2px
- `xs` - 4px
- `sm` - 8px (base)
- `md` - 12px
- `lg` - 16px
- `xl` - 24px
- `xxl` - 32px

#### Sizes: `DesignTokens.Size.*`

**Icons:**
- `iconXS` - 12px
- `iconSM` - 14px
- `iconMD` - 16px
- `iconLG` - 20px
- `iconXL` - 24px

**Buttons:**
- `buttonHeightSM` - 24px
- `buttonHeightMD` - 28px
- `buttonHeightLG` - 32px

**Avatars:**
- `avatarXS` - 16px
- `avatarSM` - 20px
- `avatarMD` - 24px
- `avatarLG` - 32px
- `avatarXL` - 40px

#### Corner Radius: `DesignTokens.CornerRadius.*`

- `none` - 0
- `sm` - 4px
- `md` - 6px
- `lg` - 8px
- `xl` - 12px

#### Animation: `DesignTokens.Animation.*`

**Durations:**
- `instant` - 0.1s
- `fast` - 0.2s
- `normal` - 0.3s
- `slow` - 0.5s

**Presets:**
- `defaultEasing` - easeInOut(0.3s)
- `fastEasing` - easeInOut(0.2s)
- `slowEasing` - easeInOut(0.5s)
- `spring` - spring(response: 0.3, damping: 0.7)

#### Colors: `AppTheme.*` SIEMPRE

**Text:**
- `textPrimary` - Texto principal
- `textSecondary` - Texto secundario
- `textMuted` - Texto desactivado/placeholder

**Backgrounds:**
- `background` - Fondo principal
- `backgroundSecondary` - Fondo secundario (paneles)
- `backgroundTertiary` - Fondo terciario (cards)
- `panel` - Panel con opacidad
- `toolbar` - Toolbar background
- `sidebar` - Sidebar background

**Interactive:**
- `accent` - Color principal de la app
- `accentHover` - Hover state del accent
- `hover` - Background hover genérico
- `selection` - Background selection
- `border` - Bordes

**Semantic:**
- `success` - Verde para acciones positivas
- `error` - Rojo para errores
- `warning` - Amarillo para advertencias
- `info` - Azul para información

**Git Status:**
- `gitAdded` - Archivos añadidos
- `gitModified` - Archivos modificados
- `gitDeleted` - Archivos eliminados
- `gitConflict` - Conflictos

**Branches:**
- `branchLocal` - Rama local
- `branchRemote` - Rama remota
- `branchCurrent` - Rama actual

**Diff Colors (Kaleidoscope-style):**
- `diffAddition` - Verde para líneas añadidas
- `diffDeletion` - Rojo para líneas eliminadas
- `diffChange` - Azul para líneas modificadas
- `diffAdditionBg` - Fondo verde con opacidad
- `diffDeletionBg` - Fondo rojo con opacidad
- `diffChangeBg` - Fondo azul con opacidad

### Componentes del Design System

**Todos los componentes del Design System usan el prefijo `DS`**

#### Atoms (Primitivos)

**Buttons:**
- `DSButton` - Botón estándar con estados (default, primary, destructive, ghost)
- `DSIconButton` - Botón solo con icono
- `DSTabButton` - Botón para tabs
- `DSToolbarButton` - Botón para toolbar
- `DSCloseButton` - Botón de cierre estándar
- `DSLinkButton` - Botón estilo link/hipervínculo

**Inputs:**
- `DSTextField` - Campo de texto
- `DSSecureField` - Campo de contraseña
- `DSTextEditor` - Editor de texto multilínea
- `DSPicker` - Selector dropdown
- `DSToggle` - Switch on/off
- `DSSearchField` - Campo de búsqueda con icono

**Display:**
- `DSText` - Texto con estilos predefinidos
- `DSIcon` - Icono con tamaños estándar
- `DSBadge` - Badge/pill para contadores
- `DSAvatar` - Avatar circular
- `DSDivider` - Separador horizontal/vertical
- `DSSpacer` - Espaciador flexible

**Feedback:**
- `DSSpinner` - Spinner de carga
- `DSProgressBar` - Barra de progreso
- `DSSkeletonBox` - Skeleton loader
- `DSTooltip` - Tooltip informativo

#### Molecules (Compuestos)

**Forms:**
- `DSLabeledField` - Campo con label y descripción
- `DSSearchBar` - Barra de búsqueda completa
- `DSFilterMenu` - Menú de filtros
- `DSActionBar` - Barra de acciones con botones

**Display:**
- `DSEmptyState` - Estado vacío con icono y mensaje
- `DSLoadingState` - Estado de carga
- `DSErrorState` - Estado de error
- `DSStatusBadge` - Badge de estado (success, warning, error)
- `DSHeader` - Header de sección

**Lists:**
- `DSListItem` - Item de lista estándar
- `DSExpandableItem` - Item expandible
- `DSDraggableItem` - Item arrastrable
- `DSDropZone` - Zona de drop

#### Organisms (Complejos)

**Panels:**
- `DSPanel` - Panel genérico con header/footer
- `DSResizablePanel` - Panel redimensionable
- `DSCollapsiblePanel` - Panel colapsable
- `DSTabPanel` - Panel con tabs

**Lists:**
- `DSDraggableList` - Lista con drag & drop
- `DSInfiniteList` - Lista con scroll infinito
- `DSGroupedList` - Lista agrupada por secciones
- `DSVirtualizedList` - Lista virtualizada (>1000 items)

**Integration:**
- `DSIntegrationPanel` - Panel para integraciones
- `DSLoginPrompt` - Prompt de login
- `DSSettingsSheet` - Sheet de configuración

---

## Performance Guidelines

### ViewModels

**✅ SIEMPRE usar `@MainActor`:**

```swift
@MainActor
class BranchListViewModel: ObservableObject {
    @Published var branches: [Branch] = []
    @Published var searchText: String = ""
}
```

**Razón:** Garantiza que todas las actualizaciones de UI ocurran en el main thread.

### Computed Properties

**❌ INCORRECTO** (recalcula en cada render):

```swift
var filteredItems: [Item] {
    items.filter { $0.matches(searchText) }
}
```

**✅ CORRECTO** (cacheado con state):

```swift
@State private var cachedFilteredItems: [Item] = []

.onChange(of: searchText) { _, newValue in
    cachedFilteredItems = items.filter { $0.matches(newValue) }
}
```

**Razón:** SwiftUI puede re-renderizar views frecuentemente. Computed properties costosas deben cachearse.

### Task Closures

**✅ SIEMPRE usar `[weak self]` en Tasks:**

```swift
Task { [weak self] in
    guard let self = self else { return }
    await self.loadData()
}
```

**Razón:** Previene retain cycles y memory leaks.

### Lista Performance por Tamaño

| Items | Componente | Notas |
|-------|-----------|-------|
| < 20 | `VStack` | Simple stack, sin lazy loading |
| 20-100 | `LazyVStack` | Lazy loading básico |
| 100-1000 | `LazyVStack` + caching | Cachear computed properties |
| > 1000 | `DSVirtualizedList` | Virtualización completa |

### Async/Await Best Practices

**✅ CORRECTO:**

```swift
// Usar MainActor.run para updates de UI
await MainActor.run {
    self.isLoading = false
}
```

**❌ INCORRECTO:**

```swift
// NO usar DispatchQueue.main.async
DispatchQueue.main.async {
    self.isLoading = false
}
```

**Razón:** `MainActor.run` es el approach moderno y type-safe de Swift Concurrency.

---

## Component Architecture

### Atomic Design Hierarchy

**Atoms (Nivel 1):**
- Inmutables y stateless
- Solo propiedades de configuración
- No lógica de negocio
- Ejemplo: `DSButton`, `DSIcon`, `DSText`

**Molecules (Nivel 2):**
- Combinan 2-5 atoms
- Lógica mínima (validación básica, formateo)
- Reutilizables en contextos similares
- Ejemplo: `DSLabeledField`, `DSSearchBar`

**Organisms (Nivel 3):**
- Manejan estado complejo
- Lógica de negocio específica
- Específicos de dominio
- Ejemplo: `DSPanel`, `DSDraggableList`

### Component Composition Rules

#### ✅ DO:

```swift
// Usar componentes DS existentes
DSButton(
    title: "Save",
    style: .primary,
    action: save
)

// Componer molecules desde atoms
struct DSLabeledField: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            DSText(label, style: .caption)
            DSTextField(text: $text)
        }
    }
}
```

#### ❌ DON'T:

```swift
// NO crear custom buttons si DSButton sirve
struct MyCustomButton: View {
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13)) // ❌ Hardcoded
                .padding(8) // ❌ Hardcoded
        }
    }
}

// NO poner lógica de negocio en Views
struct BranchListView: View {
    var body: some View {
        // ❌ NO hacer esto aquí
        let branches = gitEngine.listBranches()

        List(branches) { branch in
            Text(branch.name)
        }
    }
}
```

---

## Naming Conventions

### Componentes

| Tipo | Prefijo/Sufijo | Ejemplo |
|------|---------------|---------|
| Componentes DS | `DS` prefijo | `DSButton`, `DSPanel` |
| ViewModels | `ViewModel` sufijo | `BranchListViewModel` |
| Views | `View` sufijo | `BranchListView` |
| Services | `Service` sufijo | `AvatarService`, `GitEngine` |
| Protocols | Sin prefijo | `IntegrationViewModel`, `Codable` |
| Extensions | Categoría clara | `String+Git`, `View+Theme` |

### Variables y Properties

```swift
// ✅ Descriptivo y claro
@Published var filteredBranches: [Branch] = []
@State private var isExpanded: Bool = false
private let themeManager = ThemeManager.shared

// ❌ Vago o críptico
@Published var items: [Any] = []
@State private var flag: Bool = false
private let tm = ThemeManager.shared
```

### Functions

```swift
// ✅ Verbos claros, nombres descriptivos
func loadBranches() async
func filterBranches(by searchText: String) -> [Branch]
func deleteBranch(_ branch: Branch) async throws

// ❌ Nombres vagos
func load()
func filter(_ text: String)
func delete(_ item: Any)
```

---

## Plugin System

GitMac tiene un sistema de plugins extensible para integraciones (GitHub, GitLab, Jira, Linear, etc.).

### Arquitectura de Plugins

Para crear una nueva integración:

#### 1. Crear ViewModel conformando `IntegrationViewModel`

```swift
@MainActor
class GitHubViewModel: ObservableObject, IntegrationViewModel {
    @Published var isAuthenticated: Bool = false
    @Published var repositories: [Repository] = []
    @Published var isLoading: Bool = false
    @Published var error: String?

    let serviceName = "GitHub"
    let icon = "github"

    func authenticate() async {
        isLoading = true
        defer { isLoading = false }

        // Authentication logic...
    }

    func loadData() async {
        // Load repositories...
    }
}
```

#### 2. Crear Plugin conformando `IntegrationPlugin`

```swift
struct GitHubPlugin: IntegrationPlugin {
    let id = "github"
    let name = "GitHub"
    let description = "GitHub repositories and PRs"
    let icon = "github"

    func createViewModel() -> any IntegrationViewModel {
        GitHubViewModel()
    }

    func createView(viewModel: any IntegrationViewModel) -> AnyView {
        AnyView(
            GitHubView(viewModel: viewModel as! GitHubViewModel)
        )
    }
}
```

#### 3. Crear View usando `DSIntegrationPanel`

```swift
struct GitHubView: View {
    @ObservedObject var viewModel: GitHubViewModel

    var body: some View {
        DSIntegrationPanel(
            serviceName: viewModel.serviceName,
            icon: viewModel.icon,
            isAuthenticated: viewModel.isAuthenticated,
            isLoading: viewModel.isLoading,
            error: viewModel.error,
            authenticateAction: {
                Task {
                    await viewModel.authenticate()
                }
            }
        ) {
            // Authenticated content
            List(viewModel.repositories) { repo in
                DSListItem(
                    title: repo.name,
                    subtitle: repo.description
                )
            }
        }
    }
}
```

#### 4. Registrar Plugin

```swift
// En AppDelegate o GitMacApp
PluginRegistry.shared.register(GitHubPlugin())
```

### Benefits del Plugin System

- **Consistente:** Todos los plugins usan `DSIntegrationPanel`
- **Type-Safe:** Protocols garantizan implementación correcta
- **Desacoplado:** Plugins no dependen entre sí
- **Testable:** ViewModels son fáciles de testear

---

## Code Review Checklist

Antes de hacer commit, verifica:

### Design System
- [ ] Cero valores hardcoded (fonts, spacing, colors, corner radius)
- [ ] Usa `DesignTokens.*` para valores numéricos
- [ ] Usa `AppTheme.*` para colores
- [ ] Usa componentes `DS*` existentes (no crear custom si no es necesario)

### Performance
- [ ] ViewModels tienen `@MainActor`
- [ ] Task closures usan `[weak self]`
- [ ] Computed properties costosas están cacheadas en `@State`
- [ ] Listas grandes usan `LazyVStack` o `DSVirtualizedList`
- [ ] No hay llamadas síncronas blocking en main thread

### Architecture
- [ ] Lógica de negocio está en ViewModels, no en Views
- [ ] Views son declarativas y stateless (cuando sea posible)
- [ ] Usa composición de componentes (atoms → molecules → organisms)
- [ ] No hay retain cycles (weak self en closures)

### Code Quality
- [ ] Nombres descriptivos (no `item`, `data`, `temp`)
- [ ] SwiftUI Previews para componentes nuevos
- [ ] Sin warnings del compilador
- [ ] Performance OK (60fps en scroll de listas)

### Testing
- [ ] Unit tests para lógica de negocio compleja
- [ ] No regresiones visuales (verifica en Light/Dark mode)
- [ ] Testea edge cases (listas vacías, errores de red, etc.)

---

## Anti-patterns

### ❌ NO Hacer

#### 1. Hardcodear Valores

```swift
// ❌ NUNCA
.font(.system(size: 13))
.padding(12)
.foregroundColor(.blue)

// ✅ SIEMPRE
.font(DesignTokens.Typography.body)
.padding(DesignTokens.Spacing.md)
.foregroundColor(AppTheme.accent)
```

#### 2. Singletons Innecesarios

```swift
// ❌ NO
@StateObject private var themeManager = ThemeManager.shared

// ✅ SÍ (usa @Environment)
@Environment(\.themeColors) private var theme
```

#### 3. Crear Custom Buttons sin Razón

```swift
// ❌ NO
struct SaveButton: View {
    var body: some View {
        Button("Save") { save() }
            .buttonStyle(.borderedProminent)
    }
}

// ✅ SÍ
DSButton(title: "Save", style: .primary, action: save)
```

#### 4. Lógica de Negocio en Views

```swift
// ❌ NO
struct BranchListView: View {
    var body: some View {
        let branches = GitEngine.shared.listBranches() // ❌
        List(branches) { ... }
    }
}

// ✅ SÍ
@MainActor
class BranchListViewModel: ObservableObject {
    @Published var branches: [Branch] = []

    func loadBranches() async {
        branches = await GitEngine.shared.listBranches()
    }
}
```

#### 5. ViewModels sin `@MainActor`

```swift
// ❌ NO
class MyViewModel: ObservableObject {
    @Published var data: [Item] = []
}

// ✅ SÍ
@MainActor
class MyViewModel: ObservableObject {
    @Published var data: [Item] = []
}
```

#### 6. Computed Properties sin Cachear

```swift
// ❌ NO (en listas grandes)
var filteredItems: [Item] {
    items.filter { $0.matches(query) } // Re-ejecuta cada render
}

// ✅ SÍ
@State private var filteredItems: [Item] = []

.onChange(of: query) { _, newValue in
    filteredItems = items.filter { $0.matches(newValue) }
}
```

#### 7. DispatchQueue en vez de MainActor

```swift
// ❌ NO
DispatchQueue.main.async {
    self.isLoading = false
}

// ✅ SÍ
await MainActor.run {
    self.isLoading = false
}
```

#### 8. Force Unwrapping sin Guard

```swift
// ❌ NO
let url = URL(string: urlString)!
let data = try! Data(contentsOf: url)

// ✅ SÍ
guard let url = URL(string: urlString) else {
    throw URLError(.badURL)
}
let data = try Data(contentsOf: url)
```

---

## Resources

### Documentation

- **`DESIGN_SYSTEM.md`** - Guía completa del Design System
- **`PLUGIN_TEMPLATE.md`** - Template para crear plugins (si existe)
- **`ComponentCatalog.swift`** - Preview de todos los componentes DS

### Key Files

- **`/GitMac/UI/Theme/DesignTokens.swift`** - Tokens centralizados
- **`/GitMac/UI/Components/AppTheme.swift`** - Sistema de colores
- **`/GitMac/UI/Components/Atoms/`** - Componentes primitivos
- **`/GitMac/UI/Components/Molecules/`** - Componentes compuestos
- **`/GitMac/UI/Components/Organisms/`** - Componentes complejos

### Examples

**Good Examples to Study:**
- `BranchListView.swift` - Lista optimizada con lazy loading
- `CommitGraphView.swift` - Rendering complejo con performance
- `DiffView.swift` - Diff viewer con syntax highlighting
- `SettingsView.swift` - Forms complejas con validación

---

## Summary

**Tres Reglas de Oro:**

1. **NUNCA hardcodear valores** → Usa `DesignTokens.*` y `AppTheme.*`
2. **SIEMPRE usar `@MainActor` en ViewModels** → Thread safety
3. **SIEMPRE usar componentes `DS*` existentes** → Consistencia

**Cuando tengas dudas:**
- Revisa `DESIGN_SYSTEM.md`
- Busca ejemplos en `/GitMac/UI/Components/`
- Pregunta antes de crear componentes custom

**Performance Checklist:**
- [ ] ViewModels con `@MainActor`
- [ ] Tasks con `[weak self]`
- [ ] Computed properties cacheados
- [ ] Listas lazy para > 20 items

---

**Última actualización:** December 28, 2025
**Versión:** 1.0
**Mantenido por:** Equipo GitMac
