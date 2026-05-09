import SwiftUI

struct ThemeButton: View {
    @Environment(ThemeManager.self) private var themeManager
    let theme: Theme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: theme.icon)
                    .font(DesignTokens.Typography.iconXXL)
                    .foregroundStyle(isSelected ? .white : iconColor)
                    .frame(width: DesignTokens.Spacing.xxl + DesignTokens.Spacing.lg, height: DesignTokens.Spacing.xxl + DesignTokens.Spacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                            .fill(isSelected ? AppTheme.accent : AppTheme.backgroundSecondary)
                    )

                Text(theme.displayName)
                    .foregroundStyle(AppTheme.textPrimary)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }

    private var iconColor: Color {
        switch theme {
        case .system: return AppTheme.textSecondary
        case .light: return AppTheme.warning
        case .dark: return AppTheme.accent
        case .custom: return AppTheme.accent.opacity(0.8)
        }
    }
}
