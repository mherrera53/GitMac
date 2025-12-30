import SwiftUI

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

// MARK: - Themed Color Extension

extension Color {
    /// Namespace for theme-aware colors
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

        // MARK: - Common UI Colors (replacing hardcoded values)
        var separatorColor: Color { border }
        var hoverBackground: Color { hover }
        var activeBackground: Color { selection }

        // MARK: - Lane Colors (for graph)
        var laneColors: [Color] {
            [graphLine1, graphLine2, graphLine3, graphLine4, graphLine5,
             info, warning, success]
        }

        // MARK: - Diff Colors (Kaleidoscope-style)
        var diffAddition: Color { colors.diffAddition.color }
        var diffDeletion: Color { colors.diffDeletion.color }
        var diffChange: Color { colors.diffChange.color }
        var diffAdditionBg: Color { diffAddition.opacity(0.08) }
        var diffDeletionBg: Color { diffDeletion.opacity(0.08) }
        var diffChangeBg: Color { diffChange.opacity(0.08) }
        var diffLineNumberBg: Color { backgroundSecondary }
        var diffLineNumber: Color { textMuted }

        // MARK: - Button Colors
        var buttonTextOnColor: Color { background }
    }
}

// MARK: - AppTheme (Legacy Support)

/// Modern theme colors for consistent UI - now using dynamic theme system
/// For new code, use Color.Theme with environment instead
@MainActor
enum AppTheme {
    // MARK: - Primary Colors
    static var accent: Color {
        Color.Theme(ThemeManager.shared.colors).accent
    }
    static var accentGreen: Color {
        Color.Theme(ThemeManager.shared.colors).success
    }
    static var accentRed: Color {
        Color.Theme(ThemeManager.shared.colors).error
    }
    static var accentOrange: Color {
        Color.Theme(ThemeManager.shared.colors).warning
    }
    static var accentPurple: Color {
        Color.Theme(ThemeManager.shared.colors).accent
    }
    static var accentYellow: Color {
        Color.Theme(ThemeManager.shared.colors).warning
    }
    static var accentCyan: Color {
        Color.Theme(ThemeManager.shared.colors).info
    }

    // MARK: - Background Colors
    static var background: Color {
        Color.Theme(ThemeManager.shared.colors).background
    }
    static var backgroundSecondary: Color {
        Color.Theme(ThemeManager.shared.colors).backgroundSecondary
    }
    static var backgroundTertiary: Color {
        Color.Theme(ThemeManager.shared.colors).backgroundTertiary
    }
    static var panel: Color {
        Color.Theme(ThemeManager.shared.colors).backgroundSecondary.opacity(0.5)
    }
    static var toolbar: Color {
        Color.Theme(ThemeManager.shared.colors).backgroundSecondary
    }
    static var sidebar: Color {
        Color.Theme(ThemeManager.shared.colors).backgroundSecondary
    }

    // MARK: - Text Colors
    static var textPrimary: Color {
        Color.Theme(ThemeManager.shared.colors).text
    }
    static var textSecondary: Color {
        Color.Theme(ThemeManager.shared.colors).textSecondary
    }
    static var textMuted: Color {
        Color.Theme(ThemeManager.shared.colors).textMuted
    }

    // MARK: - Interactive Colors
    static var hover: Color {
        Color.Theme(ThemeManager.shared.colors).hover
    }
    static var selection: Color {
        Color.Theme(ThemeManager.shared.colors).selection
    }
    static var border: Color {
        Color.Theme(ThemeManager.shared.colors).border
    }

    // MARK: - Semantic Colors
    static var success: Color {
        Color.Theme(ThemeManager.shared.colors).success
    }
    static var warning: Color {
        Color.Theme(ThemeManager.shared.colors).warning
    }
    static var error: Color {
        Color.Theme(ThemeManager.shared.colors).error
    }
    static var info: Color {
        Color.Theme(ThemeManager.shared.colors).accent
    }

    // MARK: - Shadow & Overlay Colors
    static var shadow: Color {
        Color.Theme(ThemeManager.shared.colors).shadow
    }
    static var overlay: Color {
        Color.Theme(ThemeManager.shared.colors).overlay
    }
    static var overlayLight: Color {
        Color.Theme(ThemeManager.shared.colors).overlayLight
    }

    // MARK: - Branch/Lane Colors
    static var laneColors: [Color] {
        Color.Theme(ThemeManager.shared.colors).laneColors
    }

    // MARK: - Kaleidoscope-style Diff Colors
    /// Professional diff colors - now using theme system for proper theme adaptation
    static var diffAddition: Color {
        Color.Theme(ThemeManager.shared.colors).diffAddition
    }
    static var diffDeletion: Color {
        Color.Theme(ThemeManager.shared.colors).diffDeletion
    }
    static var diffChange: Color {
        Color.Theme(ThemeManager.shared.colors).diffChange
    }
    static var diffAdditionBg: Color {
        diffAddition.opacity(0.08)
    }
    static var diffDeletionBg: Color {
        diffDeletion.opacity(0.08)
    }
    static var diffChangeBg: Color {
        diffChange.opacity(0.08)
    }
    static var diffLineNumberBg: Color {
        backgroundSecondary.opacity(0.5)
    }
    static var diffLineNumber: Color {
        textMuted.opacity(0.6)
    }
}

