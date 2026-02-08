//
//  StagingViewModel.swift
//  GitMac
//
//  ViewModel for staging area operations
//

import SwiftUI

@MainActor
class StagingViewModel: ObservableObject {
    // MARK: - Pagination Constants
    private static let initialBatchSize = 100
    private static let loadMoreBatchSize = 100
    private static let largeRepoThreshold = 500

    // MARK: - Published State (visible files for UI)
    @Published var unstagedFiles: [StagingFile] = []
    @Published var stagedFiles: [StagingFile] = []

    // MARK: - Total counts (always accurate, even when paginated)
    @Published var totalUnstagedCount: Int = 0
    @Published var totalStagedCount: Int = 0

    // MARK: - Pagination state
    @Published var hasMoreUnstaged: Bool = false
    @Published var hasMoreStaged: Bool = false
    @Published var isLoadingMore: Bool = false

    // MARK: - Large repo warning
    @Published var isLargeRepo: Bool = false

    // MARK: - Private storage (full lists for operations)
    private var allUnstagedFiles: [StagingFile] = []
    private var allStagedFiles: [StagingFile] = []
    private var unstagedLoadedCount: Int = 0
    private var stagedLoadedCount: Int = 0

    private let engine = GitEngine()
    private var currentPath: String?

    // MARK: - Load Status with Pagination

    func loadStatus(at path: String) async {
        currentPath = path
        do {
            let status = try await engine.getStatus(at: path)

            // Build full lists internally
            allUnstagedFiles = status.unstaged.map { StagingFile(from: $0, staged: false) } +
                               status.untracked.map { StagingFile(path: $0, status: .untracked, isStaged: false) }
            allStagedFiles = status.staged.map { StagingFile(from: $0, staged: true) }

            // Update totals
            totalUnstagedCount = allUnstagedFiles.count
            totalStagedCount = allStagedFiles.count

            // Check if large repo
            let totalFiles = totalUnstagedCount + totalStagedCount
            isLargeRepo = totalFiles > Self.largeRepoThreshold

            // Load initial batch (or all if small repo)
            if isLargeRepo {
                // Paginated loading
                unstagedLoadedCount = min(Self.initialBatchSize, allUnstagedFiles.count)
                stagedLoadedCount = min(Self.initialBatchSize, allStagedFiles.count)

                unstagedFiles = Array(allUnstagedFiles.prefix(unstagedLoadedCount))
                stagedFiles = Array(allStagedFiles.prefix(stagedLoadedCount))

                hasMoreUnstaged = unstagedLoadedCount < totalUnstagedCount
                hasMoreStaged = stagedLoadedCount < totalStagedCount
            } else {
                // Small repo - load everything
                unstagedFiles = allUnstagedFiles
                stagedFiles = allStagedFiles
                unstagedLoadedCount = allUnstagedFiles.count
                stagedLoadedCount = allStagedFiles.count
                hasMoreUnstaged = false
                hasMoreStaged = false
            }
        } catch {
            print("Error loading status: \(error)")
        }
    }

    // MARK: - Load More (for infinite scroll)

    func loadMoreUnstaged() {
        guard hasMoreUnstaged, !isLoadingMore else { return }
        isLoadingMore = true

        let newCount = min(unstagedLoadedCount + Self.loadMoreBatchSize, allUnstagedFiles.count)
        let newFiles = Array(allUnstagedFiles[unstagedLoadedCount..<newCount])

        unstagedFiles.append(contentsOf: newFiles)
        unstagedLoadedCount = newCount
        hasMoreUnstaged = unstagedLoadedCount < totalUnstagedCount
        isLoadingMore = false
    }

    func loadMoreStaged() {
        guard hasMoreStaged, !isLoadingMore else { return }
        isLoadingMore = true

        let newCount = min(stagedLoadedCount + Self.loadMoreBatchSize, allStagedFiles.count)
        let newFiles = Array(allStagedFiles[stagedLoadedCount..<newCount])

        stagedFiles.append(contentsOf: newFiles)
        stagedLoadedCount = newCount
        hasMoreStaged = stagedLoadedCount < totalStagedCount
        isLoadingMore = false
    }

