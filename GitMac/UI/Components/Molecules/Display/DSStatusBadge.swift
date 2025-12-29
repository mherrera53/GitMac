//
//  DSStatusBadge.swift
//  GitMac
//
//  Created on 28/12/2025.
//  Atomic Design System - Level 3: Status Badge Molecule
//

import SwiftUI

/// Status badge display component - Icon + Text badge
struct DSStatusBadge: View {
    let text: String
    let icon: String?
    let variant: DSStatusVariant
    let size: DSBadgeSize

    init(
        _ text: String,
        icon: String? = nil,
        variant: DSStatusVariant = .neutral,
        size: DSBadgeSize = .md
    ) {
        self.text = text
        self.icon = icon
        self.variant = variant
        self.size = size
    }

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            if let icon = icon {
                DSIcon(icon, size: iconSize, color: foregroundColor)
            }

            Text(text)
                .font(font)
                .foregroundColor(foregroundColor)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(backgroundColor)
        .cornerRadius(cornerRadius)
    }

    // MARK: - Variant Colors

    private var foregroundColor: Color {
        switch variant {
        case .success: return AppTheme.success
        case .warning: return AppTheme.warning
        case .error: return AppTheme.error
        case .info: return AppTheme.info
        case .neutral: return AppTheme.textSecondary
        case .primary: return AppTheme.accent
        }
    }

    private var backgroundColor: Color {
        switch variant {
        case .success: return AppTheme.success.opacity(0.15)
        case .warning: return AppTheme.warning.opacity(0.15)
        case .error: return AppTheme.error.opacity(0.15)
        case .info: return AppTheme.info.opacity(0.15)
        case .neutral: return AppTheme.backgroundSecondary
        case .primary: return AppTheme.accent.opacity(0.15)
        }
    }

    // MARK: - Size Properties

    private var font: Font {
        switch size {
        case .sm: return DesignTokens.Typography.caption
        case .md: return DesignTokens.Typography.caption
        case .lg: return DesignTokens.Typography.body
        }
    }

    private var iconSize: DSIconSize {
        switch size {
        case .sm: return .sm
        case .md: return .sm
        case .lg: return .md
        }
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .sm: return DesignTokens.Spacing.xs
        case .md: return DesignTokens.Spacing.sm
        case .lg: return DesignTokens.Spacing.md
        }
    }

    private var verticalPadding: CGFloat {
        switch size {
        case .sm: return DesignTokens.Spacing.xxs
        case .md: return DesignTokens.Spacing.xs
        case .lg: return DesignTokens.Spacing.sm
        }
    }

    private var cornerRadius: CGFloat {
        switch size {
        case .sm: return DesignTokens.CornerRadius.sm
        case .md: return DesignTokens.CornerRadius.md
        case .lg: return DesignTokens.CornerRadius.lg
        }
    }
}

/// Status badge variants
enum DSStatusVariant {
    case success, warning, error, info, neutral, primary
}

/// Badge size options
enum DSBadgeSize {
    case sm, md, lg
}

// MARK: - Previews

#Preview("Status Badge - Variants") {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
        DSStatusBadge("Success", icon: "checkmark.circle.fill", variant: .success)
        DSStatusBadge("Warning", icon: "exclamationmark.triangle.fill", variant: .warning)
        DSStatusBadge("Error", icon: "xmark.circle.fill", variant: .error)
        DSStatusBadge("Info", icon: "info.circle.fill", variant: .info)
        DSStatusBadge("Neutral", icon: "circle.fill", variant: .neutral)
        DSStatusBadge("Primary", icon: "star.fill", variant: .primary)
    }
    .padding()
    .background(AppTheme.background)
}

#Preview("Status Badge - Sizes") {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
        DSStatusBadge("Small", icon: "tag.fill", variant: .primary, size: .sm)
        DSStatusBadge("Medium", icon: "tag.fill", variant: .primary, size: .md)
        DSStatusBadge("Large", icon: "tag.fill", variant: .primary, size: .lg)
    }
    .padding()
    .background(AppTheme.background)
}

#Preview("Status Badge - Git Status") {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
        DSStatusBadge("Modified", icon: "pencil", variant: .warning)
        DSStatusBadge("Added", icon: "plus", variant: .success)
        DSStatusBadge("Deleted", icon: "minus", variant: .error)
        DSStatusBadge("Untracked", icon: "questionmark", variant: .neutral)
        DSStatusBadge("Staged", icon: "checkmark", variant: .info)
    }
    .padding()
    .background(AppTheme.background)
}

#Preview("Status Badge - Without Icons") {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
        DSStatusBadge("Active", variant: .success)
        DSStatusBadge("Pending", variant: .warning)
        DSStatusBadge("Failed", variant: .error)
        DSStatusBadge("Draft", variant: .neutral)
    }
    .padding()
    .background(AppTheme.background)
}
