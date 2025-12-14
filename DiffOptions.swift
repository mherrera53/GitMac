import Foundation

// MARK: - Diff Options

/// Configuration options for diff operations
struct DiffOptions: Sendable {
    var contextLines: Int
    var enableWordDiff: Bool
    var enableSyntaxHighlight: Bool
    var largeFileMode: LargeFileMode
    var sideBySide: AutoFlag
    var noRenames: Bool
    
    init(
        contextLines: Int = 3,
        enableWordDiff: Bool = true,
        enableSyntaxHighlight: Bool = true,
        largeFileMode: LargeFileMode = .auto(),
        sideBySide: AutoFlag = .auto,
        noRenames: Bool = false
    ) {
        self.contextLines = contextLines
        self.enableWordDiff = enableWordDiff
        self.enableSyntaxHighlight = enableSyntaxHighlight
        self.largeFileMode = largeFileMode
        self.sideBySide = sideBySide
        self.noRenames = noRenames
    }
    
    /// Default options
    static var `default`: DiffOptions {
        DiffOptions()
    }
    
    /// Options optimized for large files
    static var largeFile: DiffOptions {
        DiffOptions(
            enableWordDiff: false,
            enableSyntaxHighlight: false,
            largeFileMode: .manualOn,
            sideBySide: .off,
            noRenames: true
        )
    }
    
    /// Options optimized for speed
    static var fast: DiffOptions {
        DiffOptions(
            contextLines: 1,
            enableWordDiff: false,
            enableSyntaxHighlight: false,
            sideBySide: .off,
            noRenames: true
        )
    }
}

// MARK: - Large File Mode

/// Large File Mode configuration
enum LargeFileMode: Sendable, Codable {
    case auto(thresholds: LFMThresholds = .default)
    case manualOn
    case manualOff
    
    var isEnabled: Bool {
        switch self {
        case .manualOn: return true
        case .manualOff: return false
        case .auto: return false  // Determined at runtime
        }
    }
    
    var thresholds: LFMThresholds {
        switch self {
        case .auto(let thresholds): return thresholds
        case .manualOn, .manualOff: return .default
        }
    }
}

/// Thresholds for automatic Large File Mode activation
struct LFMThresholds: Sendable, Codable {
    var fileSizeMB: Int
    var estimatedLines: Int
    var maxLineLength: Int
    var maxHunks: Int
    
    init(
        fileSizeMB: Int = 8,
        estimatedLines: Int = 50_000,
        maxLineLength: Int = 2_000,
        maxHunks: Int = 1_000
    ) {
        self.fileSizeMB = fileSizeMB
        self.estimatedLines = estimatedLines
        self.maxLineLength = maxLineLength
        self.maxHunks = maxHunks
    }
    
    /// Default thresholds
    static var `default`: LFMThresholds {
        LFMThresholds()
    }
    
    /// Conservative thresholds (activate LFM earlier)
    static var conservative: LFMThresholds {
        LFMThresholds(
            fileSizeMB: 4,
            estimatedLines: 20_000,
            maxLineLength: 1_000,
            maxHunks: 500
        )
    }
    
    /// Aggressive thresholds (activate LFM later)
    static var aggressive: LFMThresholds {
        LFMThresholds(
            fileSizeMB: 16,
            estimatedLines: 100_000,
            maxLineLength: 5_000,
            maxHunks: 2_000
        )
    }
    
    /// Check if stats exceed thresholds
    func shouldActivateLFM(stats: DiffPreflightStats) -> Bool {
        return stats.patchSizeBytes > fileSizeMB * 1_024 * 1_024 ||
               stats.estimatedLines > estimatedLines ||
               stats.maxLineLength > maxLineLength ||
               stats.hunkCount > maxHunks
    }
}

// MARK: - Auto Flag

/// Tri-state flag for automatic/manual control
enum AutoFlag: String, Sendable, Codable {
    case auto
    case on
    case off
    
    func resolve(condition: Bool) -> Bool {
        switch self {
        case .auto: return condition
        case .on: return true
        case .off: return false
        }
    }
}

// MARK: - Diff Preflight Stats

/// Statistics gathered during preflight to determine LFM activation
struct DiffPreflightStats: Sendable {
    let additions: Int
    let deletions: Int
    let patchSizeBytes: Int
    let estimatedLines: Int
    let maxLineLength: Int
    let hunkCount: Int
    let isBinary: Bool
    
    init(
        additions: Int = 0,
        deletions: Int = 0,
        patchSizeBytes: Int = 0,
        estimatedLines: Int = 0,
        maxLineLength: Int = 0,
        hunkCount: Int = 0,
        isBinary: Bool = false
    ) {
        self.additions = additions
        self.deletions = deletions
        self.patchSizeBytes = patchSizeBytes
        self.estimatedLines = estimatedLines
        self.maxLineLength = maxLineLength
        self.hunkCount = hunkCount
        self.isBinary = isBinary
    }
    
    /// Create stats from git diff --numstat output
    static func from(numstatLine: String, patchSize: Int, hunkCount: Int, maxLineLength: Int) -> DiffPreflightStats {
        let parts = numstatLine.split(separator: "\t")
        guard parts.count >= 2 else {
            return DiffPreflightStats(
                patchSizeBytes: patchSize,
                hunkCount: hunkCount,
                maxLineLength: maxLineLength
            )
        }
        
        // Binary files show "-" for additions/deletions
        let isBinary = parts[0] == "-" && parts[1] == "-"
        let additions = Int(parts[0]) ?? 0
        let deletions = Int(parts[1]) ?? 0
        let estimatedLines = additions + deletions
        
        return DiffPreflightStats(
            additions: additions,
            deletions: deletions,
            patchSizeBytes: patchSize,
            estimatedLines: estimatedLines,
            maxLineLength: maxLineLength,
            hunkCount: hunkCount,
            isBinary: isBinary
        )
    }
}

// MARK: - Diff Degradation

/// Types of performance degradations applied
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
    var lfmThresholds: LFMThresholds
    var lfmManualOverrides: [String: Bool]  // File path -> manual LFM on/off
    var defaultContextLines: Int
    var enableWordDiffOnDemand: Bool
    var enableSyntaxHighlightOnDemand: Bool
    var defaultViewMode: DiffViewModePreference
    var showLineNumbers: Bool
    var showWhitespace: Bool
    
    init(
        lfmThresholds: LFMThresholds = .default,
        lfmManualOverrides: [String: Bool] = [:],
        defaultContextLines: Int = 3,
        enableWordDiffOnDemand: Bool = true,
        enableSyntaxHighlightOnDemand: Bool = true,
        defaultViewMode: DiffViewModePreference = .split,
        showLineNumbers: Bool = true,
        showWhitespace: Bool = false
    ) {
        self.lfmThresholds = lfmThresholds
        self.lfmManualOverrides = lfmManualOverrides
        self.defaultContextLines = defaultContextLines
        self.enableWordDiffOnDemand = enableWordDiffOnDemand
        self.enableSyntaxHighlightOnDemand = enableSyntaxHighlightOnDemand
        self.defaultViewMode = defaultViewMode
        self.showLineNumbers = showLineNumbers
        self.showWhitespace = showWhitespace
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
