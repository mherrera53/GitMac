import Foundation

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
