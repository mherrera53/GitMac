import SwiftUI

// MARK: - Section Header

/// Collapsible section header with icon, title, count, and actions
/// Used for grouping file lists, branches, commits, etc.
struct SectionHeader<Actions: View>: View {
    let title: String
    let count: Int
    let icon: String
    var color: Color = AppTheme.accent
    var isCollapsible: Bool = true
    @Binding var isExpanded: Bool
    @ViewBuilder var actions: () -> Actions
    var style: HeaderStyle = .default

    enum HeaderStyle {
        case `default`      // Standard padding and background
        case compact        // Reduced padding
        case prominent      // Larger text, more prominent
    }

    @State private var isHovered = false

    var body: some View {
        HStack {
            // Collapse/Expand button
            if isCollapsible {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: style.spacing) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(style.chevronFont)
                            .foregroundColor(AppTheme.chevronColor)

                        Image(systemName: icon)
                            .font(style.iconFont)
                            .foregroundColor(color)

                        Text(title)
                            .font(style.titleFont)
                            .fontWeight(style.titleWeight)

                        Text("(\(count))")
                            .font(style.countFont)
                            .foregroundColor(AppTheme.textSecondary)

                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: style.spacing) {
                    Image(systemName: icon)
                        .font(style.iconFont)
                        .foregroundColor(color)

                    Text(title)
                        .font(style.titleFont)
                        .fontWeight(style.titleWeight)

                    Text("(\(count))")
                        .font(style.countFont)
                        .foregroundColor(AppTheme.textSecondary)

                    Spacer()
                }
            }

            // Actions
            actions()
        }
        .padding(.horizontal, style.horizontalPadding)
        .padding(.vertical, style.verticalPadding)
        .background(backgroundColor)
        .onHover { isHovered = $0 }
    }

    private var backgroundColor: Color {
        switch style {
        case .default:
            return isHovered ? AppTheme.hover : Color(nsColor: .controlBackgroundColor)
        case .compact:
            return .clear
        case .prominent:
            return isHovered ? color.opacity(0.15) : color.opacity(0.1)
        }
    }
}

// MARK: - Header Style Extension

extension SectionHeader.HeaderStyle {
    var spacing: CGFloat {
        switch self {
        case .default: return 8
        case .compact: return 6
        case .prominent: return 10
        }
    }

    var chevronFont: Font {
        switch self {
        case .default: return .caption
        case .compact: return .caption2
        case .prominent: return .body
        }
    }

    var iconFont: Font {
        switch self {
        case .default: return .body
        case .compact: return .caption
        case .prominent: return .title3
        }
    }

    var titleFont: Font {
        switch self {
        case .default: return .body
        case .compact: return .caption
        case .prominent: return .title3
        }
    }

    var titleWeight: Font.Weight {
        switch self {
        case .default: return .medium
        case .compact: return .regular
        case .prominent: return .semibold
        }
    }

    var countFont: Font {
        switch self {
        case .default: return .body
        case .compact: return .caption
        case .prominent: return .title3
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .default: return 12
        case .compact: return 8
        case .prominent: return 16
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .default: return 8
        case .compact: return 4
        case .prominent: return 12
        }
    }
}

// MARK: - Convenience Initializers

extension SectionHeader where Actions == EmptyView {
    /// Creates a section header without actions
    init(
        title: String,
        count: Int,
        icon: String,
        color: Color = AppTheme.accent,
        isCollapsible: Bool = true,
        isExpanded: Binding<Bool>,
        style: HeaderStyle = .default
    ) {
        self.title = title
        self.count = count
        self.icon = icon
        self.color = color
        self.isCollapsible = isCollapsible
        self._isExpanded = isExpanded
        self.actions = { EmptyView() }
        self.style = style
    }

    /// Creates a non-collapsible section header
    static func fixed(
        title: String,
        count: Int,
        icon: String,
        color: Color = AppTheme.accent,
        style: HeaderStyle = .default
    ) -> SectionHeader<EmptyView> {
        SectionHeader(
            title: title,
            count: count,
            icon: icon,
            color: color,
            isCollapsible: false,
            isExpanded: .constant(true),
            style: style
        )
    }
}

// MARK: - Preview

#if DEBUG
struct SectionHeader_Previews: PreviewProvider {
    @State static var isExpanded1 = true
    @State static var isExpanded2 = false
    @State static var isExpanded3 = true

    static var previews: some View {
        VStack(spacing: 16) {
            // Default style
            SectionHeader(
                title: "Unstaged Files",
                count: 15,
                icon: "doc.badge.ellipsis",
                color: AppTheme.warning,
                isExpanded: $isExpanded1
            )

            // With actions
            SectionHeader(
                title: "Staged Files",
                count: 8,
                icon: "checkmark.circle.fill",
                color: AppTheme.success,
                isExpanded: $isExpanded2
            ) {
                HStack(spacing: 4) {
                    DSIconButton(iconName: "minus.circle.fill", variant: .ghost, size: .sm, action: { print("Unstage all") })
                        .help("Unstage All")
                    DSIconButton(iconName: "trash.fill", variant: .ghost, size: .sm, action: { print("Discard all") })
                        .help("Discard All")
                }
            }

            // Compact style
            SectionHeader(
                title: "Local Branches",
                count: 12,
                icon: "arrow.branch",
                color: AppTheme.accent,
                isExpanded: $isExpanded3,
                style: .compact
            )

            // Prominent style
            SectionHeader(
                title: "Recent Commits",
                count: 42,
                icon: "clock",
                color: AppTheme.accentPurple,
                isExpanded: .constant(true),
                style: .prominent
            )

            // Fixed (non-collapsible)
            SectionHeader.fixed(
                title: "Remote Branches",
                count: 5,
                icon: "cloud",
                color: AppTheme.accentCyan
            )
        }
        .padding()
        .frame(width: 400)
    }
}
#endif
