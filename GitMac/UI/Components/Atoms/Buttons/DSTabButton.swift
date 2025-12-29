//
//  DSTabButton.swift
//  GitMac
//
//  Created on 28/12/2025.
//  Atomic Design System - Level 2: Tab Button Atom
//  Replaces: TabButton, TerminalTabButton, BottomPanelTabButton
//

import SwiftUI

/// Tab selector button with active state indicator
struct DSTabButton: View {
    let title: String
    let iconName: String?
    let isSelected: Bool
    let size: DSButtonSize
    let action: () -> Void
    let onClose: (() -> Void)?

    @State private var isHovered = false

    init(
        title: String,
        iconName: String? = nil,
        isSelected: Bool = false,
        size: DSButtonSize = .md,
        onClose: (() -> Void)? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.iconName = iconName
        self.isSelected = isSelected
        self.size = size
        self.onClose = onClose
        self.action = action
    }

    var body: some View {
        HStack(spacing: 0) {
            // Main tab button
            Button(action: action) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    if let iconName = iconName {
                        Image(systemName: iconName)
                            .font(.system(size: iconSizeForSize))
                    }

                    Text(title)
                        .font(fontForSize)
                        .lineLimit(1)
                }
                .padding(.leading, horizontalPaddingForSize)
                .padding(.trailing, onClose != nil && isHovered ? DesignTokens.Spacing.xxs : horizontalPaddingForSize)
                .padding(.vertical, verticalPaddingForSize)
                .frame(height: heightForSize)
            }
            .buttonStyle(.plain)

            // Close button (shown on hover if onClose is provided)
            if let onClose = onClose, isHovered {
                Button(action: {
                    onClose()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: iconSizeForSize * 0.7, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
                .padding(.trailing, DesignTokens.Spacing.xs)
                .onHover { hovering in
                    // Prevent hover state from changing when hovering close button
                }
            }
        }
        .foregroundColor(foregroundColor)
        .background(backgroundColor)
        .cornerRadius(DesignTokens.CornerRadius.md)
        .overlay(
            // Bottom border indicator for selected state
            Rectangle()
                .fill(AppTheme.accent)
                .frame(height: 2)
                .offset(y: heightForSize / 2)
                .opacity(isSelected ? 1 : 0)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }

    // MARK: - Size Properties

    private var fontForSize: Font {
        switch size {
        case .sm: return DesignTokens.Typography.caption
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

    private var iconSizeForSize: CGFloat {
        switch size {
        case .sm: return DesignTokens.Size.iconSM
        case .md: return DesignTokens.Size.iconMD
        case .lg: return DesignTokens.Size.iconLG
        }
    }

    // MARK: - Colors

    private var foregroundColor: Color {
        if isSelected {
            return AppTheme.textPrimary
        }
        return isHovered ? AppTheme.textPrimary : AppTheme.textSecondary
    }

    private var backgroundColor: Color {
        if isSelected {
            return AppTheme.backgroundSecondary.opacity(0.5)
        }
        return isHovered ? AppTheme.backgroundSecondary.opacity(0.3) : Color.clear
    }
}

// MARK: - Previews

#Preview("Tab Buttons") {
    HStack(spacing: DesignTokens.Spacing.xs) {
        DSTabButton(title: "Files", iconName: "folder", isSelected: true) {
            print("Files clicked")
        }

        DSTabButton(title: "History", iconName: "clock", isSelected: false) {
            print("History clicked")
        }

        DSTabButton(title: "Branches", iconName: "arrow.triangle.branch", isSelected: false) {
            print("Branches clicked")
        }
    }
    .padding()
}

#Preview("Tab Sizes") {
    VStack(spacing: DesignTokens.Spacing.md) {
        HStack(spacing: DesignTokens.Spacing.xs) {
            DSTabButton(title: "Small", isSelected: true, size: .sm) {
                print("Small clicked")
            }

            DSTabButton(title: "Tab", isSelected: false, size: .sm) {
                print("Tab clicked")
            }
        }

        HStack(spacing: DesignTokens.Spacing.xs) {
            DSTabButton(title: "Medium", isSelected: true, size: .md) {
                print("Medium clicked")
            }

            DSTabButton(title: "Tab", isSelected: false, size: .md) {
                print("Tab clicked")
            }
        }

        HStack(spacing: DesignTokens.Spacing.xs) {
            DSTabButton(title: "Large", isSelected: true, size: .lg) {
                print("Large clicked")
            }

            DSTabButton(title: "Tab", isSelected: false, size: .lg) {
                print("Tab clicked")
            }
        }
    }
    .padding()
}

#Preview("Text Only Tabs") {
    HStack(spacing: DesignTokens.Spacing.xs) {
        DSTabButton(title: "Overview", isSelected: true) {
            print("Overview clicked")
        }

        DSTabButton(title: "Details", isSelected: false) {
            print("Details clicked")
        }

        DSTabButton(title: "Settings", isSelected: false) {
            print("Settings clicked")
        }
    }
    .padding()
}
