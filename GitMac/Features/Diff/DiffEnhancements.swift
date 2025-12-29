import SwiftUI
import AppKit
import Splash
import os.signpost

// MARK: - Intraline Word-Diff Engine

/// High-performance intraline diff with budget control
public actor IntralineDiffEngine {

    private static let signpostLog = OSLog(subsystem: "com.gitmac.IntralineDiff", category: "Performance")

    /// Maximum time budget per line in milliseconds
    private let timeBudgetMs: Double

    /// Maximum line length to process
    private let maxLineLength: Int

    /// Cache for computed intraline diffs
    private var cache: [String: IntralineResult] = [:]
    private let maxCacheSize = 1000

    public init(timeBudgetMs: Double = 5.0, maxLineLength: Int = 1000) {
        self.timeBudgetMs = timeBudgetMs
        self.maxLineLength = maxLineLength
    }

    /// Result of intraline diff computation
    public struct IntralineResult: Sendable {
        public let oldSegments: [IntralineSegment]
        public let newSegments: [IntralineSegment]
        public let wasAborted: Bool
        public let computeTimeMs: Double
    }

    /// A segment within a line
    public struct IntralineSegment: Sendable, Identifiable {
        public let id = UUID()
        public let text: String
        public let type: SegmentType

        public enum SegmentType: Sendable {
            case unchanged
            case added
            case removed
        }
    }

    /// Compute intraline diff between old and new line
    public func compute(oldLine: String, newLine: String) async -> IntralineResult {
        // Check cache
        let cacheKey = "\(oldLine.hashValue):\(newLine.hashValue)"
        if let cached = cache[cacheKey] {
            return cached
        }

        let startTime = CFAbsoluteTimeGetCurrent()

        // Skip if lines are too long
        guard oldLine.count <= maxLineLength && newLine.count <= maxLineLength else {
            return IntralineResult(
                oldSegments: [IntralineSegment(text: oldLine, type: .removed)],
                newSegments: [IntralineSegment(text: newLine, type: .added)],
                wasAborted: true,
                computeTimeMs: 0
            )
        }

        // Identical lines
        if oldLine == newLine {
            let result = IntralineResult(
                oldSegments: [IntralineSegment(text: oldLine, type: .unchanged)],
                newSegments: [IntralineSegment(text: newLine, type: .unchanged)],
                wasAborted: false,
                computeTimeMs: 0
            )
            cacheResult(result, forKey: cacheKey)
            return result
        }

        // Empty cases
        if oldLine.isEmpty {
            let result = IntralineResult(
                oldSegments: [],
                newSegments: [IntralineSegment(text: newLine, type: .added)],
                wasAborted: false,
                computeTimeMs: 0
            )
            cacheResult(result, forKey: cacheKey)
            return result
        }

        if newLine.isEmpty {
            let result = IntralineResult(
                oldSegments: [IntralineSegment(text: oldLine, type: .removed)],
                newSegments: [],
                wasAborted: false,
                computeTimeMs: 0
            )
            cacheResult(result, forKey: cacheKey)
            return result
        }

        // Compute LCS-based diff with timeout
        let result = await computeWithBudget(oldLine: oldLine, newLine: newLine, startTime: startTime)

        let endTime = CFAbsoluteTimeGetCurrent()
        let finalResult = IntralineResult(
            oldSegments: result.oldSegments,
            newSegments: result.newSegments,
            wasAborted: result.wasAborted,
            computeTimeMs: (endTime - startTime) * 1000
        )

        cacheResult(finalResult, forKey: cacheKey)
        return finalResult
    }

    private func computeWithBudget(oldLine: String, newLine: String, startTime: CFAbsoluteTime) async -> IntralineResult {
        // Find common prefix
        let oldChars = Array(oldLine)
        let newChars = Array(newLine)

        var prefixLen = 0
        while prefixLen < oldChars.count && prefixLen < newChars.count && oldChars[prefixLen] == newChars[prefixLen] {
            prefixLen += 1

            // Check budget periodically
            if prefixLen % 100 == 0 {
                let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
                if elapsed > timeBudgetMs {
                    return abortedResult(oldLine: oldLine, newLine: newLine)
                }
            }
        }

        // Find common suffix
        var suffixLen = 0
        while suffixLen < (oldChars.count - prefixLen) &&
              suffixLen < (newChars.count - prefixLen) &&
              oldChars[oldChars.count - 1 - suffixLen] == newChars[newChars.count - 1 - suffixLen] {
            suffixLen += 1

            if suffixLen % 100 == 0 {
                let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
                if elapsed > timeBudgetMs {
                    return abortedResult(oldLine: oldLine, newLine: newLine)
                }
            }
        }

        // Build segments
        var oldSegments: [IntralineSegment] = []
        var newSegments: [IntralineSegment] = []

        // Prefix (unchanged)
        if prefixLen > 0 {
            let prefix = String(oldChars[0..<prefixLen])
            oldSegments.append(IntralineSegment(text: prefix, type: .unchanged))
            newSegments.append(IntralineSegment(text: prefix, type: .unchanged))
        }

        // Middle (changed)
        let oldMiddleEnd = oldChars.count - suffixLen
        let newMiddleEnd = newChars.count - suffixLen

        if prefixLen < oldMiddleEnd {
            let oldMiddle = String(oldChars[prefixLen..<oldMiddleEnd])
            oldSegments.append(IntralineSegment(text: oldMiddle, type: .removed))
        }

        if prefixLen < newMiddleEnd {
            let newMiddle = String(newChars[prefixLen..<newMiddleEnd])
            newSegments.append(IntralineSegment(text: newMiddle, type: .added))
        }

        // Suffix (unchanged)
        if suffixLen > 0 {
            let suffix = String(oldChars[(oldChars.count - suffixLen)...])
            oldSegments.append(IntralineSegment(text: suffix, type: .unchanged))
            newSegments.append(IntralineSegment(text: suffix, type: .unchanged))
        }

        return IntralineResult(
            oldSegments: oldSegments,
            newSegments: newSegments,
            wasAborted: false,
            computeTimeMs: 0
        )
    }

    private func abortedResult(oldLine: String, newLine: String) -> IntralineResult {
        IntralineResult(
            oldSegments: [IntralineSegment(text: oldLine, type: .removed)],
            newSegments: [IntralineSegment(text: newLine, type: .added)],
            wasAborted: true,
            computeTimeMs: 0
        )
    }

    private func cacheResult(_ result: IntralineResult, forKey key: String) {
        if cache.count >= maxCacheSize {
            // Remove oldest entries (simple approach)
            let keysToRemove = Array(cache.keys.prefix(maxCacheSize / 4))
            for k in keysToRemove {
                cache.removeValue(forKey: k)
            }
        }
        cache[key] = result
    }

    public func clearCache() {
        cache.removeAll()
    }
}

