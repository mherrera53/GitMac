import SwiftUI

// MARK: - List Row

/// Simple generic row for lists - most versatile row type
/// Use this when you don't need specialized behavior
struct ListRow: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    var iconColor: Color = .primary
    var badge: String? = nil
    var badgeColor: Color = .blue
    var trailing: ListRowTrailing? = nil
    var isSelected: Bool = false
    var style: RowStyle = .default
    var actions: [RowAction] = []
    var contextMenu: (() -> AnyView)? = nil
    var onSelect: (() -> Void)? = nil

    enum ListRowTrailing {
        case text(String)
        case icon(String, Color = .secondary)
        case badge(String, Color = .secondary)
        case chevron
        case custom(AnyView)
    }

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
        if let icon = icon {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 20)
        }

        // Title and subtitle
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(title)
                    .lineLimit(1)

                if let badge = badge {
                    Text(badge)
                        .font(.caption.bold())
                        .foregroundColor(badgeColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(badgeColor.opacity(0.2))
                        .cornerRadius(4)
                }
            }

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
            }
        }

        Spacer()

        // Trailing content
        if let trailing = trailing {
            trailingView(trailing)
        }
    }

    @ViewBuilder
    private func trailingView(_ content: ListRowTrailing) -> some View {
        switch content {
        case .text(let text):
            Text(text)
                .font(.caption)
                .foregroundColor(AppTheme.textPrimary)

        case .icon(let systemName, let color):
            Image(systemName: systemName)
                .foregroundColor(color)

        case .badge(let text, let color):
            Text(text)
                .font(.caption.bold())
                .foregroundColor(color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(color.opacity(0.2))
                .cornerRadius(4)

        case .chevron:
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(AppTheme.textPrimary)

        case .custom(let view):
            view
        }
    }
}

// MARK: - Convenience Initializers

extension ListRow {
    /// Creates a simple text-only row
    static func text(
        _ title: String,
        isSelected: Bool = false,
        onSelect: (() -> Void)? = nil
    ) -> ListRow {
        ListRow(title: title, isSelected: isSelected, onSelect: onSelect)
    }

    /// Creates a row with icon and text
    static func iconText(
        icon: String,
        iconColor: Color = .primary,
        title: String,
        isSelected: Bool = false,
        onSelect: (() -> Void)? = nil
    ) -> ListRow {
        ListRow(
            title: title,
            icon: icon,
            iconColor: iconColor,
            isSelected: isSelected,
            onSelect: onSelect
        )
    }

    /// Creates a row with title, subtitle, and chevron (navigation style)
    static func navigation(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        isSelected: Bool = false,
        onSelect: (() -> Void)? = nil
    ) -> ListRow {
        ListRow(
            title: title,
            subtitle: subtitle,
            icon: icon,
            trailing: .chevron,
            isSelected: isSelected,
            onSelect: onSelect
        )
    }

    /// Creates a settings-style row
    static func setting(
        title: String,
        value: String,
        icon: String? = nil,
        iconColor: Color = AppTheme.accent,
        isSelected: Bool = false,
        onSelect: (() -> Void)? = nil
    ) -> ListRow {
        ListRow(
            title: title,
            icon: icon,
            iconColor: iconColor,
            trailing: .text(value),
            isSelected: isSelected,
            onSelect: onSelect
        )
    }
}

// MARK: - Preview

#if DEBUG
struct ListRow_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 8) {
            // Simple text row
            ListRow.text("Simple item")

            // Icon and text
            ListRow.iconText(
                icon: "folder.fill",
                iconColor: .blue,
                title: "Documents"
            )

            // With subtitle
            ListRow(
                title: "Project Files",
                subtitle: "Updated 2 hours ago",
                icon: "folder.fill",
                iconColor: .blue
            )

            // With badge
            ListRow(
                title: "Pull Requests",
                icon: "arrow.triangle.pull",
                badge: "3",
                badgeColor: AppTheme.success
            )

            // Navigation style
            ListRow.navigation(
                title: "Settings",
                subtitle: "Configure your preferences",
                icon: "gearshape.fill"
            )

            // Setting row
            ListRow.setting(
                title: "Theme",
                value: "Dark",
                icon: "paintbrush.fill"
            )

            // Selected row
            ListRow(
                title: "Selected Item",
                icon: "checkmark.circle.fill",
                iconColor: AppTheme.success,
                isSelected: true
            )

            // With actions
            ListRow(
                title: "Item with actions",
                icon: "doc.fill",
                actions: [
                    .edit {},
                    .delete {}
                ]
            )

            // Compact style
            ListRow(
                title: "Compact row",
                icon: "star.fill",
                iconColor: .yellow,
                style: .compact
            )
        }
        .padding()
        .frame(width: 400)
    }
}
#endif
