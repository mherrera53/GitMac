//
//  DSProgressBar.swift
//  GitMac
//
//  Created on 2025-12-28.
//

import SwiftUI

/// Design System Progress Bar component
struct DSProgressBar: View {
    let value: Double // 0.0 to 1.0
    let height: CGFloat
    let backgroundColor: Color?
    let foregroundColor: Color?

    init(value: Double, height: CGFloat = 6, backgroundColor: Color? = nil, foregroundColor: Color? = nil) {
        self.value = min(max(value, 0.0), 1.0) // Clamp between 0 and 1
        self.height = height
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(backgroundColor ?? AppTheme.backgroundSecondary)

                // Foreground progress
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(foregroundColor ?? AppTheme.accent)
                    .frame(width: geometry.size.width * value)
            }
        }
        .frame(height: height)
    }
}

#Preview("DSProgressBar Variants") {
    VStack(spacing: DesignTokens.Spacing.lg) {
        // Different progress values
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("25% Complete")
                .font(DesignTokens.Typography.caption)
            DSProgressBar(value: 0.25)
        }

        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("50% Complete")
                .font(DesignTokens.Typography.caption)
            DSProgressBar(value: 0.5)
        }

        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("75% Complete")
                .font(DesignTokens.Typography.caption)
            DSProgressBar(value: 0.75)
        }

        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("100% Complete")
                .font(DesignTokens.Typography.caption)
            DSProgressBar(value: 1.0, foregroundColor: AppTheme.success)
        }

        Divider()

        // Different heights
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Thin (4pt)")
                .font(DesignTokens.Typography.caption)
            DSProgressBar(value: 0.6, height: 4)
        }

        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Medium (8pt)")
                .font(DesignTokens.Typography.caption)
            DSProgressBar(value: 0.6, height: 8)
        }

        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Thick (12pt)")
                .font(DesignTokens.Typography.caption)
            DSProgressBar(value: 0.6, height: 12)
        }

        Divider()

        // Semantic colors
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Success")
                .font(DesignTokens.Typography.caption)
            DSProgressBar(value: 0.8, foregroundColor: AppTheme.success)
        }

        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Warning")
                .font(DesignTokens.Typography.caption)
            DSProgressBar(value: 0.5, foregroundColor: AppTheme.warning)
        }

        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Error")
                .font(DesignTokens.Typography.caption)
            DSProgressBar(value: 0.3, foregroundColor: AppTheme.error)
        }
    }
    .padding()
    .background(AppTheme.background)
}