// MARK: - Syntax Highlighter with Cancellation

/// On-demand syntax highlighting with cancellation support
public actor SyntaxHighlightEngine {

    private static let signpostLog = OSLog(subsystem: "com.gitmac.SyntaxHighlight", category: "Performance")

    /// Splash highlighter
    private let highlighter: SyntaxHighlighter<AttributedStringOutputFormat>

    /// Cache for highlighted content
    private var cache: [String: NSAttributedString] = [:]
    private let maxCacheSize = 500

    /// Current highlighting tasks (for cancellation)
    private var activeTasks: [UUID: Task<Void, Never>] = [:]

    public init() {
        let theme = Theme(
            font: DesignTokens.Typography.diffLine.font,
            plainTextColor: Color(AppTheme.textPrimary),
            tokenColors: [
                .keyword: Color(red: 0.6, green: 0.4, blue: 0.8),
                .string: Color(red: 0.8, green: 0.6, blue: 0.4),
                .type: Color(red: 0.4, green: 0.7, blue: 0.8),
                .call: Color(red: 0.6, green: 0.8, blue: 0.6),
                .number: Color(red: 0.8, green: 0.7, blue: 0.5),
                .comment: Color(AppTheme.textMuted),
                .property: Color(red: 0.7, green: 0.6, blue: 0.8),
                .dotAccess: Color(red: 0.6, green: 0.7, blue: 0.8),
                .preprocessing: Color(red: 0.8, green: 0.5, blue: 0.5)
            ],
            backgroundColor: Color.clear
        )
        self.highlighter = SyntaxHighlighter(format: AttributedStringOutputFormat(theme: theme))
    }

    /// Highlight code with cancellation support
    public func highlight(
        code: String,
        language: String?,
        taskId: UUID = UUID()
    ) async throws -> NSAttributedString {
        // Check cache
        let cacheKey = "\(code.hashValue):\(language ?? "unknown")"
        if let cached = cache[cacheKey] {
            return cached
        }

        // Create cancellable task
        return try await withTaskCancellationHandler {
            // Check cancellation before starting
            try Task.checkCancellation()

            let result = highlighter.highlight(code)

            // Cache result
            if cache.count >= maxCacheSize {
                let keysToRemove = Array(cache.keys.prefix(maxCacheSize / 4))
                for k in keysToRemove {
                    cache.removeValue(forKey: k)
                }
            }

            let nsResult = NSAttributedString(result)
            cache[cacheKey] = nsResult

            return nsResult
        } onCancel: {
            // Cleanup on cancellation
            Task { await self.cancelTask(taskId) }
        }
    }

    /// Highlight multiple lines for viewport
    public func highlightViewport(
        lines: [(index: Int, content: String)],
        language: String?
    ) async -> [Int: NSAttributedString] {
        var results: [Int: NSAttributedString] = [:]

        for (index, content) in lines {
            if Task.isCancelled { break }

            do {
                let highlighted = try await highlight(code: content, language: language)
                results[index] = highlighted
            } catch {
                // Use plain text on error
                results[index] = NSAttributedString(string: content)
            }
        }

        return results
    }

    private func cancelTask(_ taskId: UUID) {
        activeTasks[taskId]?.cancel()
        activeTasks.removeValue(forKey: taskId)
    }

    public func cancelAllTasks() {
        for task in activeTasks.values {
            task.cancel()
        }
        activeTasks.removeAll()
    }

    public func clearCache() {
        cache.removeAll()
    }
}

