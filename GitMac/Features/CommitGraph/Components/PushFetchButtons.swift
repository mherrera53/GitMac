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
            // Push button with enhanced icons
            Button(action: onPush) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: aheadCount > 0 ? "arrow.up.square.fill" : "arrow.up.circle")
                        .font(DesignTokens.Typography.callout)
                        .foregroundColor(aheadCount > 0 ? AppTheme.success : theme.textMuted)
                        .symbolRenderingMode(.hierarchical)

                    Text("Push")
                        .font(DesignTokens.Typography.callout)
                        .fontWeight(aheadCount > 0 ? .semibold : .regular)
                        .foregroundColor(theme.text)

                    if aheadCount > 0 {
                        ZStack {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [AppTheme.success, AppTheme.success.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: AppTheme.success.opacity(0.3), radius: 2, x: 0, y: 1)

                            Text("\(aheadCount)")
                                .font(DesignTokens.Typography.caption2.monospacedDigit())
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        .frame(height: 18)
                        .padding(.horizontal, DesignTokens.Spacing.xs)
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

            // Fetch button with enhanced icons
            Button(action: onFetch) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: behindCount > 0 ? "arrow.down.square.fill" : "arrow.down.circle")
                        .font(DesignTokens.Typography.callout)
                        .foregroundColor(behindCount > 0 ? AppTheme.warning : theme.textMuted)
                        .symbolRenderingMode(.hierarchical)

                    Text("Fetch")
                        .font(DesignTokens.Typography.callout)
                        .fontWeight(behindCount > 0 ? .semibold : .regular)
                        .foregroundColor(theme.text)

                    if let lastFetch = lastFetchDate {
                        Text("(\(relativeTime(from: lastFetch)))")
                            .font(DesignTokens.Typography.caption2.monospacedDigit())
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
