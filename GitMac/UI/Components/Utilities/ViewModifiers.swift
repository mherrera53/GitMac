//
//  ViewModifiers.swift
//  GitMac
//
//  Created on 28/12/2025.
//  Atomic Design System - Utilities: Reusable View Modifiers
//

import SwiftUI

// MARK: - Hover Effect Modifier

/// Applies consistent hover effect with background and optional border
struct DSHoverEffect: ViewModifier {
    @Binding var isHovered: Bool
    let backgroundColor: Color?
    let borderColor: Color?
    let cornerRadius: CGFloat
    let animationDuration: Double

    init(
        isHovered: Binding<Bool>,
        backgroundColor: Color? = AppTheme.hover,
        borderColor: Color? = nil,
        cornerRadius: CGFloat = DesignTokens.CornerRadius.md,
        animationDuration: Double = DesignTokens.Animation.fast
    ) {
        self._isHovered = isHovered
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
        self.cornerRadius = cornerRadius
        self.animationDuration = animationDuration
    }

    func body(content: Content) -> some View {
        content
            .background(isHovered && backgroundColor != nil ? backgroundColor : Color.clear)
            .cornerRadius(cornerRadius)
            .overlay(
                borderColor != nil ?
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(isHovered ? borderColor! : Color.clear, lineWidth: 1)
                : nil
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: animationDuration)) {
                    isHovered = hovering
                }
            }
    }
}

// MARK: - Conditional Modifier

/// Applies a modifier conditionally
struct DSConditionalModifier<TrueModifier: ViewModifier, FalseModifier: ViewModifier>: ViewModifier {
    let condition: Bool
    let trueModifier: TrueModifier
    let falseModifier: FalseModifier

    func body(content: Content) -> some View {
        Group {
            if condition {
                content.modifier(trueModifier)
            } else {
                content.modifier(falseModifier)
            }
        }
    }
}

// MARK: - Loading State Modifier

/// Displays loading overlay on the view
struct DSLoadingOverlay: ViewModifier {
    let isLoading: Bool
    let text: String?

    func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(isLoading)
                .blur(radius: isLoading ? 2 : 0)

            if isLoading {
                VStack(spacing: DesignTokens.Spacing.md) {
                    ProgressView()
                        .scaleEffect(1.2)

                    if let text = text {
                        Text(text)
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
                .padding(DesignTokens.Spacing.xl)
                .background(AppTheme.backgroundSecondary)
                .cornerRadius(DesignTokens.CornerRadius.lg)
                .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 4)
            }
        }
    }
}

// MARK: - Card Style Modifier

/// Applies card styling with elevation and shadow
struct DSCardStyle: ViewModifier {
    let elevation: Elevation
    @State private var isHovered = false

    enum Elevation {
        case none, low, medium, high

        var shadowRadius: CGFloat {
            switch self {
            case .none: return 0
            case .low: return 2
            case .medium: return 4
            case .high: return 8
            }
        }

        var shadowOpacity: Double {
            switch self {
            case .none: return 0
            case .low: return 0.1
            case .medium: return 0.15
            case .high: return 0.25
            }
        }
    }

    func body(content: Content) -> some View {
        content
            .background(AppTheme.backgroundTertiary)
            .cornerRadius(DesignTokens.CornerRadius.lg)
            .shadow(
                color: AppTheme.shadow.opacity(isHovered ? elevation.shadowOpacity * 1.5 : elevation.shadowOpacity),
                radius: isHovered ? elevation.shadowRadius * 1.5 : elevation.shadowRadius,
                x: 0,
                y: isHovered ? elevation.shadowRadius / 2 : elevation.shadowRadius / 3
            )
            .onHover { hovering in
                withAnimation(DesignTokens.Animation.fastEasing) {
                    isHovered = hovering
                }
            }
    }
}

// MARK: - Shimmer Effect Modifier

/// Adds shimmer loading effect for skeleton screens
struct DSShimmer: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        Color.clear,
                        AppTheme.backgroundSecondary.opacity(0.3),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 300
                }
            }
    }
}

// MARK: - Selection Highlight Modifier

/// Highlights the view when selected
struct DSSelectionHighlight: ViewModifier {
    let isSelected: Bool
    let color: Color
    let style: SelectionStyle

    enum SelectionStyle {
        case background, border, accent
    }

    init(
        isSelected: Bool,
        color: Color = AppTheme.accent,
        style: SelectionStyle = .background
    ) {
        self.isSelected = isSelected
        self.color = color
        self.style = style
    }

