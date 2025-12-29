import Testing
import Foundation
@testable import GitMac

// MARK: - Diff Engine Tests

@Suite("DiffEngine Streaming Parser Tests")
struct DiffEngineTests {
    
    @Test("Parse simple unified diff")
    func testSimpleDiffParsing() async throws {
        let sampleDiff = """
        diff --git a/test.swift b/test.swift
        index 1234567..abcdefg 100644
        --- a/test.swift
        +++ b/test.swift
        @@ -1,5 +1,6 @@
         import Foundation
         
        -let oldValue = 42
        +let newValue = 100
        +let extraLine = true
         
         print("done")
        """
        
        let lines = sampleDiff.split(separator: "\n").map(String.init)
        let lineStream = AsyncThrowingStream<String, Error> { continuation in
            for line in lines {
                continuation.yield(line)
            }
            continuation.finish()
        }
        
        let parser = DiffStreamParser(options: .default)
        var hunks: [DiffHunk] = []
        
        for await hunk in try await parser.parse(lineStream: lineStream) {
            hunks.append(hunk)
        }
        
        #expect(hunks.count == 1)
        
        let hunk = hunks[0]
        #expect(hunk.oldStart == 1)
        #expect(hunk.oldLines == 5)
        #expect(hunk.newStart == 1)
        #expect(hunk.newLines == 6)
        #expect(hunk.lines.count == 5)
        
        // Check line types
        #expect(hunk.lines[0].type == .context)
        #expect(hunk.lines[1].type == .context)
        #expect(hunk.lines[2].type == .deletion)
        #expect(hunk.lines[3].type == .addition)
        #expect(hunk.lines[4].type == .addition)
    }
    
    @Test("Parse multiple hunks")
    func testMultipleHunks() async throws {
        let sampleDiff = """
        diff --git a/test.swift b/test.swift
        @@ -1,3 +1,3 @@
         line 1
        -line 2
        +line 2 modified
         line 3
        @@ -10,3 +10,4 @@
         line 10
        +line 10.5
         line 11
         line 12
        """
        
        let lines = sampleDiff.split(separator: "\n").map(String.init)
        let lineStream = AsyncThrowingStream<String, Error> { continuation in
            for line in lines {
                continuation.yield(line)
            }
            continuation.finish()
        }
        
        let parser = DiffStreamParser(options: .default)
        var hunks: [DiffHunk] = []
        
        for await hunk in try await parser.parse(lineStream: lineStream) {
            hunks.append(hunk)
        }
        
        #expect(hunks.count == 2)
        
        let hunk1 = hunks[0]
        #expect(hunk1.oldStart == 1)
        #expect(hunk1.lines.count == 3)
        
        let hunk2 = hunks[1]
        #expect(hunk2.oldStart == 10)
        #expect(hunk2.lines.count == 4)
    }
    
    @Test("Handle UTF-8 multibyte characters")
    func testUTF8Handling() async throws {
        let sampleDiff = """
        @@ -1,2 +1,2 @@
        -Hola mundo 🌍
        +Hola 世界 🚀
         Final line
        """
        
        let lines = sampleDiff.split(separator: "\n").map(String.init)
        let lineStream = AsyncThrowingStream<String, Error> { continuation in
            for line in lines {
                continuation.yield(line)
            }
            continuation.finish()
        }
        
        let parser = DiffStreamParser(options: .default)
        var hunks: [DiffHunk] = []
        
        for await hunk in try await parser.parse(lineStream: lineStream) {
            hunks.append(hunk)
        }
        
        #expect(hunks.count == 1)
        #expect(hunks[0].lines[0].content == "Hola mundo 🌍")
        #expect(hunks[0].lines[1].content == "Hola 世界 🚀")
    }
}

// MARK: - Diff Cache Tests

@Suite("DiffCache LRU Tests")
struct DiffCacheTests {
    
    @Test("Basic cache operations")
    func testBasicCacheOperations() async throws {
        let cache = DiffCache(maxBytes: 10_000, maxEntries: 10)
        
        let hunk = DiffHunk(
            header: "@@ -1,1 +1,1 @@",
            oldStart: 1,
            oldLines: 1,
            newStart: 1,
            newLines: 1,
            lines: [
                DiffLine(type: .context, content: "test", oldLineNumber: 1, newLineNumber: 1)
            ]
        )
        
        let cached = CachedHunk(hunk: hunk, materializedLines: hunk.lines, fileKey: "test.swift")
        
        // Set
        await cache.set("key1", hunk: cached)
        
        // Get (hit)
        let retrieved = await cache.get("key1")
        #expect(retrieved != nil)
        #expect(retrieved?.hunk.header == hunk.header)
        
        // Stats
        let stats = await cache.stats()
        #expect(stats.hits == 1)
        #expect(stats.misses == 0)
        #expect(stats.entries == 1)
    }
    
