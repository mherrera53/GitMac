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
    @Published var errorMessage: String?

    private let engine = GitEngine()
    private var currentLoadSHA: String?

    func reset() {
        currentLoadSHA = nil
        changedFiles = []
        errorMessage = nil
        isLoading = false
    }

    func loadCommitFiles(sha: String, at path: String) async {
        // Avoid redundant loads for the same commit (unless reset was called)
        guard sha != currentLoadSHA || changedFiles.isEmpty else { return }
        currentLoadSHA = sha
        isLoading = true
        errorMessage = nil
        do {
            let files = try await engine.getCommitFiles(sha: sha, at: path)
            // Only apply if still the current request
            if currentLoadSHA == sha {
                changedFiles = files
            }
        } catch {
            if currentLoadSHA == sha {
                errorMessage = error.localizedDescription
                changedFiles = []
            }
        }
        if currentLoadSHA == sha {
            isLoading = false
        }
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
            print("Error getting streaming diff: \(error)")
            return nil
        }
    }
}
