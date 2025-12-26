import Foundation

/// Specialized service for staging area operations
@MainActor
class StagingService {
    private let engine = GitEngine()
    
    func stage(files: [String], at repoPath: String) async throws {
        try await engine.stage(files: files, at: repoPath)
    }
    
    func stageAll(at repoPath: String) async throws {
        try await engine.stageAll(at: repoPath)
    }
    
    func unstage(files: [String], at repoPath: String) async throws {
        try await engine.unstage(files: files, at: repoPath)
    }
    
    func discardChanges(files: [String], at repoPath: String) async throws {
        try await engine.discardChanges(files: files, at: repoPath)
    }
}
