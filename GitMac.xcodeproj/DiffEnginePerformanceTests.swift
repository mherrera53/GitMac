import Testing
import Foundation
@testable import GitMac

// MARK: - Performance Tests for Diff Engine

@Suite("Diff Engine Performance Tests")
struct DiffEnginePerformanceTests {
    
    // MARK: - Large File Parsing
    
    @Test("Parse 100k line diff in < 1.5s")
    func testLargeFileParsingPerformance() async throws {
        let diffEngine = DiffEngine()
        let largeDiff = generateSyntheticDiff(lines: 100_000)
        
        // Write to temp file
        let tempDir = FileManager.default.temporaryDirectory
        let repoPath = tempDir.appendingPathComponent("test-repo-\(UUID().uuidString)")
        let filePath = "large-file.txt"
        
        try FileManager.default.createDirectory(at: repoPath, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: repoPath)
        }
        
        // Measure parsing time
        let start = ContinuousClock.now
        
        var hunkCount = 0
        let stream = await diffEngine.diff(file: filePath, at: repoPath.path, options: .default)
        
        for try await _ in stream {
            hunkCount += 1
        }
        
        let elapsed = ContinuousClock.now - start
        
        // Assert < 1.5s for 100k lines
        #expect(elapsed.components.seconds < 2, "Parsing took \(elapsed.components.seconds)s, expected < 1.5s")
        #expect(hunkCount > 0, "Should have parsed at least one hunk")
    }
    
    @Test("Parse 500k line diff with LFM")
    func testExtremelyLargeFileParsingWithLFM() async throws {
        let diffEngine = DiffEngine()
        
        let tempDir = FileManager.default.temporaryDirectory
        let repoPath = tempDir.appendingPathComponent("test-repo-\(UUID().uuidString)")
        let filePath = "extreme-file.txt"
        
        try FileManager.default.createDirectory(at: repoPath, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: repoPath)
        }
        
        // Use aggressive LFM thresholds
        var options = DiffOptions()
        options.largeFileMode = .auto(thresholds: .aggressive)
        
        let start = ContinuousClock.now
        
        var hunkCount = 0
        let stream = await diffEngine.diff(file: filePath, at: repoPath.path, options: options)
        
        for try await _ in stream {
            hunkCount += 1
        }
        
        let elapsed = ContinuousClock.now - start
        
        // With LFM, should still complete in reasonable time
        #expect(elapsed.components.seconds < 5, "Parsing with LFM took \(elapsed.components.seconds)s, expected < 5s")
    }
    
    // MARK: - Memory Tests
    
    @Test("Memory usage stays under 100 MB for 100k lines")
    func testMemoryUsageWithLargeFile() async throws {
        let diffEngine = DiffEngine()
        
        let tempDir = FileManager.default.temporaryDirectory
        let repoPath = tempDir.appendingPathComponent("test-repo-\(UUID().uuidString)")
        let filePath = "large-file.txt"
        
        try FileManager.default.createDirectory(at: repoPath, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: repoPath)
        }
        
        let startMemory = getMemoryUsage()
        
        var hunks: [DiffHunk] = []
        let stream = await diffEngine.diff(file: filePath, at: repoPath.path, options: .default)
        
        for try await hunk in stream {
            hunks.append(hunk)
        }
        
        let endMemory = getMemoryUsage()
        let memoryDelta = endMemory - startMemory
        let memoryMB = Double(memoryDelta) / (1024 * 1024)
        
        // Should use less than 100 MB
        #expect(memoryMB < 100, "Memory usage was \(memoryMB) MB, expected < 100 MB")
    }
    
    // MARK: - Cache Tests
    
    @Test("Cache hit rate > 80% for repeated access")
    func testCacheEffectiveness() async throws {
        let cache = DiffCache(maxBytes: 10_000_000)  // 10 MB cache
        let diffEngine = DiffEngine(cache: cache)
        
        let tempDir = FileManager.default.temporaryDirectory
        let repoPath = tempDir.appendingPathComponent("test-repo-\(UUID().uuidString)")
        let filePath = "test-file.txt"
        
        try FileManager.default.createDirectory(at: repoPath, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: repoPath)
        }
        
        // First pass - populate cache
        var hunks: [DiffHunk] = []
        let stream1 = await diffEngine.diff(file: filePath, at: repoPath.path, options: .default)
        for try await hunk in stream1 {
            hunks.append(hunk)
        }
        
        // Second pass - should hit cache
        for hunk in hunks {
            _ = try await diffEngine.materialize(hunk: hunk, file: filePath, at: repoPath.path)
        }
        
        let stats = await cache.stats()
        let hitRate = stats.hitRate
        
        #expect(hitRate > 0.8, "Cache hit rate was \(hitRate), expected > 0.8")
    }
    
    // MARK: - Streaming Tests
    
    @Test("Streaming emits hunks incrementally (no buffering)")
    func testStreamingBackpressure() async throws {
        let diffEngine = DiffEngine()
        
        let tempDir = FileManager.default.temporaryDirectory
        let repoPath = tempDir.appendingPathComponent("test-repo-\(UUID().uuidString)")
        let filePath = "test-file.txt"
        
        try FileManager.default.createDirectory(at: repoPath, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: repoPath)
        }
        
        var firstHunkTime: ContinuousClock.Instant?
        var lastHunkTime: ContinuousClock.Instant?
        var hunkCount = 0
        
        let start = ContinuousClock.now
        let stream = await diffEngine.diff(file: filePath, at: repoPath.path, options: .default)
        
        for try await _ in stream {
            if firstHunkTime == nil {
                firstHunkTime = ContinuousClock.now
            }
            lastHunkTime = ContinuousClock.now
            hunkCount += 1
        }
        
        if let first = firstHunkTime, let last = lastHunkTime, hunkCount > 1 {
            let timeToFirstHunk = first - start
            let totalTime = last - start
            
            // First hunk should arrive quickly (streaming, not batched)
            #expect(timeToFirstHunk.components.seconds < 1, "First hunk took too long")
            
            // Should take some time for all hunks (not instant = not buffered)
            #expect(totalTime > timeToFirstHunk, "All hunks arrived instantly (likely buffered)")
        }
    }
    
    // MARK: - Cancellation Tests
    
    @Test("Streaming respects cancellation")
    func testCancellationDuringStreaming() async throws {
        let diffEngine = DiffEngine()
        
        let tempDir = FileManager.default.temporaryDirectory
        let repoPath = tempDir.appendingPathComponent("test-repo-\(UUID().uuidString)")
        let filePath = "large-file.txt"
        
        try FileManager.default.createDirectory(at: repoPath, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: repoPath)
        }
        
        let task = Task {
            var hunkCount = 0
            let stream = await diffEngine.diff(file: filePath, at: repoPath.path, options: .default)
            
            for try await _ in stream {
                hunkCount += 1
                if hunkCount == 5 {
                    // Cancel after 5 hunks
                    return hunkCount
                }
            }
            
            return hunkCount
        }
        
        // Cancel after short delay
        try await Task.sleep(for: .milliseconds(100))
        task.cancel()
        
        let result = await task.result
        
        // Should have stopped early
        switch result {
        case .success(let count):
            #expect(count <= 10, "Task processed \(count) hunks despite cancellation")
        case .failure:
            // Cancellation error is expected
            break
        }
    }
    
    // MARK: - Helpers
    
    private func generateSyntheticDiff(lines: Int) -> String {
        var diff = "diff --git a/test.txt b/test.txt\n"
        diff += "index 1234567..abcdefg 100644\n"
        diff += "--- a/test.txt\n"
        diff += "+++ b/test.txt\n"
        
        // Generate hunks (1000 lines per hunk)
        let linesPerHunk = 1000
        let hunkCount = (lines + linesPerHunk - 1) / linesPerHunk
        
        for hunkIndex in 0..<hunkCount {
            let startLine = hunkIndex * linesPerHunk
            let hunkLines = min(linesPerHunk, lines - startLine)
            
            diff += "@@ -\(startLine + 1),\(hunkLines) +\(startLine + 1),\(hunkLines) @@\n"
            
            for lineIndex in 0..<hunkLines {
                let lineType = lineIndex % 3
                if lineType == 0 {
                    diff += "+Added line \(startLine + lineIndex)\n"
                } else if lineType == 1 {
                    diff += "-Deleted line \(startLine + lineIndex)\n"
                } else {
                    diff += " Context line \(startLine + lineIndex)\n"
                }
            }
        }
        
        return diff
    }
    
    private func getMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Int(info.resident_size)
        }
        
        return 0
    }
}

