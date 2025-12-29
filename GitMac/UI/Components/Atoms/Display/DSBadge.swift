//
//  DSBadge.swift
//  GitMac
//
//  Created on 2025-12-28.
//

import SwiftUI

/// Badge semantic variants
enum DSBadgeVariant {
    case info
    case success
    case warning
    case error
    case neutral

    @MainActor
    var backgroundColor: Color {
        switch self {
        case .info: return AppTheme.info.opacity(0.15)
        case .success: return AppTheme.success.opacity(0.15)
        case .warning: return AppTheme.warning.opacity(0.15)
        case .error: return AppTheme.error.opacity(0.15)
        case .neutral: return AppTheme.backgroundSecondary
        }
    }

    @MainActor
    var foregroundColor: Color {
        switch self {
        case .info: return AppTheme.info
        case .success: return AppTheme.success
        case .warning: return AppTheme.warning
        case .error: return AppTheme.error
        case .neutral: return AppTheme.textPrimary
        }
    }
}

/// Design System Badge/Tag component
struct DSBadge: View {
    let text: String
    let variant: DSBadgeVariant
    let icon: String?

    init(_ text: String, variant: DSBadgeVariant = .neutral, icon: String? = nil) {
        self.text = text
        self.variant = variant
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 10))
            }
            Text(text)
                .font(DesignTokens.Typography.caption)
        }
        .foregroundColor(variant.foregroundColor)
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xxs)
        .background(variant.backgroundColor)
        .cornerRadius(DesignTokens.CornerRadius.sm)
    }
}

#Preview("DSBadge Variants") {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
        HStack(spacing: DesignTokens.Spacing.sm) {
            DSBadge("Info", variant: .info)
            DSBadge("Success", variant: .success)
            DSBadge("Warning", variant: .warning)
            DSBadge("Error", variant: .error)
            DSBadge("Neutral", variant: .neutral)
        }

        HStack(spacing: DesignTokens.Spacing.sm) {
            DSBadge("Info", variant: .info, icon: "info.circle")
            DSBadge("Done", variant: .success, icon: "checkmark.circle")
            DSBadge("Alert", variant: .warning, icon: "exclamationmark.triangle")
            DSBadge("Failed", variant: .error, icon: "xmark.circle")
        }

        HStack(spacing: DesignTokens.Spacing.sm) {
            DSBadge("v1.0.0", variant: .neutral, icon: "tag.fill")
            DSBadge("Beta", variant: .info)
            DSBadge("New", variant: .success, icon: "sparkles")
            DSBadge("Deprecated", variant: .warning)
        }
    }
    .padding()
    .background(AppTheme.background)
}
