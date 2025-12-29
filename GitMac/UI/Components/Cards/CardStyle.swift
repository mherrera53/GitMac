import SwiftUI

// MARK: - Card Style Modifier

/// Applies consistent card styling with hover effects and borders
struct CardStyle: ViewModifier {
    @Binding var isHovered: Bool
    let accentColor: Color
    let cornerRadius: CGFloat

    init(isHovered: Binding<Bool>, accentColor: Color = AppTheme.accent, cornerRadius: CGFloat = 6) {
        self._isHovered = isHovered
        self.accentColor = accentColor
        self.cornerRadius = cornerRadius
    }

    func body(content: Content) -> some View {
        content
            .padding(10)
            .background(isHovered ? AppTheme.hover : AppTheme.backgroundSecondary)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(isHovered ? accentColor.opacity(0.5) : AppTheme.border, lineWidth: 1)
            )
            .onHover { isHovered = $0 }
    }
}

// MARK: - View Extension

extension View {
    /// Applies card styling with hover effect
    /// - Parameters:
    ///   - isHovered: Binding to hover state
    ///   - accentColor: Color to use for hover border (default: AppTheme.accent)
    ///   - cornerRadius: Corner radius (default: 6)
    /// - Returns: Styled view
    func cardStyle(isHovered: Binding<Bool>, accentColor: Color = AppTheme.accent, cornerRadius: CGFloat = 6) -> some View {
        modifier(CardStyle(isHovered: isHovered, accentColor: accentColor, cornerRadius: cornerRadius))
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Card Style Examples") {
    VStack(spacing: 16) {
        // Example 1: Default card
        CardPreviewExample(
            title: "Default Card",
            accentColor: AppTheme.accent
        )

        // Example 2: Success card
        CardPreviewExample(
            title: "Success Card",
            accentColor: AppTheme.success
        )

        // Example 3: Error card
        CardPreviewExample(
            title: "Error Card",
            accentColor: AppTheme.error
        )
    }
    .padding()
    .frame(width: 300)
    .background(AppTheme.background)
}

private struct CardPreviewExample: View {
    let title: String
    let accentColor: Color
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)

            Text("Hover to see border highlight")
                .font(.system(size: 10))
                .foregroundColor(AppTheme.textSecondary)
        }
        .cardStyle(isHovered: $isHovered, accentColor: accentColor)
    }
}
#endif
