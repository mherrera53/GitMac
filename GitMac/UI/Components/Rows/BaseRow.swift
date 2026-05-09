import SwiftUI

// MARK: - Base Row

/// Generic base row component that handles selection, hover, and actions
/// Use this as a foundation for all list row types
struct BaseRow<Content: View, MenuContent: View>: View {
    let isSelected: Bool
    var style: RowStyle = .default
    var actions: [RowAction] = []
    var onSelect: (() -> Void)? = nil
    @ViewBuilder let content: () -> Content
    @ViewBuilder let contextMenu: () -> MenuContent

    @State private var isHovered = false
    @State private var loadingActions: Set<UUID> = []

    var body: some View {
        HStack(spacing: style.spacing) {
            content()

            Spacer()

            // Hover actions
            if style.showHoverActions && isHovered && !actions.isEmpty {
                HStack(spacing: 4) {
                    ForEach(actions) { action in
                        DSIconButton(
                            iconName: action.icon,
                            variant: .ghost,
                            size: .sm,
                            isDisabled: false,
                            action: action.action
                        )
                        .help(action.tooltip)
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, style.horizontalPadding)
        .padding(.vertical, style.verticalPadding)
        .background(backgroundColor)
        .clipShape(.rect(cornerRadius: style.cornerRadius))
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect?()
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            contextMenu()
        }
    }

    private var backgroundColor: Color {
        if style.highlightOnSelection && isSelected {
            return AppTheme.accent.opacity(0.2)
        } else if style.highlightOnHover && isHovered {
            return AppTheme.hover
        } else {
            return Color.clear
        }
    }
}

// MARK: - BaseRow convenience init (no context menu)

extension BaseRow where MenuContent == EmptyView {
    init(
        isSelected: Bool,
        style: RowStyle = .default,
        actions: [RowAction] = [],
        onSelect: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isSelected = isSelected
        self.style = style
        self.actions = actions
        self.onSelect = onSelect
        self.content = content
        self.contextMenu = { EmptyView() }
    }
}

// MARK: - Base Row with Data

/// Base row that takes RowData directly
struct DataRow<Data: RowData, MenuContent: View>: View {
    let data: Data
    let isSelected: Bool
    var style: RowStyle = .default
    var actions: [RowAction] = []
    var showLeadingIcon: Bool = true
    var showTrailingContent: Bool = true
    var onSelect: (() -> Void)? = nil
    @ViewBuilder let contextMenu: () -> MenuContent

    var body: some View {
        BaseRow(
            isSelected: isSelected,
            style: style,
            actions: actions,
            onSelect: onSelect,
            content: { rowContent },
            contextMenu: contextMenu
        )
    }

    @ViewBuilder
    private var rowContent: some View {
        // Leading icon
        if showLeadingIcon, let icon = data.leadingIcon {
            Image(systemName: icon.systemName)
                .foregroundStyle(icon.color)
                .frame(width: icon.size, height: icon.size)
        }

        // Text content
        VStack(alignment: .leading, spacing: 2) {
            Text(data.primaryText)
                .lineLimit(1)

            if let secondary = data.secondaryText {
                Text(secondary)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
            }
        }

        Spacer()

        // Trailing content
        if showTrailingContent, let trailing = data.trailingContent {
            trailingContentView(trailing)
        }
    }

    @ViewBuilder
    private func trailingContentView(_ content: RowTrailingContent) -> some View {
        switch content {
        case .text(let text, let color):
            Text(text)
                .font(.caption)
                .foregroundStyle(color)

        case .badge(let text, let color):
            Text(text)
                .font(.caption.bold())
                .foregroundStyle(color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(color.opacity(0.2))
                .clipShape(.rect(cornerRadius: 4))

        case .stats(let additions, let deletions):
            DiffStatsView(additions: additions, deletions: deletions)

        case .icon(let systemName, let color):
            Image(systemName: systemName)
                .foregroundStyle(color)

        case .custom(let view):
            AnyView(view)
        }
    }
}

// MARK: - DataRow convenience init (no context menu)

extension DataRow where MenuContent == EmptyView {
    init(
        data: Data,
        isSelected: Bool,
        style: RowStyle = .default,
        actions: [RowAction] = [],
        showLeadingIcon: Bool = true,
        showTrailingContent: Bool = true,
        onSelect: (() -> Void)? = nil
    ) {
        self.data = data
        self.isSelected = isSelected
        self.style = style
        self.actions = actions
        self.showLeadingIcon = showLeadingIcon
        self.showTrailingContent = showTrailingContent
        self.onSelect = onSelect
        self.contextMenu = { EmptyView() }
    }
}

// MARK: - Convenience Extensions

extension BaseRow {
    /// Creates a row with a single text label
    static func text(
        _ text: String,
        isSelected: Bool = false,
        style: RowStyle = .default,
        onSelect: (() -> Void)? = nil
    ) -> BaseRow<Text, EmptyView> where Content == Text, MenuContent == EmptyView {
        BaseRow(
            isSelected: isSelected,
            style: style,
            onSelect: onSelect
        ) {
            Text(text)
        }
    }

    // TODO: Fix generic parameter conflict in iconText convenience initializer
    /*
    /// Creates a row with icon and text
    static func iconText(
        icon: String,
        iconColor: Color = .primary,
        text: String,
        isSelected: Bool = false,
        style: RowStyle = .default,
        onSelect: (() -> Void)? = nil
    ) -> BaseRow<HStack<TupleView<(Image, Text)>>> where Content == HStack<TupleView<(Image, Text)>> {
        BaseRow(
            isSelected: isSelected,
            style: style,
            onSelect: onSelect
        ) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                Text(text)
            }
        }
    }
    */
}

// MARK: - Preview
// TODO: Fix preview to not use commented iconText function

/*
#if DEBUG
struct BaseRow_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 8) {
            // Simple text row
            BaseRow.text("Simple row", isSelected: false)

            // Selected row
            BaseRow.text("Selected row", isSelected: true)

            // Row with icon
            BaseRow.iconText(
                icon: "doc.fill",
                iconColor: .blue,
                text: "File with icon"
            )

            // Row with actions
            BaseRow(isSelected: false, actions: [
                .stage {},
                .discard {}
            ]) {
                HStack {
                    Image(systemName: "doc.fill")
                        .foregroundStyle(AppTheme.accent)
                    Text("Row with hover actions")
                }
            }

            // Compact style
            BaseRow.text("Compact row", style: .compact)

            // Comfortable style
            BaseRow.text("Comfortable row", style: .comfortable)
        }
        .padding()
        .frame(width: 400)
    }
}
#endif
*/
