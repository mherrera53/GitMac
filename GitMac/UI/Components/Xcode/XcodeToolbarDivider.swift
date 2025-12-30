//
//  XcodeToolbarDivider.swift
//  GitMac
//
//  Created on 2025-12-29.
//  Xcode-style toolbar divider using DesignTokens
//

import SwiftUI

/// Xcode-style vertical divider for toolbar button groups
struct XcodeToolbarDivider: View {
    var body: some View {
        Rectangle()
            .fill(AppTheme.border)
            .frame(
                width: DesignTokens.Toolbar.dividerWidth,
                height: DesignTokens.Toolbar.dividerHeight
            )
    }
}

// MARK: - Preview

#Preview("Toolbar Divider") {
    HStack(spacing: DesignTokens.Spacing.sm) {
        XcodeToolbarButton(icon: "arrow.uturn.backward") { }
        XcodeToolbarButton(icon: "arrow.uturn.forward") { }

        XcodeToolbarDivider()
            .padding(.horizontal, DesignTokens.Spacing.xs)

        XcodeToolbarButton(icon: "arrow.down.circle", color: AppTheme.info) { }
        XcodeToolbarButton(icon: "arrow.up.circle.fill", color: AppTheme.accent) { }
    }
    .padding()
    .frame(height: DesignTokens.Toolbar.height)
    .background(VisualEffectBlur.toolbar)
}
