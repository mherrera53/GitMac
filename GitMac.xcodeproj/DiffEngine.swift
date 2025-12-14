import Foundation
import os.signpost

// MARK: - Performance Logging

private let diffLog = OSLog(subsystem: "com.gitmac", category: "diff")

// MARK: - Diff Engine

/// High-performance diff engine with streaming, LFM, and caching
actor DiffEngine {
    private let shellExecutor: ShellExecutor
    private let cache: DiffCache
    private let preferences: DiffPreferences
    
    init(shellExecutor: ShellExecutor = ShellExecutor(), cache: DiffCache = DiffCache()) {
        self.shellExecutor = shellExecutor
        self.cache = cache
        self.preferences = DiffPreferences.load()
    }
    
    // MARK: - Preflight
    
    /// Fast preflight check to gather statistics and determine if LFM should activate
    func preflight(file: String, at repoPath: String) async throws -> DiffPreflightStats {
        let signpostID = OSSignpostID(log: diffLog)
        os_signpost(.begin, log: diffLog, name: "diff.preflight", signpostID: signpostID,
                    "file=%{public}s", file)
        defer {
            os_signpost(.end, log: diffLog, name: "diff.preflight", signpostID: signpostID)
        }
        
        // Run git diff --numstat to get additions/deletions
        let result = await shellExecutor.execute(
            "git",
            arguments: ["diff", "--numstat", "--", file],
            workingDirectory: repoPath
        )
        
        guard result.exitCode == 0 else {
            throw GitError.commandFailed("git diff --numstat", result.stderr)
        }
        
        // Parse numstat output: "additions deletions filename"
        let parts = result.stdout.split(separator: "\t")
        guard parts.count >= 3 else {
            // Binary file or no changes
            return DiffPreflightStats(
                filePath: file,
                additions: 0,
                deletions: 0,
                fileSizeBytes: 0,
                maxLineLength: nil,
                estimatedHunkCount: nil
            )
        }
        
        let additions = Int(parts[0]) ?? 0
        let deletions = Int(parts[1]) ?? 0
        
        // Get file size (if possible)
        let fullPath = (repoPath as NSString).appendingPathComponent(file)
        let fileSize = try? FileManager.default.attributesOfItem(atPath: fullPath)[.size] as? Int ?? 0
        
        return DiffPreflightStats(
            filePath: file,
            additions: additions,
            deletions: deletions,
            fileSizeBytes: fileSize ?? 0,
            maxLineLength: nil,  // Could estimate from sample
            estimatedHunkCount: nil  // Could estimate from additions + deletions
        )
    }
    
    // MARK: - Streaming Diff
    
    /// Stream diff hunks incrementally with optional LFM
    func diff(
        file: String,
        at repoPath: String,
        options: DiffOptions
    ) -> AsyncThrowingStream<DiffHunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                let signpostID = OSSignpostID(log: diffLog)
                os_signpost(.begin, log: diffLog, name: "diff.stream", signpostID: signpostID,
                            "file=%{public}s", file)
                defer {
                    os_signpost(.end, log: diffLog, name: "diff.stream", signpostID: signpostID)
                }
                
                do {
                    // Determine if LFM should be active
                    let preflightStats = try await preflight(file: file, at: repoPath)
                    let lfmActive = options.largeFileMode.shouldActivate(for: preflightStats)
                    
                    if lfmActive {
                        os_signpost(.event, log: diffLog, name: "diff.lfm_activated",
                                    "lines=%d", preflightStats.totalChangedLines)
                    }
                    
                    // Get diff stream
                    var args = ["diff", "--no-color", "--no-ext-diff"]
                    args.append(contentsOf: options.gitArguments)
                    args.append("--")
                    args.append(file)
                    
                    let diffStream = shellExecutor.executeStreaming(
                        "git",
                        arguments: args,
                        workingDirectory: repoPath,
                        bufferSize: lfmActive ? 100 : 50  // Larger buffer in LFM
                    )
                    
                    // Parse stream with state machine
                    let parser = DiffStreamParser(lfmActive: lfmActive)
                    
                    for try await hunk in parser.parse(stream: diffStream) {
                        // Check for cancellation
                        try Task.checkCancellation()
                        
                        // Yield hunk
                        continuation.yield(hunk)
                        
                        os_signpost(.event, log: diffLog, name: "diff.hunk_parsed",
                                    "lines=%d", hunk.lines.count)
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
    
    // MARK: - Materialization
    
    /// Materialize lines from a hunk (on-demand for LFM)
    func materialize(
        hunk: DiffHunk,
        rangeInHunk: Range<Int>? = nil,
        file: String,
        at repoPath: String
    ) async throws -> [DiffLine] {
        let signpostID = OSSignpostID(log: diffLog)
        os_signpost(.begin, log: diffLog, name: "diff.materialize", signpostID: signpostID,
                    "hunk_id=%{public}s", hunk.id.uuidString)
        defer {
            os_signpost(.end, log: diffLog, name: "diff.materialize", signpostID: signpostID)
        }
        
        // Check cache first
        if let cached = await cache.getHunk(repoPath: repoPath, filePath: file, hunkID: hunk.id),
           let materializedLines = cached.materializedLines {
            // Return requested range or all
            if let range = rangeInHunk {
                let start = max(0, range.lowerBound)
                let end = min(materializedLines.count, range.upperBound)
                return Array(materializedLines[start..<end])
            }
            return materializedLines
        }
        
        // Materialize from hunk
        // In a real implementation with byte offsets, we'd read from the buffer
        // For now, we already have materialized lines in the hunk
        let lines = hunk.lines
        
        // Cache for future use
        await cache.setHunk(
            repoPath: repoPath,
            filePath: file,
            hunk: hunk,
            materializedLines: lines
        )
        
        // Return requested range or all
        if let range = rangeInHunk {
            let start = max(0, range.lowerBound)
            let end = min(lines.count, range.upperBound)
            return Array(lines[start..<end])
        }
        
        return lines
    }
    
    // MARK: - Stats
    
    /// Get diff statistics (fast, uses numstat)
    func stats(file: String, at repoPath: String) async throws -> DiffStats {
        let preflight = try await self.preflight(file: file, at: repoPath)
        
        return DiffStats(
            additions: preflight.additions,
            deletions: preflight.deletions,
            filesChanged: 1
        )
    }
    
    // MARK: - Cache Management
    
    /// Get cache statistics
    func cacheStats() async -> CacheStats {
        await cache.stats()
    }
    
    /// Clear cache
    func clearCache() async {
        await cache.clear()
    }
}

// MARK: - Diff Stream Parser

/// Streaming parser for git diff output with state machine
private actor DiffStreamParser {
    private let lfmActive: Bool
    
    private enum ParserState {
        case initial
        case fileHeader
        case hunkHeader
        case lines
    }
    
    init(lfmActive: Bool) {
        self.lfmActive = lfmActive
    }
    
    func parse(stream: AsyncThrowingStream<String, Error>) -> AsyncThrowingStream<DiffHunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var state: ParserState = .initial
                var currentHunkHeader: String?
                var currentHunkLines: [DiffLine] = []
                var oldStart = 0
                var oldLines = 0
                var newStart = 0
                var newLines = 0
                var oldLineNum = 0
                var newLineNum = 0
                
                do {
                    for try await line in stream {
                        // Check for cancellation
                        try Task.checkCancellation()
                        
                        // State machine
                        if line.hasPrefix("diff --git") {
                            // Emit previous hunk if any
                            if let header = currentHunkHeader, !currentHunkLines.isEmpty {
                                let hunk = DiffHunk(
                                    header: header,
                                    oldStart: oldStart,
                                    oldLines: oldLines,
                                    newStart: newStart,
                                    newLines: newLines,
                                    lines: currentHunkLines
                                )
                                continuation.yield(hunk)
                                currentHunkLines = []
                                currentHunkHeader = nil
                            }
                            
                            state = .fileHeader
                        } else if line.hasPrefix("@@") {
                            // Emit previous hunk if any
                            if let header = currentHunkHeader, !currentHunkLines.isEmpty {
                                let hunk = DiffHunk(
                                    header: header,
                                    oldStart: oldStart,
                                    oldLines: oldLines,
                                    newStart: newStart,
                                    newLines: newLines,
                                    lines: currentHunkLines
                                )
                                continuation.yield(hunk)
                            }
                            
                            // Parse hunk header: @@ -oldStart,oldLines +newStart,newLines @@
                            currentHunkHeader = line
                            currentHunkLines = []
                            
                            if let parsed = parseHunkHeader(line) {
                                oldStart = parsed.oldStart
                                oldLines = parsed.oldLines
                                newStart = parsed.newStart
                                newLines = parsed.newLines
                                oldLineNum = oldStart
                                newLineNum = newStart
                            }
                            
                            state = .lines
                        } else if state == .lines {
                            // Parse diff line
                            let type: DiffLineType
                            var content = line
                            var oldNum: Int? = nil
                            var newNum: Int? = nil
                            
                            if line.hasPrefix("+") {
                                type = .addition
                                content = String(line.dropFirst())
                                newNum = newLineNum
                                newLineNum += 1
                            } else if line.hasPrefix("-") {
                                type = .deletion
                                content = String(line.dropFirst())
                                oldNum = oldLineNum
                                oldLineNum += 1
                            } else if line.hasPrefix(" ") {
                                type = .context
                                content = String(line.dropFirst())
                                oldNum = oldLineNum
                                newNum = newLineNum
                                oldLineNum += 1
                                newLineNum += 1
                            } else if line.hasPrefix("\\") {
                                // "\ No newline at end of file" - skip
                                continue
                            } else {
                                type = .context
                                oldNum = oldLineNum
                                newNum = newLineNum
                                oldLineNum += 1
                                newLineNum += 1
                            }
                            
                            let diffLine = DiffLine(
                                type: type,
                                content: content,
                                oldLineNumber: oldNum,
                                newLineNumber: newNum
                            )
                            
                            currentHunkLines.append(diffLine)
                        }
                    }
                    
                    // Emit final hunk if any
                    if let header = currentHunkHeader, !currentHunkLines.isEmpty {
                        let hunk = DiffHunk(
                            header: header,
                            oldStart: oldStart,
                            oldLines: oldLines,
                            newStart: newStart,
                            newLines: newLines,
                            lines: currentHunkLines
                        )
                        continuation.yield(hunk)
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
    
    private func parseHunkHeader(_ line: String) -> (oldStart: Int, oldLines: Int, newStart: Int, newLines: Int)? {
        // Parse: @@ -oldStart,oldLines +newStart,newLines @@
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
        
        return (oldStart, oldLines, newStart, newLines)
    }
}