// MARK: - Diff Preferences

/// User preferences for diff viewer
public struct DiffPreferences: Codable, Equatable {
    // MARK: - LFM Thresholds
    public var lfmFileSizeThresholdMB: Int = 8
    public var lfmLinesThreshold: Int = 50_000
    public var lfmMaxLineLengthThreshold: Int = 2_000
    public var lfmHunksThreshold: Int = 1_000

    // MARK: - Display Options
    public var defaultViewMode: ViewModePreference = .unified
    public var showLineNumbers: Bool = true
    public var contextLines: Int = 3
    public var wordWrap: Bool = false
    public var tabWidth: Int = 4

    // MARK: - Highlighting
    public var enableWordDiff: Bool = true
    public var enableSyntaxHighlight: Bool = true
    public var wordDiffTimeBudgetMs: Double = 5.0

    // MARK: - Colors
    public var additionBackgroundOpacity: Double = 0.15
    public var deletionBackgroundOpacity: Double = 0.15
    public var useHighContrastColors: Bool = false

    // MARK: - Performance
    public var enableCaching: Bool = true
    public var maxCacheSizeMB: Int = 50

    public enum ViewModePreference: String, Codable, CaseIterable {
        case unified = "Unified"
        case sideBySide = "Side by Side"
        case auto = "Auto"
    }

