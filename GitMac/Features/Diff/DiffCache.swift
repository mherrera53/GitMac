import Foundation

// MARK: - Diff Cache

/// LRU cache for materialized diff hunks
/// Uses byte-cost based eviction to stay within memory budget
actor DiffCache {
    private var cache: [String: CachedHunk] = [:]
    private var lruOrder: [String] = []  // Most recently used at the end
    private var totalBytes: Int = 0

    let maxBytes: Int
    let maxEntries: Int

    // Statistics
    private(set) var hits: Int = 0
    private(set) var misses: Int = 0
    private(set) var evictions: Int = 0

    init(maxBytes: Int = 50_000_000, maxEntries: Int = 1000) {
        self.maxBytes = maxBytes
        self.maxEntries = maxEntries
    }

    // MARK: - Public API

    /// Get a cached hunk
    @inlinable
    func get(_ key: String) -> CachedHunk? {
        if let cached = cache[key] {
            updateLRU(key)
            hits += 1
            return cached
        } else {
            misses += 1
            return nil
        }
    }

    /// Set a cached hunk
    func set(_ key: String, hunk: CachedHunk) {
        // Remove old entry if exists
        if let old = cache[key] {
            totalBytes -= old.costInBytes
        } else {
            lruOrder.append(key)
        }

        cache[key] = hunk
        totalBytes += hunk.costInBytes
        updateLRU(key)
        evictIfNeeded()
    }

    /// Remove a specific entry
    func remove(_ key: String) {
        guard let cached = cache.removeValue(forKey: key) else { return }
        totalBytes -= cached.costInBytes
        lruOrder.removeAll { $0 == key }
    }

    /// Clear all cached entries
    func clear() {
        cache.removeAll()
        lruOrder.removeAll()
        totalBytes = 0
    }

    /// Get cache statistics
    func stats() -> CacheStats {
        CacheStats(
            entries: cache.count,
            totalBytes: totalBytes,
            maxBytes: maxBytes,
            hits: hits,
            misses: misses,
            evictions: evictions,
            hitRate: hits + misses > 0 ? Double(hits) / Double(hits + misses) : 0
        )
    }

    // MARK: - Private Methods

    @inline(__always)
    private func updateLRU(_ key: String) {
        if let index = lruOrder.lastIndex(of: key) {
            lruOrder.remove(at: index)
        }
        lruOrder.append(key)
    }

    private func evictIfNeeded() {
        while totalBytes > maxBytes && !lruOrder.isEmpty {
            evictLRU()
        }
        while cache.count > maxEntries && !lruOrder.isEmpty {
            evictLRU()
        }
    }

    @inline(__always)
    private func evictLRU() {
        guard let key = lruOrder.first else { return }
        guard let cached = cache.removeValue(forKey: key) else { return }
        lruOrder.removeFirst()
        totalBytes -= cached.costInBytes
        evictions += 1
    }
}

// MARK: - Cached Hunk

/// A cached materialized hunk
struct CachedHunk: Sendable {
    let hunk: DiffHunk
    let materializedLines: [DiffLine]?
    let costInBytes: Int
    let fileKey: String

    init(hunk: DiffHunk, materializedLines: [DiffLine]? = nil, fileKey: String) {
        self.hunk = hunk
        self.materializedLines = materializedLines
        self.fileKey = fileKey

        // Estimate cost in bytes
        var cost = hunk.header.utf8.count

        if let lines = materializedLines {
            for line in lines {
                cost += line.content.utf8.count + MemoryLayout<DiffLine>.size
            }
        } else {
            cost += (hunk.oldLines + hunk.newLines) * 80
        }

        self.costInBytes = cost
    }
}

// MARK: - Cache Stats

struct CacheStats: Sendable {
    let entries: Int
    let totalBytes: Int
    let maxBytes: Int
    let hits: Int
    let misses: Int
    let evictions: Int
    let hitRate: Double

    var usagePercent: Double {
        maxBytes > 0 ? Double(totalBytes) / Double(maxBytes) * 100 : 0
    }
}

// MARK: - Cache Key Generation

extension DiffCache {
    static func key(file: String, hunkIndex: Int, staged: Bool = false) -> String {
        staged ? "\(file)#\(hunkIndex):staged" : "\(file)#\(hunkIndex)"
    }

    static func fileKey(file: String, staged: Bool = false) -> String {
        staged ? "\(file):staged" : file
    }

    func removeFile(_ file: String, staged: Bool = false) async {
        let fKey = Self.fileKey(file: file, staged: staged)
        let keysToRemove = cache.filter { $0.value.fileKey == fKey }.map { $0.key }
        for key in keysToRemove {
            remove(key)
        }
    }
}

// MARK: - Global Cache Instance

actor GlobalDiffCache {
    static let shared = GlobalDiffCache()

    private let cache: DiffCache

    private init() {
        self.cache = DiffCache(maxBytes: 10_000_000, maxEntries: 300)

        Task {
            await Self.setupMemoryPressureObserver()
        }
    }

    @MainActor
    private static func setupMemoryPressureObserver() {
        NotificationCenter.default.addObserver(
            forName: MemoryPressureHandler.memoryPressureNotification,
            object: nil,
            queue: .main
        ) { notification in
            let level = notification.userInfo?["level"] as? String ?? "warning"
            Task {
                if level == "critical" {
                    await GlobalDiffCache.shared.clear()
                } else {
                    await GlobalDiffCache.shared.trimCache()
                }
            }
        }
    }

    func trimCache() async {
        await cache.clear()
    }

    func get(_ key: String) async -> CachedHunk? {
        await cache.get(key)
    }

    func set(_ key: String, hunk: CachedHunk) async {
        await cache.set(key, hunk: hunk)
    }

    func remove(_ key: String) async {
        await cache.remove(key)
    }

    func clear() async {
        await cache.clear()
    }

    func stats() async -> CacheStats {
        await cache.stats()
    }

    func removeFile(_ file: String, staged: Bool = false) async {
        await cache.removeFile(file, staged: staged)
    }
}
