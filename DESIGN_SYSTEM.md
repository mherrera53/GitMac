# GitMac Design System

**Version:** 1.0
**Last Updated:** December 28, 2025

---

## Table of Contents

1. [Introduction](#introduction)
2. [Design Tokens](#design-tokens)
3. [Component Hierarchy](#component-hierarchy)
4. [Naming Conventions](#naming-conventions)
5. [Component Composition Rules](#component-composition-rules)
6. [Performance Best Practices](#performance-best-practices)
7. [Examples](#examples)
8. [Theme System](#theme-system)

---

## Introduction

### What is the GitMac Design System?

The GitMac Design System is a comprehensive, atomic-based design framework that ensures consistency, performance, and maintainability across the entire application. It follows the **Atomic Design** methodology, breaking UI into hierarchical components: **Atoms → Molecules → Organisms**.

### Why Use Atomic Components?

- **DRY (Don't Repeat Yourself)**: Reusable components eliminate code duplication
- **Consistency**: Uniform spacing, colors, and interactions across the app
- **Performance**: Optimized components with built-in best practices
- **Maintainability**: Changes propagate automatically through token updates
- **Developer Experience**: Autocomplete-friendly naming and clear APIs

### Benefits

- **Centralized Design Tokens**: All values (colors, spacing, fonts) are defined once
- **Type-Safe**: Swift's type system prevents invalid values
- **Theme Support**: Dynamic theming with instant preview
- **Production-Ready**: Battle-tested components with loading states, hover effects, and animations

---

## Design Tokens

Design tokens are the **atomic values** of our design system. They define colors, spacing, typography, and other visual properties.

### Core Principles

1. **NEVER hardcode values** - Always use design tokens
2. **Use semantic names** - `LayoutConstants.Spacing.md` over `8`
3. **Follow hierarchy** - Use tokens from most specific to most general

### Available Token Namespaces

| Namespace | Purpose | Example |
|-----------|---------|---------|
| `LayoutConstants.Spacing` | Consistent spacing between elements | `md`, `lg`, `xl` |
| `LayoutConstants.Padding` | Internal padding for containers | `compact`, `standard`, `comfortable` |
| `LayoutConstants.CornerRadius` | Border radius for UI elements | `sm`, `md`, `lg` |
| `LayoutConstants.RowHeight` | Height of list rows | `compact`, `standard`, `comfortable` |
| `LayoutConstants.IconSize` | Icon dimensions | `sm`, `md`, `lg` |
| `LayoutConstants.FontSize` | Typography sizes | `xs`, `sm`, `md`, `lg` |
| `LayoutConstants.BorderWidth` | Border stroke width | `thin`, `standard`, `thick` |
| `LayoutConstants.Opacity` | Transparency levels | `subtle`, `mild`, `medium` |
| `LayoutConstants.AnimationDuration` | Animation timing | `fast`, `standard`, `slow` |
| `AppTheme.*` | All color values | `accent`, `success`, `error`, `background` |

### Usage Examples

#### ❌ Incorrect - Hardcoded Values

```swift
VStack(spacing: 8) {
    Text("Hello")
        .font(.system(size: 13))
        .padding(.horizontal, 12)
        .background(Color.blue)
        .cornerRadius(6)
}
```

**Problems:**
- Magic numbers scattered throughout code
- Inconsistent spacing (8 vs 12 vs 6)
- Hardcoded colors don't adapt to themes
- Difficult to maintain at scale

#### ✅ Correct - Design Tokens

```swift
VStack(spacing: LayoutConstants.Spacing.md) {
    Text("Hello")
        .font(.system(size: LayoutConstants.FontSize.lg))
        .padding(.horizontal, LayoutConstants.Padding.standard)
        .background(AppTheme.accent)
        .cornerRadius(LayoutConstants.CornerRadius.md)
}
```

**Benefits:**
- Self-documenting code (`md` = medium spacing)
- Consistent across entire app
- Theme-aware colors
- Single source of truth for updates

### Color System

#### Primary Colors

```swift
AppTheme.accent           // Main brand color
AppTheme.accentHover      // Hover state
AppTheme.accentPressed    // Pressed state
```

#### Background Colors

```swift
AppTheme.background           // Primary background
AppTheme.backgroundSecondary  // Secondary areas (panels, sidebars)
AppTheme.backgroundTertiary   // Tertiary (cards, elevated surfaces)
```

#### Text Colors

```swift
AppTheme.textPrimary      // Main text
AppTheme.textSecondary    // Supporting text
AppTheme.textMuted        // Disabled/subtle text
```

#### Semantic Colors

```swift
AppTheme.success    // Positive actions (e.g., stage file)
AppTheme.warning    // Caution actions (e.g., unstage)
AppTheme.error      // Destructive actions (e.g., delete)
AppTheme.info       // Informational
```

#### Git-Specific Colors

```swift
AppTheme.gitAdded        // Added files
AppTheme.gitModified     // Modified files
AppTheme.gitDeleted      // Deleted files
AppTheme.gitConflict     // Conflict state
```

#### Interactive States

```swift
AppTheme.hover           // Hover background
AppTheme.selection       // Selected state
AppTheme.border          // Border color
AppTheme.focus           // Focus ring
```

### Spacing Scale

```swift
LayoutConstants.Spacing.xs     // 2pt  - Very tight spacing
LayoutConstants.Spacing.sm     // 4pt  - Compact spacing
LayoutConstants.Spacing.md     // 8pt  - Default spacing (most common)
LayoutConstants.Spacing.lg     // 12pt - Comfortable spacing
LayoutConstants.Spacing.xl     // 16pt - Loose spacing
LayoutConstants.Spacing.xxl    // 24pt - Section spacing
LayoutConstants.Spacing.section // 32pt - Major section breaks
```

### Typography

```swift
LayoutConstants.FontSize.xs    // 9pt  - Caption 2
LayoutConstants.FontSize.sm    // 10pt - Caption
LayoutConstants.FontSize.md    // 12pt - Body (default)
LayoutConstants.FontSize.lg    // 13pt - Headline
LayoutConstants.FontSize.xl    // 16pt - Title 3
LayoutConstants.FontSize.xxl   // 20pt - Title 2
LayoutConstants.FontSize.xxxl  // 24pt - Title 1
```

---

## Component Hierarchy

The Design System follows **Atomic Design** principles with three levels:

### 1. Atoms (Base Components)

**Definition:** The smallest, indivisible UI elements. No business logic, purely presentational.

**Characteristics:**
- Stateless (no `@State` unless for UI animation)
- Immutable props
- No external dependencies
- Single responsibility

**Examples:**
- `ActionButton` - Icon button with loading state
- Icons (`FileTypeIcon`, `StatusIcon`)
- `Separator` - Visual divider

**Usage Pattern:**

```swift
ActionButton(
    icon: "plus.circle",
    color: AppTheme.success,
    size: .compact,
    tooltip: "Add Item"
) {
    // Action
}
```

### 2. Molecules (Composite Components)

**Definition:** Combinations of atoms with minimal logic. Handle simple interactions.

**Characteristics:**
- Combine multiple atoms
- Minimal state (e.g., hover, expanded)
- Generic and reusable
- Self-contained functionality

**Examples:**
- `BaseRow` - Generic list row with hover/selection
- `SectionHeader` - Collapsible header with icon and actions
- `EmptyStateView` - Empty state with icon, title, message

**Usage Pattern:**

```swift
SectionHeader(
    title: "Unstaged Files",
    count: 15,
    icon: "doc.badge.ellipsis",
    color: AppTheme.warning,
    isExpanded: $isExpanded
) {
    ActionButton.stage { await stageAll() }
}
```

### 3. Organisms (Feature Components)

**Definition:** Complex components with business logic and state management.

**Characteristics:**
- Manage application state
- Handle data fetching
- Coordinate multiple molecules
- Feature-specific logic

**Examples:**
- `BranchListView` - Full branch management UI
- `CommitGraphView` - Git graph visualization
- `StagingAreaView` - Staging workflow

**Guidelines:**
- Use `@StateObject` for ViewModels
- Keep logic in ViewModels, not Views
- Compose molecules, not atoms directly

---

## Naming Conventions

### Component Prefixes

All Design System components should be easily discoverable via autocomplete.

#### Current Patterns

1. **Layout Constants**: `LayoutConstants.*`
2. **Theme Colors**: `AppTheme.*`
3. **Base Components**: Descriptive names (`BaseRow`, `ActionButton`)

#### Best Practices

- **Be specific**: `FileRow` over `Row`
- **Use suffixes**: `View`, `Button`, `Icon`, `Header`
- **Avoid abbreviations**: `SectionHeader` over `SecHdr`
- **Prefix for discovery**: Consider future `DS` prefix (e.g., `DSButton`, `DSPanel`)

### Future Consideration: DS Prefix

**Proposal:** Prefix Design System components with `DS` for clear separation:

```swift
// Future naming convention
DSButton         // vs ActionButton
DSTextField      // vs custom TextField
DSPanel          // vs generic container
DSSectionHeader  // vs SectionHeader
```

**Benefits:**
- Instant identification of Design System components
- Autocomplete: Type "DS" to see all available components
- Clear separation from SwiftUI built-ins and custom features

---

## Component Composition Rules

### Atom Guidelines

**DO:**
- Keep stateless (no business logic)
- Accept all props via `init`
- Use `@ViewBuilder` for flexible content
- Document all parameters

**DON'T:**
- Fetch data from external sources
- Manage complex state
- Depend on environment objects (unless theme)

**Example:**

```swift
struct DSBadge: View {
    let text: String
    let color: Color
    let style: BadgeStyle

    var body: some View {
        Text(text)
            .font(.system(size: LayoutConstants.FontSize.sm))
            .padding(.horizontal, LayoutConstants.Padding.compact)
            .padding(.vertical, LayoutConstants.Spacing.xs)
            .background(color.opacity(LayoutConstants.Opacity.mild))
            .cornerRadius(LayoutConstants.CornerRadius.sm)
    }
}
```

### Molecule Guidelines

**DO:**
- Combine atoms logically
- Handle UI state (hover, focus)
- Use protocols for flexibility
- Provide sensible defaults

**DON'T:**
- Fetch remote data
- Implement business logic
- Hardcode specific features

**Example:**

```swift
struct DSCard<Content: View>: View {
    var style: CardStyle = .default
    @ViewBuilder let content: () -> Content
    @State private var isHovered = false

    var body: some View {
        content()
            .padding(style.padding)
            .background(backgroundColor)
            .cornerRadius(style.cornerRadius)
            .shadow(radius: isHovered ? style.shadowRadius : 0)
            .onHover { isHovered = $0 }
    }

    private var backgroundColor: Color {
        isHovered ? AppTheme.backgroundSecondary : AppTheme.backgroundTertiary
    }
}
```

### Organism Guidelines

**DO:**
- Use `@StateObject` for ViewModels
- Compose molecules and atoms
- Handle feature-specific logic
- Manage loading/error states

**DON'T:**
- Style directly with hardcoded values
- Duplicate molecule functionality
- Create god views (split into sub-organisms)

**Example:**

```swift
struct BranchListView: View {
    @StateObject private var viewModel = BranchListViewModel()
    @State private var isExpanded = true

    var body: some View {
        VStack(spacing: LayoutConstants.Spacing.md) {
            SectionHeader(
                title: "Branches",
                count: viewModel.branches.count,
                icon: "arrow.branch",
                isExpanded: $isExpanded
            ) {
                ActionButton.refresh {
                    await viewModel.refresh()
                }
            }

            if isExpanded {
                if viewModel.branches.isEmpty {
                    EmptyStateView.noBranches {
                        viewModel.showCreateBranch()
                    }
                } else {
                    LazyVStack(spacing: LayoutConstants.Spacing.sm) {
                        ForEach(viewModel.branches) { branch in
                            BranchRow(branch: branch)
                        }
                    }
                }
            }
        }
    }
}
```

### Using Generics for Reusability

**Pattern:** Use Swift generics to create flexible components

```swift
struct DSList<Item: Identifiable, RowContent: View>: View {
    let items: [Item]
    let emptyState: EmptyStateView?
    @ViewBuilder let rowContent: (Item) -> RowContent

    var body: some View {
        if items.isEmpty, let emptyState = emptyState {
            emptyState
        } else {
            LazyVStack(spacing: LayoutConstants.Spacing.sm) {
                ForEach(items) { item in
                    rowContent(item)
                }
            }
        }
    }
}

// Usage
DSList(items: files, emptyState: .noFiles()) { file in
    FileRow(file: file)
}
```

---

## Performance Best Practices

### 1. Use `@MainActor` for ViewModels

All ViewModels that update UI should be marked `@MainActor`:

```swift
@MainActor
final class BranchListViewModel: ObservableObject {
    @Published var branches: [Branch] = []
    @Published var isLoading = false

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        branches = await gitEngine.fetchBranches()
    }
}
```

**Why?** Ensures all UI updates happen on the main thread, preventing crashes.

### 2. Cache Computed Properties

For expensive computations, use lazy properties or cache results:

```swift
// ❌ Recalculated on every render
var filteredBranches: [Branch] {
    branches.filter { $0.isLocal }
}

// ✅ Cached with @Published
@Published var filteredBranches: [Branch] = []

func updateFilter() {
    filteredBranches = branches.filter { $0.isLocal }
}
```

### 3. LazyVStack for Medium Lists (20-100 items)

Use `LazyVStack` instead of `VStack` for lists over 20 items:

```swift
// ❌ Renders all items immediately
VStack {
    ForEach(branches) { branch in
        BranchRow(branch: branch)
    }
}

// ✅ Lazy rendering
LazyVStack(spacing: LayoutConstants.Spacing.sm) {
    ForEach(branches) { branch in
        BranchRow(branch: branch)
    }
}
```

### 4. Virtualization for Large Lists (>100 items)

For very large lists, implement virtualization with scroll tracking:

```swift
struct VirtualizedList<Item: Identifiable, RowContent: View>: View {
    let items: [Item]
    let rowHeight: CGFloat
    @ViewBuilder let rowContent: (Item) -> RowContent

    @State private var visibleRange: Range<Int> = 0..<50

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(items[visibleRange], id: \.id) { item in
                        rowContent(item)
                            .frame(height: rowHeight)
                    }
                }
                .onPreferenceChange(ScrollOffsetKey.self) { offset in
                    updateVisibleRange(offset: offset)
                }
            }
        }
    }

    private func updateVisibleRange(offset: CGFloat) {
        let startIndex = max(0, Int(offset / rowHeight) - 10)
        let endIndex = min(items.count, startIndex + 60)
        visibleRange = startIndex..<endIndex
    }
}
```

### 5. Avoid Nested Observed Objects

Don't nest `@ObservedObject` or `@StateObject`. Use a single ViewModel:

```swift
// ❌ Multiple observed objects
struct ParentView: View {
    @StateObject var parentVM = ParentViewModel()
    @StateObject var childVM = ChildViewModel()

    var body: some View {
        // Both VMs trigger refreshes
    }
}

// ✅ Single ViewModel
struct ParentView: View {
    @StateObject var viewModel = ParentViewModel()

    var body: some View {
        // ViewModel manages all state
    }
}
```

### 6. Use Equatable for Complex Data

Prevent unnecessary re-renders by conforming to `Equatable`:

```swift
struct Branch: Identifiable, Equatable {
    let id: String
    let name: String
    let isLocal: Bool

    static func == (lhs: Branch, rhs: Branch) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name
    }
}
```

---

## Examples

### Example 1: Creating a Custom Button

```swift
import SwiftUI

struct DSPrimaryButton: View {
    let title: String
    let icon: String?
    let action: () async -> Void

    @State private var isLoading = false
    @State private var isHovered = false

    var body: some View {
        Button {
            Task {
                isLoading = true
                await action()
                isLoading = false
            }
        } label: {
            HStack(spacing: LayoutConstants.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: LayoutConstants.IconSize.md))
                }

                Text(title)
                    .font(.system(size: LayoutConstants.FontSize.md, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, LayoutConstants.Padding.standard)
            .padding(.vertical, LayoutConstants.Padding.compact)
            .background(backgroundColor)
            .cornerRadius(LayoutConstants.CornerRadius.md)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .onHover { isHovered = $0 }
    }

    private var backgroundColor: Color {
        if isLoading {
            return AppTheme.accent.opacity(LayoutConstants.Opacity.strong)
        } else if isHovered {
            return AppTheme.accentHover
        } else {
            return AppTheme.accent
        }
    }
}

// Usage
DSPrimaryButton(title: "Commit", icon: "checkmark") {
    await gitEngine.commit(message: message)
}
```

### Example 2: Creating a Panel Component

```swift
import SwiftUI

struct DSPanel<Content: View>: View {
    let title: String?
    var style: PanelStyle = .default
    @ViewBuilder let content: () -> Content

    enum PanelStyle {
        case `default`
        case highlighted
        case compact

        var backgroundColor: Color {
            switch self {
            case .default: return AppTheme.backgroundSecondary
            case .highlighted: return AppTheme.accent.opacity(0.1)
            case .compact: return AppTheme.backgroundTertiary
            }
        }

        var padding: CGFloat {
            switch self {
            case .default: return LayoutConstants.Padding.standard
            case .highlighted: return LayoutConstants.Padding.comfortable
            case .compact: return LayoutConstants.Padding.compact
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LayoutConstants.Spacing.md) {
            if let title = title {
                Text(title)
                    .font(.system(size: LayoutConstants.FontSize.lg, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
            }

            content()
        }
        .padding(style.padding)
        .background(style.backgroundColor)
        .cornerRadius(LayoutConstants.CornerRadius.lg)
    }
}

// Usage
DSPanel(title: "Recent Activity", style: .highlighted) {
    VStack(spacing: LayoutConstants.Spacing.sm) {
        ForEach(activities) { activity in
            ActivityRow(activity: activity)
        }
    }
}
```

### Example 3: Using Design Tokens Throughout

```swift
struct SettingsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: LayoutConstants.Spacing.lg) {
            // Header
            Text("Appearance")
                .font(.system(size: LayoutConstants.FontSize.xl, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)

            // Settings items
            VStack(spacing: LayoutConstants.Spacing.md) {
                SettingRow(
                    icon: "paintbrush",
                    title: "Theme",
                    value: "Dark"
                )

                SettingRow(
                    icon: "textformat.size",
                    title: "Font Size",
                    value: "Medium"
                )
            }
            .padding(LayoutConstants.Padding.standard)
            .background(AppTheme.backgroundSecondary)
            .cornerRadius(LayoutConstants.CornerRadius.lg)
        }
        .padding(LayoutConstants.Padding.container)
    }
}

struct SettingRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: LayoutConstants.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: LayoutConstants.IconSize.md))
                .foregroundColor(AppTheme.accent)
                .frame(width: LayoutConstants.IconSize.lg, height: LayoutConstants.IconSize.lg)

            Text(title)
                .font(.system(size: LayoutConstants.FontSize.md))
                .foregroundColor(AppTheme.textPrimary)

            Spacer()

            Text(value)
                .font(.system(size: LayoutConstants.FontSize.sm))
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding(.vertical, LayoutConstants.Spacing.sm)
    }
}
```

---

## Theme System

### Dynamic Theming

GitMac supports dynamic theme switching powered by `ThemeManager`:

```swift
// Access current theme
@Environment(\.themeColors) var theme

// Use in views
Color.Theme(theme).accent
Color.Theme(theme).background
Color.Theme(theme).success
```

### Creating Custom Themes

Themes are defined in `ThemeManager` with color schemes:

```swift
struct ColorScheme {
    // Primary
    let accent: ThemedColor
    let accentHover: ThemedColor

    // Backgrounds
    let background: ThemedColor
    let backgroundSecondary: ThemedColor

    // Text
    let text: ThemedColor
    let textSecondary: ThemedColor

    // Semantic
    let success: ThemedColor
    let error: ThemedColor
    let warning: ThemedColor
}
```

### Best Practices

1. **Always use `AppTheme`** for colors (it's theme-aware)
2. **Test in both light and dark** modes
3. **Use semantic colors** (`success`, `error`) over specific hues
4. **Respect system preferences** when possible

---

## Quick Reference

### Common Patterns

```swift
// Standard padding
.padding(LayoutConstants.Padding.standard)

// Standard spacing
VStack(spacing: LayoutConstants.Spacing.md)

// Standard corner radius
.cornerRadius(LayoutConstants.CornerRadius.md)

// Standard icon
Image(systemName: "star")
    .font(.system(size: LayoutConstants.IconSize.md))
    .foregroundColor(AppTheme.accent)

// Standard row height
.frame(height: LayoutConstants.RowHeight.standard)

// Standard border
.overlay(
    RoundedRectangle(cornerRadius: LayoutConstants.CornerRadius.md)
        .stroke(AppTheme.border, lineWidth: LayoutConstants.BorderWidth.standard)
)

// Standard animation
withAnimation(.easeInOut(duration: LayoutConstants.AnimationDuration.standard))
```

---

## Contributing

When creating new components:

1. **Check existing atoms/molecules first** - Don't reinvent the wheel
2. **Use design tokens exclusively** - No hardcoded values
3. **Follow naming conventions** - Descriptive and discoverable
4. **Add documentation** - Comment all public APIs
5. **Create previews** - SwiftUI previews for all components
6. **Test both themes** - Light and dark mode support

---

## Migration Guide

### Migrating Hardcoded Values to Tokens

**Before:**

```swift
.padding(.horizontal, 12)
.background(Color.blue)
.cornerRadius(6)
.font(.system(size: 13))
```

**After:**

```swift
.padding(.horizontal, LayoutConstants.Padding.standard)
.background(AppTheme.accent)
.cornerRadius(LayoutConstants.CornerRadius.md)
.font(.system(size: LayoutConstants.FontSize.lg))
```

### Finding and Replacing

Use Xcode's Find & Replace (⌘⇧F) to locate hardcoded values:

- Search for: `padding\(\.\w+, \d+\)`
- Search for: `Color\(red:.*green:.*blue:`
- Search for: `\.system\(size: \d+\)`

---

**Maintained by:** GitMac Development Team
**Questions?** Check existing components in `/GitMac/UI/Components/` for reference implementations.
