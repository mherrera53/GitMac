import Foundation

// MARK: - Diff Options

/// Configuration options for diff operations with Large File Mode support
struct DiffOptions: Sendable {
    var contextLines: Int = 3
    var enableWordDiff: Bool = false  // Only on-demand in LFM
    var enableSyntaxHighlight: Bool = false  // Only on-demand in LFM
    var largeFileMode: LargeFileMode = .auto(thresholds: .default)
    var sideBySide: AutoFlag = .auto
    var showWhitespace: Bool = false
    var ignoreWhitespace: Bool = false
    
    /// Create default options
    static let `default` = DiffOptions()
    
    /// Create options optimized for performance (LFM enabled)
    static var performance: DiffOptions {
        var options = DiffOptions()
        options.largeFileMode = .manualOn
        options.enableWordDiff = false
        options.enableSyntaxHighlight = false
        options.sideBySide = .off
        return options
    }
    
    /// Git arguments for this configuration
    var gitArguments: [String] {
        var args: [String] = []
        
        args.append("--unified=\(contextLines)")
        
        if ignoreWhitespace {
            args.append("-w")
        }
        
        // Word diff is handled separately, not via git
        // We compute it on-demand in the UI
        
        return args
    }
}

// MARK: - Large File Mode

/// Large File Mode configuration
enum LargeFileMode: Sendable {
    case auto(thresholds: LFMThresholds)
    case manualOn
    case manualOff
    
    /// Determine if LFM should be active for given stats
    func shouldActivate(for stats: DiffPreflightStats) -> Bool {
        switch self {
        case .auto(let thresholds):
            return thresholds.exceeds(stats)
        case .manualOn:
            return true
        case .manualOff:
            return false
        }
    }
}

/// Thresholds for automatic Large File Mode activation
struct LFMThresholds: Codable, Sendable {
    var fileSizeMB: Int = 8
    var estimatedLines: Int = 50_000
    var maxLineLength: Int = 2_000
    var maxHunks: Int = 1_000
    
    static let `default` = LFMThresholds()
    
    /// More aggressive thresholds (activate LFM earlier)
    static var aggressive: LFMThresholds {
        LFMThresholds(
            fileSizeMB: 4,
            estimatedLines: 20_000,
            maxLineLength: 1_000,
            maxHunks: 500
        )
    }
    
    /// More lenient thresholds (activate LFM later)
    static var lenient: LFMThresholds {
        LFMThresholds(
            fileSizeMB: 16,
            estimatedLines: 100_000,
            maxLineLength: 5_000,
            maxHunks: 2_000
        )
    }
    
    /// Check if stats exceed any threshold
    func exceeds(_ stats: DiffPreflightStats) -> Bool {
        // File size
        if stats.fileSizeBytes > fileSizeMB * 1_024 * 1_024 {
            return true
        }
        
        // Estimated lines
        if stats.additions + stats.deletions > estimatedLines {
            return true
        }
        
        // Max line length (if available)
        if let maxLen = stats.maxLineLength, maxLen > maxLineLength {
            return true
        }
        
        // Hunk count (if available)
        if let hunkCount = stats.estimatedHunkCount, hunkCount > maxHunks {
            return true
        }
        
        return false
    }
}

// MARK: - Auto Flag

/// Three-state flag for automatic feature activation
enum AutoFlag: Sendable {
    case auto
    case on
    case off
    
    /// Determine if feature should be active
    func shouldEnable(default defaultValue: Bool) -> Bool {
        switch self {
        case .auto: return defaultValue
        case .on: return true
        case .off: return false
        }
    }
}

// MARK: - Preflight Stats

/// Statistics gathered during preflight check (git diff --numstat)
struct DiffPreflightStats: Sendable {
    let filePath: String
    let additions: Int
    let deletions: Int
    let fileSizeBytes: Int
    let maxLineLength: Int?
    let estimatedHunkCount: Int?
    
    var totalChangedLines: Int {
        additions + deletions
    }
    
    var isBinary: Bool {
        additions == 0 && deletions == 0
    }
}

// MARK: - Diff Preferences

/// User preferences for diff operations (stored in UserDefaults)
struct DiffPreferences: Codable {
    var lfmThresholds: LFMThresholds = .default
    var lfmManualOverrides: [String: Bool] = [:]  // Per-file overrides
    var defaultContextLines: Int = 3
    var enableWordDiffOnDemand: Bool = true
    var enableSyntaxHighlightOnDemand: Bool = true
    var defaultViewMode: String = "split"  // "split", "unified", "hunk"
    var showLineNumbers: Bool = true
    var showWhitespace: Bool = false
    
    static let `default` = DiffPreferences()
    
    /// UserDefaults key
    private static let userDefaultsKey = "DiffPreferences"
    
    /// Load from UserDefaults
    static func load() -> DiffPreferences {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let prefs = try? JSONDecoder().decode(DiffPreferences.self, from: data) else {
            return .default
        }
        return prefs
    }
    
    /// Save to UserDefaults
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
        }
    }
    
    /// Get LFM override for specific file
    func lfmOverride(for filePath: String) -> Bool? {
        lfmManualOverrides[filePath]
    }
    
    /// Set LFM override for specific file
    mutating func setLFMOverride(for filePath: String, enabled: Bool?) {
        if let enabled = enabled {
            lfmManualOverrides[filePath] = enabled
        } else {
            lfmManualOverrides.removeValue(forKey: filePath)
        }
    }
}

// MARK: - Diff Degradations

/// Active degradations due to LFM or performance constraints
struct DiffDegradation: Identifiable, Sendable {
    let id: String
    let description: String
    let icon: String
    let reason: String
    
    static func wordDiffDisabled(reason: String = "Large file mode active") -> DiffDegradation {
        DiffDegradation(
            id: "word-diff-disabled",
            description: "Word-level diff disabled",
            icon: "text.word.spacing",
            reason: reason
        )
    }
    
    static func syntaxHighlightDisabled(reason: String = "Large file mode active") -> DiffDegradation {
        DiffDegradation(
            id: "syntax-highlight-disabled",
            description: "Syntax highlighting disabled",
            icon: "paintbrush.fill",
            reason: reason
        )
    }
    
    static func sideBySideDisabled(reason: String = "Large file mode active") -> DiffDegradation {
        DiffDegradation(
            id: "side-by-side-disabled",
            description: "Side-by-side view disabled",
            icon: "rectangle.split.2x1",
            reason: reason
        )
    }
    
    static func intralineAborted(lineLength: Int) -> DiffDegradation {
        DiffDegradation(
            id: "intraline-aborted",
            description: "Character-level diff skipped",
            icon: "exclamationmark.triangle",
            reason: "Line too long (\(lineLength) chars)"
        )
    }
}

// MARK: - Diff State

/// Current state of diff rendering with performance metrics
struct DiffState: Sendable {
    var isLFMActive: Bool = false
    var degradations: [DiffDegradation] = []
    var parseTimeSeconds: TimeInterval = 0
    var memoryUsageBytes: Int = 0
    var totalHunks: Int = 0
    var materializedHunks: Int = 0
    var visibleLines: Int = 0
    
    var memoryUsageMB: Double {
        Double(memoryUsageBytes) / (1024 * 1024)
    }
    
    mutating func addDegradation(_ degradation: DiffDegradation) {
        // Remove existing degradation with same ID
        degradations.removeAll { $0.id == degradation.id }
        degradations.append(degradation)
    }
    
    mutating func removeDegradation(id: String) {
        degradations.removeAll { $0.id == id }
    }
}
