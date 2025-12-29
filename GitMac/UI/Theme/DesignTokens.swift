//
//  DesignTokens.swift
//  GitMac
//
//  Created on 28/12/2025.
//  Atomic Design System - Level 1: Design Tokens
//

import SwiftUI

/// Design Tokens - Sistema centralizado de valores de diseño
/// Estos tokens son la base del Atomic Design System
enum DesignTokens {

    // MARK: - Typography

    /// Sistema tipográfico con escala modular
    enum Typography {
        // Base scale (Major Third: 1.250)
        static let caption2: Font = .system(size: 10)    // 10px
        static let caption: Font = .system(size: 11)     // 11px
        static let callout: Font = .system(size: 12)     // 12px
        static let body: Font = .system(size: 13)        // 13px (base)
        static let headline: Font = .system(size: 14, weight: .semibold)  // 14px semibold
        static let subheadline: Font = .system(size: 15) // 15px
        static let title3: Font = .system(size: 17)      // 17px
        static let title2: Font = .system(size: 20)      // 20px
        static let title1: Font = .system(size: 22, weight: .bold)      // 22px
        static let largeTitle: Font = .system(size: 28, weight: .bold)  // 28px

        // Large icons for decorative/hero elements (como tallas de ropa: XL → XXL → XXXL → XXXXL)
        static let iconXL: Font = .system(size: 24)        // 24px - XL icons
        static let iconXXL: Font = .system(size: 32)       // 32px - XXL icons
        static let iconXXXL: Font = .system(size: 40)      // 40px - XXXL icons/emojis
        static let iconXXXXL: Font = .system(size: 48)     // 48px - XXXXL hero icons/emojis

        // Semantic Git-specific
        static let commitHash: Font = .system(size: 11, design: .monospaced)
        static let commitMessage: Font = .system(size: 13)
        static let branchName: Font = .system(size: 12, weight: .medium)
        static let diffLine: Font = .system(size: 12, design: .monospaced)

        // MARK: - NSFont Helpers (for AppKit components)

        /// Convierte tokens de Font a NSFont para uso en componentes AppKit
        static func nsFont(for token: Font) -> NSFont {
            // Mapeo de tokens SwiftUI Font a NSFont
            switch token {
            case diffLine, commitHash:
                return NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            case caption2:
                return NSFont.systemFont(ofSize: 10)
            case caption:
                return NSFont.systemFont(ofSize: 11)
            case callout:
                return NSFont.systemFont(ofSize: 12)
            case body:
                return NSFont.systemFont(ofSize: 13)
            case headline:
                return NSFont.systemFont(ofSize: 14, weight: .semibold)
            case iconXL:
                return NSFont.systemFont(ofSize: 24)
            case iconXXL:
                return NSFont.systemFont(ofSize: 32)
            case iconXXXL:
                return NSFont.systemFont(ofSize: 40)
            case iconXXXXL:
                return NSFont.systemFont(ofSize: 48)
            default:
                return NSFont.systemFont(ofSize: 13) // body por defecto
            }
        }

        /// NSFont para diffLine (monospaced 12pt)
        static var nsDiffLine: NSFont {
            NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        }

        /// NSFont para commitHash (monospaced 11pt)
        static var nsCommitHash: NSFont {
            NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        }

        /// Size para diffLine (usado en contextos donde se necesita solo el tamaño)
        static let diffLineSize: CGFloat = 12
    }

    // MARK: - Spacing

    /// Sistema de espaciado basado en grid de 8pt
    enum Spacing {
        static let xxs: CGFloat = 2    // 2px
        static let xs: CGFloat = 4     // 4px
        static let sm: CGFloat = 8     // 8px (base)
        static let md: CGFloat = 12    // 12px
        static let lg: CGFloat = 16    // 16px
        static let xl: CGFloat = 24    // 24px
        static let xxl: CGFloat = 32   // 32px
    }

    // MARK: - Corner Radius

    /// Radios de esquina para consistencia visual
    enum CornerRadius {
        static let none: CGFloat = 0
        static let sm: CGFloat = 4
        static let md: CGFloat = 6
        static let lg: CGFloat = 8
        static let xl: CGFloat = 12
    }

    // MARK: - Size

    /// Tamaños predefinidos para componentes
    enum Size {
        // Icons
        static let iconXS: CGFloat = 12
        static let iconSM: CGFloat = 14
        static let iconMD: CGFloat = 16
        static let iconLG: CGFloat = 20
        static let iconXL: CGFloat = 24

        // Buttons
        static let buttonHeightSM: CGFloat = 24
        static let buttonHeightMD: CGFloat = 28
        static let buttonHeightLG: CGFloat = 32

        // Avatars
        static let avatarXS: CGFloat = 16
        static let avatarSM: CGFloat = 20
        static let avatarMD: CGFloat = 24
        static let avatarLG: CGFloat = 32
        static let avatarXL: CGFloat = 40
    }

    // MARK: - Sizing (Alias for backwards compatibility)

    /// Alias for Size enum to maintain compatibility with existing code
    enum Sizing {
        enum Icon {
            static let sm: CGFloat = Size.iconXS
            static let md: CGFloat = Size.iconMD
            static let lg: CGFloat = Size.iconLG
            static let xl: CGFloat = Size.iconXL
        }

        enum Button {
            static let sm: CGFloat = Size.buttonHeightSM
            static let md: CGFloat = Size.buttonHeightMD
            static let lg: CGFloat = Size.buttonHeightLG
        }
    }

    // MARK: - Animation

    /// Duraciones de animación estandarizadas
    enum Animation {
        static let instant: Double = 0.1
        static let fast: Double = 0.2
        static let normal: Double = 0.3
        static let slow: Double = 0.5

        // Presets
        static let defaultEasing = SwiftUI.Animation.easeInOut(duration: normal)
        static let fastEasing = SwiftUI.Animation.easeInOut(duration: fast)
        static let slowEasing = SwiftUI.Animation.easeInOut(duration: slow)
        static let spring = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7)
    }

    // MARK: - Opacity

    /// Valores de opacidad estandarizados
    enum Opacity {
        static let disabled: Double = 0.5
        static let muted: Double = 0.7
        static let hover: Double = 0.9
        static let full: Double = 1.0
    }

    // MARK: - Z-Index

    /// Capas de profundidad para overlays y modales
    enum ZIndex {
        static let base: Double = 0
        static let dropdown: Double = 100
        static let sticky: Double = 200
        static let overlay: Double = 300
        static let modal: Double = 400
        static let popover: Double = 500
        static let tooltip: Double = 600
    }
}

// MARK: - Convenience Extensions

extension View {
    /// Aplica espaciado estándar de padding
    func padding(_ size: DesignTokens.Spacing.Type) -> some View {
        self.padding(DesignTokens.Spacing.md)
    }
}
