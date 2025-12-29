import Foundation

/// Specialized service for branch operations
@MainActor
class BranchService {
    private let engine = GitEngine()
    private var branchesCache = CacheWithTTL<[Branch]>(ttl: 30)
    private var remoteBranchesCache = CacheWithTTL<[Branch]>(ttl: 60)
    
    func getBranches(at repoPath: String) async throws -> [Branch] {
        if let cached = branchesCache.get() { return cached }
        let branches = try await engine.getBranches(at: repoPath)
        branchesCache.set(branches)
        return branches
    }
    
    func getRemoteBranches(at repoPath: String) async throws -> [Branch] {
        if let cached = remoteBranchesCache.get() { return cached }
        let branches = try await engine.getRemoteBranches(at: repoPath)
        remoteBranchesCache.set(branches)
        return branches
    }
    
    func createBranch(
        named name: String,
        from startPoint: String = "HEAD",
        checkout: Bool = false,
        at repoPath: String
    ) async throws -> Branch {
        let branch = try await engine.createBranch(
            named: name,
            from: startPoint,
            checkout: checkout,
            at: repoPath
        )
        invalidateCache()
        return branch
    }
    
    func deleteBranch(named name: String, force: Bool = false, at repoPath: String) async throws {
        try await engine.deleteBranch(named: name, force: force, at: repoPath)
        invalidateCache()
    }
    
    func checkout(_ ref: String, at repoPath: String) async throws {
        try await engine.checkout(ref, at: repoPath)
        invalidateCache()
    }
    
    func checkoutForce(_ ref: String, at repoPath: String) async throws {
        try await engine.checkoutForce(ref, at: repoPath)
        invalidateCache()
    }
    
    func invalidateCache() {
        branchesCache.invalidate()
        remoteBranchesCache.invalidate()
    }
}