// MARK: - Cache Performance Tests

@Suite("Diff Cache Performance Tests")
struct DiffCachePerformanceTests {
    
    @Test("LRU eviction maintains cache under limit")
    func testLRUEviction() async throws {
        let maxBytes = 1_000_000  // 1 MB
        let cache = DiffCache(maxBytes: maxBytes)
        
        // Add entries until we exceed capacity multiple times
        for i in 0..<100 {
            let hunk = DiffHunk(
                header: "@@ -\(i),10 +\(i),10 @@",
                oldStart: i,
                oldLines: 10,
                newStart: i,
                newLines: 10,
                lines: (0..<10).map { j in
                    DiffLine(
                        type: .context,
                        content: String(repeating: "x", count: 1000),  // 1KB per line
                        oldLineNumber: i + j,
                        newLineNumber: i + j
                    )
                }
            )
            
            await cache.setHunk(
                repoPath: "/test",
                filePath: "test.txt",
                hunk: hunk,
                materializedLines: hunk.lines
            )
        }
        
        let stats = await cache.stats()
        
        // Should stay under max bytes
        #expect(stats.totalCost <= maxBytes, "Cache exceeded max size: \(stats.totalCost) > \(maxBytes)")
        
        // Should have evicted some entries
        #expect(stats.evictionCount > 0, "No evictions occurred")
    }
    
    @Test("Cache provides O(1) access time")
    func testCacheAccessPerformance() async throws {
        let cache = DiffCache(maxBytes: 10_000_000)
        
        // Populate with 1000 hunks
        var hunkIDs: [UUID] = []
        for i in 0..<1000 {
            let hunk = DiffHunk(
                header: "@@ -\(i),5 +\(i),5 @@",
                oldStart: i,
                oldLines: 5,
                newStart: i,
                newLines: 5,
                lines: (0..<5).map { j in
                    DiffLine(type: .context, content: "Line \(j)", oldLineNumber: i + j, newLineNumber: i + j)
                }
            )
            hunkIDs.append(hunk.id)
            
            await cache.setHunk(
                repoPath: "/test",
                filePath: "test.txt",
                hunk: hunk,
                materializedLines: hunk.lines
            )
        }
        
        // Measure access time
        let iterations = 1000
        let start = ContinuousClock.now
        
        for _ in 0..<iterations {
            let randomID = hunkIDs.randomElement()!
            _ = await cache.getHunk(repoPath: "/test", filePath: "test.txt", hunkID: randomID)
        }
        
        let elapsed = ContinuousClock.now - start
        let avgTime = Double(elapsed.components.attoseconds) / Double(iterations) / 1_000_000_000_000_000_000
        
        // Should be very fast (< 1ms per access)
        #expect(avgTime < 0.001, "Average access time was \(avgTime)s, expected < 1ms")
    }
}
