//
//  DSText.swift
//  GitMac
//
//  Created on 2025-12-28.
//

import SwiftUI

/// Semantic text variants for consistent typography
enum DSTextVariant {
    case largeTitle
    case title1
    case title2
    case title3
    case headline
    case body
    case callout
    case caption
    case caption2

    var font: Font {
        switch self {
        case .largeTitle: return DesignTokens.Typography.largeTitle
        case .title1: return DesignTokens.Typography.title1
        case .title2: return DesignTokens.Typography.title2
        case .title3: return DesignTokens.Typography.title3
        case .headline: return DesignTokens.Typography.headline
        case .body: return DesignTokens.Typography.body
        case .callout: return DesignTokens.Typography.callout
        case .caption: return DesignTokens.Typography.caption
        case .caption2: return DesignTokens.Typography.caption2
        }
    }
}

extension DSTextVariant {
    @MainActor
    var defaultColor: Color {
        switch self {
        case .largeTitle, .title1, .title2, .title3, .headline:
            return AppTheme.textPrimary
        case .body, .callout:
            return AppTheme.textSecondary
        case .caption, .caption2:
            return AppTheme.textMuted
        }
    }
}

/// Design System Text component with semantic variants
struct DSText: View {
    let text: String
    let variant: DSTextVariant
    let color: Color?

    init(_ text: String, variant: DSTextVariant = .body, color: Color? = nil) {
        self.text = text
        self.variant = variant
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(variant.font)
            .foregroundColor(color ?? variant.defaultColor)
    }
}

#Preview("DSText Variants") {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
        DSText("Large Title", variant: .largeTitle)
        DSText("Title 1", variant: .title1)
        DSText("Title 2", variant: .title2)
        DSText("Title 3", variant: .title3)
        DSText("Headline Text", variant: .headline)
        DSText("Body text for general content", variant: .body)
        DSText("Callout text for emphasis", variant: .callout)
        DSText("Caption text for details", variant: .caption)
        DSText("Caption 2 smallest text", variant: .caption2)

        Divider().padding(.vertical, DesignTokens.Spacing.sm)

        DSText("Custom colored text", variant: .body, color: AppTheme.accent)
        DSText("Success message", variant: .callout, color: AppTheme.success)
        DSText("Error message", variant: .callout, color: AppTheme.error)
    }
    .padding()
    .background(AppTheme.background)
}
