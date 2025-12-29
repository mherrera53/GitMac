import SwiftUI

// MARK: - Fast Hunk Header

/// Optimized hunk header rendering
/// Displays the @@ -line,count +line,count @@ header for diff hunks
struct FastHunkHeader: View {
    let header: String
    var style: HeaderStyle = .default
    var actions: [HunkAction] = []
    var onHover: ((Bool) -> Void)? = nil

    enum HeaderStyle {
        case `default`  // Cyan background
        case compact    // Minimal padding
        case prominent  // Larger, more visible
    }

    struct HunkAction: Identifiable {
        let id = UUID()
        let icon: String
        let color: Color
        let tooltip: String
        let action: () async -> Void
    }

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            // Hunk separator line
            Rectangle()
                .fill(AppTheme.border.opacity(0.3))
                .frame(height: 1)
                .padding(.bottom, 4)

            HStack(spacing: 8) {
                // Hunk header text
                Text(header)
                    .font(headerFont)
                    .foregroundColor(headerColor)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Hover actions
                if !actions.isEmpty && isHovered {
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
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(backgroundColor)
        }
        .frame(height: rowHeight + 5) // Add height for separator
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
            onHover?(hovering)
        }
    }

    private var headerFont: Font {
        switch style {
        case .default: return .system(size: 11, design: .monospaced)
        case .compact: return .system(size: 10, design: .monospaced)
        case .prominent: return .system(size: 12, weight: .medium, design: .monospaced)
        }
    }

    private var headerColor: Color {
        switch style {
        case .default, .compact: return AppTheme.accentCyan
        case .prominent: return .white
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .default, .compact:
            return AppTheme.accentCyan.opacity(isHovered ? 0.15 : 0.1)
        case .prominent:
            return AppTheme.accentCyan.opacity(isHovered ? 0.9 : 0.7)
        }
    }

    private var horizontalPadding: CGFloat {
        style == .compact ? 6 : 8
    }

    private var verticalPadding: CGFloat {
        switch style {
        case .default: return 4
        case .compact: return 2
        case .prominent: return 6
        }
    }

    private var rowHeight: CGFloat {
        switch style {
        case .default: return 22
        case .compact: return 18
        case .prominent: return 28
        }
    }
}

// MARK: - Hunk Header with Actions

/// Hunk header with built-in stage/discard actions
/// Displays hover actions for staging or discarding the entire hunk
struct HunkHeaderWithActions: View {
    let header: String
    var onStage: (() async -> Void)? = nil
    var onDiscard: (() async -> Void)? = nil
    var style: FastHunkHeader.HeaderStyle = .default

    private var actions: [FastHunkHeader.HunkAction] {
        var result: [FastHunkHeader.HunkAction] = []

        if let stage = onStage {
            result.append(FastHunkHeader.HunkAction(
                icon: "plus.circle.fill",
                color: AppTheme.diffAddition,
                tooltip: "Stage Hunk",
                action: stage
            ))
        }

        if let discard = onDiscard {
            result.append(FastHunkHeader.HunkAction(
                icon: "trash.fill",
                color: AppTheme.diffDeletion,
                tooltip: "Discard Hunk",
                action: discard
            ))
        }

        return result
    }

    var body: some View {
        FastHunkHeader(header: header, style: style, actions: actions)
    }
}

// MARK: - Convenience Initializers

extension FastHunkHeader {
    /// Creates a default hunk header
    static func `default`(header: String) -> FastHunkHeader {
        FastHunkHeader(header: header, style: .default)
    }

    /// Creates a compact hunk header
    static func compact(header: String) -> FastHunkHeader {
        FastHunkHeader(header: header, style: .compact)
    }

    /// Creates a prominent hunk header
    static func prominent(header: String) -> FastHunkHeader {
        FastHunkHeader(header: header, style: .prominent)
    }

    /// Creates a hunk header with stage action
    static func withStage(header: String, onStage: @escaping () async -> Void) -> FastHunkHeader {
        let action = HunkAction(
            icon: "plus.circle.fill",
            color: AppTheme.diffAddition,
            tooltip: "Stage Hunk",
            action: onStage
        )
        return FastHunkHeader(header: header, actions: [action])
    }

    /// Creates a hunk header with discard action
    static func withDiscard(header: String, onDiscard: @escaping () async -> Void) -> FastHunkHeader {
        let action = HunkAction(
            icon: "trash.fill",
            color: AppTheme.diffDeletion,
            tooltip: "Discard Hunk",
            action: onDiscard
        )
        return FastHunkHeader(header: header, actions: [action])
    }

    /// Creates a hunk header with both stage and discard actions
    static func withActions(
        header: String,
        onStage: @escaping () async -> Void,
        onDiscard: @escaping () async -> Void
    ) -> FastHunkHeader {
        let actions = [
            HunkAction(
                icon: "plus.circle.fill",
                color: AppTheme.diffAddition,
                tooltip: "Stage Hunk",
                action: onStage
            ),
            HunkAction(
                icon: "trash.fill",
                color: AppTheme.diffDeletion,
                tooltip: "Discard Hunk",
                action: onDiscard
            )
        ]
        return FastHunkHeader(header: header, actions: actions)
    }
}

// MARK: - Preview

#if DEBUG
struct DiffHunkView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            // Default style
            VStack(alignment: .leading, spacing: 4) {
                Text("Default Style").font(.headline)
                FastHunkHeader(header: "@@ -42,7 +42,8 @@ func calculateSum()")
                FastHunkHeader(header: "@@ -1,3 +1,5 @@ import SwiftUI")
            }

            Divider()

            // With actions
            VStack(alignment: .leading, spacing: 4) {
                Text("With Actions (hover to see)").font(.headline)
                HunkHeaderWithActions(
                    header: "@@ -10,4 +10,6 @@ struct MyView: View",
                    onStage: { print("Stage hunk") },
                    onDiscard: { print("Discard hunk") }
                )
            }

            Divider()

            // Compact style
            VStack(alignment: .leading, spacing: 4) {
                Text("Compact Style").font(.headline)
                FastHunkHeader.compact(header: "@@ -1,1 +1,1 @@")
            }

            Divider()

            // Prominent style
            VStack(alignment: .leading, spacing: 4) {
                Text("Prominent Style").font(.headline)
                FastHunkHeader.prominent(header: "@@ -100,20 +100,25 @@ class Repository")
            }
        }
        .padding()
        .frame(width: 600)
    }
}
#endif
