import SwiftUI
import AppKit

// MARK: - Theme Environment Key

private struct ThemeColorsKey: EnvironmentKey {
    static let defaultValue: ColorScheme = ColorScheme.dark
}

extension EnvironmentValues {
    var themeColors: ColorScheme {
        get { self[ThemeColorsKey.self] }
        set { self[ThemeColorsKey.self] = newValue }
    }
}

// MARK: - Apple HIG Compliant Theme System
// Following Apple Human Interface Guidelines:
// https://developer.apple.com/design/human-interface-guidelines/color
// Always use semantic system colors for UI elements - they adapt automatically

/// AppTheme - Sistema de colores siguiendo Apple Human Interface Guidelines
/// Los colores semánticos de NSColor se adaptan automáticamente a light/dark mode
@MainActor
enum AppTheme {

    // MARK: - Text Colors (Always use NSColor semantic colors)
    // These colors automatically adapt to light/dark appearance

    /// Primary text - highest contrast, for main content
    static var textPrimary: Color {
        Color(nsColor: .labelColor)
    }

    /// Secondary text - for subtitles and less prominent text
    static var textSecondary: Color {
        Color(nsColor: .secondaryLabelColor)
    }

    /// Muted text - for placeholder and disabled states
    static var textMuted: Color {
        Color(nsColor: .tertiaryLabelColor)
    }

    /// Quaternary text - least prominent
    static var textQuaternary: Color {
        Color(nsColor: .quaternaryLabelColor)
    }

    // MARK: - Background Colors (Always use NSColor semantic colors)

    /// Main window background
    static var background: Color {
        Color(nsColor: .windowBackgroundColor)
    }

    /// Secondary background for grouped content
    static var backgroundSecondary: Color {
        Color(nsColor: .controlBackgroundColor)
    }

    /// Tertiary background for nested content
    static var backgroundTertiary: Color {
        Color(nsColor: .windowBackgroundColor)
    }

    /// Panel background with transparency
    static var panel: Color {
        Color(nsColor: .controlBackgroundColor).opacity(0.8)
    }

    /// Toolbar background
    static var toolbar: Color {
        Color(nsColor: .windowBackgroundColor)
    }

    /// Sidebar background
    static var sidebar: Color {
        Color(nsColor: .controlBackgroundColor)
    }

    /// Text input background
    static var inputBackground: Color {
        Color(nsColor: .textBackgroundColor)
    }

    // MARK: - Accent Colors

    /// System accent color (user-configurable in System Preferences)
    static var accent: Color {
        Color(nsColor: .controlAccentColor)
    }

    /// Accent hover state
    static var accentHover: Color {
        Color(nsColor: .controlAccentColor).opacity(0.8)
    }

    /// Accent pressed state
    static var accentPressed: Color {
        Color(nsColor: .controlAccentColor).opacity(0.7)
    }

    /// Accent disabled state
    static var accentDisabled: Color {
        Color(nsColor: .tertiaryLabelColor)
    }

    // MARK: - Semantic Status Colors (System colors that adapt to appearance)

    /// Success color - green
    static var success: Color {
        Color(nsColor: .systemGreen)
    }

    /// Warning color - orange
    static var warning: Color {
        Color(nsColor: .systemOrange)
    }

    /// Error color - red
    static var error: Color {
        Color(nsColor: .systemRed)
    }

    /// Info color - blue
    static var info: Color {
        Color(nsColor: .systemBlue)
    }

    // MARK: - Accent Aliases (using system colors)

    static var accentGreen: Color { Color(nsColor: .systemGreen) }
    static var accentRed: Color { Color(nsColor: .systemRed) }
    static var accentOrange: Color { Color(nsColor: .systemOrange) }
    static var accentPurple: Color { Color(nsColor: .systemPurple) }
    static var accentYellow: Color { Color(nsColor: .systemYellow) }
    static var accentCyan: Color { Color(nsColor: .systemCyan) }
    static var accentPink: Color { Color(nsColor: .systemPink) }
    static var accentBrown: Color { Color(nsColor: .systemBrown) }
    static var accentIndigo: Color { Color(nsColor: .systemIndigo) }
    static var accentTeal: Color { Color(nsColor: .systemTeal) }
    static var accentMint: Color { Color(nsColor: .systemMint) }

    // MARK: - Interactive Colors

    /// Hover state background
    static var hover: Color {
        Color(nsColor: .controlAccentColor).opacity(0.1)
    }

