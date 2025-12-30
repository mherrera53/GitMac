import SwiftUI

/// Visual indicator showing file changes with count and add/delete bars
struct FileChangesIndicator: View {
    let additions: Int
    let deletions: Int
    let filesChanged: Int
    let compact: Bool

    @StateObject private var themeManager = ThemeManager.shared

    init(additions: Int, deletions: Int, filesChanged: Int, compact: Bool = false) {
        self.additions = additions
        self.deletions = deletions
        self.filesChanged = filesChanged
        self.compact = compact
    }

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        return HStack(spacing: DesignTokens.Spacing.xs) {
            // File count icon
            HStack(spacing: DesignTokens.Spacing.xxs) {
                Image(systemName: "doc.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(theme.textMuted)

                if filesChanged > 0 {
                    Text("\(filesChanged)")
                        .font(DesignTokens.Typography.caption2)
                        .foregroundColor(theme.text)
                }
            }

            if !compact && (additions > 0 || deletions > 0) {
                // Visual bar (proportional to changes)
                GeometryReader { geo in
                    HStack(spacing: 1) {
                        // Green bar for additions
                        if additions > 0 {
                            Rectangle()
                                .fill(AppTheme.diffAddition)
                                .frame(width: barWidth(for: additions, in: geo.size.width))
                                .frame(height: 8)
                        }

                        // Red bar for deletions
                        if deletions > 0 {
                            Rectangle()
                                .fill(AppTheme.diffDeletion)
                                .frame(width: barWidth(for: deletions, in: geo.size.width))
                                .frame(height: 8)
                        }
                    }
                }
                .frame(width: 60, height: 8)
                .cornerRadius(2)
            }

            if !compact {
                // Text indicators
                HStack(spacing: DesignTokens.Spacing.xxs) {
                    if additions > 0 {
                        Text("+\(additions)")
                            .font(DesignTokens.Typography.caption2.monospacedDigit())
                            .foregroundColor(AppTheme.diffAddition)
                    }

                    if deletions > 0 {
                        Text("-\(deletions)")
                            .font(DesignTokens.Typography.caption2.monospacedDigit())
                            .foregroundColor(AppTheme.diffDeletion)
                    }
                }
            }
        }
    }

    private func barWidth(for count: Int, in totalWidth: CGFloat) -> CGFloat {
        let total = additions + deletions
        guard total > 0 else { return 0 }
        return totalWidth * (CGFloat(count) / CGFloat(total))
    }
}

#Preview {
    VStack(spacing: DesignTokens.Spacing.md) {
        FileChangesIndicator(additions: 150, deletions: 45, filesChanged: 5)
        FileChangesIndicator(additions: 5, deletions: 120, filesChanged: 3)
        FileChangesIndicator(additions: 50, deletions: 50, filesChanged: 10)
        FileChangesIndicator(additions: 10, deletions: 2, filesChanged: 1, compact: true)
    }
    .padding()
    .frame(width: 200)
}
