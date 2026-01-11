import Foundation

// MARK: - Diff Degradation (UI-level)

/// Types of visual degradations applied for performance
enum DiffDegradation: String, Identifiable, Sendable {
    case largeFileModeActive
    case wordDiffDisabled
    case syntaxHighlightDisabled
    case sideBySideDisabled
    case softWrapDisabled
    case hunksCollapsedByDefault

    var id: String { rawValue }

    var description: String {
        switch self {
        case .largeFileModeActive:
            return "Large File Mode"
        case .wordDiffDisabled:
            return "Word-level diff disabled"
        case .syntaxHighlightDisabled:
            return "Syntax highlighting disabled"
        case .sideBySideDisabled:
            return "Side-by-side view disabled"
        case .softWrapDisabled:
            return "Word wrap disabled"
        case .hunksCollapsedByDefault:
            return "Hunks collapsed by default"
        }
    }

    var icon: String {
        switch self {
        case .largeFileModeActive:
            return "bolt.fill"
        case .wordDiffDisabled:
            return "character.cursor.ibeam"
        case .syntaxHighlightDisabled:
            return "paintbrush.fill"
        case .sideBySideDisabled:
            return "rectangle.split.2x1"
        case .softWrapDisabled:
            return "text.alignleft"
        case .hunksCollapsedByDefault:
            return "chevron.down.circle"
        }
    }

    var severity: DegradationSeverity {
        switch self {
        case .largeFileModeActive:
            return .warning
        case .wordDiffDisabled, .syntaxHighlightDisabled, .sideBySideDisabled:
            return .info
        case .softWrapDisabled, .hunksCollapsedByDefault:
            return .info
        }
    }
}

enum DegradationSeverity {
    case info
    case warning
    case error
}

// MARK: - Diff UI Preferences

/// User preferences for diff viewing (stored in UserDefaults)
/// Note: DiffViewMode enum is defined in UI/Components/Diff/DiffToolbar.swift
struct DiffUIPreferences: Codable {
    var defaultContextLines: Int
    var enableWordDiffOnDemand: Bool
    var enableSyntaxHighlightOnDemand: Bool
    var defaultViewModeRaw: String  // Uses DiffViewMode.rawValue
    var showLineNumbers: Bool
    var showWhitespace: Bool
    var fontSize: Int
    var fontName: String

    init(
        defaultContextLines: Int = 3,
        enableWordDiffOnDemand: Bool = true,
        enableSyntaxHighlightOnDemand: Bool = true,
        defaultViewModeRaw: String = "Split",
        showLineNumbers: Bool = true,
        showWhitespace: Bool = false,
        fontSize: Int = 12,
        fontName: String = "SF Mono"
    ) {
        self.defaultContextLines = defaultContextLines
        self.enableWordDiffOnDemand = enableWordDiffOnDemand
        self.enableSyntaxHighlightOnDemand = enableSyntaxHighlightOnDemand
        self.defaultViewModeRaw = defaultViewModeRaw
        self.showLineNumbers = showLineNumbers
        self.showWhitespace = showWhitespace
        self.fontSize = fontSize
        self.fontName = fontName
    }

    /// Default preferences
    static var `default`: DiffUIPreferences {
        DiffUIPreferences()
    }
}

// MARK: - UserDefaults Extension

extension UserDefaults {
    private static let diffUIPreferencesKey = "com.gitmac.diffUIPreferences"

    var diffUIPreferences: DiffUIPreferences {
        get {
            guard let data = data(forKey: Self.diffUIPreferencesKey) else {
                return .default
            }

            do {
                return try JSONDecoder().decode(DiffUIPreferences.self, from: data)
            } catch {
                print("Failed to decode DiffUIPreferences: \(error)")
                return .default
            }
        }
        set {
            do {
                let data = try JSONEncoder().encode(newValue)
                set(data, forKey: Self.diffUIPreferencesKey)
            } catch {
                print("Failed to encode DiffUIPreferences: \(error)")
            }
        }
    }
}