    /// Selection background
    static var selection: Color {
        Color(nsColor: .selectedContentBackgroundColor)
    }

    /// Unemphasized selection (when window is not key)
    static var selectionUnemphasized: Color {
        Color(nsColor: .unemphasizedSelectedContentBackgroundColor)
    }

    /// Border/separator color
    static var border: Color {
        Color(nsColor: .separatorColor)
    }

    /// Grid color for tables
    static var grid: Color {
        Color(nsColor: .gridColor)
    }

    // MARK: - Link Colors

    /// Link color
    static var link: Color {
        Color(nsColor: .linkColor)
    }

    /// Link hover color
    static var linkHover: Color {
        Color(nsColor: .controlAccentColor)
    }

    // MARK: - Shadow & Overlay Colors

    static var shadow: Color {
        Color.black.opacity(0.2)
    }

    static var overlay: Color {
        Color(nsColor: .windowBackgroundColor).opacity(0.8)
    }

    static var overlayLight: Color {
        Color.black.opacity(0.1)
    }

    static var overlayMedium: Color {
        Color.black.opacity(0.3)
    }

    // MARK: - UI States

    /// Chevron/disclosure arrow color
    static var chevronColor: Color {
        textSecondary
    }

    /// Button text on colored backgrounds - always white for vibrant system colors
    /// System colors (blue, green, orange, red) are designed to have white text
    static var buttonTextOnColor: Color {
        Color.white
    }

    /// Calculate contrasting text color based on background
    /// Returns white for dark backgrounds, labelColor for light backgrounds
    static func contrastingTextColor(for background: Color) -> Color {
        // For system colors used as backgrounds, white text is recommended
        // This follows Apple HIG for buttons with colored backgrounds
        Color.white
    }

    /// Get appropriate text color for a badge/button based on color scheme
    /// In light mode, use darker text for better contrast on bright backgrounds
    static func badgeTextColor(colorScheme: SwiftUI.ColorScheme) -> Color {
        colorScheme == .dark ? Color.white : Color(nsColor: .labelColor)
    }

    /// Focus ring color
    static var focus: Color {
        accent
    }

    /// Border color for focused elements
    static var borderFocus: Color {
        accent
    }

    /// Code block background
    static var codeBackground: Color {
        backgroundSecondary.opacity(0.5)
    }

    /// Inline code background
    static var inlineCodeBackground: Color {
        backgroundSecondary.opacity(0.3)
    }

    // MARK: - Git Status Colors (Custom - these can be themed)
    // These are app-specific semantic colors

    static var gitAdded: Color {
        if ThemeManager.shared.currentTheme == .custom {
            return Color.Theme(ThemeManager.shared.colors).gitAdded
        }
        return Color(nsColor: .systemGreen)
    }

    static var gitModified: Color {
        if ThemeManager.shared.currentTheme == .custom {
            return Color.Theme(ThemeManager.shared.colors).gitModified
        }
        return Color(nsColor: .systemOrange)
    }

    static var gitDeleted: Color {
        if ThemeManager.shared.currentTheme == .custom {
            return Color.Theme(ThemeManager.shared.colors).gitDeleted
        }
        return Color(nsColor: .systemRed)
    }

    static var gitConflict: Color {
        if ThemeManager.shared.currentTheme == .custom {
            return Color.Theme(ThemeManager.shared.colors).gitConflict
        }
        return Color(nsColor: .systemPink)
    }

    static var gitRenamed: Color {
        if ThemeManager.shared.currentTheme == .custom {
            return Color.Theme(ThemeManager.shared.colors).branchRemote
        }
        return Color(nsColor: .systemBlue)
    }

    static var gitUntracked: Color {
        Color(nsColor: .tertiaryLabelColor)
    }

    // MARK: - Branch Colors (Custom - these can be themed)

    static var branchLocal: Color {
        if ThemeManager.shared.currentTheme == .custom {
            return Color.Theme(ThemeManager.shared.colors).branchLocal
        }
        return Color(nsColor: .systemGreen)
    }

    static var branchRemote: Color {
        if ThemeManager.shared.currentTheme == .custom {
            return Color.Theme(ThemeManager.shared.colors).branchRemote
        }
        return Color(nsColor: .systemBlue)
    }

    static var branchCurrent: Color {
        if ThemeManager.shared.currentTheme == .custom {
            return Color.Theme(ThemeManager.shared.colors).branchCurrent
        }
        return Color(nsColor: .systemOrange)
    }

    // MARK: - Graph Lane Colors (Custom - these can be themed)

