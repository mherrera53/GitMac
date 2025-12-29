import Foundation

/// Specialized service for diff operations
@MainActor
class DiffService {
    private let engine = GitEngine()
    
    func getDiff(for file: String? = nil, staged: Bool = false, at repoPath: String) async throws -> String {
        return try await engine.getDiff(for: file, staged: staged, at: repoPath)
    }
    
    func getDiff(from baseBranch: String, to headBranch: String, at repoPath: String) async throws -> String {
        return try await engine.getDiff(from: baseBranch, to: headBranch, at: repoPath)
    }
}
