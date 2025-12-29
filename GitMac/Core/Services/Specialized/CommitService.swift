import Foundation

/// Specialized service for commit operations
@MainActor
class CommitService {
    private let engine = GitEngine()
    
    func commit(message: String, amend: Bool = false, at repoPath: String) async throws -> Commit {
        return try await engine.commit(message: message, amend: amend, at: repoPath)
    }
    
    func getCommits(
        branch: String? = nil,
        limit: Int = 100,
        skip: Int = 0,
        at repoPath: String
    ) async throws -> [Commit] {
        return try await engine.getCommits(at: repoPath, branch: branch, limit: limit, skip: skip)
    }
}
