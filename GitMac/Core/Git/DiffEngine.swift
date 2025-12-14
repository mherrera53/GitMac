import Foundation
import os.signpost

// MARK: - DiffEngine Configuration

/// Large File Mode configuration
public struct LargeFileModeConfig: Codable, Equatable {
    /// File size threshold in bytes (default: 8 MB)
    public var fileSizeThreshold: Int = 8 * 1024 * 1024

    /// Estimated lines threshold (default: 50k)
    public var linesThreshold: Int = 50_000

    /// Maximum line length before triggering LFM (default: 2k characters)
    public var maxLineLengthThreshold: Int = 2_000

    /// Maximum hunks before triggering LFM (default: 1k)
    public var hunksThreshold: Int = 1_000

    /// Context lines in LFM mode (default: 3)
    public var lfmContextLines: Int = 3

    public static let `default` = LargeFileModeConfig()
}

/// Controls Large File Mode behavior
public enum LargeFileMode: Equatable {
    case auto           // Automatically detect based on thresholds
    case forceOn        // Always use LFM
    case forceOff       // Never use LFM (may cause performance issues)
}

/// Controls side-by-side view
public enum SideBySideMode: Equatable {
    case auto           // Off in LFM, on otherwise (if medium size)
    case forceOn        // Always side-by-side
    case forceOff       // Always unified
}

/// Options for diff operations
public struct DiffOptions: Equatable {
    /// Number of context lines around changes
    public var contextLines: Int = 3

    /// Enable word-level diff highlighting
    public var enableWordDiff: Bool = true

    /// Enable syntax highlighting
    public var enableSyntaxHighlight: Bool = true

    /// Large file mode setting
    public var largeFileMode: LargeFileMode = .auto

    /// Side-by-side view setting
    public var sideBySide: SideBySideMode = .auto

    /// LFM configuration thresholds
    public var lfmConfig: LargeFileModeConfig = .default

    public static let `default` = DiffOptions()

    /// Options optimized for large files
    public static var largeFile: DiffOptions {
        var opts = DiffOptions()
        opts.enableWordDiff = false
        opts.enableSyntaxHighlight = false
        opts.largeFileMode = .forceOn
        opts.sideBySide = .forceOff
        opts.contextLines = 3
        return opts
    }
}

// MARK: - Preflight Stats

/// Statistics from preflight check (git diff --numstat)
public struct DiffPreflightStats {
    public let additions: Int
    public let deletions: Int
    public let estimatedLines: Int
    public let fileSizeBytes: Int?
    public let isLargeFile: Bool
    public let suggestedOptions: DiffOptions

    public var totalChanges: Int { additions + deletions }
}

// MARK: - Extended Models

/// Extended DiffHunk with LFM support
public struct StreamingDiffHunk: Identifiable, Sendable {
    public let id: UUID
    public let header: String
    public let oldStart: Int
    public let oldLines: Int
    public let newStart: Int
    public let newLines: Int

    /// For LFM: byte offsets in the raw diff stream (lazy materialization)
    public let byteRange: Range<Int>?

    /// Estimated line count (may differ from actual after materialization)
    public let estimatedLineCount: Int

    /// Whether this hunk is collapsed in the UI
    public var isCollapsed: Bool = true

    /// Materialized lines (nil until expanded in LFM)
    public var lines: [DiffLine]?

    /// Whether lines have been materialized
    public var isMaterialized: Bool { lines != nil }

    public init(
        header: String,
        oldStart: Int,
        oldLines: Int,
        newStart: Int,
        newLines: Int,
        byteRange: Range<Int>? = nil,
        estimatedLineCount: Int = 0,
        isCollapsed: Bool = true,
        lines: [DiffLine]? = nil
    ) {
        self.id = UUID()
        self.header = header
        self.oldStart = oldStart
        self.oldLines = oldLines
        self.newStart = newStart
        self.newLines = newLines
        self.byteRange = byteRange
        self.estimatedLineCount = estimatedLineCount
        self.isCollapsed = isCollapsed
        self.lines = lines
    }

