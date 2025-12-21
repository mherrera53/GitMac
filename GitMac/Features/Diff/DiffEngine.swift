import Foundation
import os.signpost

// MARK: - Performance Logging

private let diffLog = OSLog(subsystem: "com.gitmac", category: "diff")

// MARK: - Diff Engine

/// High-performance diff engine with streaming parser and on-demand materialization
actor DiffEngine {
    private let shellExecutor: ShellExecutor
    private let cache: DiffCache
    
    init(shellExecutor: ShellExecutor = ShellExecutor(), cacheSize: Int = 50_000_000) {
        self.shellExecutor = shellExecutor
        self.cache = DiffCache(maxBytes: cacheSize)
    }
    
    // MARK: - Public API
    
    /// Get preflight statistics for a diff (fast, uses --numstat)
    func stats(file: String, at repoPath: String, staged: Bool = false) async throws -> DiffPreflightStats {
        let signpostID = OSSignpostID(log: diffLog)
        os_signpost(.begin, log: diffLog, name: "diff.preflight", signpostID: signpostID, "file=%{public}s", file)
        
        defer {
            os_signpost(.end, log: diffLog, name: "diff.preflight", signpostID: signpostID)
        }
        
        var args = ["diff", "--numstat"]
        if staged {
            args.append("--cached")
        }
        args.append("--")
        args.append(file)
        
        let result = await shellExecutor.execute("git", arguments: args, workingDirectory: repoPath)
        
        guard result.exitCode == 0 else {
            throw DiffError.preflightFailed(result.stderr)
        }
        
        // Get patch size estimate
        let patchResult = await shellExecutor.execute(
            "git",
            arguments: staged ? ["diff", "--cached", "--", file] : ["diff", "--", file],
            workingDirectory: repoPath
        )
        
        let patchSize = patchResult.stdout.utf8.count
        
        // Estimate hunk count and max line length from patch
        let (hunkCount, maxLineLength) = estimatePatchComplexity(patchResult.stdout)
        
        return DiffPreflightStats.from(
            numstatLine: result.stdout,
            patchSize: patchSize,
            hunkCount: hunkCount,
            maxLineLength: maxLineLength
        )
    }
    
    /// Stream diff hunks incrementally
    func diff(
        file: String,
        at repoPath: String,
        options: DiffOptions
    ) async throws -> AsyncThrowingStream<DiffHunk, Error> {
        let signpostID = OSSignpostID(log: diffLog)
        os_signpost(.begin, log: diffLog, name: "diff.stream", signpostID: signpostID, "file=%{public}s", file)
        
        // Build git diff arguments
        var args = ["diff", "--no-color", "--no-ext-diff", "--unified=\(options.contextLines)"]
        
        if options.noRenames {
            args.append("--no-renames")
        }
        
        // Note: --word-diff is handled separately in materialize() for performance
        
        args.append("--")
        args.append(file)
        
        let lineStream = shellExecutor.executeStreaming(
            "git",
            arguments: args,
            workingDirectory: repoPath,
            bufferSize: 100
        )
        
        return AsyncThrowingStream { continuation in
            Task {
                defer {
                    os_signpost(.end, log: diffLog, name: "diff.stream", signpostID: signpostID)
                    continuation.finish()
                }
                
                do {
                    let parser = DiffStreamParser(options: options)
                    
                    for try await hunk in parser.parse(lineStream: lineStream) {
                        // Check for cancellation
                        if Task.isCancelled {
                            continuation.finish()
                            return
                        }
                        
                        continuation.yield(hunk)
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    /// Materialize a hunk (convert byte offsets to actual DiffLine objects)
    func materialize(
        hunk: DiffHunk,
        rangeInHunk: Range<Int>? = nil
    ) async throws -> [DiffLine] {
        let signpostID = OSSignpostID(log: diffLog)
        os_signpost(.begin, log: diffLog, name: "diff.materialize", signpostID: signpostID)
        
        defer {
            os_signpost(.end, log: diffLog, name: "diff.materialize", signpostID: signpostID)
        }
        
        // If already materialized, just return the lines (or range)
        if hunk.byteOffsets == nil {
            if let range = rangeInHunk {
                let safeRange = max(0, range.lowerBound)..<min(hunk.lines.count, range.upperBound)
                return Array(hunk.lines[safeRange])
            } else {
                return hunk.lines
            }
        }
        
        // TODO: Implement actual byte-offset materialization from stored data
        // For now, return empty array as this is a skeleton
        return []
    }
    
    /// Get cache statistics
    func cacheStats() async -> CacheStats {
        await cache.stats()
    }
    
    /// Clear cache for a specific file
    func clearCache(file: String, staged: Bool = false) async {
        await cache.removeFile(file, staged: staged)
    }
    
    // MARK: - Private Helpers
    
    private func estimatePatchComplexity(_ patchOutput: String) -> (hunkCount: Int, maxLineLength: Int) {
        var hunkCount = 0
        var maxLineLength = 0
        
        for line in patchOutput.split(separator: "\n") {
            if line.starts(with: "@@") {
                hunkCount += 1
            }
            maxLineLength = max(maxLineLength, line.count)
        }
        
        return (hunkCount, maxLineLength)
    }
}

// MARK: - Diff Stream Parser

/// Streaming parser for git diff output using a state machine
struct DiffStreamParser {
    private let options: DiffOptions
    
    init(options: DiffOptions) {
        self.options = options
    }
    
    /// Parse a stream of lines into hunks
    func parse(lineStream: AsyncThrowingStream<String, Error>) async throws -> AsyncStream<DiffHunk> {
        AsyncStream { continuation in
            Task {
                var state = ParserState.initial
                var currentHunk: PartialHunk?
                var currentLines: [DiffLine] = []
                var oldLineNum = 0
                var newLineNum = 0
                
                do {
                    for try await line in lineStream {
                        // Check for cancellation
                        if Task.isCancelled {
                            continuation.finish()
                            return
                        }
                        
                        // State machine
                        switch state {
                        case .initial, .fileHeader:
                            if line.starts(with: "diff --git") {
                                state = .fileHeader
                            } else if line.starts(with: "@@") {
                                // Hunk header
                                if let hunk = parseHunkHeader(line) {
                                    // Finish previous hunk if exists
                                    if let prev = currentHunk {
                                        let completed = finishHunk(prev, lines: currentLines)
                                        continuation.yield(completed)
                                        currentLines.removeAll()
                                    }
                                    
                                    currentHunk = hunk
                                    oldLineNum = hunk.oldStart
                                    newLineNum = hunk.newStart
                                    state = .lines
                                }
                            }
                            
                        case .lines:
                            if line.starts(with: "@@") {
                                // New hunk
                                if let hunk = parseHunkHeader(line) {
                                    // Finish previous hunk
                                    if let prev = currentHunk {
                                        let completed = finishHunk(prev, lines: currentLines)
                                        continuation.yield(completed)
                                        currentLines.removeAll()
                                    }
                                    
                                    currentHunk = hunk
                                    oldLineNum = hunk.oldStart
                                    newLineNum = hunk.newStart
                                }
                            } else if line.starts(with: "+") {
                                // Addition
                                let content = String(line.dropFirst())
                                currentLines.append(DiffLine(
                                    type: .addition,
                                    content: content,
                                    oldLineNumber: nil,
                                    newLineNumber: newLineNum
                                ))
                                newLineNum += 1
                            } else if line.starts(with: "-") {
                                // Deletion
                                let content = String(line.dropFirst())
                                currentLines.append(DiffLine(
                                    type: .deletion,
                                    content: content,
                                    oldLineNumber: oldLineNum,
                                    newLineNumber: nil
                                ))
                                oldLineNum += 1
                            } else if line.starts(with: " ") {
                                // Context
                                let content = String(line.dropFirst())
                                currentLines.append(DiffLine(
                                    type: .context,
                                    content: content,
                                    oldLineNumber: oldLineNum,
                                    newLineNumber: newLineNum
                                ))
                                oldLineNum += 1
                                newLineNum += 1
                            } else if line.starts(with: "\\") {
                                // Special line (e.g., "\ No newline at end of file")
                                // Ignore for now
                            } else {
                                // Could be file header or empty line, ignore
                            }
                        }
                    }
                    
                    // Finish last hunk
                    if let last = currentHunk {
                        let completed = finishHunk(last, lines: currentLines)
                        continuation.yield(completed)
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish()
                }
            }
        }
    }
    
    private func parseHunkHeader(_ line: String) -> PartialHunk? {
        // Parse: @@ -oldStart,oldLines +newStart,newLines @@ ...
        let pattern = #"@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
            return nil
        }
        
        let oldStart = Int(line[Range(match.range(at: 1), in: line)!]) ?? 0
        let oldLines = match.range(at: 2).location != NSNotFound
            ? Int(line[Range(match.range(at: 2), in: line)!]) ?? 1
            : 1
        let newStart = Int(line[Range(match.range(at: 3), in: line)!]) ?? 0
        let newLines = match.range(at: 4).location != NSNotFound
            ? Int(line[Range(match.range(at: 4), in: line)!]) ?? 1
            : 1
        
        return PartialHunk(
            header: line,
            oldStart: oldStart,
            oldLines: oldLines,
            newStart: newStart,
            newLines: newLines
        )
    }
    
    private func finishHunk(_ partial: PartialHunk, lines: [DiffLine]) -> DiffHunk {
        DiffHunk(
            header: partial.header,
            oldStart: partial.oldStart,
            oldLines: partial.oldLines,
            newStart: partial.newStart,
            newLines: partial.newLines,
            lines: lines
        )
    }
}

// MARK: - Parser State

enum ParserState {
    case initial
    case fileHeader
    case lines
}

struct PartialHunk {
    let header: String
    let oldStart: Int
    let oldLines: Int
    let newStart: Int
    let newLines: Int
}

// MARK: - Diff Errors

enum DiffError: LocalizedError {
    case preflightFailed(String)
    case parsingFailed(String)
    case materializationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .preflightFailed(let message):
            return "Diff preflight failed: \(message)"
        case .parsingFailed(let message):
            return "Diff parsing failed: \(message)"
        case .materializationFailed(let message):
            return "Diff materialization failed: \(message)"
        }
    }
}
