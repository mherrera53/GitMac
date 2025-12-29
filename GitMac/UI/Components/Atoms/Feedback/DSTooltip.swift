//
//  DSTooltip.swift
//  GitMac
//
//  Created on 2025-12-28.
//

import SwiftUI

/// Design System Tooltip wrapper component
struct DSTooltip<Content: View>: View {
    let tooltip: String
    let content: Content

    @State private var isHovering = false

    init(_ tooltip: String, @ViewBuilder content: () -> Content) {
        self.tooltip = tooltip
        self.content = content()
    }

    var body: some View {
        content
            .help(tooltip) // Native macOS tooltip
            .overlay(alignment: .top) {
                if isHovering {
                    VStack {
                        Text(tooltip)
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(AppTheme.textPrimary)
                            .padding(.horizontal, DesignTokens.Spacing.sm)
                            .padding(.vertical, DesignTokens.Spacing.xs)
                            .background(AppTheme.backgroundTertiary)
                            .cornerRadius(DesignTokens.CornerRadius.sm)
                            .shadow(color: AppTheme.shadow, radius: 4, x: 0, y: 2)
                            .offset(y: -40)
                            .transition(.opacity)
                    }
                }
            }
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovering = hovering
                }
            }
    }
}

#Preview("DSTooltip Examples") {
    VStack(spacing: DesignTokens.Spacing.xl) {
        // Icon with tooltip
        DSTooltip("Settings") {
            DSIcon("gear", size: .lg, color: AppTheme.accent)
        }

        // Button with tooltip
        DSTooltip("Click to save your changes") {
            Button(action: {}) {
                Text("Save")
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .background(AppTheme.accent)
                    .foregroundColor(AppTheme.buttonTextOnColor)
                    .cornerRadius(DesignTokens.CornerRadius.md)
            }
            .buttonStyle(.plain)
        }

        // Badge with tooltip
        DSTooltip("This feature is currently in beta") {
            DSBadge("Beta", variant: .warning, icon: "exclamationmark.triangle")
        }

        // Text with tooltip
        DSTooltip("Additional information appears here") {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Text("Hover me")
                    .font(DesignTokens.Typography.body)
                DSIcon("info.circle", size: .sm, color: AppTheme.info)
            }
        }

        Text("Hover over the items above to see tooltips")
            .font(DesignTokens.Typography.caption)
            .foregroundColor(AppTheme.textMuted)
    }
    .padding()
    .frame(width: 400, height: 500)
    .background(AppTheme.background)
}
