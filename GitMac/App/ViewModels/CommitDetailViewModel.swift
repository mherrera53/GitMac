//
//  CommitDetailViewModel.swift
//  GitMac
//
//  ViewModel for commit detail panel
//

import SwiftUI

@MainActor
class CommitDetailViewModel: ObservableObject {
    @Published var changedFiles: [CommitFile] = []
    @Published var isLoading = false

    private let engine = GitEngine()
    /// Tracks which SHA is currently being loaded so stale results are discarded.
    private var currentLoadingSHA: String?

    func loadCommitFiles(sha: String, at path: String) async {
        currentLoadingSHA = sha
        isLoading = true
        changedFiles = []
        do {
            let files = try await engine.getCommitFiles(sha: sha, at: path)
            // Discard result if a newer load was started while we were awaiting
            guard currentLoadingSHA == sha else { return }
            changedFiles = files
        } catch {
            guard currentLoadingSHA == sha else { return }
            Logger.debug("Error loading commit files: \(error)")
            changedFiles = []
        }
        guard currentLoadingSHA == sha else { return }
        isLoading = false
    }

    func getDiff(for file: CommitFile, commit: Commit, at path: String) async -> FileDiff? {
        do {
            let maxLines = 100000
            var diffLines: [String] = []
            var lineCount = 0

            for try await line in engine.getCommitFileDiffStreaming(sha: commit.sha, filePath: file.path, at: path) {
                diffLines.append(line)
                lineCount += 1

                if lineCount >= maxLines {
                    diffLines.append("\n... [Output truncated - file too large] ...")
                    break
                }
            }

            let diffString = diffLines.joined(separator: "\n")
            let diffs = await DiffParser.parseAsync(diffString)
            return diffs.first
        } catch {
            Logger.debug("Error getting streaming diff: \(error)")
            return nil
        }
    }
}