// MARK: - UI States Extension
extension AppTheme {
    /// Color for chevrons (disclosure arrows) - visible in all themes
    static var chevronColor: Color {
        textSecondary
    }

    /// Adaptive button text color on colored backgrounds (white/black depending on theme)
    static var buttonTextOnColor: Color {
        Color.Theme(ThemeManager.shared.colors).background
    }

    /// Accent color in pressed state (darker)
    static var accentPressed: Color {
        accent.opacity(0.8)
    }

    /// Accent color when disabled
    static var accentDisabled: Color {
        textMuted
    }

    /// Border color for focused elements
    static var borderFocus: Color {
        accent
    }

    /// Link color for hyperlinks
    static var link: Color {
        info
    }

    /// Link color on hover
    static var linkHover: Color {
        accent
    }

    /// Focus color for input fields
    static var focus: Color {
        accent
    }

    /// Background for code blocks
    static var codeBackground: Color {
        backgroundSecondary.opacity(0.5)
    }

    /// Background for inline code
    static var inlineCodeBackground: Color {
        backgroundSecondary.opacity(0.3)
    }
}

// MARK: - File Type Colors Extension
extension AppTheme {
    /// Swift file icon color (orange)
    static var fileSwift: Color {
        Color(red: 1.0, green: 0.55, blue: 0.26) // #FF8C42
    }

    /// JavaScript file icon color (yellow)
    static var fileJavaScript: Color {
        Color(red: 0.97, green: 0.87, blue: 0.31) // #F7DF1E
    }

    /// TypeScript file icon color (blue)
    static var fileTypeScript: Color {
        Color(red: 0.19, green: 0.47, blue: 0.78) // #3178C6
    }

    /// Python file icon color (blue)
    static var filePython: Color {
        Color(red: 0.22, green: 0.46, blue: 0.67) // #3776AB
    }

    /// JSON file icon color (green)
    static var fileJSON: Color {
        Color(red: 0.31, green: 0.79, blue: 0.69) // #4EC9B0
    }

    /// Markdown file icon color (gray)
    static var fileMarkdown: Color {
        textMuted
    }

    /// HTML file icon color (orange)
    static var fileHTML: Color {
        Color(red: 0.89, green: 0.30, blue: 0.15) // #E34C26
    }

    /// CSS file icon color (blue)
    static var fileCSS: Color {
        Color(red: 0.09, green: 0.45, blue: 0.71) // #1572B6
    }

    /// Image file icon color (pink)
    static var fileImage: Color {
        Color(red: 1.0, green: 0.42, blue: 0.71) // #FF6BB5
    }

    /// Archive file icon color (yellow)
    static var fileArchive: Color {
        Color(red: 0.97, green: 0.87, blue: 0.31) // #F7DF1E
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
        Color(red: 0.0, green: 0.48, blue: 1.0) // Blue
    }

    /// String color for syntax highlighting
    static var syntaxString: Color {
        Color(red: 0.2, green: 0.78, blue: 0.35) // Green
    }

    /// Comment color for syntax highlighting
    static var syntaxComment: Color {
        textMuted
    }

    /// Number color for syntax highlighting
    static var syntaxNumber: Color {
        Color(red: 0.31, green: 0.79, blue: 0.69) // Cyan
    }

    /// Type color for syntax highlighting
    static var syntaxType: Color {
        Color(red: 0.31, green: 0.79, blue: 0.69) // Jade green
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

// MARK: - Git & Branch Colors Extension
extension AppTheme {
    static var gitAdded: Color {
        Color.Theme(ThemeManager.shared.colors).gitAdded
    }
    static var gitModified: Color {
        Color.Theme(ThemeManager.shared.colors).gitModified
    }
    static var gitDeleted: Color {
        Color.Theme(ThemeManager.shared.colors).gitDeleted
    }
    static var gitConflict: Color {
        Color.Theme(ThemeManager.shared.colors).gitConflict
    }
    static var branchLocal: Color {
        Color.Theme(ThemeManager.shared.colors).branchLocal
    }
    static var branchRemote: Color {
        Color.Theme(ThemeManager.shared.colors).branchRemote
    }
    static var branchCurrent: Color {
        Color.Theme(ThemeManager.shared.colors).branchCurrent
    }
}

// MARK: - Graph Lane Colors
extension AppTheme {
    /// Theme-aware colors for commit graph lanes
    static let graphLaneColors: [Color] = [
        .blue,
        .green,
        .orange,
        Color.purple.opacity(0.8),
        .red,
        Color.cyan.opacity(0.8),
        Color.pink.opacity(0.8),
        Color.yellow.opacity(0.8)
    ]
}