    /// Convert to standard DiffHunk (requires materialization)
    public func toDiffHunk() -> DiffHunk? {
        guard let lines = lines else { return nil }
        return DiffHunk(
            header: header,
            oldStart: oldStart,
            oldLines: oldLines,
            newStart: newStart,
            newLines: newLines,
            lines: lines
        )
    }
}

/// Extended DiffLine with intraline ranges
public struct ExtendedDiffLine: Identifiable, Sendable {
    public let id: UUID
    public let type: DiffLineType
    public let content: String
    public let oldLineNumber: Int?
    public let newLineNumber: Int?

    /// Ranges within the line that are specifically changed (for word-diff)
    public var intralineRanges: [Range<String.Index>]?

    public init(
        type: DiffLineType,
        content: String,
        oldLineNumber: Int?,
        newLineNumber: Int?,
        intralineRanges: [Range<String.Index>]? = nil
    ) {
        self.id = UUID()
        self.type = type
        self.content = content
        self.oldLineNumber = oldLineNumber
        self.newLineNumber = newLineNumber
        self.intralineRanges = intralineRanges
    }

    /// Convert to standard DiffLine
    public func toDiffLine() -> DiffLine {
        DiffLine(
            type: type,
            content: content,
            oldLineNumber: oldLineNumber,
            newLineNumber: newLineNumber
        )
    }
}

// MARK: - Parser State Machine

/// State for the streaming diff parser
private enum ParserState {
    case initial
    case inFileHeader
    case inHunk
    case finished
}

/// Parsed hunk header info
private struct HunkHeaderInfo {
    let oldStart: Int
    let oldLines: Int
    let newStart: Int
    let newLines: Int
    let header: String
}

// MARK: - DiffEngine Actor