    public static let `default` = DiffPreferences()

    /// Convert to LargeFileModeConfig
    public func toLFMConfig() -> LargeFileModeConfig {
        var config = LargeFileModeConfig()
        config.fileSizeThreshold = lfmFileSizeThresholdMB * 1024 * 1024
        config.linesThreshold = lfmLinesThreshold
        config.maxLineLengthThreshold = lfmMaxLineLengthThreshold
        config.hunksThreshold = lfmHunksThreshold
        config.lfmContextLines = contextLines
        return config
    }

    /// Convert to DiffOptions
    public func toDiffOptions() -> DiffOptions {
        var options = DiffOptions()
        options.contextLines = contextLines
        options.enableWordDiff = enableWordDiff
        options.enableSyntaxHighlight = enableSyntaxHighlight
        options.lfmConfig = toLFMConfig()

        switch defaultViewMode {
        case .unified:
            options.sideBySide = .forceOff
        case .sideBySide:
            options.sideBySide = .forceOn
        case .auto:
            options.sideBySide = .auto
        }

        return options
    }
}

// MARK: - Preferences Manager

/// Manages diff preferences with persistence
@MainActor
public class DiffPreferencesManager: ObservableObject {
    public static let shared = DiffPreferencesManager()

    @Published public var preferences: DiffPreferences {
        didSet {
            save()
        }
    }

    private let userDefaultsKey = "DiffPreferences"

    private init() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode(DiffPreferences.self, from: data) {
            self.preferences = decoded
        } else {
            self.preferences = .default
        }
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    public func reset() {
        preferences = .default
    }
}

// MARK: - Preferences View

/// Settings view for diff preferences
struct DiffPreferencesView: View {
    @StateObject private var themeManager = ThemeManager.shared

