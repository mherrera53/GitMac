import SwiftUI

// MARK: - Layout Constants

/// Centralized layout constants for consistent spacing and sizing
/// Use these instead of hard-coded values for maintainability
enum LayoutConstants {

    // MARK: - Spacing

    enum Spacing {
        /// Extra small spacing (2pt)
        static let xs: CGFloat = 2

        /// Small spacing (4pt)
        static let sm: CGFloat = 4

        /// Medium spacing (8pt) - Default for most layouts
        static let md: CGFloat = 8

        /// Large spacing (12pt)
        static let lg: CGFloat = 12

        /// Extra large spacing (16pt)
        static let xl: CGFloat = 16

        /// Extra extra large spacing (24pt)
        static let xxl: CGFloat = 24

        /// Section spacing (32pt)
        static let section: CGFloat = 32
    }

    // MARK: - Padding

    enum Padding {
        /// Compact padding (6pt)
        static let compact: CGFloat = 6

        /// Standard padding (12pt)
        static let standard: CGFloat = 12

        /// Comfortable padding (16pt)
        static let comfortable: CGFloat = 16

        /// Large padding (20pt)
        static let large: CGFloat = 20

        /// Container padding (24pt)
        static let container: CGFloat = 24
    }

    // MARK: - Corner Radius

    enum CornerRadius {
        /// Small radius (4pt) - For badges, small buttons
        static let sm: CGFloat = 4

        /// Standard radius (6pt) - For most UI elements
        static let md: CGFloat = 6

        /// Large radius (8pt) - For cards, panels
        static let lg: CGFloat = 8

        /// Extra large radius (12pt) - For prominent containers
        static let xl: CGFloat = 12
    }

    // MARK: - Row Heights

    enum RowHeight {
        /// Compact row (18pt)
        static let compact: CGFloat = 18

        /// Standard row (22pt) - Default for diff lines, file rows
        static let standard: CGFloat = 22

        /// Comfortable row (28pt)
        static let comfortable: CGFloat = 28

        /// Large row (32pt) - For headers, prominent items
        static let large: CGFloat = 32

        /// Extra large row (40pt) - For toolbars
        static let extraLarge: CGFloat = 40
    }

    // MARK: - Icon Sizes

    enum IconSize {
        /// Small icon (12pt)
        static let sm: CGFloat = 12

        /// Medium icon (16pt) - Default
        static let md: CGFloat = 16

        /// Large icon (20pt)
        static let lg: CGFloat = 20

        /// Extra large icon (24pt)
        static let xl: CGFloat = 24

        /// Header icon (32pt)
        static let header: CGFloat = 32
    }

    // MARK: - Button Sizes

    enum ButtonSize {
        /// Compact button (20x20)
        static let compact = CGSize(width: 20, height: 20)

        /// Standard button (24x24)
        static let standard = CGSize(width: 24, height: 24)

        /// Large button (32x32)
        static let large = CGSize(width: 32, height: 32)

        /// Extra large button (40x40)
        static let extraLarge = CGSize(width: 40, height: 40)
    }

    // MARK: - Font Sizes

    enum FontSize {
        /// Caption 2 (9pt)
        static let xs: CGFloat = 9

        /// Caption (10pt)
        static let sm: CGFloat = 10

        /// Body (12pt)
        static let md: CGFloat = 12

        /// Headline (13pt)
        static let lg: CGFloat = 13

        /// Title 3 (16pt)
        static let xl: CGFloat = 16

        /// Title 2 (20pt)
        static let xxl: CGFloat = 20

        /// Title 1 (24pt)
        static let xxxl: CGFloat = 24
    }

    // MARK: - Borders

    enum BorderWidth {
        /// Thin border (0.5pt)
        static let thin: CGFloat = 0.5

        /// Standard border (1pt)
        static let standard: CGFloat = 1

        /// Thick border (2pt)
        static let thick: CGFloat = 2

        /// Extra thick border (3pt)
        static let extraThick: CGFloat = 3
    }

    // MARK: - Opacity

    enum Opacity {
        /// Very subtle (0.1)
        static let subtle: Double = 0.1

        /// Mild (0.3)
        static let mild: Double = 0.3

        /// Medium (0.5)
        static let medium: Double = 0.5

        /// Strong (0.7)
        static let strong: Double = 0.7

        /// Very strong (0.9)
        static let veryStrong: Double = 0.9
    }

    // MARK: - Animation Durations

    enum AnimationDuration {
        /// Fast animation (0.1s)
        static let fast: Double = 0.1

        /// Standard animation (0.15s)
        static let standard: Double = 0.15

        /// Slow animation (0.25s)
        static let slow: Double = 0.25

