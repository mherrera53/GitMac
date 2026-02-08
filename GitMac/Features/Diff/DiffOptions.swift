import Foundation

// MARK: - Diff Degradation

/// Types of performance degradations applied for UI display
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

// MARK: - Diff Preferences

/// User preferences for diff viewing
struct DiffPreferences: Codable {
    var lfmFileSizeThreshold: Int  // In MB
    var lfmLinesThreshold: Int
    var lfmManualOverrides: [String: Bool]  // File path -> manual LFM on/off
    var defaultContextLines: Int
    var enableWordDiffOnDemand: Bool
    var enableSyntaxHighlightOnDemand: Bool
    var defaultViewMode: DiffViewModePreference
    var showLineNumbers: Bool
    var showWhitespace: Bool
    var ignoreWhitespace: Bool

    init(
        lfmFileSizeThreshold: Int = 8,
        lfmLinesThreshold: Int = 50_000,
        lfmManualOverrides: [String: Bool] = [:],
        defaultContextLines: Int = 3,
        enableWordDiffOnDemand: Bool = true,
        enableSyntaxHighlightOnDemand: Bool = true,
        defaultViewMode: DiffViewModePreference = .split,
        showLineNumbers: Bool = true,
        showWhitespace: Bool = false,
        ignoreWhitespace: Bool = false
    ) {
        self.lfmFileSizeThreshold = lfmFileSizeThreshold
        self.lfmLinesThreshold = lfmLinesThreshold
        self.lfmManualOverrides = lfmManualOverrides
        self.defaultContextLines = defaultContextLines
        self.enableWordDiffOnDemand = enableWordDiffOnDemand
        self.enableSyntaxHighlightOnDemand = enableSyntaxHighlightOnDemand
        self.defaultViewMode = defaultViewMode
        self.showLineNumbers = showLineNumbers
        self.showWhitespace = showWhitespace
        self.ignoreWhitespace = ignoreWhitespace
    }

    /// Default preferences
    static var `default`: DiffPreferences {
        DiffPreferences()
    }

    /// Get manual LFM override for a file
    func lfmOverride(for filePath: String) -> Bool? {
        lfmManualOverrides[filePath]
    }

    /// Set manual LFM override for a file
    mutating func setLfmOverride(for filePath: String, enabled: Bool) {
        lfmManualOverrides[filePath] = enabled
    }

    /// Clear manual LFM override for a file
    mutating func clearLfmOverride(for filePath: String) {
        lfmManualOverrides.removeValue(forKey: filePath)
    }
}

enum DiffViewModePreference: String, Codable {
    case split
    case inline
    case hunk
}

// MARK: - UserDefaults Extension

extension UserDefaults {
    private static let diffPreferencesKey = "com.gitmac.diffPreferences"

    var diffPreferences: DiffPreferences {
        get {
            guard let data = data(forKey: Self.diffPreferencesKey) else {
                return .default
            }

            do {
                return try JSONDecoder().decode(DiffPreferences.self, from: data)
            } catch {
                print("Failed to decode DiffPreferences: \(error)")
                return .default
            }
        }
        set {
            do {
                let data = try JSONEncoder().encode(newValue)
                set(data, forKey: Self.diffPreferencesKey)
            } catch {
                print("Failed to encode DiffPreferences: \(error)")
            }
        }
    }
}
