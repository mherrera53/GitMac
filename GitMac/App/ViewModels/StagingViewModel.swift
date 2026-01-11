//
//  StagingViewModel.swift
//  GitMac
//
//  ViewModel for staging area operations
//

import SwiftUI

@MainActor
class StagingViewModel: ObservableObject {
    @Published var unstagedFiles: [StagingFile] = []
    @Published var stagedFiles: [StagingFile] = []

    private let engine = GitEngine()
    private var currentPath: String?

    func loadStatus(at path: String) async {
        currentPath = path
        do {
            let status = try await engine.getStatus(at: path)
            unstagedFiles = status.unstaged.map { StagingFile(from: $0, staged: false) } +
                           status.untracked.map { StagingFile(path: $0, status: .untracked, isStaged: false) }
            stagedFiles = status.staged.map { StagingFile(from: $0, staged: true) }
        } catch {
            print("Error loading status: \(error)")
        }
    }

    func stage(file: StagingFile) {
        guard let path = currentPath else { return }
        Task {
            do {
                try await engine.stage(files: [file.path], at: path)
                await loadStatus(at: path)
            } catch {
                print("Error staging: \(error)")
            }
        }
    }

    func unstage(file: StagingFile) {
        guard let path = currentPath else { return }
        Task {
            do {
                try await engine.unstage(files: [file.path], at: path)
                await loadStatus(at: path)
            } catch {
                print("Error unstaging: \(error)")
            }
        }
    }

    func stageAll() {
        guard let path = currentPath else { return }
        Task {
            do {
                try await engine.stageAll(at: path)
                await loadStatus(at: path)
            } catch {
                print("Error staging all: \(error)")
            }
        }
    }

    func unstageAll() {
        guard let path = currentPath else { return }
        Task {
            do {
                let files = stagedFiles.map { $0.path }
                try await engine.unstage(files: files, at: path)
                await loadStatus(at: path)
            } catch {
                print("Error unstaging all: \(error)")
            }
        }
    }

    func stageFolder(_ folder: String) {
        guard let path = currentPath else { return }
        Task {
            do {
                let filesToStage = unstagedFiles.filter {
                    $0.path.hasPrefix(folder + "/") || $0.path == folder
                }.map { $0.path }
                if !filesToStage.isEmpty {
                    try await engine.stage(files: filesToStage, at: path)
                    await loadStatus(at: path)
                }
            } catch {
                print("Error staging folder: \(error)")
            }
        }
    }

    func unstageFolder(_ folder: String) {
        guard let path = currentPath else { return }
        Task {
            do {
                let filesToUnstage = stagedFiles.filter {
                    $0.path.hasPrefix(folder + "/") || $0.path == folder
                }.map { $0.path }
                if !filesToUnstage.isEmpty {
                    try await engine.unstage(files: filesToUnstage, at: path)
                    await loadStatus(at: path)
                }
            } catch {
                print("Error unstaging folder: \(error)")
            }
        }
    }

    func discard(file: StagingFile) {
        guard let path = currentPath else { return }
        Task {
            do {
                try await engine.discardChanges(files: [file.path], at: path)
                await loadStatus(at: path)
            } catch {
                print("Error discarding changes: \(error)")
            }
        }
    }

    func deleteFile(_ file: StagingFile) {
        guard let repoPath = currentPath else { return }
        let absolutePath = URL(fileURLWithPath: repoPath).appendingPathComponent(file.path).path
        Task {
            do {
                try FileManager.default.removeItem(atPath: absolutePath)
                await loadStatus(at: repoPath)
            } catch {
                print("Error deleting file: \(error)")
            }
        }
    }

    func commit(message: String, onSuccess: @escaping () -> Void) {
        guard let path = currentPath, !message.isEmpty else { return }
        Task {
            do {
                _ = try await engine.commit(message: message, at: path)
                await loadStatus(at: path)
                onSuccess()
            } catch {
                print("Error committing: \(error)")
            }
        }
    }

    func getDiff(for file: StagingFile, at path: String) async -> FileDiff? {
        if file.status == .untracked {
            return await getUntrackedFileDiff(for: file, at: path)
        }

        do {
            let diffString = try await engine.getDiff(for: file.path, staged: file.isStaged, at: path)
            let diffs = await DiffParser.parseAsync(diffString)
            return diffs.first
        } catch {
            print("Error getting diff: \(error)")
            return nil
        }
    }

    private func getUntrackedFileDiff(for file: StagingFile, at repoPath: String) async -> FileDiff? {
        let fullPath = (repoPath as NSString).appendingPathComponent(file.path)

        guard let content = try? String(contentsOfFile: fullPath, encoding: .utf8) else {
            if FileManager.default.fileExists(atPath: fullPath) {
                return FileDiff(
                    oldPath: "/dev/null",
                    newPath: file.path,
                    status: .untracked,
                    hunks: [DiffHunk(
                        header: "@@ -0,0 +1 @@",
                        oldStart: 0,
                        oldLines: 0,
                        newStart: 1,
                        newLines: 1,
                        lines: [DiffLine(type: .context, content: "[Binary or unreadable file]", oldLineNumber: nil, newLineNumber: 1)]
                    )],
                    isBinary: true,
                    additions: 0,
                    deletions: 0
                )
            }
            return nil
        }

        let lines = content.components(separatedBy: .newlines)
        var diffLines: [DiffLine] = []

        for (index, line) in lines.enumerated() {
            diffLines.append(DiffLine(
                type: .addition,
                content: line,
                oldLineNumber: nil,
                newLineNumber: index + 1
            ))
        }

        let hunk = DiffHunk(
            header: "@@ -0,0 +1,\(lines.count) @@",
            oldStart: 0,
            oldLines: 0,
            newStart: 1,
            newLines: lines.count,
            lines: diffLines
        )

        return FileDiff(
            oldPath: "/dev/null",
            newPath: file.path,
            status: .untracked,
            hunks: [hunk],
            isBinary: false,
            additions: lines.count,
            deletions: 0
        )
    }
}
