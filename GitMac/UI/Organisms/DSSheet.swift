//
//  DSSheet.swift
//  GitMac
//
//  Created on 28/12/2025.
//  Design System - Sheet/Modal Organism
//  Estándar para ventanas modales y sheets
//

import SwiftUI

/// Sheet/Modal estándar del Design System
/// Proporciona estructura consistente para ventanas emergentes
struct DSSheet<Content: View>: View {
    let title: String
    let subtitle: String?
    let onDismiss: () -> Void
    @ViewBuilder let content: () -> Content

    // Size presets
    enum Size {
        case small      // 400x300
        case medium     // 600x400
        case large      // 800x600
        case extraLarge // 1000x700
        case custom(width: CGFloat, height: CGFloat)

        var dimensions: (width: CGFloat, height: CGFloat) {
            switch self {
            case .small: return (400, 300)
            case .medium: return (600, 400)
            case .large: return (800, 600)
            case .extraLarge: return (1000, 700)
            case .custom(let w, let h): return (w, h)
            }
        }
    }

    let size: Size

    init(
        title: String,
        subtitle: String? = nil,
        size: Size = .medium,
        onDismiss: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.size = size
        self.onDismiss = onDismiss
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header estándar
            sheetHeader

            DSDivider()

            // Content area
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: size.dimensions.width, height: size.dimensions.height)
        .background(AppTheme.background)
    }

    private var sheetHeader: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                DSText(
                    title,
                    variant: .headline,
                    color: AppTheme.textPrimary
                )

                if let subtitle = subtitle {
                    DSText(
                        subtitle,
                        variant: .caption,
                        color: AppTheme.textSecondary
                    )
                }
            }

            Spacer()

            DSButton(variant: .primary, size: .sm) {
                onDismiss()
            } label: {
                Text("Done")
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
        .background(AppTheme.backgroundSecondary)
    }
}

// MARK: - Preview

#Preview("DSSheet Sizes") {
    VStack(spacing: DesignTokens.Spacing.lg) {
        DSSheet(
            title: "Small Sheet",
            size: .small,
            onDismiss: {}
        ) {
            DSEmptyState(
                icon: "doc.text",
                title: "Small Content",
                description: "400x300"
            )
        }

        DSSheet(
            title: "Medium Sheet",
            subtitle: "With subtitle",
            size: .medium,
            onDismiss: {}
        ) {
            DSEmptyState(
                icon: "doc.text",
                title: "Medium Content",
                description: "600x400"
            )
        }
    }
    .padding()
}
