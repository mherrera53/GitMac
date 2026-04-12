import SwiftUI

// MARK: - Branch Badge (Modern)
struct BranchBadge: View {
    let name: String
    let color: Color
    let isHead: Bool
    let isTag: Bool
    var hasWorktree: Bool = false
    var onDropBranch: ((BranchTransferable) -> Void)? = nil
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false
    @State private var isDragTargeted = false

    init(name: String, color: Color, isHead: Bool = false, isTag: Bool = false, hasWorktree: Bool = false, onDropBranch: ((BranchTransferable) -> Void)? = nil) {
        self.name = name
        self.color = color
        self.isHead = isHead
        self.isTag = isTag
        self.hasWorktree = hasWorktree
        self.onDropBranch = onDropBranch
    }

    var body: some View {
        // Simple, clean design like Xcode with proper contrast
        HStack(spacing: DesignTokens.Spacing.xxs) {
            Image(systemName: iconName)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(color)

            Text(name)
                .font(DesignTokens.Typography.caption2)
                .fontWeight(isHead ? .semibold : .regular)
                .lineLimit(1)
                .foregroundStyle(textColor)

            // Worktree indicator
            if hasWorktree {
                Image(systemName: "folder.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(AppTheme.accentPurple)
                    .help("Branch has active worktree")
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.xs + 2)
        .padding(.vertical, DesignTokens.Spacing.xxs + 1)
        .background(isDragTargeted ? AppTheme.accent.opacity(0.3) : color.opacity(colorScheme == .dark ? 0.2 : 0.12))
        .clipShape(.rect(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(isDragTargeted ? AppTheme.accent : color.opacity(0.4), lineWidth: isDragTargeted ? 2 : 0.5)
        )
        .draggable(BranchTransferable(name: name, isHead: isHead))
        .dropDestination(for: BranchTransferable.self) { items, _ in
            guard let dropped = items.first, dropped.name != name else { return false }
            onDropBranch?(dropped)
            return true
        } isTargeted: { targeted in
            isDragTargeted = targeted
        }
    }

    /// Adaptive text color - darker in light mode for better contrast
    private var textColor: Color {
        if colorScheme == .dark {
            return color
        } else {
            // In light mode, use the primary text color for better readability
            return Color(nsColor: .labelColor)
        }
    }

    private var iconName: String {
        if isTag {
            return "tag.circle.fill"
        }
        if isHead {
            return "star.circle.fill"
        }
        return "arrow.triangle.branch"
    }

    private var symbolMode: SymbolRenderingMode {
        if isHead || isTag {
            return .hierarchical
        }
        return .monochrome
    }
}
