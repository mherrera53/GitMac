import Testing
import Foundation
@testable import GitMac

private final class DiffFixture: @unchecked Sendable {
    let directory: URL
    let file = "file ñ.txt"
    init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("gitmac-diff-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    }
    deinit { try? FileManager.default.removeItem(at: directory) }
    func write(_ text: String) throws { try text.write(to: directory.appendingPathComponent(file), atomically: true, encoding: .utf8) }
    func git(_ arguments: [String]) async throws -> String {
        let result = await ShellExecutor.shared.execute("git", arguments: arguments, workingDirectory: directory.path)
        guard result.isSuccess else { throw GitError.commandFailed(arguments.joined(separator: " "), result.output) }
        return result.stdout
    }
    func baseline(_ text: String) async throws {
        _ = try await git(["init", "--quiet"])
        try write(text)
        _ = try await git(["add", "--", file])
        _ = try await git(["commit", "--quiet", "-m", "Fixture"])
    }
    func hunks(_ engine: DiffEngine, options: DiffOptions = .default) async throws -> [StreamingDiffHunk] {
        var hunks: [StreamingDiffHunk] = []
        for try await hunk in engine.diff(file: file, at: directory.path, options: options) { hunks.append(hunk) }
        return hunks
    }
}

@Suite("Production DiffEngine and Git oracle")
struct DiffEngineTests {
    @Test func unifiedParsing() async throws {
        let fixture = try DiffFixture()
        try await fixture.baseline("one\nbefore\nlast\n")
        try fixture.write("one\nafter\nextra\nlast\n")
        let hunks = try await fixture.hunks(DiffEngine())
        #expect(hunks.count == 1)
        let hunk = try #require(hunks.first)
        #expect(hunk.oldStart == 1 && hunk.oldLines == 3 && hunk.newStart == 1 && hunk.newLines == 4)
        #expect(hunk.lines?.map(\.type) == [.context, .deletion, .addition, .addition, .context])
    }
    @Test func multipleHunks() async throws {
        let fixture = try DiffFixture()
        let before = (1...20).map { "line \($0)" }
        try await fixture.baseline(before.joined(separator: "\n") + "\n")
        var after = before
        after[1] = "changed first"
        after[18] = "changed last"
        try fixture.write(after.joined(separator: "\n") + "\n")
        var options = DiffOptions.default
        options.contextLines = 1
        let hunks = try await fixture.hunks(DiffEngine(), options: options)
        #expect(hunks.count == 2)
        #expect(hunks.first?.oldStart == 1 && hunks.last?.oldStart == 18)
    }
    @Test func unicodeAndNoFinalNewline() async throws {
        let fixture = try DiffFixture()
        try await fixture.baseline("Hola 🌍")
        try fixture.write("Hola 世界 🚀")
        let hunks = try await fixture.hunks(DiffEngine())
        let lines = try #require(hunks.first?.lines)
        #expect(lines.contains { $0.content == "Hola 🌍" && $0.type == .deletion })
        #expect(lines.contains { $0.content == "Hola 世界 🚀" && $0.type == .addition })
        #expect(lines.contains { $0.content.contains("No newline") })
    }
    @Test func contentMustNotBeMistakenForFileHeaders() async throws {
        let fixture = try DiffFixture()
        try await fixture.baseline("-- before\n")
        try fixture.write("++ after\n")
        let hunks = try await fixture.hunks(DiffEngine())
        #expect(hunks.first?.lines?.contains { $0.type == .deletion && $0.content == "-- before" } == true)
        #expect(hunks.first?.lines?.contains { $0.type == .addition && $0.content == "++ after" } == true)
    }
    @Test func cacheInvalidatesAfterWorkingTreeChanges() async throws {
        let fixture = try DiffFixture()
        try await fixture.baseline("before\n")
        let engine = DiffEngine()
        try fixture.write("first\n")
        _ = try await fixture.hunks(engine)
        try fixture.write("second\n")
        let hunks = try await fixture.hunks(engine)
        #expect(hunks.first?.lines?.contains { $0.content == "second" && $0.type == .addition } == true)
        #expect(hunks.first?.lines?.contains { $0.content == "first" } == false)
    }
    @Test func contextAndLargeFileModeAreNotStaleCacheKeys() async throws {
        let fixture = try DiffFixture()
        try await fixture.baseline("one\ntwo\nthree\n")
        try fixture.write("one\nchanged\nthree\n")
        let engine = DiffEngine()
        _ = try await fixture.hunks(engine)
        var narrow = DiffOptions.default
        narrow.contextLines = 0
        let hunks = try await fixture.hunks(engine, options: narrow)
        #expect(hunks.first?.oldLines == 1 && hunks.first?.newLines == 1)
        narrow.largeFileMode = .forceOn
        let lazy = try await fixture.hunks(engine, options: narrow)
        #expect(lazy.first?.lines == nil && lazy.first?.byteRange != nil)
    }
    @Test func lazyMaterialization() async throws {
        let fixture = try DiffFixture()
        try await fixture.baseline("before\n")
        try fixture.write("after\n")
        var options = DiffOptions.default
        options.largeFileMode = .forceOn
        let engine = DiffEngine()
        let hunks = try await fixture.hunks(engine, options: options)
        let raw = try await fixture.git(["diff", "--no-color", "--no-ext-diff", "--unified=3", "--no-renames", "--", fixture.file])
        let lines = try await engine.materialize(hunk: #require(hunks.first), rawDiffData: Data(raw.utf8))
        #expect(lines.map(\.content) == ["before", "after"])
    }
    @Test func preflightDoesNotHideProcessFailure() async throws {
        let fixture = try DiffFixture()
        do {
            _ = try await DiffEngine().preflight(file: fixture.file, at: fixture.directory.path)
            Issue.record("Non-repository preflight must fail")
        } catch {}
    }
    @Test func invalidMaterializationRangeIsRejected() async throws {
        let hunk = StreamingDiffHunk(header: "@@ -1 +1 @@", oldStart: 1, oldLines: 1, newStart: 1, newLines: 1, byteRange: 100..<200)
        do {
            _ = try await DiffEngine().materialize(hunk: hunk, rawDiffData: Data("tiny".utf8))
            Issue.record("Invalid byte ranges must fail before indexing Data")
        } catch { #expect(error is DiffEngineError) }
    }
    @Test func thresholdsUseActualProductionConfiguration() async throws {
        let fixture = try DiffFixture()
        try await fixture.baseline("one\n")
        try fixture.write("one\ntwo\n")
        var threshold = LargeFileModeConfig.default
        threshold.fileSizeThreshold = 1
        let stats = try await DiffEngine().preflight(file: fixture.file, at: fixture.directory.path, config: threshold)
        #expect(stats.additions == 1 && stats.deletions == 0 && stats.isLargeFile)
        #expect(stats.suggestedOptions.largeFileMode == .forceOn)
    }
}

@Suite("Production diff cache budgets")
struct DiffCacheTests {
    private func cached(_ content: String) -> CachedHunk {
        let line = DiffLine(type: .context, content: content, oldLineNumber: 1, newLineNumber: 1)
        let hunk = DiffHunk(header: "@@ -1 +1 @@", oldStart: 1, oldLines: 1, newStart: 1, newLines: 1, lines: [line])
        return CachedHunk(hunk: hunk, materializedLines: [line], fileKey: "fixture")
    }
    @Test func hitAndMissStats() async {
        let cache = DiffCache(maxBytes: 10000, maxEntries: 3)
        await cache.set("one", hunk: cached("one"))
        #expect(await cache.get("one") != nil)
        #expect(await cache.get("missing") == nil)
        let stats = await cache.stats()
        #expect(stats.hits == 1 && stats.misses == 1 && stats.entries == 1)
    }
    @Test func leastRecentlyUsedIsEvicted() async {
        let cache = DiffCache(maxBytes: 100000, maxEntries: 3)
        for key in ["one", "two", "three"] { await cache.set(key, hunk: cached(key)) }
        _ = await cache.get("one")
        await cache.set("four", hunk: cached("four"))
        #expect(await cache.get("two") == nil)
        #expect(await cache.get("one") != nil)
        #expect(await cache.get("three") != nil)
    }
    @Test func byteBudgetIsRespected() async {
        let cache = DiffCache(maxBytes: 1000, maxEntries: 100)
        for index in 0..<10 { await cache.set(String(index), hunk: cached(String(repeating: "x", count: 200))) }
        let stats = await cache.stats()
        #expect(stats.totalBytes <= 1000 && stats.evictions > 0)
    }
    @Test func coreCacheRejectsOversizedEntry() {
        let cache = LRUDiffCache<String, String>(maxCostBytes: 10)
        cache.set(key: "valid", value: "valid", cost: 4)
        cache.set(key: "oversized", value: "large", cost: 100)
        #expect(cache.stats().bytesUsed <= 10)
        #expect(cache.get(key: "valid") == "valid")
        #expect(cache.get(key: "oversized") == nil)
    }
    @Test func zeroCostEntriesStillConsumeBudget() {
        let cache = LRUDiffCache<String, String>(maxCostBytes: 50)
        for index in 0..<5000 { cache.set(key: String(index), value: "", cost: 0) }
        #expect(cache.stats().entries <= 50 && cache.stats().bytesUsed <= 50)
    }
}

@Suite("Production diff preferences")
struct DiffOptionsTests {
    @Test func isolatedPreferencesRoundTrip() throws {
        let name = "gitmac-tests-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        var preferences = DiffPreferences.default
        preferences.defaultContextLines = 5
        preferences.enableWordDiffOnDemand = false
        preferences.setLfmOverride(for: "large.txt", enabled: true)
        defaults.diffPreferences = preferences
        #expect(defaults.diffPreferences.defaultContextLines == 5)
        #expect(defaults.diffPreferences.enableWordDiffOnDemand == false)
        #expect(defaults.diffPreferences.lfmOverride(for: "large.txt") == true)
    }
}
