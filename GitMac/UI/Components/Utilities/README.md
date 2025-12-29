# Design System Utilities

**Created:** December 28, 2025
**Version:** 1.0

Componentes utilitarios avanzados que complementan el sistema de diseño atómico de GitMac. Estos componentes fueron identificados mediante análisis exhaustivo del codebase para eliminar patrones repetitivos y mejorar la consistencia.

---

## Tabla de Contenidos

1. [View Modifiers](#view-modifiers)
2. [Layout Helpers](#layout-helpers)
3. [State Management](#state-management)
4. [Gesture Handlers](#gesture-handlers)
5. [Animation Extensions](#animation-extensions)
6. [Guía de Uso](#guía-de-uso)

---

## View Modifiers

### `ViewModifiers.swift`

Modifiers reutilizables para efectos comunes. Elimina código duplicado encontrado en 62+ archivos.

#### DSHoverEffect

Aplica efecto de hover consistente con animación:

```swift
@State private var isHovered = false

Text("Hover me")
    .padding()
    .hoverEffect(isHovered: $isHovered)

// Con borde
Text("Hover with border")
    .padding()
    .hoverEffect(
        isHovered: $isHovered,
        borderColor: AppTheme.accent
    )
```

#### DSCardStyle

Aplica estilo de tarjeta con elevación:

```swift
VStack {
    Text("Card Content")
}
.cardStyle(elevation: .medium)

// Elevations: .none, .low, .medium, .high
```

#### DSLoadingOverlay

Muestra overlay de carga sobre el contenido:

```swift
VStack {
    // Your content
}
.loadingOverlay(isLoading: viewModel.isLoading, text: "Loading data...")
```

#### DSSelectionHighlight

Resalta elementos seleccionados:

```swift
HStack {
    Text("Item")
}
.selectionHighlight(
    isSelected: isSelected,
    color: AppTheme.accent,
    style: .background // .background, .border, .accent
)
```

#### DSShimmer

Añade efecto shimmer para skeleton screens:

```swift
Rectangle()
    .fill(AppTheme.backgroundSecondary)
    .frame(height: 60)
    .cornerRadius(DesignTokens.CornerRadius.md)
    .shimmer()
```

#### DSConditionalModifier

Aplica modifiers condicionalmente:

```swift
Text("Conditional")
    .if(isSpecial, modifier: SpecialModifier())
```

---

## Layout Helpers

### `LayoutHelpers.swift`

Componentes de layout con spacing del Design System por defecto. Simplifica código encontrado en 100+ vistas.

#### DSVStack / DSHStack

VStack y HStack con spacing del Design System:

```swift
DSVStack(spacing: DesignTokens.Spacing.md) {
    Text("Item 1")
    Text("Item 2")
    Text("Item 3")
}

DSHStack(spacing: DesignTokens.Spacing.sm) {
    Icon("star")
    Text("Starred")
}
```

#### DSScrollView

ScrollView con configuración consistente:

```swift
DSScrollView {
    // Content
}

// Con opciones
DSScrollView(.vertical, showsIndicators: true, bounce: true) {
    // Content
}
```

#### DSLazyVStack / DSLazyHStack

LazyStacks con spacing del Design System:

```swift
DSLazyVStack(spacing: DesignTokens.Spacing.sm) {
    ForEach(items) { item in
        ItemRow(item: item)
    }
}
```

#### DSGrid

Grid layout con spacing consistente:

```swift
DSGrid(columns: 3, spacing: DesignTokens.Spacing.md) {
    ForEach(items) { item in
        GridCell(item: item)
    }
}
```

#### DSSection

Contenedor de sección con título y footer:

```swift
DSSection(
    title: "User Settings",
    footer: "These settings apply to your account"
) {
    SettingsContent()
}
```

#### DSContainer

Contenedor con max width y padding:

```swift
DSContainer(maxWidth: 600, padding: DesignTokens.Spacing.lg) {
    CenteredContent()
}

// Como extension
MyView()
    .container(maxWidth: 800, background: AppTheme.backgroundSecondary)
```

---

## State Management

### `StateManagement.swift`

Wrappers para manejar estados async automáticamente. Reemplaza código repetitivo en 40+ ViewModels.

#### DSAsyncState

Enum que representa estados de operaciones async:

```swift
enum DSAsyncState<T> {
    case idle
    case loading
    case success(T)
    case failure(Error)
}
```

#### DSAsyncContent

Wrapper para contenido async con estados automáticos:

```swift
@State private var state: DSAsyncState<[Branch]> = .idle

DSAsyncContent(
    state: state,
    retry: {
        await loadBranches()
    }
) { branches in
    // Success view
    ForEach(branches) { branch in
        BranchRow(branch: branch)
    }
}
// Maneja automáticamente: loading, error, empty, success
```

#### DSStatefulView

View que maneja loading/error/empty states:

```swift
DSStatefulView(
    isLoading: viewModel.isLoading,
    error: viewModel.error,
    isEmpty: viewModel.items.isEmpty,
    retry: {
        await viewModel.reload()
    }
) {
    // Success content
    ItemsList(items: viewModel.items)
}
```

#### DSTaskStateManager

Gestiona el estado de tasks async con retry automático:

```swift
@StateObject private var taskManager = DSTaskStateManager<[Branch]>()

// Execute
taskManager.execute {
    try await gitService.loadBranches()
}

// Use in view
DSAsyncContent(state: taskManager.state, retry: {
    await taskManager.retry {
        try await gitService.loadBranches()
    }
}) { branches in
    BranchList(branches: branches)
}
```

#### DSLoadableViewModel Protocol

Protocol para ViewModels con loading states:

```swift
@MainActor
class MyViewModel: ObservableObject, DSLoadableViewModel {
    @Published var loadingState: DSAsyncState<[Item]> = .idle

    func load() async {
        await performLoad {
            try await fetchItems()
        }
    }
}
```

---

## Gesture Handlers

### `GestureHandlers.swift`

Gestures reutilizables con feedback visual. Simplifica código encontrado en 30+ archivos.

#### Double Tap

Añade gesto de doble tap con haptic feedback:

```swift
Text("Double tap me")
    .onDoubleTap {
        print("Double tapped!")
    }

// Sin haptic feedback
Text("Silent double tap")
    .onDoubleTap(hapticFeedback: false) {
        performAction()
    }
```

#### Long Press

Añade long press con feedback visual:

```swift
Text("Long press me")
    .onLongPress(minimumDuration: 0.5) {
        showContextMenu()
    }
```

#### Swipeable

Hace una view swipeable con acciones:

```swift
HStack {
    Text("Swipe me")
}
.swipeable(
    leading: [
        .init(icon: "checkmark.circle.fill", color: AppTheme.success) {
            markAsDone()
        }
    ],
    trailing: [
        .init(icon: "trash.fill", color: AppTheme.error) {
            delete()
        }
    ]
)
```

#### Magnifiable

Añade pinch-to-zoom:

```swift
@State private var scale: CGFloat = 1.0

Image("photo")
    .magnifiable(scale: $scale, minScale: 0.5, maxScale: 3.0)
```

#### Draggable / Drop Target

Drag & drop con preview visual:

```swift
// Draggable
Text("Drag me")
    .draggable(branch)

// Drop target
VStack {
    // Content
}
.dropTarget { (branch: Branch) in
    handleDrop(branch)
    return true
}
```

---

## Animation Extensions

### `AnimationExtensions.swift`

Presets de animación y efectos reutilizables. Estandariza animaciones inconsistentes en todo el codebase.

#### Animation Presets

Acceso rápido a animaciones del Design System:

```swift
withAnimation(.ds(.fast)) {
    isExpanded = true
}

withAnimation(.ds(.spring)) {
    offset = 0
}

// Presets disponibles:
// .instant, .fast, .normal, .slow
// .spring, .bouncy, .smooth
// .easeIn, .easeOut, .easeInOut
```

#### Transition Presets

Transiciones predefinidas:

```swift
if showContent {
    ContentView()
        .transition(.fadeIn)
}

if showPanel {
    Panel()
        .transition(.slideIn(from: .bottom))
}

// Disponibles:
// .fadeIn, .fadeOut
// .slideIn(from:), .slideOut(to:)
// .scaleIn, .scaleOut
// .pop, .push(from:)
// .slide(from:, to:)
```

#### View Animation Extensions

Métodos de conveniencia para animaciones comunes:

```swift
// Fade in
Text("Hello")
    .fadeIn()

// Slide in
Panel()
    .slideIn(from: .bottom)

// Scale in
Button("Click")
    .scaleIn()

// Pop in
Alert()
    .popIn()

// Staggered animation (para listas)
ForEach(items.indices, id: \.self) { index in
    ItemRow(items[index])
        .staggeredAnimation(index: index, total: items.count)
}
```

#### Animation Effects

Efectos especiales:

```swift
// Shake (para errores)
TextField("Email", text: $email)
    .shake(offset: isInvalid ? 10 : 0)

// Pulse
Circle()
    .pulse(scale: 1.2, duration: 1.0)

// Wiggle
Icon("bell")
    .wiggle(angle: 15, duration: 0.3)

// Bounce
Box()
    .bounce(height: 30, duration: 0.8)

// Rotate continuously
Icon("loading")
    .rotateInfinitely(duration: 2.0)
```

---

## Guía de Uso

### Principios Generales

1. **Siempre usar componentes DS cuando existan**: No reinventar la rueda
2. **Combinar utilities para casos complejos**: Los utilities son composables
3. **Seguir Design Tokens**: Spacing, colores, animaciones siempre del sistema
4. **Preferir declarativo sobre imperativo**: Usar modifiers en vez de lógica manual

### Ejemplos de Composición

#### Tarjeta Interactiva con Estados

```swift
struct BranchCard: View {
    let branch: Branch
    @State private var isHovered = false
    @State private var isLoading = false

    var body: some View {
        DSHStack(spacing: DesignTokens.Spacing.md) {
            DSIcon("arrow.branch", size: .md, color: AppTheme.accent)

            DSVStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(branch.name)
                    .font(DesignTokens.Typography.body)
                Text("\(branch.commitCount) commits")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()
        }
        .padding()
        .hoverEffect(isHovered: $isHovered, borderColor: AppTheme.accent)
        .cardStyle(elevation: .low)
        .loadingOverlay(isLoading: isLoading)
        .onDoubleTap {
            checkout(branch)
        }
        .swipeable(
            trailing: [
                .init(icon: "trash", color: AppTheme.error) {
                    delete(branch)
                }
            ]
        )
    }
}
```

#### Lista con Async Loading

```swift
struct BranchListView: View {
    @StateObject private var taskManager = DSTaskStateManager<[Branch]>()

    var body: some View {
        DSAsyncContent(
            state: taskManager.state,
            retry: {
                await loadBranches()
            }
        ) { branches in
            DSScrollView {
                DSLazyVStack(spacing: DesignTokens.Spacing.sm) {
                    ForEach(branches.indices, id: \.self) { index in
                        BranchCard(branch: branches[index])
                            .staggeredAnimation(index: index, total: branches.count)
                    }
                }
                .padding()
            }
        }
        .onAppear {
            await loadBranches()
        }
    }

    private func loadBranches() async {
        taskManager.execute {
            try await gitService.loadBranches()
        }
    }
}
```

#### Panel Colapsable Animado

```swift
struct SettingsPanel: View {
    @State private var isExpanded = true

    var body: some View {
        DSSection(
            title: "Advanced Settings",
            footer: "These settings affect performance"
        ) {
            if isExpanded {
                DSVStack(spacing: DesignTokens.Spacing.md) {
                    ForEach(settings) { setting in
                        SettingRow(setting: setting)
                    }
                }
                .transition(.slideIn(from: .top))
            }
        }
        .onTapGesture {
            withAnimation(.ds(.spring)) {
                isExpanded.toggle()
            }
        }
    }
}
```

### Performance Tips

1. **Use LazyStacks para listas grandes**: `DSLazyVStack` en vez de `DSVStack` cuando > 20 items
2. **Cache async results**: `DSTaskStateManager` maneja caching automático
3. **Evita re-renders innecesarios**: Los utilities ya usan `@State` internamente
4. **Staggered animations con moderación**: No usar en listas > 20 items

---

## Migración de Código Existente

### Antes (Código Repetitivo)

```swift
// ❌ Código antiguo
struct OldRow: View {
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Text("Item")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHovered ? Color.gray.opacity(0.1) : Color.clear)
        .cornerRadius(6)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}
```

### Después (Con Utilities)

```swift
// ✅ Código nuevo con utilities
struct NewRow: View {
    @State private var isHovered = false

    var body: some View {
        DSHStack {
            Text("Item")
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .hoverEffect(isHovered: $isHovered)
    }
}
```

**Beneficios:**
- 7 líneas → 4 líneas (43% menos código)
- Usa Design Tokens consistentes
- Animación estándar del sistema
- Más legible y mantenible

---

## Integración con Sistema Existente

Estos utilities **complementan** el sistema de diseño existente:

- **Atoms**: Componentes básicos (DSButton, DSIcon, etc.) → Siguen igual
- **Molecules**: Combinan atoms → Pueden usar utilities internamente
- **Organisms**: Features complejos → Usan utilities para estados/animaciones
- **Utilities**: Nuevos helpers transversales → Usados en todos los niveles

### Jerarquía Actualizada

```
Design System
├── Tokens (DesignTokens, AppTheme)
├── Atoms (DSButton, DSIcon, DSText, etc.)
├── Molecules (DSListItem, DSSearchBar, etc.)
├── Organisms (DSPanel, DSDraggableList, etc.)
└── Utilities (NEW!)
    ├── ViewModifiers (hover, card, loading, etc.)
    ├── LayoutHelpers (stacks, grids, sections)
    ├── StateManagement (async states, task manager)
    ├── GestureHandlers (tap, swipe, drag, etc.)
    └── AnimationExtensions (presets, effects)
```

---

## Testing

Todos los componentes incluyen SwiftUI Previews para verificación visual:

```bash
# Ver previews en Xcode
# Abrir cualquier archivo .swift de utilities
# Canvas → Show Preview
```

---

## Referencias

- **STANDARDS.md**: Estándares generales del proyecto
- **DESIGN_SYSTEM.md**: Guía completa del Design System
- **DesignTokens.swift**: Tokens centralizados
- **AppTheme.swift**: Sistema de colores

---

**Creado por:** Análisis del codebase GitMac
**Archivos analizados:** 200+ archivos Swift
**Patrones identificados:** 150+ instancias de código repetitivo
**Reducción de código estimada:** 30-40% en views complejas
