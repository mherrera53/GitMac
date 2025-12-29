//
//  DSLoadingState.swift
//  GitMac
//
//  Created on 28/12/2025.
//  Atomic Design System - Level 3: Loading State Molecule
//

import SwiftUI

/// Loading state display component - Spinner + Message
struct DSLoadingState: View {
    let message: String
    let style: DSLoadingStyle

    init(
        message: String = "Loading...",
        style: DSLoadingStyle = .standard
    ) {
        self.message = message
        self.style = style
    }

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            ProgressView()
                .scaleEffect(style == .large ? 1.2 : 1.0)
                .tint(AppTheme.accent)

            Text(message)
                .font(style == .large ? DesignTokens.Typography.body : DesignTokens.Typography.caption)
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding(style == .large ? DesignTokens.Spacing.xl : DesignTokens.Spacing.md)
        .frame(maxWidth: style == .inline ? nil : .infinity, maxHeight: style == .inline ? nil : .infinity)
    }
}

/// Loading state style variants
enum DSLoadingStyle {
    case inline      // Small, for inline use
    case standard    // Medium, for content areas
    case large       // Large, for full screens
}

// MARK: - Previews

#Preview("Loading State - Inline") {
    DSLoadingState(
        message: "Loading commits...",
        style: .inline
    )
    .padding()
    .background(AppTheme.background)
}

#Preview("Loading State - Standard") {
    DSLoadingState(
        message: "Fetching repository data...",
        style: .standard
    )
    .frame(width: 400, height: 300)
    .background(AppTheme.background)
}

#Preview("Loading State - Large") {
    DSLoadingState(
        message: "Cloning repository...",
        style: .large
    )
    .frame(width: 600, height: 400)
    .background(AppTheme.background)
}

#Preview("Loading States - All Variants") {
    VStack(spacing: DesignTokens.Spacing.xl) {
        DSLoadingState(message: "Inline loading", style: .inline)
            .padding()
            .background(AppTheme.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.md)

        DSLoadingState(message: "Standard loading", style: .standard)
            .frame(height: 150)
            .background(AppTheme.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.md)

        DSLoadingState(message: "Large loading", style: .large)
            .frame(height: 200)
            .background(AppTheme.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.md)
    }
    .padding()
    .background(AppTheme.background)
}
