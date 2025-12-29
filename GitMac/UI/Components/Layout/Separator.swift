import SwiftUI

// MARK: - Separator

/// Styled separator/divider for layouts
/// Provides horizontal and vertical separators with modern styling
struct Separator: View {
    var orientation: Orientation = .horizontal
    var style: SeparatorStyle = .default
    var thickness: CGFloat? = nil
    var color: Color? = nil

    enum Orientation {
        case horizontal
        case vertical
    }

    enum SeparatorStyle {
        case `default`      // Standard border color
        case subtle         // Very light separator
        case prominent      // Darker, more visible
        case accent         // Uses accent color
    }

    var body: some View {
        Rectangle()
            .fill(separatorColor)
            .frame(
                width: orientation == .vertical ? (thickness ?? defaultThickness) : nil,
                height: orientation == .horizontal ? (thickness ?? defaultThickness) : nil
            )
    }

    private var separatorColor: Color {
        if let color = color {
            return color
        }

        switch style {
        case .default:
            return AppTheme.border
        case .subtle:
            return AppTheme.border.opacity(0.3)
        case .prominent:
            return AppTheme.border.opacity(1.5)
        case .accent:
            return AppTheme.accent.opacity(0.5)
        }
    }

    private var defaultThickness: CGFloat {
        switch style {
        case .default: return 1
        case .subtle: return 1
        case .prominent: return 2
        case .accent: return 2
        }
    }
}

// MARK: - Convenience Initializers

extension Separator {
    /// Creates a horizontal separator (default)
    static func horizontal(
        style: SeparatorStyle = .default,
        thickness: CGFloat? = nil,
        color: Color? = nil
    ) -> Separator {
        Separator(orientation: .horizontal, style: style, thickness: thickness, color: color)
    }

    /// Creates a vertical separator
    static func vertical(
        style: SeparatorStyle = .default,
        thickness: CGFloat? = nil,
        color: Color? = nil
    ) -> Separator {
        Separator(orientation: .vertical, style: style, thickness: thickness, color: color)
    }

    /// Creates a subtle horizontal separator
    static var subtle: Separator {
        Separator(style: .subtle)
    }

    /// Creates a prominent horizontal separator
    static var prominent: Separator {
        Separator(style: .prominent)
    }

    /// Creates an accent-colored horizontal separator
    static var accent: Separator {
        Separator(style: .accent)
    }
}

// MARK: - Sectioned Separator

/// Separator with optional label/text in the middle
struct SectionedSeparator: View {
    let text: String?
    var style: Separator.SeparatorStyle = .default

    init(_ text: String? = nil, style: Separator.SeparatorStyle = .default) {
        self.text = text
        self.style = style
    }

    var body: some View {
        if let text = text {
            HStack(spacing: 12) {
                Separator(style: style)
                Text(text)
                    .font(.caption)
                    .foregroundColor(AppTheme.textPrimary)
                Separator(style: style)
            }
        } else {
            Separator(style: style)
        }
    }
}

// MARK: - Inset Separator

/// Separator with horizontal insets (padding on sides)
struct InsetSeparator: View {
    var leading: CGFloat = 12
    var trailing: CGFloat = 12
    var style: Separator.SeparatorStyle = .default

    var body: some View {
        HStack(spacing: 0) {
            Spacer()
                .frame(width: leading)
            Separator(style: style)
            Spacer()
                .frame(width: trailing)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct Separator_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 24) {
            // Horizontal separators
            VStack(alignment: .leading, spacing: 12) {
                Text("Horizontal Separators").font(.headline)

                Text("Default")
                Separator.horizontal()

                Text("Subtle")
                Separator.subtle

                Text("Prominent")
                Separator.prominent

                Text("Accent")
                Separator.accent

                Text("Custom color and thickness")
                Separator.horizontal(thickness: 3, color: .purple)
            }

            Divider()

            // Vertical separators
            VStack(alignment: .leading, spacing: 12) {
                Text("Vertical Separators").font(.headline)

                HStack(spacing: 16) {
                    Text("Left")
                    Separator.vertical(style: .default)
                        .frame(height: 40)
                    Text("Middle")
                    Separator.vertical(style: .prominent)
                        .frame(height: 40)
                    Text("Right")
                }
            }

            Divider()

            // Sectioned separators
            VStack(alignment: .leading, spacing: 12) {
                Text("Sectioned Separators").font(.headline)

                SectionedSeparator("OR")
                SectionedSeparator("SECTION", style: .prominent)
                SectionedSeparator(style: .accent)
            }

            Divider()

            // Inset separators
            VStack(alignment: .leading, spacing: 12) {
                Text("Inset Separators").font(.headline)

                InsetSeparator()
                InsetSeparator(leading: 40, trailing: 40, style: .prominent)
                InsetSeparator(leading: 100, trailing: 20, style: .accent)
            }
        }
        .padding()
        .frame(width: 500)
    }
}
#endif