    static var laneColors: [Color] {
        if ThemeManager.shared.currentTheme == .custom {
            return Color.Theme(ThemeManager.shared.colors).laneColors
        }
        return [
            Color(nsColor: .systemBlue),
            Color(nsColor: .systemGreen),
            Color(nsColor: .systemOrange),
            Color(nsColor: .systemPurple),
            Color(nsColor: .systemRed),
            Color(nsColor: .systemCyan),
            Color(nsColor: .systemPink),
            Color(nsColor: .systemYellow)
        ]
    }

    /// Static graph lane colors (for compile-time contexts) - 16 distinct colors for complex graphs
    static let graphLaneColors: [Color] = [
        Color(nsColor: .systemBlue),
        Color(nsColor: .systemGreen),
        Color(nsColor: .systemOrange),
        Color(nsColor: .systemPurple),
        Color(nsColor: .systemRed),
        Color(nsColor: .systemCyan),
        Color(nsColor: .systemPink),
        Color(nsColor: .systemYellow),
        Color(nsColor: .systemTeal),
        Color(nsColor: .systemIndigo),
        Color(nsColor: .systemMint),
        Color(nsColor: .systemBrown),
        Color(red: 0.4, green: 0.7, blue: 1.0),   // Light blue
        Color(red: 1.0, green: 0.5, blue: 0.3),   // Coral
        Color(red: 0.6, green: 0.9, blue: 0.4),   // Lime
        Color(red: 0.9, green: 0.4, blue: 0.8)    // Magenta
    ]

    // MARK: - Diff Colors (Kaleidoscope-style)

    static var diffAddition: Color {
        if ThemeManager.shared.currentTheme == .custom {
            return Color.Theme(ThemeManager.shared.colors).diffAddition
        }
        return Color(nsColor: .systemGreen)
    }

    static var diffDeletion: Color {
        if ThemeManager.shared.currentTheme == .custom {
            return Color.Theme(ThemeManager.shared.colors).diffDeletion
        }
        return Color(nsColor: .systemRed)
    }

    static var diffChange: Color {
        if ThemeManager.shared.currentTheme == .custom {
            return Color.Theme(ThemeManager.shared.colors).diffChange
        }
        return Color(nsColor: .systemBlue)
    }

    static var diffAdditionBg: Color {
        diffAddition.opacity(0.15)
    }

    static var diffDeletionBg: Color {
        diffDeletion.opacity(0.15)
    }

    static var diffChangeBg: Color {
        diffChange.opacity(0.15)
    }

    static var diffLineNumberBg: Color {
        backgroundSecondary.opacity(0.5)
    }

    static var diffLineNumber: Color {
        textMuted.opacity(0.8)
    }
}

// MARK: - File Type Colors Extension

extension AppTheme {
    /// Swift file icon color (orange)
    static var fileSwift: Color {
        Color(nsColor: .systemOrange)
    }

    /// JavaScript file icon color (yellow)
    static var fileJavaScript: Color {
        Color(nsColor: .systemYellow)
    }

    /// TypeScript file icon color (blue)
    static var fileTypeScript: Color {
        Color(nsColor: .systemBlue)
    }

    /// Python file icon color (blue)
    static var filePython: Color {
        Color(nsColor: .systemBlue)
    }

    /// JSON file icon color (green)
    static var fileJSON: Color {
        Color(nsColor: .systemGreen)
    }

    /// Markdown file icon color (gray)
    static var fileMarkdown: Color {
        textMuted
    }

    /// HTML file icon color (orange)
    static var fileHTML: Color {
        Color(nsColor: .systemOrange)
    }

    /// CSS file icon color (blue)
    static var fileCSS: Color {
        Color(nsColor: .systemBlue)
    }

    /// Image file icon color (pink)
    static var fileImage: Color {
        Color(nsColor: .systemPink)
    }

    /// Archive file icon color (yellow)
    static var fileArchive: Color {
        Color(nsColor: .systemYellow)
    }

    /// Config file icon color (gray)
    static var fileConfig: Color {
        textMuted.opacity(0.8)
    }

    /// Default file icon color
    static var fileDefault: Color {
        textMuted
    }
}

// MARK: - Syntax Highlighting Extension

extension AppTheme {
    /// Keyword color for syntax highlighting
    static var syntaxKeyword: Color {
        Color(nsColor: .systemPink)
    }

    /// String color for syntax highlighting
    static var syntaxString: Color {
        Color(nsColor: .systemGreen)
    }

