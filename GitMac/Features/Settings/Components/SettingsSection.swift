import SwiftUI

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(title)
                .foregroundStyle(AppTheme.textPrimary)
                .font(DesignTokens.Typography.headline)
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.top, DesignTokens.Spacing.md)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                content()
            }
        }
    }
}
