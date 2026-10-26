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
            Logger.debug("🔵 DSIconButton CLICKED: icon=\(iconName) isLoading=\(isLoading) isDisabled=\(isDisabled)")
            guard !isLoading && !isDisabled else {
                Logger.debug("⛔ DSIconButton BLOCKED: isLoading=\(isLoading) isDisabled=\(isDisabled)")
                return
            }
            isLoading = true  // Set immediately to prevent double-clicks
            Logger.debug("▶️ DSIconButton STARTING action...")
            Task {
                await action()
                Logger.debug("✅ DSIconButton action COMPLETED")
                isLoading = false
            }
        } label: {
            ZStack {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(foregroundColor)
                } else {
                    Image(systemName: iconName)
                        .font(.system(size: iconSizeForSize))
                }
            }
            .frame(width: buttonSizeForSize, height: buttonSizeForSize)
            .foregroundStyle(foregroundColor)
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

    private var colors: DSButtonColors { DSButtonColors(variant: variant, isDisabled: isDisabled, isHovered: isHovered) }
    private var foregroundColor: Color { colors.foreground }
    private var backgroundColor: Color { colors.background }
    private var borderColor: Color { colors.border }
}

// MARK: - Convenience Initializers

extension DSIconButton {
    /// Convenience initializer for icon buttons with sync action
    init(
        iconName: String,
        variant: DSButtonVariant = .ghost,
        size: DSButtonSize = .md,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.iconName = iconName
        self.variant = variant
        self.size = size
        self.isDisabled = isDisabled
        self.action = { action() }
    }
}

// MARK: - Previews

#Preview("Icon Button Variants") {
    HStack(spacing: DesignTokens.Spacing.md) {
        DSIconButton(iconName: "star.fill", variant: .primary) {
            Logger.debug("Primary clicked")
        }

        DSIconButton(iconName: "heart.fill", variant: .secondary) {
            Logger.debug("Secondary clicked")
        }

        DSIconButton(iconName: "trash", variant: .danger) {
            Logger.debug("Danger clicked")
        }

        DSIconButton(iconName: "gear", variant: .ghost) {
            Logger.debug("Ghost clicked")
        }

        DSIconButton(iconName: "plus", variant: .outline) {
            Logger.debug("Outline clicked")
        }
    }
    .padding()
}

#Preview("Icon Button Sizes") {
    HStack(spacing: DesignTokens.Spacing.md) {
        DSIconButton(iconName: "star.fill", size: .sm) {
            Logger.debug("Small clicked")
        }

        DSIconButton(iconName: "star.fill", size: .md) {
            Logger.debug("Medium clicked")
        }

        DSIconButton(iconName: "star.fill", size: .lg) {
            Logger.debug("Large clicked")
        }
    }
    .padding()
}

#Preview("Icon Button States") {
    HStack(spacing: DesignTokens.Spacing.md) {
        DSIconButton(iconName: "star.fill") {
            Logger.debug("Normal clicked")
        }

        DSIconButton(iconName: "star.fill", isDisabled: true) {
            Logger.debug("Disabled clicked")
        }
    }
    .padding()
}