    @ObservedObject var manager = DiffPreferencesManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            // Display Section
            Section("Display") {
                Picker("Default View", selection: $manager.preferences.defaultViewMode) {
                    ForEach(DiffPreferences.ViewModePreference.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }

                Toggle("Show Line Numbers", isOn: $manager.preferences.showLineNumbers)

                Stepper("Context Lines: \(manager.preferences.contextLines)", value: $manager.preferences.contextLines, in: 1...20)

                Toggle("Word Wrap", isOn: $manager.preferences.wordWrap)

                Stepper("Tab Width: \(manager.preferences.tabWidth)", value: $manager.preferences.tabWidth, in: 2...8)
            }

            // Highlighting Section
            Section("Highlighting") {
                Toggle("Enable Word-Level Diff", isOn: $manager.preferences.enableWordDiff)

                Toggle("Enable Syntax Highlighting", isOn: $manager.preferences.enableSyntaxHighlight)

                if manager.preferences.enableWordDiff {
                    HStack {
                        Text("Word-Diff Budget")
                        Spacer()
                        TextField("", value: $manager.preferences.wordDiffTimeBudgetMs, format: .number)
                            .frame(width: 60)
                            .textFieldStyle(.roundedBorder)
                        Text("ms")
                            .foregroundColor(AppTheme.textPrimary)
                    }
                }
            }

            // Large File Mode Section
            Section("Large File Mode Thresholds") {
                HStack {
                    Text("File Size")
                    Spacer()
                    TextField("", value: $manager.preferences.lfmFileSizeThresholdMB, format: .number)
                        .frame(width: 60)
                        .textFieldStyle(.roundedBorder)
                    Text("MB")
                        .foregroundColor(AppTheme.textPrimary)
                }

                HStack {
                    Text("Lines")
                    Spacer()
                    TextField("", value: $manager.preferences.lfmLinesThreshold, format: .number)
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                }

                HStack {
                    Text("Max Line Length")
                    Spacer()
                    TextField("", value: $manager.preferences.lfmMaxLineLengthThreshold, format: .number)
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                    Text("chars")
                        .foregroundColor(AppTheme.textPrimary)
                }

                HStack {
                    Text("Hunks")
                    Spacer()
                    TextField("", value: $manager.preferences.lfmHunksThreshold, format: .number)
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                }
            }

            // Colors Section
            Section("Colors") {
                HStack {
                    Text("Addition Background")
                    Spacer()
                    Slider(value: $manager.preferences.additionBackgroundOpacity, in: 0.05...0.5)
                        .frame(width: 150)
                    Text("\(Int(manager.preferences.additionBackgroundOpacity * 100))%")
                        .frame(width: 40)
                        .foregroundColor(AppTheme.textPrimary)
                }

                HStack {
                    Text("Deletion Background")
                    Spacer()
                    Slider(value: $manager.preferences.deletionBackgroundOpacity, in: 0.05...0.5)
                        .frame(width: 150)
                    Text("\(Int(manager.preferences.deletionBackgroundOpacity * 100))%")
                        .frame(width: 40)
                        .foregroundColor(AppTheme.textPrimary)
                }

                Toggle("High Contrast Colors", isOn: $manager.preferences.useHighContrastColors)
            }

            // Performance Section
            Section("Performance") {
                Toggle("Enable Caching", isOn: $manager.preferences.enableCaching)

                if manager.preferences.enableCaching {
                    Stepper("Cache Size: \(manager.preferences.maxCacheSizeMB) MB",
                            value: $manager.preferences.maxCacheSizeMB, in: 10...200, step: 10)
                }
            }

            // Reset Button
            Section {
                Button("Reset to Defaults") {
                    manager.reset()
                }
                .foregroundColor(AppTheme.error)
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 600)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Enhanced Line View with Intraline

/// Line view with intraline word-diff highlighting
struct IntralineDiffLineView: View {
    let line: DiffLine
    let intralineResult: IntralineDiffEngine.IntralineResult?
    let showLineNumbers: Bool
    let preferences: DiffPreferences

    var body: some View {
        HStack(spacing: 0) {
            // Line numbers
            if showLineNumbers {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Text(line.oldLineNumber.map { String($0) } ?? "")
                        .frame(width: 35, alignment: .trailing)
                    Text(line.newLineNumber.map { String($0) } ?? "")
                        .frame(width: 35, alignment: .trailing)
                }
                .font(DesignTokens.Typography.commitHash)
                .foregroundColor(AppTheme.textMuted)
                .padding(.trailing, DesignTokens.Spacing.sm)
                .background(lineNumberBackground)
            }

            // Prefix
            Text(prefix)
                .foregroundColor(prefixColor)
                .frame(width: 16)
                .font(DesignTokens.Typography.diffLine)

            // Content with intraline highlighting
            if let intraline = intralineResult, !intraline.wasAborted {
                intralineContent(segments: segmentsForLine(intraline))
            } else {
                Text(line.content)
                    .foregroundColor(textColor)
                    .font(DesignTokens.Typography.diffLine)
            }

            Spacer()
        }
        .padding(.vertical, DesignTokens.Spacing.xxs)
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .background(backgroundColor)
    }

    private func segmentsForLine(_ result: IntralineDiffEngine.IntralineResult) -> [IntralineDiffEngine.IntralineSegment] {
        switch line.type {
        case .deletion:
            return result.oldSegments
        case .addition:
            return result.newSegments
        default:
            return [IntralineDiffEngine.IntralineSegment(text: line.content, type: .unchanged)]
        }
    }

    @ViewBuilder
    private func intralineContent(segments: [IntralineDiffEngine.IntralineSegment]) -> some View {
        HStack(spacing: 0) {
            ForEach(segments) { segment in
                Text(segment.text)
                    .font(DesignTokens.Typography.diffLine)
                    .foregroundColor(colorForSegment(segment))
                    .background(backgroundForSegment(segment))
            }
        }
    }

    private func colorForSegment(_ segment: IntralineDiffEngine.IntralineSegment) -> Color {
        switch segment.type {
        case .unchanged:
            return textColor
        case .added:
            return preferences.useHighContrastColors ? .white : AppTheme.success
        case .removed:
            return preferences.useHighContrastColors ? .white : AppTheme.error
        }
    }

    private func backgroundForSegment(_ segment: IntralineDiffEngine.IntralineSegment) -> Color {
        switch segment.type {
        case .unchanged:
            return .clear
        case .added:
            return AppTheme.success.opacity(0.3)
        case .removed:
            return AppTheme.error.opacity(0.3)
        }
    }

    private var prefix: String {
        switch line.type {
        case .addition: return "+"
        case .deletion: return "-"
        case .context: return " "
        case .hunkHeader: return "@"
        }
    }

    private var prefixColor: Color {
        switch line.type {
        case .addition: return AppTheme.success
        case .deletion: return AppTheme.error
        default: return AppTheme.textMuted
        }
    }

    private var textColor: Color {
        switch line.type {
        case .addition: return AppTheme.success
        case .deletion: return AppTheme.error
        default: return AppTheme.textPrimary
        }
    }

    private var backgroundColor: Color {
        switch line.type {
        case .addition:
            return AppTheme.success.opacity(preferences.additionBackgroundOpacity)
        case .deletion:
            return AppTheme.error.opacity(preferences.deletionBackgroundOpacity)
        default:
            return .clear
        }
    }

    private var lineNumberBackground: Color {
        switch line.type {
        case .addition:
            return AppTheme.success.opacity(0.06)
        case .deletion:
            return AppTheme.error.opacity(0.06)
        default:
            return AppTheme.backgroundSecondary
        }
    }
}

// MARK: - Syntax Highlighted Line View

/// Line view with syntax highlighting
struct SyntaxHighlightedLineView: View {
    let line: DiffLine
    let highlightedContent: NSAttributedString?
    let showLineNumbers: Bool

