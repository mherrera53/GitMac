import Foundation

// MARK: - LRU Cache with Cost-Based Eviction

/// Generic LRU cache with cost-based eviction (thread-safe via actor)
actor LRUCache<Key: Hashable & Sendable, Value: Sendable> {
    private struct CacheEntry {
        let value: Value
        let cost: Int
        var accessTime: Date
    }
    
    private var cache: [Key: CacheEntry] = [:]
    private var accessOrder: [Key] = []  // LRU order (oldest first)
    private var totalCost: Int = 0
    private let maxCost: Int
    
    /// Statistics for monitoring
    private(set) var hitCount: Int = 0
    private(set) var missCount: Int = 0
    private(set) var evictionCount: Int = 0
    
    init(maxCost: Int) {
        self.maxCost = maxCost
    }
    
    /// Get value from cache (returns nil on miss)
    func get(_ key: Key) -> Value? {
        guard var entry = cache[key] else {
            missCount += 1
            return nil
        }
        
        // Update access time
        entry.accessTime = Date()
        cache[key] = entry
        
        // Move to end of LRU list (most recently used)
        if let index = accessOrder.firstIndex(of: key) {
            accessOrder.remove(at: index)
        }
        accessOrder.append(key)
        
        hitCount += 1
        return entry.value
    }
    
    /// Set value in cache with cost
    func set(_ key: Key, value: Value, cost: Int) {
        // Remove existing entry if present
        if let existing = cache[key] {
            totalCost -= existing.cost
            if let index = accessOrder.firstIndex(of: key) {
                accessOrder.remove(at: index)
            }
        }
        
        // Evict until we have space
        while totalCost + cost > maxCost && !accessOrder.isEmpty {
            evictLRU()
        }
        
        // Add new entry
        let entry = CacheEntry(value: value, cost: cost, accessTime: Date())
        cache[key] = entry
        accessOrder.append(key)
        totalCost += cost
    }
    
    /// Remove value from cache
    func remove(_ key: Key) {
        guard let entry = cache[key] else { return }
        
        cache.removeValue(forKey: key)
        totalCost -= entry.cost
        
        if let index = accessOrder.firstIndex(of: key) {
            accessOrder.remove(at: index)
        }
    }
    
    /// Clear all cached values
    func clear() {
        cache.removeAll()
        accessOrder.removeAll()
        totalCost = 0
    }
    
    /// Get cache statistics
    func stats() -> CacheStats {
        CacheStats(
            entryCount: cache.count,
            totalCost: totalCost,
            maxCost: maxCost,
            hitCount: hitCount,
            missCount: missCount,
            evictionCount: evictionCount,
            hitRate: hitRate
        )
    }
    
    // MARK: - Private
    
    private func evictLRU() {
        guard let oldestKey = accessOrder.first,
              let entry = cache[oldestKey] else {
            return
        }
        
        cache.removeValue(forKey: oldestKey)
        accessOrder.removeFirst()
        totalCost -= entry.cost
        evictionCount += 1
    }
    
    private var hitRate: Double {
        let total = hitCount + missCount
        return total > 0 ? Double(hitCount) / Double(total) : 0
    }
}

// MARK: - Cache Stats

struct CacheStats: Sendable {
    let entryCount: Int
    let totalCost: Int
    let maxCost: Int
    let hitCount: Int
    let missCount: Int
    let evictionCount: Int
    let hitRate: Double
    
    var utilizationPercent: Double {
        maxCost > 0 ? Double(totalCost) / Double(maxCost) * 100 : 0
    }
}

// MARK: - Diff Cache

