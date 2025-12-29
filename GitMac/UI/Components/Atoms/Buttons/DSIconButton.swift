//
//  DSIconButton.swift
//  GitMac
//
//  Created on 28/12/2025.
//  Atomic Design System - Level 2: Icon Button Atom
//

import SwiftUI

/// Icon-only button with circular design
struct DSIconButton: View {
    let iconName: String
    let variant: DSButtonVariant
    let size: DSButtonSize
    let isDisabled: Bool
    let action: () async -> Void

    @State private var isLoading = false
    @State private var isHovered = false

    init(
        iconName: String,
        variant: DSButtonVariant = .ghost,
        size: DSButtonSize = .md,
        isDisabled: Bool = false,
        action: @escaping () async -> Void
    ) {
        self.iconName = iconName
        self.variant = variant
        self.size = size
        self.isDisabled = isDisabled
        self.action = action
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
            ZStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                } else {
                    Image(systemName: iconName)
                        .font(.system(size: iconSizeForSize))
                }
            }
            .frame(width: buttonSizeForSize, height: buttonSizeForSize)
            .foregroundColor(foregroundColor)
            .background(backgroundColor)
            .clipShape(Circle())
            .overlay(
                Circle()
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

    private var buttonSizeForSize: CGFloat {
        switch size {
        case .sm: return DesignTokens.Size.buttonHeightSM
        case .md: return DesignTokens.Size.buttonHeightMD
        case .lg: return DesignTokens.Size.buttonHeightLG
        }
    }

    private var iconSizeForSize: CGFloat {
        switch size {
        case .sm: return DesignTokens.Size.iconSM
        case .md: return DesignTokens.Size.iconMD
        case .lg: return DesignTokens.Size.iconLG
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

#Preview("Icon Button Variants") {
    HStack(spacing: DesignTokens.Spacing.md) {
        DSIconButton(iconName: "star.fill", variant: .primary) {
            print("Primary clicked")
        }

        DSIconButton(iconName: "heart.fill", variant: .secondary) {
            print("Secondary clicked")
        }

        DSIconButton(iconName: "trash", variant: .danger) {
            print("Danger clicked")
        }

        DSIconButton(iconName: "gear", variant: .ghost) {
            print("Ghost clicked")
        }

        DSIconButton(iconName: "plus", variant: .outline) {
            print("Outline clicked")
        }
    }
    .padding()
}

#Preview("Icon Button Sizes") {
    HStack(spacing: DesignTokens.Spacing.md) {
        DSIconButton(iconName: "star.fill", size: .sm) {
            print("Small clicked")
        }

        DSIconButton(iconName: "star.fill", size: .md) {
            print("Medium clicked")
        }

        DSIconButton(iconName: "star.fill", size: .lg) {
            print("Large clicked")
        }
    }
    .padding()
}

#Preview("Icon Button States") {
    HStack(spacing: DesignTokens.Spacing.md) {
        DSIconButton(iconName: "star.fill") {
            print("Normal clicked")
        }

        DSIconButton(iconName: "star.fill", isDisabled: true) {
            print("Disabled clicked")
        }
    }
    .padding()
}