    var body: some View {
        HStack(spacing: 0) {
            if showLineNumbers {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Text(line.oldLineNumber.map { String($0) } ?? "")
                        .frame(width: 35, alignment: .trailing)
                    Text(line.newLineNumber.map { String($0) } ?? "")
                        .frame(width: 35, alignment: .trailing)
                }
                .font(DesignTokens.Typography.commitHash)
                .foregroundColor(AppTheme.textMuted)
                .padding(.trailing, DesignTokens.Spacing.sm)
            }

            // Prefix
            Text(prefix)
                .foregroundColor(prefixColor)
                .frame(width: 16)
                .font(DesignTokens.Typography.diffLine)

            // Content
            if let highlighted = highlightedContent {
                AttributedText(highlighted)
            } else {
                Text(line.content)
                    .foregroundColor(textColor)
                    .font(DesignTokens.Typography.diffLine)
            }

            Spacer()
        }
        .padding(.vertical, DesignTokens.Spacing.xxs)
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .background(backgroundColor)
    }

    private var prefix: String {
        switch line.type {
        case .addition: return "+"
        case .deletion: return "-"
        case .context: return " "
        case .hunkHeader: return "@"
        }
    }

    private var prefixColor: Color {
        switch line.type {
        case .addition: return AppTheme.success
        case .deletion: return AppTheme.error
        default: return AppTheme.textMuted
        }
    }

    private var textColor: Color {
        switch line.type {
        case .addition: return AppTheme.success
        case .deletion: return AppTheme.error
        default: return AppTheme.textPrimary
        }
    }

    private var backgroundColor: Color {
        switch line.type {
        case .addition: return AppTheme.success.opacity(0.15)
        case .deletion: return AppTheme.error.opacity(0.15)
        default: return .clear
        }
    }
}

// MARK: - AttributedText Helper

/// SwiftUI wrapper for NSAttributedString
struct AttributedText: View {
    let attributedString: NSAttributedString

    init(_ attributedString: NSAttributedString) {
        self.attributedString = attributedString
    }

