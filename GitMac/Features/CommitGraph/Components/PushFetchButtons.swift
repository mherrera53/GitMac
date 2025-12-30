import SwiftUI

struct PushFetchButtons: View {
    let currentBranch: Branch?
    let aheadCount: Int
    let behindCount: Int
    let lastFetchDate: Date?
    let onPush: () -> Void
    let onFetch: () -> Void

    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        return HStack(spacing: DesignTokens.Spacing.xs) {
            // Push button
            Button(action: onPush) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(DesignTokens.Typography.callout)
                        .foregroundColor(aheadCount > 0 ? AppTheme.success : theme.textMuted)

                    Text("Push")
                        .font(DesignTokens.Typography.callout)
                        .foregroundColor(theme.text)

                    if aheadCount > 0 {
                        Text("\(aheadCount)")
                            .font(DesignTokens.Typography.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.textPrimary)
                            .padding(.horizontal, DesignTokens.Spacing.xs)
                            .padding(.vertical, 2)
                            .background(AppTheme.success)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .background(theme.backgroundTertiary)
                .cornerRadius(DesignTokens.CornerRadius.md)
            }
            .buttonStyle(.plain)
            .disabled(aheadCount == 0 || currentBranch == nil)
            .help(aheadCount > 0 ? "Push \(aheadCount) commits" : "Nothing to push")

            // Fetch button
            Button(action: onFetch) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(DesignTokens.Typography.callout)
                        .foregroundColor(behindCount > 0 ? AppTheme.warning : theme.textMuted)

                    Text("Fetch")
                        .font(DesignTokens.Typography.callout)
                        .foregroundColor(theme.text)

                    if let lastFetch = lastFetchDate {
                        Text("(\(relativeTime(from: lastFetch)))")
                            .font(DesignTokens.Typography.caption2)
                            .foregroundColor(theme.textMuted)
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .background(theme.backgroundTertiary)
                .cornerRadius(DesignTokens.CornerRadius.md)
            }
            .buttonStyle(.plain)
            .help("Fetch from remote")
        }
    }

    private func relativeTime(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)

        if days > 0 {
            return "\(days)d ago"
        } else if hours > 0 {
            return "\(hours)h ago"
        } else if minutes > 0 {
            return "\(minutes)m ago"
        } else {
            return "just now"
        }
    }
}
