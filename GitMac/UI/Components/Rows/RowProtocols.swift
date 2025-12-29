import SwiftUI

// MARK: - Row Data Protocol

/// Protocol for data that can be displayed in a row
protocol RowData: Identifiable {
    /// Primary text to display
    var primaryText: String { get }

    /// Optional secondary text (smaller, below primary)
    var secondaryText: String? { get }

    /// Leading icon configuration
    var leadingIcon: RowIcon? { get }

    /// Trailing content type (stats, badge, etc.)
    var trailingContent: RowTrailingContent? { get }
}

// MARK: - Row Icon

/// Represents an icon that can be displayed in a row
struct RowIcon {
    let systemName: String
    let color: Color
    let size: CGFloat

    init(systemName: String, color: Color = .primary, size: CGFloat = 16) {
        self.systemName = systemName
        self.color = color
        self.size = size
    }
}

// MARK: - Row Trailing Content

/// Different types of content that can appear at the end of a row
enum RowTrailingContent {
    case text(String, Color = .secondary)
    case badge(String, Color)
    case stats(additions: Int, deletions: Int)
    case icon(String, Color)
    case custom(AnyView)
}

// MARK: - Row Action

/// Represents an action that can be performed on a row
struct RowAction: Identifiable {
    let id = UUID()
    let icon: String
    let color: Color
    let tooltip: String
    let action: () async -> Void

    init(icon: String, color: Color = .blue, tooltip: String, action: @escaping () async -> Void) {
        self.icon = icon
        self.color = color
        self.tooltip = tooltip
        self.action = action
    }

    // MARK: - Common Actions

    @MainActor
    static func stage(action: @escaping () async -> Void) -> RowAction {
        RowAction(
            icon: "plus.circle",
            color: AppTheme.success,
            tooltip: "Stage",
            action: action
        )
    }

    @MainActor
    static func unstage(action: @escaping () async -> Void) -> RowAction {
        RowAction(
            icon: "minus.circle",
            color: AppTheme.warning,
            tooltip: "Unstage",
            action: action
        )
    }

    @MainActor
    static func discard(action: @escaping () async -> Void) -> RowAction {
        RowAction(
            icon: "xmark.circle",
            color: AppTheme.error,
            tooltip: "Discard",
            action: action
        )
    }

    @MainActor
    static func delete(action: @escaping () async -> Void) -> RowAction {
        RowAction(
            icon: "trash",
            color: AppTheme.error,
            tooltip: "Delete",
            action: action
        )
    }

    @MainActor
    static func edit(action: @escaping () async -> Void) -> RowAction {
        RowAction(
            icon: "pencil",
            color: AppTheme.accent,
            tooltip: "Edit",
            action: action
        )
    }
}

// MARK: - Row Style

/// Visual style configuration for rows
struct RowStyle {
    var horizontalPadding: CGFloat = 12
    var verticalPadding: CGFloat = 6
    var spacing: CGFloat = 8
    var cornerRadius: CGFloat = 4
    var showHoverActions: Bool = true
    var highlightOnHover: Bool = true
    var highlightOnSelection: Bool = true

    static let `default` = RowStyle()
    static let compact = RowStyle(verticalPadding: 4, spacing: 6)
    static let comfortable = RowStyle(verticalPadding: 8, spacing: 10)
}

// MARK: - Selectable Protocol

/// Protocol for rows that can be selected
protocol Selectable {
    var isSelected: Bool { get }
    var onSelect: (() -> Void)? { get }
}

// MARK: - Hoverable Protocol

/// Protocol for rows that respond to hover
protocol Hoverable {
    var isHovered: Bool { get set }
}

// MARK: - Actionable Protocol

/// Protocol for rows that have actions
protocol Actionable {
    var actions: [RowAction] { get }
}