    /// Load all remaining files (use with caution on large repos)
    func loadAllFiles() {
        unstagedFiles = allUnstagedFiles
        stagedFiles = allStagedFiles
        unstagedLoadedCount = allUnstagedFiles.count
        stagedLoadedCount = allStagedFiles.count
        hasMoreUnstaged = false
        hasMoreStaged = false
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

    /// Discard all tracked unstaged changes (git checkout -- for all modified files)
    func discardAll() {
        guard let path = currentPath else { return }
        let trackedFiles = unstagedFiles.filter { $0.status != .untracked }.map { $0.path }
        guard !trackedFiles.isEmpty else { return }
        Task {
            do {
                try await engine.discardChanges(files: trackedFiles, at: path)
                await loadStatus(at: path)
                NotificationManager.shared.success("Discarded changes", detail: "\(trackedFiles.count) file(s) reverted")
            } catch {
                NotificationManager.shared.error("Discard failed", detail: error.localizedDescription)
            }
        }
    }

    /// Discard tracked changes in a specific folder
    func discardFolder(_ folder: String) {
        guard let path = currentPath else { return }
        let trackedFiles = unstagedFiles.filter {
            $0.status != .untracked && ($0.path.hasPrefix(folder + "/") || $0.path == folder)
        }.map { $0.path }
        guard !trackedFiles.isEmpty else { return }
        Task {
            do {
                try await engine.discardChanges(files: trackedFiles, at: path)
                await loadStatus(at: path)
                NotificationManager.shared.success("Reverted folder", detail: "\(trackedFiles.count) file(s) in \(folder)")
            } catch {
                NotificationManager.shared.error("Revert failed", detail: error.localizedDescription)
            }
        }
    }

    /// Delete all untracked files in a specific folder
    func deleteUntrackedInFolder(_ folder: String) {
        guard let repoPath = currentPath else { return }
        let untrackedFiles = unstagedFiles.filter {
            $0.status == .untracked && ($0.path.hasPrefix(folder + "/") || $0.path == folder)
        }
        guard !untrackedFiles.isEmpty else { return }
        var deleted = 0
        var failed = 0
        for file in untrackedFiles {
            let absolutePath = URL(fileURLWithPath: repoPath).appendingPathComponent(file.path).path
            do {
                try FileManager.default.removeItem(atPath: absolutePath)
                deleted += 1
            } catch {
                failed += 1
                print("Error deleting \(file.path): \(error)")
            }
        }
        Task {
            await loadStatus(at: repoPath)
            if failed == 0 {
                NotificationManager.shared.success("Deleted folder files", detail: "\(deleted) file(s) in \(folder)")
            } else {
                NotificationManager.shared.warning("Partially deleted", detail: "\(deleted) deleted, \(failed) failed")
            }
        }
    }

    /// Delete all untracked files from disk
    func deleteAllUntracked() {
        guard let repoPath = currentPath else { return }
        let untrackedFiles = unstagedFiles.filter { $0.status == .untracked }
        guard !untrackedFiles.isEmpty else { return }
        var deleted = 0
        var failed = 0
        for file in untrackedFiles {
            let absolutePath = URL(fileURLWithPath: repoPath).appendingPathComponent(file.path).path
            do {
                try FileManager.default.removeItem(atPath: absolutePath)
                deleted += 1
            } catch {
                failed += 1
                print("Error deleting \(file.path): \(error)")
            }
        }
        Task {
            await loadStatus(at: repoPath)
            if failed == 0 {
                NotificationManager.shared.success("Deleted untracked files", detail: "\(deleted) file(s) removed")
            } else {
                NotificationManager.shared.warning("Partially deleted", detail: "\(deleted) deleted, \(failed) failed")
            }
        }
    }

    func commit(message: String, amend: Bool = false, onSuccess: @escaping () -> Void) {
        guard let path = currentPath, !message.isEmpty else { return }
        Task {
            do {
                let commit = try await engine.commit(message: message, amend: amend, at: path)
                let shortSHA = String(commit.sha.prefix(7))
                await loadStatus(at: path)

                // Record in commit history
                CommitMessageHistory.shared.recordMessage(message)

                // Notify that branch ahead/behind changed (for push button to update)
                NotificationCenter.default.post(name: .branchDidChange, object: path)

                onSuccess()
                NotificationManager.shared.success(amend ? "Amend completed" : "Commit completed", detail: "SHA: \(shortSHA)")
            } catch {
                NotificationManager.shared.error(amend ? "Amend failed" : "Commit failed", detail: error.localizedDescription)
            }
        }
    }

    /// Async version of commit that returns success status
    func commitAsync(message: String, amend: Bool = false) async -> Bool {
        guard let path = currentPath, !message.isEmpty else { return false }
        do {
            let commit = try await engine.commit(message: message, amend: amend, at: path)
            let shortSHA = String(commit.sha.prefix(7))
            await loadStatus(at: path)

            // Record in commit history
            CommitMessageHistory.shared.recordMessage(message)

            // Notify that branch ahead/behind changed (for push button to update)
            NotificationCenter.default.post(name: .branchDidChange, object: path)

            NotificationManager.shared.success(amend ? "Amend completed" : "Commit completed", detail: "SHA: \(shortSHA)")
            return true
        } catch {
            NotificationManager.shared.error(amend ? "Amend failed" : "Commit failed", detail: error.localizedDescription)
            return false
        }
    }

    // MARK: - Hunk Staging

    /// Stage a specific hunk from a file diff
    func stageHunk(file: String, hunkIndex: Int) async -> Bool {
        guard let path = currentPath else { return false }
        do {
            guard let hunkPatch = try await engine.getDiffHunk(file: file, hunkIndex: hunkIndex, staged: false, at: path) else {
                return false
            }
            try await engine.stagePatch(hunkPatch, at: path)
            await loadStatus(at: path)
            NotificationManager.shared.success("Hunk staged", detail: file)
            return true
        } catch {
            NotificationManager.shared.error("Stage hunk failed", detail: error.localizedDescription)
            return false
        }
    }

    /// Discard a specific hunk from a file (applies reverse patch to working tree)
    func discardHunk(file: String, hunkIndex: Int) async -> Bool {
        guard let path = currentPath else { return false }
        do {
            guard let hunkPatch = try await engine.getDiffHunk(file: file, hunkIndex: hunkIndex, staged: false, at: path) else {
                return false
            }
            // Apply reverse patch to discard the hunk
            let tempFile = "/tmp/gitmac_discard_\(UUID().uuidString).patch"
            try hunkPatch.write(toFile: tempFile, atomically: true, encoding: .utf8)
            defer { try? FileManager.default.removeItem(atPath: tempFile) }

            let shell = ShellExecutor()
            let result = await shell.execute(
                "git",
                arguments: ["apply", "--reverse", tempFile],
                workingDirectory: path
            )
            guard result.exitCode == 0 else {
                throw GitError.commandFailed("git apply --reverse", result.stderr)
            }
            await loadStatus(at: path)
            NotificationManager.shared.success("Hunk discarded", detail: file)
            return true
        } catch {
            NotificationManager.shared.error("Discard hunk failed", detail: error.localizedDescription)
            return false
        }
    }

    /// Unstage a specific hunk from staged changes
    func unstageHunk(file: String, hunkIndex: Int) async -> Bool {
        guard let path = currentPath else { return false }
        do {
            guard let hunkPatch = try await engine.getDiffHunk(file: file, hunkIndex: hunkIndex, staged: true, at: path) else {
                return false
            }
            try await engine.unstagePatch(hunkPatch, at: path)
            await loadStatus(at: path)
            NotificationManager.shared.success("Hunk unstaged", detail: file)
            return true
        } catch {
            NotificationManager.shared.error("Unstage hunk failed", detail: error.localizedDescription)
            return false
        }
    }

    /// Image file extensions
    private static let imageExtensions = Set(["png", "jpg", "jpeg", "gif", "webp", "bmp", "tiff", "ico", "svg", "heic", "heif"])

    /// Check if file is an image based on extension
    private func isImageFile(_ path: String) -> Bool {
        let ext = (path as NSString).pathExtension.lowercased()
        return Self.imageExtensions.contains(ext)
    }

    func getDiff(for file: StagingFile, at path: String, contextLines: Int? = nil, ignoreWhitespace: Bool = false) async -> FileDiff? {
        // Handle untracked files
        if file.status == .untracked {
            return await getUntrackedFileDiff(for: file, at: path)
        }

        // Check if file is an image - return binary FileDiff for image preview
        if isImageFile(file.path) {
            return FileDiff(
                oldPath: file.path,
                newPath: file.path,
                status: file.status == .deleted ? .deleted : .modified,
                hunks: [],
                isBinary: true,
                additions: 0,
                deletions: 0
            )
        }

        do {
            let diffString = try await engine.getDiff(for: file.path, staged: file.isStaged, at: path, contextLines: contextLines, ignoreWhitespace: ignoreWhitespace)

            // Check if git reports this as a binary file (exact pattern: "Binary files ... differ")
            // Git outputs: "Binary files a/path and b/path differ"
            if diffString.hasPrefix("Binary files ") && diffString.contains(" differ\n") {
                return FileDiff(
                    oldPath: file.path,
                    newPath: file.path,
                    status: file.status == .deleted ? .deleted : .modified,
                    hunks: [],
                    isBinary: true,
                    additions: 0,
                    deletions: 0
                )
            }

            let diffs = await DiffParser.parseAsync(diffString)
            return diffs.first
        } catch {
            print("Error getting diff: \(error)")
            return nil
        }
    }

    private func getUntrackedFileDiff(for file: StagingFile, at repoPath: String) async -> FileDiff? {
        let fullPath = (repoPath as NSString).appendingPathComponent(file.path)

        // Check if file is an image - return binary FileDiff for image preview
        if isImageFile(file.path) {
            return FileDiff(
                oldPath: "/dev/null",
                newPath: file.path,
                status: .untracked,
                hunks: [],
                isBinary: true,
                additions: 0,
                deletions: 0
            )
        }

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