    var body: some View {
        Text(AttributedString(attributedString))
    }
}

// MARK: - Viewport-Based Enhancement Manager

/// Manages on-demand intraline and syntax highlighting for visible viewport
@MainActor
public class ViewportEnhancementManager: ObservableObject {
    private let intralineEngine = IntralineDiffEngine()
    private let syntaxEngine = SyntaxHighlightEngine()

    @Published public var intralineResults: [String: IntralineDiffEngine.IntralineResult] = [:]
    @Published public var syntaxResults: [Int: NSAttributedString] = [:]

    private var currentTask: Task<Void, Never>?

    /// Process visible lines for enhancements
    public func processViewport(
        lines: [DiffLine],
        visibleRange: Range<Int>,
        language: String?,
        preferences: DiffPreferences
    ) {
        // Cancel previous task
        currentTask?.cancel()

        currentTask = Task {
            // Process intraline diffs
            if preferences.enableWordDiff {
                await processIntraline(lines: lines, visibleRange: visibleRange)
            }

            // Process syntax highlighting
            if preferences.enableSyntaxHighlight {
                await processSyntaxHighlight(lines: lines, visibleRange: visibleRange, language: language)
            }
        }
    }

    private func processIntraline(lines: [DiffLine], visibleRange: Range<Int>) async {
        // Find pairs of deletion/addition for intraline comparison
        var i = visibleRange.lowerBound
        while i < min(visibleRange.upperBound, lines.count) {
            if Task.isCancelled { return }

            let line = lines[i]

            // Look for deletion followed by addition
            if line.type == .deletion && i + 1 < lines.count && lines[i + 1].type == .addition {
                let oldLine = line.content
                let newLine = lines[i + 1].content

                let result = await intralineEngine.compute(oldLine: oldLine, newLine: newLine)

                await MainActor.run {
                    intralineResults["\(i)"] = result
                    intralineResults["\(i + 1)"] = result
                }

                i += 2
            } else {
                i += 1
            }
        }
    }

    private func processSyntaxHighlight(lines: [DiffLine], visibleRange: Range<Int>, language: String?) async {
        let linesToHighlight = (visibleRange.lowerBound..<min(visibleRange.upperBound, lines.count))
            .filter { lines[$0].type == .context || lines[$0].type == .addition }
            .map { (index: $0, content: lines[$0].content) }

        let results = await syntaxEngine.highlightViewport(lines: linesToHighlight, language: language)

        await MainActor.run {
            for (index, highlighted) in results {
                syntaxResults[index] = highlighted
            }
        }
    }

    public func clearCache() async {
        await intralineEngine.clearCache()
        await syntaxEngine.clearCache()
        intralineResults.removeAll()
        syntaxResults.removeAll()
    }
}

// MARK: - File Language Detection

/// Detects programming language from file extension
struct LanguageDetector {
    static func detect(from filePath: String) -> String? {
        let ext = URL(fileURLWithPath: filePath).pathExtension.lowercased()

        switch ext {
        case "swift": return "swift"
        case "m", "mm": return "objective-c"
        case "c", "h": return "c"
        case "cpp", "cc", "cxx", "hpp": return "cpp"
        case "js", "jsx", "mjs": return "javascript"
        case "ts", "tsx": return "typescript"
        case "py": return "python"
        case "rb": return "ruby"
        case "go": return "go"
        case "rs": return "rust"
        case "java": return "java"
        case "kt", "kts": return "kotlin"
        case "cs": return "csharp"
        case "php": return "php"
        case "html", "htm": return "html"
        case "css", "scss", "sass", "less": return "css"
        case "json": return "json"
        case "xml", "plist": return "xml"
        case "yaml", "yml": return "yaml"
        case "md", "markdown": return "markdown"
        case "sh", "bash", "zsh": return "bash"
        case "sql": return "sql"
        default: return nil
        }
    }
}
