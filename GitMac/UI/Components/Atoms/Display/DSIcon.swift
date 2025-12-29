//
//  DSIcon.swift
//  GitMac
//
//  Created on 2025-12-28.
//

import SwiftUI

/// Icon sizes following design system
enum DSIconSize {
    case sm
    case md
    case lg
    case xl

    var dimension: CGFloat {
        switch self {
        case .sm: return DesignTokens.Sizing.Icon.sm
        case .md: return DesignTokens.Sizing.Icon.md
        case .lg: return DesignTokens.Sizing.Icon.lg
        case .xl: return DesignTokens.Sizing.Icon.xl
        }
    }
}

/// Design System Icon component - SF Symbol wrapper
struct DSIcon: View {
    let name: String
    let size: DSIconSize
    let color: Color?

    init(_ name: String, size: DSIconSize = .md, color: Color? = nil) {
        self.name = name
        self.size = size
        self.color = color
    }

    var body: some View {
        Image(systemName: name)
            .font(.system(size: size.dimension))
            .foregroundColor(color ?? AppTheme.textPrimary)
    }
}

#Preview("DSIcon Sizes") {
    VStack(spacing: DesignTokens.Spacing.lg) {
        HStack(spacing: DesignTokens.Spacing.md) {
            DSIcon("star.fill", size: .sm, color: .yellow)
            DSIcon("star.fill", size: .md, color: .yellow)
            DSIcon("star.fill", size: .lg, color: .yellow)
            DSIcon("star.fill", size: .xl, color: .yellow)
        }

        HStack(spacing: DesignTokens.Spacing.md) {
            DSIcon("checkmark.circle.fill", size: .sm, color: AppTheme.success)
            DSIcon("checkmark.circle.fill", size: .md, color: AppTheme.success)
            DSIcon("checkmark.circle.fill", size: .lg, color: AppTheme.success)
            DSIcon("checkmark.circle.fill", size: .xl, color: AppTheme.success)
        }

        HStack(spacing: DesignTokens.Spacing.md) {
            DSIcon("xmark.circle.fill", size: .sm, color: AppTheme.error)
            DSIcon("xmark.circle.fill", size: .md, color: AppTheme.error)
            DSIcon("xmark.circle.fill", size: .lg, color: AppTheme.error)
            DSIcon("xmark.circle.fill", size: .xl, color: AppTheme.error)
        }

        HStack(spacing: DesignTokens.Spacing.md) {
            DSIcon("info.circle", size: .sm)
            DSIcon("gear", size: .md)
            DSIcon("heart.fill", size: .lg, color: .red)
            DSIcon("sparkles", size: .xl, color: AppTheme.accent)
        }
    }
    .padding()
    .background(AppTheme.background)
}
