import SwiftUI

/// Shared scrolling and content insets for section-based settings pages.
/// Form-based panes keep their native Form behavior instead of nesting scroll views.
struct SettingsPage<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        DSScrollView(bounce: false) {
            DSVStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignTokens.Spacing.lg)
        }
        .background(AppTheme.background)
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(title)
                .font(DesignTokens.Typography.headline)
                .foregroundStyle(AppTheme.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, DesignTokens.Spacing.md)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                content()
            }
        }
    }
}
