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
            Task {
                isLoading = true
                await action()
                isLoading = false
            }
        } label: {
            HStack(spacing: DesignTokens.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    label()
                }
            }
            .font(fontForSize)
            .padding(.horizontal, horizontalPaddingForSize)
            .padding(.vertical, verticalPaddingForSize)
            .frame(height: heightForSize)
            .foregroundColor(foregroundColor)
            .background(backgroundColor)
            .cornerRadius(DesignTokens.CornerRadius.md)
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

    private var foregroundColor: Color {
        if isDisabled {
            return AppTheme.textMuted
        }

        switch variant {
        case .primary:
            return .white
        case .secondary:
            return AppTheme.textPrimary
        case .danger:
            return .white
        case .ghost:
            return isHovered ? AppTheme.textPrimary : AppTheme.textSecondary
        case .outline:
            return AppTheme.accent
        case .link:
            return AppTheme.accent
        }
    }

    private var backgroundColor: Color {
        if isDisabled {
            return AppTheme.backgroundSecondary
        }

        switch variant {
        case .primary:
            return isHovered ? AppTheme.accent.opacity(0.9) : AppTheme.accent
        case .secondary:
            return isHovered ? AppTheme.backgroundSecondary.opacity(0.8) : AppTheme.backgroundSecondary
        case .danger:
            return isHovered ? AppTheme.error.opacity(0.9) : AppTheme.error
        case .ghost:
            return isHovered ? AppTheme.backgroundSecondary.opacity(0.5) : Color.clear
        case .outline:
            return isHovered ? AppTheme.accent.opacity(0.1) : Color.clear
        case .link:
            return Color.clear
        }
    }

    private var borderColor: Color {
        if isDisabled {
            return AppTheme.backgroundSecondary
        }

        return variant == .outline ? AppTheme.accent : Color.clear
    }
}

// MARK: - Previews

#Preview("Button Variants") {
    VStack(spacing: DesignTokens.Spacing.md) {
        DSButton(variant: .primary) {
            print("Primary clicked")
        } label: {
            Text("Primary")
        }

        DSButton(variant: .secondary) {
            print("Secondary clicked")
        } label: {
            Text("Secondary")
        }

        DSButton(variant: .danger) {
            print("Danger clicked")
        } label: {
            Text("Danger")
        }

        DSButton(variant: .ghost) {
            print("Ghost clicked")
        } label: {
            Text("Ghost")
        }

        DSButton(variant: .outline) {
            print("Outline clicked")
        } label: {
            Text("Outline")
        }

        DSButton(variant: .link) {
            print("Link clicked")
        } label: {
            Text("Link")
        }
    }
    .padding()
}

#Preview("Button Sizes") {
    VStack(spacing: DesignTokens.Spacing.md) {
        DSButton(size: .sm) {
            print("Small clicked")
        } label: {
            Text("Small")
        }

        DSButton(size: .md) {
            print("Medium clicked")
        } label: {
            Text("Medium")
        }

        DSButton(size: .lg) {
            print("Large clicked")
        } label: {
            Text("Large")
        }
    }
    .padding()
}

#Preview("Button States") {
    VStack(spacing: DesignTokens.Spacing.md) {
        DSButton {
            print("Normal clicked")
        } label: {
            Text("Normal")
        }

        DSButton(isDisabled: true) {
            print("Disabled clicked")
        } label: {
            Text("Disabled")
        }
    }
    .padding()
}