/// Actor for parsing and managing diffs with streaming support
public actor DiffEngine {

    // MARK: - Signposts for Instrumentation

    private static let signpostLog = OSLog(subsystem: "com.gitmac.DiffEngine", category: "Performance")
    private let parseSignpost = OSSignpostID(log: signpostLog)

    // MARK: - Dependencies

    private let shellExecutor: ShellExecutor

    // MARK: - Cache

    private var hunkCache: DiffCache<String, [StreamingDiffHunk]>

    // MARK: - Initialization

    public init(shellExecutor: ShellExecutor = ShellExecutor(), cacheSize: Int = 50 * 1024 * 1024) {
        self.shellExecutor = shellExecutor
        self.hunkCache = DiffCache(maxCostBytes: cacheSize)
    }

    // MARK: - Preflight

    /// Quick stats check before loading full diff
    public func preflight(file: String, staged: Bool = false, at repoPath: String, config: LargeFileModeConfig = .default) async throws -> DiffPreflightStats {
        os_signpost(.begin, log: Self.signpostLog, name: "Preflight", signpostID: parseSignpost)
        defer { os_signpost(.end, log: Self.signpostLog, name: "Preflight", signpostID: parseSignpost) }

        // Get numstat for additions/deletions
        var args = ["diff", "--numstat"]
        if staged {
            args.append("--cached")
        }
        args.append("--")
        args.append(file)

        let result = await shellExecutor.execute("git", arguments: args, workingDirectory: repoPath)

        var additions = 0
        var deletions = 0

        if result.exitCode == 0 {
            let parts = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\t")
            if parts.count >= 2 {
                additions = Int(parts[0]) ?? 0
                deletions = Int(parts[1]) ?? 0
            }
        }

        // Get file size
        let fullPath = URL(fileURLWithPath: repoPath).appendingPathComponent(file).path
        let fileSize = try? FileManager.default.attributesOfItem(atPath: fullPath)[.size] as? Int

        let estimatedLines = additions + deletions

        // Determine if LFM should be activated
        let isLargeFile = (fileSize ?? 0) > config.fileSizeThreshold ||
                          estimatedLines > config.linesThreshold

        var suggestedOptions = DiffOptions.default
        if isLargeFile {
            suggestedOptions = .largeFile
            suggestedOptions.lfmConfig = config
        }

        return DiffPreflightStats(
            additions: additions,
            deletions: deletions,
            estimatedLines: estimatedLines,
            fileSizeBytes: fileSize,
            isLargeFile: isLargeFile,
            suggestedOptions: suggestedOptions
        )
    }

    // MARK: - Streaming Diff

    /// Stream diff hunks for a file
    public func diff(
        file: String,
        staged: Bool = false,
        at repoPath: String,
        options: DiffOptions = .default
    ) -> AsyncThrowingStream<StreamingDiffHunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    os_signpost(.begin, log: Self.signpostLog, name: "ParseDiff", signpostID: self.parseSignpost)
                    defer { os_signpost(.end, log: Self.signpostLog, name: "ParseDiff", signpostID: self.parseSignpost) }

                    // Check cache first
                    let cacheKey = "\(repoPath):\(file):\(staged)"
                    if let cached = self.hunkCache.get(key: cacheKey) {
                        for hunk in cached {
                            continuation.yield(hunk)
                        }
                        continuation.finish()
                        return
                    }

                    // Build git diff command
                    var args = ["diff", "--no-color", "--no-ext-diff", "--unified=\(options.contextLines)"]
                    if staged {
                        args.append("--cached")
                    }

                    // In LFM, avoid expensive options
                    let useLFM = options.largeFileMode == .forceOn ||
                                 (options.largeFileMode == .auto && await self.shouldUseLFM(file: file, staged: staged, at: repoPath, config: options.lfmConfig))

                    if useLFM {
                        args.append("--no-renames")
                    }

                    args.append("--")
                    args.append(file)

                    // Execute and parse
                    let result = await self.shellExecutor.execute("git", arguments: args, workingDirectory: repoPath)

                    guard result.exitCode == 0 else {
                        continuation.finish(throwing: GitError.commandFailed("git diff", result.stderr))
                        return
                    }

                    // Parse hunks
                    let hunks = self.parseHunksFromOutput(result.stdout, materializeLines: !useLFM)

                    // Cache the results
                    let cost = result.stdout.utf8.count
                    self.hunkCache.set(key: cacheKey, value: hunks, cost: cost)

                    // Yield hunks
                    for hunk in hunks {
                        if Task.isCancelled {
                            continuation.finish(throwing: CancellationError())
                            return
                        }
                        continuation.yield(hunk)
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Materialization

    /// Materialize lines for a specific hunk (for LFM lazy loading)
    public func materialize(
        hunk: StreamingDiffHunk,
        rawDiffData: Data,
        range: Range<Int>? = nil
    ) async throws -> [DiffLine] {
        os_signpost(.begin, log: Self.signpostLog, name: "Materialize", signpostID: parseSignpost)
        defer { os_signpost(.end, log: Self.signpostLog, name: "Materialize", signpostID: parseSignpost) }

        guard let byteRange = hunk.byteRange else {
            return hunk.lines ?? []
        }

        // Extract the relevant bytes
        let startIndex = rawDiffData.index(rawDiffData.startIndex, offsetBy: byteRange.lowerBound)
        let endIndex = rawDiffData.index(rawDiffData.startIndex, offsetBy: min(byteRange.upperBound, rawDiffData.count))
        let hunkData = rawDiffData[startIndex..<endIndex]

        guard let hunkString = String(data: hunkData, encoding: .utf8) else {
            throw DiffEngineError.invalidEncoding
        }

        return parseLines(from: hunkString, startingOldLine: hunk.oldStart, startingNewLine: hunk.newStart)
    }

    // MARK: - Stats

    /// Get diff stats for a file
    public func stats(file: String, staged: Bool = false, at repoPath: String) async throws -> DiffStats {
        let preflight = try await preflight(file: file, staged: staged, at: repoPath)
        return DiffStats(
            additions: preflight.additions,
            deletions: preflight.deletions,
            filesChanged: 1
        )
    }

    // MARK: - Private Helpers

    private func shouldUseLFM(file: String, staged: Bool, at repoPath: String, config: LargeFileModeConfig) async -> Bool {
        do {
            let preflight = try await preflight(file: file, staged: staged, at: repoPath, config: config)
            return preflight.isLargeFile
        } catch {
            return false
        }
    }

    private func parseHunksFromOutput(_ output: String, materializeLines: Bool) -> [StreamingDiffHunk] {
        var hunks: [StreamingDiffHunk] = []
        var currentLines: [DiffLine] = []
        var currentHeader: HunkHeaderInfo?
        var currentByteStart = 0
        var oldLineNum = 0
        var newLineNum = 0

        let lines = output.components(separatedBy: "\n")
        var lineIndex = 0
        var byteOffset = 0

        for line in lines {
            defer {
                byteOffset += line.utf8.count + 1 // +1 for newline
                lineIndex += 1
            }

            // Skip file headers
            if line.hasPrefix("diff --git") || line.hasPrefix("index ") ||
               line.hasPrefix("--- ") || line.hasPrefix("+++ ") ||
               line.hasPrefix("new file") || line.hasPrefix("deleted file") {
                continue
            }

            // Parse hunk header
            if line.hasPrefix("@@") {
                // Save previous hunk
                if let header = currentHeader {
                    let hunk = StreamingDiffHunk(
                        header: header.header,
                        oldStart: header.oldStart,
                        oldLines: header.oldLines,
                        newStart: header.newStart,
                        newLines: header.newLines,
                        byteRange: materializeLines ? nil : currentByteStart..<byteOffset,
                        estimatedLineCount: currentLines.count,
                        isCollapsed: !materializeLines,
                        lines: materializeLines ? currentLines : nil
                    )
                    hunks.append(hunk)
                    currentLines = []
                }

                // Parse new hunk header: @@ -a,b +c,d @@
                if let headerInfo = parseHunkHeader(line) {
                    currentHeader = headerInfo
                    oldLineNum = headerInfo.oldStart
                    newLineNum = headerInfo.newStart
                    currentByteStart = byteOffset
                }
                continue
            }

            // Parse content lines
            guard currentHeader != nil else { continue }

            let diffLine: DiffLine
            if line.hasPrefix("+") {
                diffLine = DiffLine(
                    type: .addition,
                    content: String(line.dropFirst()),
                    oldLineNumber: nil,
                    newLineNumber: newLineNum
                )
                newLineNum += 1
            } else if line.hasPrefix("-") {
                diffLine = DiffLine(
                    type: .deletion,
                    content: String(line.dropFirst()),
                    oldLineNumber: oldLineNum,
                    newLineNumber: nil
                )
                oldLineNum += 1
            } else if line.hasPrefix(" ") {
                diffLine = DiffLine(
                    type: .context,
                    content: String(line.dropFirst()),
                    oldLineNumber: oldLineNum,
                    newLineNumber: newLineNum
                )
                oldLineNum += 1
                newLineNum += 1
            } else if line.hasPrefix("\\") {
                // "\ No newline at end of file"
                diffLine = DiffLine(
                    type: .context,
                    content: line,
                    oldLineNumber: nil,
                    newLineNumber: nil
                )
            } else {
                continue
            }

            currentLines.append(diffLine)
        }

        // Don't forget the last hunk
        if let header = currentHeader {
            let hunk = StreamingDiffHunk(
                header: header.header,
                oldStart: header.oldStart,
                oldLines: header.oldLines,
                newStart: header.newStart,
                newLines: header.newLines,
                byteRange: materializeLines ? nil : currentByteStart..<byteOffset,
                estimatedLineCount: currentLines.count,
                isCollapsed: !materializeLines,
                lines: materializeLines ? currentLines : nil
            )
            hunks.append(hunk)
        }

        return hunks
    }

    private func parseHunkHeader(_ line: String) -> HunkHeaderInfo? {
        // Format: @@ -oldStart,oldLines +newStart,newLines @@ optional context
        let pattern = #"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
            return nil
        }

        func extractInt(_ range: NSRange) -> Int? {
            guard range.location != NSNotFound,
                  let swiftRange = Range(range, in: line) else { return nil }
            return Int(line[swiftRange])
        }

        let oldStart = extractInt(match.range(at: 1)) ?? 0
        let oldLines = extractInt(match.range(at: 2)) ?? 1
        let newStart = extractInt(match.range(at: 3)) ?? 0
        let newLines = extractInt(match.range(at: 4)) ?? 1

        return HunkHeaderInfo(
            oldStart: oldStart,
            oldLines: oldLines,
            newStart: newStart,
            newLines: newLines,
            header: line
        )
    }

    private func parseLines(from hunkContent: String, startingOldLine: Int, startingNewLine: Int) -> [DiffLine] {
        var lines: [DiffLine] = []
        var oldLineNum = startingOldLine
        var newLineNum = startingNewLine

        for line in hunkContent.components(separatedBy: "\n") {
            if line.isEmpty { continue }

            let diffLine: DiffLine
            if line.hasPrefix("+") {
                diffLine = DiffLine(
                    type: .addition,
                    content: String(line.dropFirst()),
                    oldLineNumber: nil,
                    newLineNumber: newLineNum
                )
                newLineNum += 1
            } else if line.hasPrefix("-") {
                diffLine = DiffLine(
                    type: .deletion,
                    content: String(line.dropFirst()),
                    oldLineNumber: oldLineNum,
                    newLineNumber: nil
                )
                oldLineNum += 1
            } else if line.hasPrefix(" ") {
                diffLine = DiffLine(
                    type: .context,
                    content: String(line.dropFirst()),
                    oldLineNumber: oldLineNum,
                    newLineNumber: newLineNum
                )
                oldLineNum += 1
                newLineNum += 1
            } else if line.hasPrefix("@@") {
                continue // Skip hunk headers in content
            } else {
                diffLine = DiffLine(
                    type: .context,
                    content: line,
                    oldLineNumber: nil,
                    newLineNumber: nil
                )
            }

            lines.append(diffLine)
        }

        return lines
    }

    // MARK: - Cache Management

    /// Clear the diff cache
    public func clearCache() {
        hunkCache.clear()
    }

    /// Get cache statistics
    public func cacheStats() -> (entries: Int, bytesUsed: Int) {
        return hunkCache.stats()
    }
}

