//
//  XcodeBottomBarTab.swift
//  GitMac
//
//  Created on 2025-12-29.
//  Xcode-style bottom bar tab using DesignTokens
//

import SwiftUI

/// Xcode-style tab for bottom panel tab bar
struct XcodeBottomBarTab: View {
    let icon: String
    let title: String
    let color: Color?
    let isSelected: Bool
    let onTap: () -> Void
    let onClose: () -> Void

    @State private var isHovered = false
    @State private var isCloseHovered = false

    init(
        icon: String,
        title: String,
        color: Color? = nil,
        isSelected: Bool = false,
        onTap: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.color = color
        self.isSelected = isSelected
        self.onTap = onTap
        self.onClose = onClose
    }

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: DesignTokens.BottomBar.tabIconSize))
                .foregroundColor(tabColor)

            Text(title)
                .font(.system(size: DesignTokens.BottomBar.tabFontSize, weight: .regular))
                .foregroundColor(tabColor)
                .lineLimit(1)

            if isHovered || isSelected {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: DesignTokens.BottomBar.closeIconSize))
                        .foregroundColor(isCloseHovered ? AppTheme.textPrimary : AppTheme.textSecondary)
                        .frame(
                            width: DesignTokens.BottomBar.closeButtonSize,
                            height: DesignTokens.BottomBar.closeButtonSize
                        )
                        .background(
                            Circle()
                                .fill(isCloseHovered ? AppTheme.hover : Color.clear)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isCloseHovered = hovering
                    }
                }
            }
        }
        .padding(.horizontal, DesignTokens.BottomBar.tabHorizontalPadding)
        .padding(.vertical, DesignTokens.BottomBar.tabVerticalPadding)
        .background(backgroundColor)
        .cornerRadius(DesignTokens.CornerRadius.sm)
        .overlay(
            // Active indicator
            Group {
                if isSelected {
                    VStack {
                        Spacer()
                        Rectangle()
                            .fill(AppTheme.accent)
                            .frame(height: DesignTokens.BottomBar.activeIndicatorHeight)
                    }
                }
            }
        )
        .onTapGesture {
            onTap()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    private var tabColor: Color {
        if isSelected {
            return color ?? AppTheme.accent
        }
        return AppTheme.textSecondary
    }

    private var backgroundColor: Color {
        if isSelected {
            return AppTheme.hover.opacity(0.3)
        }
        if isHovered {
            return AppTheme.hover
        }
        return Color.clear
    }
}

// MARK: - Preview

#Preview("Bottom Bar Tabs") {
    VStack(spacing: 0) {
        HStack(spacing: DesignTokens.BottomBar.tabSpacing) {
            XcodeBottomBarTab(
                icon: "terminal.fill",
                title: "Terminal",
                isSelected: true,
                onTap: { },
                onClose: { }
            )

            XcodeBottomBarTab(
                icon: "tag.fill",
                title: "Taiga",
                color: AppTheme.success,
                isSelected: false,
                onTap: { },
                onClose: { }
            )

            XcodeBottomBarTab(
                icon: "checklist",
                title: "Planner",
                color: AppTheme.warning,
                isSelected: false,
                onTap: { },
                onClose: { }
            )

            Spacer()
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .frame(height: DesignTokens.BottomBar.height)
        .background(VisualEffectBlur.bottomBar)
    }
    .frame(width: 600)
}