    @Test("LRU eviction by byte budget")
    func testLRUEvictionByBytes() async throws {
        let cache = DiffCache(maxBytes: 1000, maxEntries: 100)
        
        // Add entries until we exceed budget
        for i in 0..<10 {
            let content = String(repeating: "x", count: 200)  // 200 bytes each
            let hunk = DiffHunk(
                header: "@@ -1,1 +1,1 @@",
                oldStart: 1,
                oldLines: 1,
                newStart: 1,
                newLines: 1,
                lines: [
                    DiffLine(type: .context, content: content, oldLineNumber: 1, newLineNumber: 1)
                ]
            )
            let cached = CachedHunk(hunk: hunk, materializedLines: hunk.lines, fileKey: "test.swift")
            await cache.set("key\(i)", hunk: cached)
        }
        
        let stats = await cache.stats()
        
        // Should have evicted some entries to stay under budget
        #expect(stats.entries < 10)
        #expect(stats.evictions > 0)
        #expect(stats.totalBytes <= 1000)
    }
    
    @Test("LRU ordering")
    func testLRUOrdering() async throws {
        let cache = DiffCache(maxBytes: 500, maxEntries: 3)
        
        // Add 3 entries
        for i in 1...3 {
            let hunk = DiffHunk(
                header: "@@ -\(i),1 +\(i),1 @@",
                oldStart: i,
                oldLines: 1,
                newStart: i,
                newLines: 1,
                lines: [
                    DiffLine(type: .context, content: String(repeating: "x", count: 100), oldLineNumber: i, newLineNumber: i)
                ]
            )
            let cached = CachedHunk(hunk: hunk, materializedLines: hunk.lines, fileKey: "test.swift")
            await cache.set("key\(i)", hunk: cached)
        }
        
        // Access key1 (make it most recently used)
        _ = await cache.get("key1")
        
        // Add key4 (should evict key2, the LRU)
        let hunk4 = DiffHunk(
            header: "@@ -4,1 +4,1 @@",
            oldStart: 4,
            oldLines: 1,
            newStart: 4,
            newLines: 1,
            lines: [
                DiffLine(type: .context, content: String(repeating: "x", count: 100), oldLineNumber: 4, newLineNumber: 4)
            ]
        )
        let cached4 = CachedHunk(hunk: hunk4, materializedLines: hunk4.lines, fileKey: "test.swift")
        await cache.set("key4", hunk: cached4)
        
        // key2 should be evicted
        let key2 = await cache.get("key2")
        #expect(key2 == nil)
        
        // key1 and key3 should still exist
        let key1 = await cache.get("key1")
        let key3 = await cache.get("key3")
        #expect(key1 != nil)
        #expect(key3 != nil)
    }
}

// MARK: - Diff Options Tests

@Suite("DiffOptions and LFM Tests")
struct DiffOptionsTests {
    
    @Test("LFM threshold detection")
    func testLFMThresholds() throws {
        let thresholds = LFMThresholds.default
        
        // Should NOT activate for small file
        let smallStats = DiffPreflightStats(
            additions: 100,
            deletions: 50,
            patchSizeBytes: 10_000,
            estimatedLines: 150,
            maxLineLength: 100,
            hunkCount: 5
        )
        #expect(!thresholds.shouldActivateLFM(stats: smallStats))
        
        // SHOULD activate for large file (by lines)
        let largeByLines = DiffPreflightStats(
            additions: 30_000,
            deletions: 25_000,
            patchSizeBytes: 1_000_000,
            estimatedLines: 55_000,
            maxLineLength: 100,
            hunkCount: 100
        )
        #expect(thresholds.shouldActivateLFM(stats: largeByLines))
        
        // SHOULD activate for long lines
        let longLines = DiffPreflightStats(
            additions: 100,
            deletions: 50,
            patchSizeBytes: 100_000,
            estimatedLines: 150,
            maxLineLength: 3_000,
            hunkCount: 5
        )
        #expect(thresholds.shouldActivateLFM(stats: longLines))
        
        // SHOULD activate for many hunks
        let manyHunks = DiffPreflightStats(
            additions: 500,
            deletions: 500,
            patchSizeBytes: 100_000,
            estimatedLines: 1_000,
            maxLineLength: 100,
            hunkCount: 1_500
        )
        #expect(thresholds.shouldActivateLFM(stats: manyHunks))
    }
    
    @Test("Diff preferences persistence")
    func testDiffPreferencesPersistence() throws {
        let defaults = UserDefaults.standard
        
        // Set custom preferences
        var prefs = DiffPreferences.default
        prefs.defaultContextLines = 5
        prefs.enableWordDiffOnDemand = false
        prefs.setLfmOverride(for: "large.txt", enabled: true)
        
        defaults.diffPreferences = prefs
        
        // Retrieve
        let retrieved = defaults.diffPreferences
        #expect(retrieved.defaultContextLines == 5)
        #expect(retrieved.enableWordDiffOnDemand == false)
        #expect(retrieved.lfmOverride(for: "large.txt") == true)
        
        // Clean up
        defaults.removeObject(forKey: "com.gitmac.diffPreferences")
    }
}