        /// Very slow animation (0.3s)
        static let verySlow: Double = 0.3
    }

    // MARK: - Z-Index / Layer Order

    enum ZIndex {
        /// Background layer
        static let background: Double = 0

        /// Content layer
        static let content: Double = 1

        /// Overlay layer
        static let overlay: Double = 10

        /// Modal layer
        static let modal: Double = 100

        /// Tooltip layer
        static let tooltip: Double = 1000
    }

    // MARK: - Minimum Widths

    enum MinWidth {
        /// Sidebar minimum width (200pt)
        static let sidebar: CGFloat = 200

        /// Panel minimum width (300pt)
        static let panel: CGFloat = 300

        /// Content minimum width (400pt)
        static let content: CGFloat = 400

        /// Window minimum width (600pt)
        static let window: CGFloat = 600
    }

    // MARK: - Maximum Widths

    enum MaxWidth {
        /// Sidebar maximum width (400pt)
        static let sidebar: CGFloat = 400

        /// Content maximum width (1200pt)
        static let content: CGFloat = 1200

        /// Modal maximum width (600pt)
        static let modal: CGFloat = 600
    }
}

// MARK: - Convenience Extensions

extension View {
    /// Applies standard padding
    func standardPadding() -> some View {
        self.padding(LayoutConstants.Padding.standard)
    }

    /// Applies container padding
    func containerPadding() -> some View {
        self.padding(LayoutConstants.Padding.container)
    }

    /// Applies standard corner radius
    func standardCornerRadius() -> some View {
        self.cornerRadius(LayoutConstants.CornerRadius.md)
    }

    /// Applies standard spacing
    // TODO: Fix generic Content type parameter issue
    /*
    func standardSpacing() -> some View {
        if let vStack = self as? VStack<Content> {
            return AnyView(vStack)
        } else if let hStack = self as? HStack<Content> {
            return AnyView(hStack)
        }
        return AnyView(self)
    }
    */
}

// MARK: - Usage Examples

#if DEBUG
struct LayoutConstants_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading, spacing: LayoutConstants.Spacing.lg) {
            Text("Layout Constants")
                .font(.system(size: LayoutConstants.FontSize.xl, weight: .bold))

            Divider()

            // Spacing examples
            VStack(alignment: .leading, spacing: LayoutConstants.Spacing.md) {
                Text("Spacing")
                    .font(.system(size: LayoutConstants.FontSize.lg, weight: .semibold))

                HStack(spacing: LayoutConstants.Spacing.sm) {
                    Text("XS").padding(LayoutConstants.Padding.compact).background(AppTheme.accent.opacity(0.2))
                    Text("SM").padding(LayoutConstants.Padding.compact).background(AppTheme.accent.opacity(0.2))
                    Text("MD").padding(LayoutConstants.Padding.compact).background(AppTheme.accent.opacity(0.2))
                    Text("LG").padding(LayoutConstants.Padding.compact).background(AppTheme.accent.opacity(0.2))
                }
            }

            Divider()

            // Corner radius examples
            VStack(alignment: .leading, spacing: LayoutConstants.Spacing.md) {
                Text("Corner Radius")
                    .font(.system(size: LayoutConstants.FontSize.lg, weight: .semibold))

                HStack(spacing: LayoutConstants.Spacing.md) {
                    Text("SM")
                        .padding(LayoutConstants.Padding.standard)
                        .background(AppTheme.success.opacity(0.2))
                        .cornerRadius(LayoutConstants.CornerRadius.sm)

                    Text("MD")
                        .padding(LayoutConstants.Padding.standard)
                        .background(AppTheme.success.opacity(0.2))
                        .cornerRadius(LayoutConstants.CornerRadius.md)

                    Text("LG")
                        .padding(LayoutConstants.Padding.standard)
                        .background(AppTheme.success.opacity(0.2))
                        .cornerRadius(LayoutConstants.CornerRadius.lg)
                }
            }

            Divider()

            // Row heights
            VStack(alignment: .leading, spacing: LayoutConstants.Spacing.md) {
                Text("Row Heights")
                    .font(.system(size: LayoutConstants.FontSize.lg, weight: .semibold))

                VStack(alignment: .leading, spacing: LayoutConstants.Spacing.sm) {
                    Text("Compact")
                        .frame(height: LayoutConstants.RowHeight.compact)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.2))

                    Text("Standard")
                        .frame(height: LayoutConstants.RowHeight.standard)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.3))

                    Text("Comfortable")
                        .frame(height: LayoutConstants.RowHeight.comfortable)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.4))
                }
            }
        }
        .containerPadding()
        .frame(width: 500)
    }
}
#endif
