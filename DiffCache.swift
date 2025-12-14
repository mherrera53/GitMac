import Foundation
import os.signpost

// MARK: - Performance Logging

private let cacheLog = OSLog(subsystem: "com.gitmac", category: "diff.cache")

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
    func get(_ key: String) -> CachedHunk? {
        if let cached = cache[key] {
            // Move to end (most recently used)
            updateLRU(key)
            hits += 1
            
            os_signpost(.event, log: cacheLog, name: "cache.hit", "key=%{public}s size=%d", key, cached.costInBytes)
            
            return cached
        } else {
            misses += 1
            os_signpost(.event, log: cacheLog, name: "cache.miss", "key=%{public}s", key)
            return nil
        }
    }
    
    /// Set a cached hunk
    func set(_ key: String, hunk: CachedHunk) {
        let signpostID = OSSignpostID(log: cacheLog)
        os_signpost(.begin, log: cacheLog, name: "cache.set", signpostID: signpostID, "key=%{public}s size=%d", key, hunk.costInBytes)
        
        defer {
            os_signpost(.end, log: cacheLog, name: "cache.set", signpostID: signpostID)
        }
        
        // Remove old entry if exists
        if let old = cache[key] {
            totalBytes -= old.costInBytes
        } else {
            // New entry
            lruOrder.append(key)
        }
        
        // Add new entry
        cache[key] = hunk
        totalBytes += hunk.costInBytes
        
        // Update LRU
        updateLRU(key)
        
        // Evict if necessary
        evictIfNeeded()
    }
    
    /// Remove a specific entry
    func remove(_ key: String) {
        guard let cached = cache.removeValue(forKey: key) else { return }
        
        totalBytes -= cached.costInBytes
        lruOrder.removeAll { $0 == key }
        
        os_signpost(.event, log: cacheLog, name: "cache.remove", "key=%{public}s size=%d", key, cached.costInBytes)
    }
    
    /// Clear all cached entries
    func clear() {
        let count = cache.count
        let bytes = totalBytes
        
        cache.removeAll()
        lruOrder.removeAll()
        totalBytes = 0
        
        os_signpost(.event, log: cacheLog, name: "cache.clear", "entries=%d bytes=%d", count, bytes)
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
    
    private func updateLRU(_ key: String) {
        lruOrder.removeAll { $0 == key }
        lruOrder.append(key)
    }
    
    private func evictIfNeeded() {
        // Evict by byte budget
        while totalBytes > maxBytes && !lruOrder.isEmpty {
            evictLRU()
        }
        
        // Evict by entry count
        while cache.count > maxEntries && !lruOrder.isEmpty {
            evictLRU()
        }
    }
    
    private func evictLRU() {
        guard let key = lruOrder.first else { return }
        
        guard let cached = cache.removeValue(forKey: key) else { return }
        
        lruOrder.removeFirst()
        totalBytes -= cached.costInBytes
        evictions += 1
        
        os_signpost(.event, log: cacheLog, name: "cache.evict", "key=%{public}s size=%d reason=%{public}s",
                   key, cached.costInBytes, totalBytes > maxBytes ? "memory" : "count")
    }
}

// MARK: - Cached Hunk

/// A cached materialized hunk
struct CachedHunk: Sendable {
    let hunk: DiffHunk
    let materializedLines: [DiffLine]?
    let costInBytes: Int
    let accessTime: Date
    let fileKey: String  // For grouping by file
    
    init(hunk: DiffHunk, materializedLines: [DiffLine]? = nil, fileKey: String) {
        self.hunk = hunk
        self.materializedLines = materializedLines
        self.fileKey = fileKey
        self.accessTime = Date()
        
        // Estimate cost in bytes
        var cost = 0
        
        // Hunk header
        cost += hunk.header.utf8.count
        
        // Lines
        if let lines = materializedLines {
            for line in lines {
                cost += line.content.utf8.count
                cost += MemoryLayout<DiffLine>.size
            }
        } else {
            // Estimate based on hunk size
            cost += (hunk.oldLines + hunk.newLines) * 80  // Average line length
        }
        
        self.costInBytes = cost
    }
}

// MARK: - Cache Stats

/// Statistics about cache performance
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
    
    var description: String {
        """
        Cache Stats:
        - Entries: \(entries)
        - Memory: \(ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .memory)) / \(ByteCountFormatter.string(fromByteCount: Int64(maxBytes), countStyle: .memory)) (\(String(format: "%.1f", usagePercent))%)
        - Hits: \(hits)
        - Misses: \(misses)
        - Hit Rate: \(String(format: "%.1f", hitRate * 100))%
        - Evictions: \(evictions)
        """
    }
}

// MARK: - Cache Key Generation

extension DiffCache {
    /// Generate a cache key for a hunk
    static func key(file: String, hunkIndex: Int, staged: Bool = false) -> String {
        let stagedSuffix = staged ? ":staged" : ""
        return "\(file)#\(hunkIndex)\(stagedSuffix)"
    }
    
    /// Generate a file key for grouping
    static func fileKey(file: String, staged: Bool = false) -> String {
        let stagedSuffix = staged ? ":staged" : ""
        return "\(file)\(stagedSuffix)"
    }
    
    /// Remove all entries for a specific file
    func removeFile(_ file: String, staged: Bool = false) async {
        let fileKey = Self.fileKey(file: file, staged: staged)
        
        let keysToRemove = cache.filter { $0.value.fileKey == fileKey }.map { $0.key }
        
        for key in keysToRemove {
            remove(key)
        }
        
        os_signpost(.event, log: cacheLog, name: "cache.remove_file", "file=%{public}s count=%d", file, keysToRemove.count)
    }
}

// MARK: - Global Cache Instance

/// Shared global diff cache
actor GlobalDiffCache {
    static let shared = GlobalDiffCache()
    
    private let cache: DiffCache
    
    private init() {
        // Default to 50 MB cache
        self.cache = DiffCache(maxBytes: 50_000_000, maxEntries: 1000)
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
