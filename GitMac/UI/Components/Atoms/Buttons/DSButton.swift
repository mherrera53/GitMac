//
//  DSButton.swift
//  GitMac
//
//  Created on 28/12/2025.
//  Atomic Design System - Level 2: Button Atom
//

import SwiftUI

/// Variant styles for DSButton
enum DSButtonVariant {
    case primary, secondary, danger, ghost, outline, link
}

/// Size options for DSButton
enum DSButtonSize {
    case sm, md, lg
}

/// Shared color policy for text and icon buttons.
@MainActor
struct DSButtonColors {
    let variant: DSButtonVariant
    let isDisabled: Bool
    let isHovered: Bool

    var foreground: Color {
        if isDisabled { return AppTheme.textMuted }
        let preferred: Color
        switch variant {
        case .primary, .danger: return AppTheme.contrastingTextColor(for: background)
        case .secondary: preferred = AppTheme.textPrimary
        case .ghost: preferred = isHovered ? AppTheme.textPrimary : AppTheme.textSecondary
        case .outline, .link: preferred = AppTheme.accent
        }
        return AppTheme.readableTextColor(preferred: preferred, on: background)
    }

    var background: Color {
        if isDisabled { return AppTheme.backgroundSecondary }
        switch variant {
        case .primary: return isHovered ? AppTheme.accentHover : AppTheme.accent
        case .secondary: return isHovered ? AppTheme.backgroundSecondary.opacity(0.8) : AppTheme.backgroundSecondary
        case .danger: return isHovered ? AppTheme.error.opacity(0.9) : AppTheme.error
        case .ghost: return isHovered ? AppTheme.backgroundSecondary.opacity(0.5) : .clear
        case .outline: return isHovered ? AppTheme.accent.opacity(0.1) : .clear
        case .link: return .clear
        }
    }

    var border: Color {
        if isDisabled { return AppTheme.backgroundSecondary }
        return variant == .outline ? AppTheme.accent : .clear
    }
}

/// Base button component with async support and loading states
struct DSButton<Label: View>: View {
    let variant: DSButtonVariant
    let size: DSButtonSize
    let isDisabled: Bool
    let action: () async -> Void
    @ViewBuilder let label: () -> Label

    @State private var isLoading = false
    @State private var isHovered = false

    init(
        variant: DSButtonVariant = .primary,
        size: DSButtonSize = .md,
        isDisabled: Bool = false,
        action: @escaping () async -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.variant = variant
        self.size = size
        self.isDisabled = isDisabled
        self.action = action
        self.label = label
    }

    var body: some View {
        Button {
            guard !isLoading && !isDisabled else { return }
            isLoading = true  // Set immediately to prevent double-clicks
            Task {
                await action()
                isLoading = false
            }
        } label: {
            ZStack {
                label().opacity(isLoading ? 0 : 1)
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(foregroundColor)
                        .accessibilityHidden(true)
                }
            }
            .font(fontForSize)
            .padding(.horizontal, horizontalPaddingForSize)
            .padding(.vertical, verticalPaddingForSize)
            .frame(height: heightForSize)
            .foregroundStyle(foregroundColor)
            .background(backgroundColor)
            .clipShape(.rect(cornerRadius: DesignTokens.CornerRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                    .stroke(borderColor, lineWidth: variant == .outline ? 1 : 0)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    // MARK: - Size Properties

    private var fontForSize: Font {
        switch size {
        case .sm: return DesignTokens.Typography.callout
        case .md: return DesignTokens.Typography.body
        case .lg: return DesignTokens.Typography.headline
        }
    }

    private var heightForSize: CGFloat {
        switch size {
        case .sm: return DesignTokens.Size.buttonHeightSM
        case .md: return DesignTokens.Size.buttonHeightMD
        case .lg: return DesignTokens.Size.buttonHeightLG
        }
    }

    private var horizontalPaddingForSize: CGFloat {
        switch size {
        case .sm: return DesignTokens.Spacing.sm
        case .md: return DesignTokens.Spacing.md
        case .lg: return DesignTokens.Spacing.lg
        }
    }

    private var verticalPaddingForSize: CGFloat {
        switch size {
        case .sm: return DesignTokens.Spacing.xs
        case .md: return DesignTokens.Spacing.sm
        case .lg: return DesignTokens.Spacing.md
        }
    }

    // MARK: - Variant Colors

    private var colors: DSButtonColors { DSButtonColors(variant: variant, isDisabled: isDisabled, isHovered: isHovered) }
    private var foregroundColor: Color { colors.foreground }
    private var backgroundColor: Color { colors.background }
    private var borderColor: Color { colors.border }
}

// MARK: - Convenience Initializers

extension DSButton where Label == Text {
    /// Convenience initializer for text-only buttons with async action
    init(
        _ title: String,
        variant: DSButtonVariant = .primary,
        size: DSButtonSize = .md,
        isDisabled: Bool = false,
        action: @escaping () async -> Void
    ) {
        self.init(variant: variant, size: size, isDisabled: isDisabled, action: action) {
            Text(title)
        }
    }

    /// Convenience initializer for text-only buttons with sync action
    init(
        _ title: String,
        variant: DSButtonVariant = .primary,
        size: DSButtonSize = .md,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.init(variant: variant, size: size, isDisabled: isDisabled, action: {
            action()
        }) {
            Text(title)
        }
    }
}

extension DSButton {
    /// Convenience initializer for custom label with sync action
    init(
        variant: DSButtonVariant = .primary,
        size: DSButtonSize = .md,
        isDisabled: Bool = false,
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.variant = variant
        self.size = size
        self.isDisabled = isDisabled
        self.action = { action() }
        self.label = label
    }
}

// MARK: - Previews

#Preview("Button Variants") {
    VStack(spacing: DesignTokens.Spacing.md) {
        DSButton(variant: .primary) {
            Logger.debug("Primary clicked")
        } label: {
            Text("Primary")
        }

        DSButton(variant: .secondary) {
            Logger.debug("Secondary clicked")
        } label: {
            Text("Secondary")
        }

        DSButton(variant: .danger) {
            Logger.debug("Danger clicked")
        } label: {
            Text("Danger")
        }

        DSButton(variant: .ghost) {
            Logger.debug("Ghost clicked")
        } label: {
            Text("Ghost")
        }

        DSButton(variant: .outline) {
            Logger.debug("Outline clicked")
        } label: {
            Text("Outline")
        }

        DSButton(variant: .link) {
            Logger.debug("Link clicked")
        } label: {
            Text("Link")
        }
    }
    .padding()
}

#Preview("Button Sizes") {
    VStack(spacing: DesignTokens.Spacing.md) {
        DSButton(size: .sm) {
            Logger.debug("Small clicked")
        } label: {
            Text("Small")
        }

        DSButton(size: .md) {
            Logger.debug("Medium clicked")
        } label: {
            Text("Medium")
        }

        DSButton(size: .lg) {
            Logger.debug("Large clicked")
        } label: {
            Text("Large")
        }
    }
    .padding()
}

#Preview("Button States") {
    VStack(spacing: DesignTokens.Spacing.md) {
        DSButton {
            Logger.debug("Normal clicked")
        } label: {
            Text("Normal")
        }

        DSButton(isDisabled: true) {
            Logger.debug("Disabled clicked")
        } label: {
            Text("Disabled")
        }
    }
    .padding()
}
