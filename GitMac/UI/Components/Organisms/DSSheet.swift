//
//  DSSheet.swift
//  GitMac
//
//  Created by GitMac on 2025-12-28.
//

import SwiftUI

/// Sheet/Modal organism con tamaños estandarizados y header consistente
///
/// Componente estándar para modales y sheets que proporciona:
/// - Tamaños predefinidos (small, medium, large, extraLarge, custom)
/// - Header estandarizado con título, subtítulo opcional y botón de cierre
/// - Backgrounds y spacing consistentes con Design System
///
/// Ejemplo de uso:
/// ```swift
/// .sheet(isPresented: $showModal) {
///     DSSheet(
///         title: "Settings",
///         subtitle: "Configure your preferences",
///         size: .medium,
///         onDismiss: { showModal = false }
///     ) {
///         SettingsContentView()
///     }
/// }
/// ```
struct DSSheet<Content: View>: View {
    enum Size {
        case small      // 400x300
        case medium     // 600x400
        case large      // 800x600
        case extraLarge // 1000x700
        case custom(width: CGFloat, height: CGFloat)

        var dimensions: (width: CGFloat, height: CGFloat) {
            switch self {
            case .small:
                return (400, 300)
            case .medium:
                return (600, 400)
            case .large:
                return (800, 600)
            case .extraLarge:
                return (1000, 700)
            case .custom(let width, let height):
                return (width, height)
            }
        }
    }

    let title: String
    let subtitle: String?
    let size: Size
    let onDismiss: () -> Void
    @ViewBuilder let content: () -> Content

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
            // Header
            sheetHeader

            // Divider
            DSDivider()

            // Content
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: size.dimensions.width, height: size.dimensions.height)
        .background(AppTheme.background)
    }

    private var sheetHeader: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // Title and subtitle
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                DSText(title, variant: .headline, color: AppTheme.textPrimary)

                if let subtitle = subtitle {
                    DSText(subtitle, variant: .caption, color: AppTheme.textSecondary)
                }
            }

            Spacer()

            // Close button
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