    /// Comment color for syntax highlighting
    static var syntaxComment: Color {
        textMuted
    }

    /// Number color for syntax highlighting
    static var syntaxNumber: Color {
        Color(nsColor: .systemCyan)
    }

    /// Type color for syntax highlighting
    static var syntaxType: Color {
        Color(nsColor: .systemTeal)
    }
}

// MARK: - Interactive Rebase Actions Extension

extension AppTheme {
    /// Color for 'pick' action in interactive rebase
    static var actionPick: Color {
        success
    }

    /// Color for 'reword' action in interactive rebase
    static var actionReword: Color {
        info
    }

    /// Color for 'edit' action in interactive rebase
    static var actionEdit: Color {
        warning
    }

    /// Color for 'squash' action in interactive rebase
    static var actionSquash: Color {
        accent
    }

    /// Color for 'drop' action in interactive rebase
    static var actionDrop: Color {
        error
    }
}

// MARK: - Themed Color Extension (for custom themes only)

extension Color {
    /// Namespace for theme-aware colors (custom themes)
    struct Theme {
        private let colors: ColorScheme

        init(_ colors: ColorScheme) {
            self.colors = colors
        }

        // MARK: - Primary Colors
        var accent: Color { colors.accent.color }
        var accentHover: Color { colors.accentHover.color }

        // MARK: - Background Colors
        var background: Color { colors.background.color }
        var backgroundSecondary: Color { colors.backgroundSecondary.color }
        var backgroundTertiary: Color { colors.backgroundTertiary.color }
        var inputBackground: Color { colors.backgroundSecondary.color.opacity(0.8) }

        // MARK: - Text Colors
        var text: Color { colors.text.color }
        var textSecondary: Color { colors.textSecondary.color }
        var textMuted: Color { colors.textMuted.color }

        // MARK: - Semantic Colors
        var success: Color { colors.success.color }
        var error: Color { colors.error.color }
        var warning: Color { colors.warning.color }
        var info: Color { colors.info.color }

        // MARK: - Git Colors
        var gitAdded: Color { colors.gitAdded.color }
        var gitModified: Color { colors.gitModified.color }
        var gitDeleted: Color { colors.gitDeleted.color }
        var gitConflict: Color { colors.gitConflict.color }

        // MARK: - Branch Colors
        var branchLocal: Color { colors.branchLocal.color }
        var branchRemote: Color { colors.branchRemote.color }
        var branchCurrent: Color { colors.branchCurrent.color }

        // MARK: - Graph Colors
        var graphLine1: Color { colors.graphLine1.color }
        var graphLine2: Color { colors.graphLine2.color }
        var graphLine3: Color { colors.graphLine3.color }
        var graphLine4: Color { colors.graphLine4.color }
        var graphLine5: Color { colors.graphLine5.color }

        // MARK: - Derived Colors
        var hover: Color { accentHover.opacity(0.1) }
        var selection: Color { accent.opacity(0.2) }
        var border: Color { textMuted.opacity(0.3) }

        // MARK: - Overlay & Shadow Colors
        var shadow: Color { text.opacity(0.3) }
        var overlay: Color { background.opacity(0.8) }
        var overlayLight: Color { background.opacity(0.1) }
        var overlayMedium: Color { background.opacity(0.5) }

        // MARK: - State Colors
        var disabled: Color { textMuted.opacity(0.5) }
        var placeholder: Color { textMuted }

        // MARK: - Common UI Colors
        var separatorColor: Color { border }
        var hoverBackground: Color { hover }
        var activeBackground: Color { selection }

        // MARK: - Lane Colors (for graph)
        var laneColors: [Color] {
            [graphLine1, graphLine2, graphLine3, graphLine4, graphLine5,
             info, warning, success]
        }

        // MARK: - Diff Colors
        var diffAddition: Color { colors.diffAddition.color }
        var diffDeletion: Color { colors.diffDeletion.color }
        var diffChange: Color { colors.diffChange.color }
        var diffAdditionBg: Color { diffAddition.opacity(0.15) }
        var diffDeletionBg: Color { diffDeletion.opacity(0.15) }
        var diffChangeBg: Color { diffChange.opacity(0.15) }
        var diffLineNumberBg: Color { backgroundSecondary }
        var diffLineNumber: Color { textMuted }

        // MARK: - Button Colors
        var buttonTextOnColor: Color { background }
    }
}

// Color.init(hex:) is defined in ThemeManager.swift