    func body(content: Content) -> some View {
        switch style {
        case .background:
            content
                .background(isSelected ? color.opacity(0.15) : Color.clear)
                .cornerRadius(DesignTokens.CornerRadius.md)

        case .border:
            content
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                        .stroke(isSelected ? color : Color.clear, lineWidth: 2)
                )

        case .accent:
            content
                .overlay(
                    isSelected ?
                    Rectangle()
                        .fill(color)
                        .frame(width: 3)
                        .cornerRadius(1.5, corners: [.topRight, .bottomRight])
                    : nil,
                    alignment: .leading
                )
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Applies hover effect with consistent styling
    func hoverEffect(
        isHovered: Binding<Bool>,
        backgroundColor: Color? = AppTheme.hover,
        borderColor: Color? = nil,
        cornerRadius: CGFloat = DesignTokens.CornerRadius.md,
        animationDuration: Double = DesignTokens.Animation.fast
    ) -> some View {
        modifier(DSHoverEffect(
            isHovered: isHovered,
            backgroundColor: backgroundColor,
            borderColor: borderColor,
            cornerRadius: cornerRadius,
            animationDuration: animationDuration
        ))
    }

    /// Applies modifier conditionally
    func `if`<TrueModifier: ViewModifier, FalseModifier: ViewModifier>(
        _ condition: Bool,
        then trueModifier: TrueModifier,
        else falseModifier: FalseModifier
    ) -> some View {
        modifier(DSConditionalModifier(
            condition: condition,
            trueModifier: trueModifier,
            falseModifier: falseModifier
        ))
    }

    /// Applies modifier conditionally (simple version)
    func `if`<M: ViewModifier>(_ condition: Bool, modifier: M) -> some View {
        Group {
            if condition {
                self.modifier(modifier)
            } else {
                self
            }
        }
    }

    /// Displays loading overlay
    func loadingOverlay(isLoading: Bool, text: String? = nil) -> some View {
        modifier(DSLoadingOverlay(isLoading: isLoading, text: text))
    }

    /// Applies card styling with elevation
    func cardStyle(elevation: DSCardStyle.Elevation = .low) -> some View {
        modifier(DSCardStyle(elevation: elevation))
    }

    /// Adds shimmer effect
    func shimmer() -> some View {
        modifier(DSShimmer())
    }

    /// Highlights when selected
    func selectionHighlight(
        isSelected: Bool,
        color: Color = AppTheme.accent,
        style: DSSelectionHighlight.SelectionStyle = .background
    ) -> some View {
        modifier(DSSelectionHighlight(isSelected: isSelected, color: color, style: style))
    }
}

// MARK: - Corner Radius Extension

extension View {
    /// Applies corner radius to specific corners
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Previews

#Preview("Hover Effect") {
    VStack(spacing: DesignTokens.Spacing.md) {
        HoverEffectPreview()
    }
    .padding()
    .background(AppTheme.background)
}

private struct HoverEffectPreview: View {
    @State private var isHovered1 = false
    @State private var isHovered2 = false
    @State private var isHovered3 = false

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Text("Hover me (background)")
                .padding()
                .hoverEffect(isHovered: $isHovered1)

            Text("Hover me (border)")
                .padding()
                .hoverEffect(isHovered: $isHovered2, backgroundColor: nil, borderColor: AppTheme.accent)

            Text("Hover me (both)")
                .padding()
                .hoverEffect(isHovered: $isHovered3, borderColor: AppTheme.success)
        }
    }
}

#Preview("Card Styles") {
    VStack(spacing: DesignTokens.Spacing.lg) {
        Text("No Elevation")
            .padding()
            .cardStyle(elevation: .none)

        Text("Low Elevation")
            .padding()
            .cardStyle(elevation: .low)

        Text("Medium Elevation")
            .padding()
            .cardStyle(elevation: .medium)

        Text("High Elevation")
            .padding()
            .cardStyle(elevation: .high)
    }
    .padding()
    .background(AppTheme.background)
}

#Preview("Selection Highlights") {
    VStack(spacing: DesignTokens.Spacing.md) {
        Text("Background Selection")
            .padding()
            .selectionHighlight(isSelected: true, style: .background)

        Text("Border Selection")
            .padding()
            .selectionHighlight(isSelected: true, style: .border)

        Text("Accent Bar Selection")
            .padding()
            .selectionHighlight(isSelected: true, style: .accent)

        Text("Not Selected")
            .padding()
            .selectionHighlight(isSelected: false, style: .background)
    }
    .padding()
    .background(AppTheme.background)
}

#Preview("Loading Overlay") {
    LoadingOverlayPreview()
}

private struct LoadingOverlayPreview: View {
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            Text("Content Area")
                .frame(width: 300, height: 200)
                .background(AppTheme.backgroundSecondary)
                .cornerRadius(DesignTokens.CornerRadius.lg)
                .loadingOverlay(isLoading: isLoading, text: "Loading data...")

            DSButton(variant: .primary) {
                isLoading.toggle()
            } label: {
                Text(isLoading ? "Stop Loading" : "Start Loading")
            }
        }
        .padding()
        .background(AppTheme.background)
    }
}

#Preview("Shimmer Effect") {
    VStack(spacing: DesignTokens.Spacing.md) {
        Rectangle()
            .fill(AppTheme.backgroundSecondary)
            .frame(height: 60)
            .cornerRadius(DesignTokens.CornerRadius.md)
            .shimmer()

        Rectangle()
            .fill(AppTheme.backgroundSecondary)
            .frame(height: 40)
            .cornerRadius(DesignTokens.CornerRadius.md)
            .shimmer()

        Rectangle()
            .fill(AppTheme.backgroundSecondary)
            .frame(height: 80)
            .cornerRadius(DesignTokens.CornerRadius.md)
            .shimmer()
    }
    .padding()
    .background(AppTheme.background)
}
