import SwiftUI

/// Visual indicator showing file changes with count and add/delete bars
struct FileChangesIndicator: View {
    let additions: Int
    let deletions: Int
    let filesChanged: Int
    let compact: Bool

    @Environment(ThemeManager.self) private var themeManager

    init(additions: Int, deletions: Int, filesChanged: Int, compact: Bool = false) {
        self.additions = additions
        self.deletions = deletions
        self.filesChanged = filesChanged
        self.compact = compact
    }

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        return HStack(spacing: DesignTokens.Spacing.xs) {
            // File count with icon -- always show count
            HStack(spacing: 2) {
                Image(systemName: "doc.fill")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(theme.textMuted)

                Text("\(filesChanged)")
                    .font(DesignTokens.Typography.caption2.monospacedDigit())
                    .foregroundStyle(theme.text)
            }

            // Compact: show mini +/- counts inline
            if compact {
                if additions > 0 || deletions > 0 {
                    HStack(spacing: 2) {
                        if additions > 0 {
                            Text("+\(additions)")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(AppTheme.diffAddition)
                        }
                        if deletions > 0 {
                            Text("-\(deletions)")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(AppTheme.diffDeletion)
                        }
                    }
                }
            } else if additions > 0 || deletions > 0 {
                // Visual bar (proportional to changes)
                GeometryReader { geo in
                    HStack(spacing: 1) {
                        if additions > 0 {
                            Rectangle()
                                .fill(AppTheme.diffAddition)
                                .frame(width: barWidth(for: additions, in: geo.size.width))
                                .frame(height: 8)
                        }
                        if deletions > 0 {
                            Rectangle()
                                .fill(AppTheme.diffDeletion)
                                .frame(width: barWidth(for: deletions, in: geo.size.width))
                                .frame(height: 8)
                        }
                    }
                }
                .frame(width: 60, height: 8)
                .clipShape(.rect(cornerRadius: 2))

                // Text indicators
                HStack(spacing: DesignTokens.Spacing.xxs) {
                    if additions > 0 {
                        Text("+\(additions)")
                            .font(DesignTokens.Typography.caption2.monospacedDigit())
                            .foregroundStyle(AppTheme.diffAddition)
                    }
                    if deletions > 0 {
                        Text("-\(deletions)")
                            .font(DesignTokens.Typography.caption2.monospacedDigit())
                            .foregroundStyle(AppTheme.diffDeletion)
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
