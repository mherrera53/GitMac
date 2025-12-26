import Foundation

/// Specialized service for tag operations
@MainActor
class TagService {
    private let engine = GitEngine()
    private var tagsCache = CacheWithTTL<[Tag]>(ttl: 120)
    
    func getTags(at repoPath: String) async throws -> [Tag] {
        if let cached = tagsCache.get() { return cached }
        let tags = try await engine.getTags(at: repoPath)
        tagsCache.set(tags)
        return tags
    }
    
    func createTag(name: String, message: String? = nil, ref: String = "HEAD", at repoPath: String) async throws -> Tag {
        let options = TagOptions(name: name, targetRef: ref, message: message, isAnnotated: message != nil)
        let tag = try await engine.createTag(options: options, at: repoPath)
        invalidateCache()
        return tag
    }
    
    func deleteTag(named name: String, at repoPath: String) async throws {
        try await engine.deleteTag(named: name, at: repoPath)
        invalidateCache()
    }
    
    func invalidateCache() {
        tagsCache.invalidate()
    }
}