// MARK: - Errors

public enum DiffEngineError: Error, LocalizedError {
    case invalidEncoding
    case parseFailed(String)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .invalidEncoding:
            return "Failed to decode diff content as UTF-8"
        case .parseFailed(let reason):
            return "Failed to parse diff: \(reason)"
        case .cancelled:
            return "Diff operation was cancelled"
        }
    }
}

// MARK: - LRU Cache

/// Cost-based LRU cache for diff data
public final class DiffCache<Key: Hashable, Value>: @unchecked Sendable {
    private struct Entry {
        let value: Value
        let cost: Int
        var lastAccess: Date
    }

    private var cache: [Key: Entry] = [:]
    private var totalCost: Int = 0
    private let maxCostBytes: Int
    private let lock = NSLock()

    public init(maxCostBytes: Int) {
        self.maxCostBytes = maxCostBytes
    }

    public func get(key: Key) -> Value? {
        lock.lock()
        defer { lock.unlock() }

        guard var entry = cache[key] else { return nil }
        entry.lastAccess = Date()
        cache[key] = entry
        return entry.value
    }

    public func set(key: Key, value: Value, cost: Int) {
        lock.lock()
        defer { lock.unlock() }

        // Remove old entry if exists
        if let existing = cache[key] {
            totalCost -= existing.cost
        }

        // Evict if needed
        while totalCost + cost > maxCostBytes && !cache.isEmpty {
            evictLRU()
        }

        cache[key] = Entry(value: value, cost: cost, lastAccess: Date())
        totalCost += cost
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAll()
        totalCost = 0
    }

    public func stats() -> (entries: Int, bytesUsed: Int) {
        lock.lock()
        defer { lock.unlock() }
        return (cache.count, totalCost)
    }

    private func evictLRU() {
        guard let oldest = cache.min(by: { $0.value.lastAccess < $1.value.lastAccess }) else { return }
        totalCost -= oldest.value.cost
        cache.removeValue(forKey: oldest.key)
    }
}
