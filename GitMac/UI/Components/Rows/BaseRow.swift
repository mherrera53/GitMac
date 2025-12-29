import SwiftUI

// MARK: - Base Row

/// Generic base row component that handles selection, hover, and actions
/// Use this as a foundation for all list row types
struct BaseRow<Content: View>: View {
    let isSelected: Bool
    var style: RowStyle = .default
    var actions: [RowAction] = []
    var contextMenu: (() -> AnyView)? = nil
    var onSelect: (() -> Void)? = nil
    @ViewBuilder let content: () -> Content

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
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .padding(.horizontal, style.horizontalPadding)
        .padding(.vertical, style.verticalPadding)
        .background(backgroundColor)
        .cornerRadius(style.cornerRadius)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect?()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            if let menu = contextMenu {
                menu()
            }
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

// MARK: - Base Row with Data

/// Base row that takes RowData directly
struct DataRow<Data: RowData>: View {
    let data: Data
    let isSelected: Bool
    var style: RowStyle = .default
    var actions: [RowAction] = []
    var showLeadingIcon: Bool = true
    var showTrailingContent: Bool = true
    var contextMenu: (() -> AnyView)? = nil
    var onSelect: (() -> Void)? = nil

    var body: some View {
        BaseRow(
            isSelected: isSelected,
            style: style,
            actions: actions,
            contextMenu: contextMenu,
            onSelect: onSelect
        ) {
            rowContent
        }
    }

    @ViewBuilder
    private var rowContent: some View {
        // Leading icon
        if showLeadingIcon, let icon = data.leadingIcon {
            Image(systemName: icon.systemName)
                .foregroundColor(icon.color)
                .frame(width: icon.size, height: icon.size)
        }

        // Text content
        VStack(alignment: .leading, spacing: 2) {
            Text(data.primaryText)
                .lineLimit(1)

            if let secondary = data.secondaryText {
                Text(secondary)
                    .font(.caption)
                    .foregroundColor(AppTheme.textPrimary)
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
                .foregroundColor(color)

        case .badge(let text, let color):
            Text(text)
                .font(.caption.bold())
                .foregroundColor(color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(color.opacity(0.2))
                .cornerRadius(4)

        case .stats(let additions, let deletions):
            DiffStatsView(additions: additions, deletions: deletions)

        case .icon(let systemName, let color):
            Image(systemName: systemName)
                .foregroundColor(color)

        case .custom(let view):
            view
        }
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
    ) -> BaseRow<Text> where Content == Text {
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
                    .foregroundColor(iconColor)
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
                        .foregroundColor(AppTheme.accent)
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
