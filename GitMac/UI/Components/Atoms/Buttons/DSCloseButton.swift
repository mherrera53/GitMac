//
//  DSCloseButton.swift
//  GitMac
//
//  Created on 28/12/2025.
//  Atomic Design System - Level 2: Close Button Atom
//

import SwiftUI

/// Close button for modals, panels, and tabs
struct DSCloseButton: View {
    let size: DSButtonSize
    let isDisabled: Bool
    let action: () -> Void

    @State private var isHovered = false

    init(
        size: DSButtonSize = .sm,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.size = size
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: iconSizeForSize, weight: .medium))
                .frame(width: buttonSizeForSize, height: buttonSizeForSize)
                .foregroundColor(foregroundColor)
                .background(backgroundColor)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    // MARK: - Size Properties

    private var buttonSizeForSize: CGFloat {
        switch size {
        case .sm: return 18
        case .md: return DesignTokens.Size.buttonHeightSM
        case .lg: return DesignTokens.Size.buttonHeightMD
        }
    }

    private var iconSizeForSize: CGFloat {
        switch size {
        case .sm: return 10
        case .md: return DesignTokens.Size.iconSM
        case .lg: return DesignTokens.Size.iconMD
        }
    }

    // MARK: - Colors

    private var foregroundColor: Color {
        if isDisabled {
            return AppTheme.textMuted
        }

        return isHovered ? AppTheme.textPrimary : AppTheme.textSecondary
    }

    private var backgroundColor: Color {
        if isDisabled {
            return Color.clear
        }

        return isHovered ? AppTheme.error.opacity(0.15) : Color.clear
    }
}

// MARK: - Previews

#Preview("Close Button Sizes") {
    HStack(spacing: DesignTokens.Spacing.lg) {
        VStack {
            DSCloseButton(size: .sm) {
                print("Small close")
            }
            Text("Small")
                .font(DesignTokens.Typography.caption)
        }

        VStack {
            DSCloseButton(size: .md) {
                print("Medium close")
            }
            Text("Medium")
                .font(DesignTokens.Typography.caption)
        }

        VStack {
            DSCloseButton(size: .lg) {
                print("Large close")
            }
            Text("Large")
                .font(DesignTokens.Typography.caption)
        }
    }
    .padding()
}

#Preview("Close Button States") {
    HStack(spacing: DesignTokens.Spacing.lg) {
        VStack {
            DSCloseButton {
                print("Normal close")
            }
            Text("Normal")
                .font(DesignTokens.Typography.caption)
        }

        VStack {
            DSCloseButton(isDisabled: true) {
                print("Disabled close")
            }
            Text("Disabled")
                .font(DesignTokens.Typography.caption)
        }
    }
    .padding()
}

#Preview("Close Button in Context") {
    VStack(spacing: 0) {
        // Modal header example
        HStack {
            Text("Modal Title")
                .font(DesignTokens.Typography.headline)
                .foregroundColor(AppTheme.textPrimary)

            Spacer()

            DSCloseButton {
                print("Close modal")
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(AppTheme.backgroundSecondary)

        // Content area
        Rectangle()
            .fill(AppTheme.background)
            .frame(height: 200)
    }
    .frame(width: 300)
    .cornerRadius(DesignTokens.CornerRadius.lg)
}

#Preview("Close Button on Tab") {
    HStack(spacing: DesignTokens.Spacing.xs) {
        Image(systemName: "doc.text")
            .font(.system(size: DesignTokens.Size.iconSM))
            .foregroundColor(AppTheme.textSecondary)

        Text("Document.swift")
            .font(DesignTokens.Typography.body)
            .foregroundColor(AppTheme.textPrimary)

        DSCloseButton(size: .sm) {
            print("Close tab")
        }
    }
    .padding(.horizontal, DesignTokens.Spacing.sm)
    .padding(.vertical, DesignTokens.Spacing.xs)
    .background(AppTheme.backgroundSecondary)
    .cornerRadius(DesignTokens.CornerRadius.md)
    .padding()
}
