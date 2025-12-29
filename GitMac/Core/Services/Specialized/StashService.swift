import Foundation

/// Specialized service for stash operations
@MainActor
class StashService {
    private let engine = GitEngine()
    private var stashesCache = CacheWithTTL<[Stash]>(ttl: 30)
    
    func getStashes(at repoPath: String) async throws -> [Stash] {
        if let cached = stashesCache.get() { return cached }
        let stashes = try await engine.getStashes(at: repoPath)
        stashesCache.set(stashes)
        return stashes
    }
    
    func stash(message: String? = nil, includeUntracked: Bool = true, at repoPath: String) async throws -> Stash? {
        let options = StashOptions(message: message, includeUntracked: includeUntracked)
        let stash = try await engine.stash(options: options, at: repoPath)
        invalidateCache()
        return stash
    }

    func stashPop(index: Int = 0, at repoPath: String) async throws {
        let stashRef = "stash@{\(index)}"
        try await engine.stashPop(stashRef: stashRef, at: repoPath)
        invalidateCache()
    }

    func stashApply(index: Int = 0, at repoPath: String) async throws {
        let stashRef = "stash@{\(index)}"
        let options = StashApplyOptions(stashRef: stashRef)
        try await engine.stashApply(options: options, at: repoPath)
        invalidateCache()
    }

    func stashDrop(index: Int, at repoPath: String) async throws {
        let stashRef = "stash@{\(index)}"
        try await engine.stashDrop(stashRef: stashRef, at: repoPath)
        invalidateCache()
    }
    
    func invalidateCache() {
        stashesCache.invalidate()
    }
}
