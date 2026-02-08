import SwiftUI

// MARK: - Stash Badge (Modern - solid background)
struct StashBadge: View {
    let name: String
    @Environment(\.colorScheme) private var colorScheme
    private var stashColor: Color { AppTheme.info }

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xxs + 1) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 9, weight: .medium))
            Text(name)
                .font(DesignTokens.Typography.caption2)
                .fontWeight(.semibold)
                .lineLimit(1)
        }
        .padding(.horizontal, DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
        .padding(.vertical, DesignTokens.Spacing.xxs + 1)
        .background(stashColor)
        .foregroundStyle(AppTheme.buttonTextOnColor) // White text on colored background for contrast
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.none + 3))
    }
}