/// Cache for materialized diff hunks with cost-based LRU eviction
actor DiffCache {
    private typealias CacheKey = String  // "repoPath:filePath:hunkID"
    
    private struct CachedHunk: Sendable {
        let hunk: DiffHunk
        let materializedLines: [DiffLine]?
        let byteBuffer: Data?
        let costInBytes: Int
    }
    
    private let cache: LRUCache<CacheKey, CachedHunk>
    
    /// Default: 50 MB cache
    init(maxBytes: Int = 50_000_000) {
        self.cache = LRUCache(maxCost: maxBytes)
    }
    
    // MARK: - Public API
    
    /// Get cached hunk (returns nil on miss)
    func getHunk(repoPath: String, filePath: String, hunkID: UUID) async -> CachedHunk? {
        let key = cacheKey(repoPath: repoPath, filePath: filePath, hunkID: hunkID)
        return await cache.get(key)
    }
    
    /// Cache a hunk with materialized lines
    func setHunk(
        repoPath: String,
        filePath: String,
        hunk: DiffHunk,
        materializedLines: [DiffLine]?
    ) async {
        let cost = estimateCost(hunk: hunk, materializedLines: materializedLines)
        let cached = CachedHunk(
            hunk: hunk,
            materializedLines: materializedLines,
            byteBuffer: nil,
            costInBytes: cost
        )
        
        let key = cacheKey(repoPath: repoPath, filePath: filePath, hunkID: hunk.id)
        await cache.set(key, value: cached, cost: cost)
    }
    
    /// Cache a hunk with byte buffer (for LFM)
    func setHunkWithBuffer(
        repoPath: String,
        filePath: String,
        hunk: DiffHunk,
        byteBuffer: Data
    ) async {
        let cost = byteBuffer.count
        let cached = CachedHunk(
            hunk: hunk,
            materializedLines: nil,
            byteBuffer: byteBuffer,
            costInBytes: cost
        )
        
        let key = cacheKey(repoPath: repoPath, filePath: filePath, hunkID: hunk.id)
        await cache.set(key, value: cached, cost: cost)
    }
    
    /// Remove cached hunks for a file
    func invalidateFile(repoPath: String, filePath: String) async {
        // Note: We can't efficiently remove all hunks for a file without iterating
        // For now, just clear the entire cache (simple but effective)
        // A more sophisticated implementation could maintain a file->hunks mapping
        await cache.clear()
    }
    
    /// Get cache statistics
    func stats() async -> CacheStats {
        await cache.stats()
    }
    
    /// Clear all cached data
    func clear() async {
        await cache.clear()
    }
    
    // MARK: - Private
    
    private func cacheKey(repoPath: String, filePath: String, hunkID: UUID) -> CacheKey {
        "\(repoPath):\(filePath):\(hunkID.uuidString)"
    }
    
    private func estimateCost(hunk: DiffHunk, materializedLines: [DiffLine]?) -> Int {
        var cost = 0
        
        // Base hunk cost
        cost += MemoryLayout<DiffHunk>.size
        cost += hunk.header.utf8.count
        
        // Materialized lines cost
        if let lines = materializedLines {
            for line in lines {
                cost += MemoryLayout<DiffLine>.size
                cost += line.content.utf8.count
            }
        } else {
            // Estimate based on line count (not materialized)
            cost += hunk.lines.count * 100  // Rough estimate
        }
        
        return cost
    }
}

// MARK: - Extended Diff Models for Caching

extension DiffHunk {
    /// Byte offsets in raw diff output (for LFM)
    var byteOffsets: (start: Int, end: Int)? {
        // This would be set by the parser when in LFM
        // For now, we'll add this as optional computed property
        nil
    }
    
    /// Estimated line count (for LFM, before materialization)
    var estimatedLineCount: Int {
        oldLines + newLines
    }
    
    /// Calculate total additions in this hunk
    var additions: Int {
        lines.filter { $0.type == .addition }.count
    }
    
    /// Calculate total deletions in this hunk
    var deletions: Int {
        lines.filter { $0.type == .deletion }.count
    }
}

extension DiffLine {
    /// Intraline ranges marking character-level changes (for word-diff)
    var intralineRanges: [(range: Range<String.Index>, type: DiffLineType)]? {
        // This would be computed on-demand by word-diff algorithm
        // For now, we'll add this as optional computed property
        nil
    }
    
    /// Estimate memory cost of this line
    var estimatedCost: Int {
        MemoryLayout<DiffLine>.size + content.utf8.count
    }
}
