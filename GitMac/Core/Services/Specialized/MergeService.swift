import Foundation

/// Specialized service for merge, rebase, reset, and revert operations
@MainActor
class MergeService {
    private let engine = GitEngine()
    
    func merge(branch: String, noFastForward: Bool = false, squash: Bool = false, at repoPath: String) async throws {
        let options = MergeOptions(noFastForward: noFastForward, squash: squash)
        try await engine.merge(branch: branch, options: options, at: repoPath)
    }
    
    func mergeAbort(at repoPath: String) async throws {
        try await engine.mergeAbort(at: repoPath)
    }

    func rebase(onto branch: String, at repoPath: String) async throws {
        let options = RebaseOptions()
        try await engine.rebase(onto: branch, options: options, at: repoPath)
    }
    
    func rebaseContinue(at repoPath: String) async throws {
        try await engine.rebaseContinue(at: repoPath)
    }
    
    func rebaseAbort(at repoPath: String) async throws {
        try await engine.rebaseAbort(at: repoPath)
    }
}
