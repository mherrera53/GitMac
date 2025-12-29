import Foundation

/// Specialized service for remote operations
@MainActor
class RemoteService {
    private let engine = GitEngine()
    
    func fetch(remote: String? = nil, prune: Bool = true, at repoPath: String) async throws {
        let options = FetchOptions(prune: prune, remote: remote)
        try await engine.fetch(options: options, at: repoPath)
    }

    func pull(rebase: Bool = false, at repoPath: String) async throws {
        let options = PullOptions(rebase: rebase)
        try await engine.pull(options: options, at: repoPath)
    }

    func push(force: Bool = false, setUpstream: Bool = false, at repoPath: String) async throws {
        let options = PushOptions(force: force, setUpstream: setUpstream)
        try await engine.push(options: options, at: repoPath)
    }
}
