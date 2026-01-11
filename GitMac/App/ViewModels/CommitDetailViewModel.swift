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

    func loadCommitFiles(sha: String, at path: String) async {
        isLoading = true
        do {
            let files = try await engine.getCommitFiles(sha: sha, at: path)
            changedFiles = files
        } catch {
            print("Error loading commit files: \(error)")
            changedFiles = []
        }
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
            print("Error getting streaming diff: \(error)")
            return nil
        }
    }
}
