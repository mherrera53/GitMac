//
//  TerminalContext.swift
//  GitMac
//
//  Git repository context provider for terminal suggestions
//

import Foundation

/// Provides git repository context for intelligent suggestions
@MainActor
class TerminalContext: ObservableObject {
    @Published var branches: [String] = []
    @Published var files: [String] = []
    @Published var directories: [String] = []
    @Published var stagedFiles: [String] = []
    @Published var modifiedFiles: [String] = []
    @Published var isLoading = false

    private var workingDirectory: String = ""
    private var lastUpdate: Date = .distantPast
    private let cacheTimeout: TimeInterval = 5.0

    /// Update working directory and refresh context
    func setWorkingDirectory(_ path: String) {
        guard path != workingDirectory else { return }
        workingDirectory = path
        refresh(force: true)
    }

    /// Refresh context (throttled unless forced)
    func refresh(force: Bool = false) {
        guard !workingDirectory.isEmpty else { return }
        guard force || Date().timeIntervalSince(lastUpdate) > cacheTimeout else { return }

        isLoading = true

        Task {
            async let b = loadBranches()
            async let f = loadFiles()
            async let d = loadDirectories()
            async let s = loadGitStatus()

            let (newBranches, newFiles, newDirs, status) = await (b, f, d, s)

            await MainActor.run {
                branches = newBranches
                files = newFiles
                directories = newDirs
                stagedFiles = status.staged
                modifiedFiles = status.modified
                lastUpdate = Date()
                isLoading = false
            }
        }
    }

    // MARK: - Git Status

    private func loadGitStatus() async -> (staged: [String], modified: [String]) {
        guard !workingDirectory.isEmpty else { return ([], []) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["status", "--porcelain"]
        process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            var staged: [String] = []
            var modified: [String] = []

            for line in output.components(separatedBy: .newlines) where !line.isEmpty {
                guard line.count > 3 else { continue }
                let indexStatus = String(line.prefix(1))
                let workTreeStatus = String(line.dropFirst(1).prefix(1))
                let filename = String(line.dropFirst(3))

                // Staged: A=added, M=modified, R=renamed, D=deleted
                if ["A", "M", "R", "D"].contains(indexStatus) {
                    staged.append(filename)
                }
                // Modified or untracked in working tree
                if workTreeStatus == "M" || workTreeStatus == "?" {
                    modified.append(filename)
                }
            }

            return (staged, modified)
        } catch {
            return ([], [])
        }
    }

    // MARK: - Git Branches

    private func loadBranches() async -> [String] {
        guard !workingDirectory.isEmpty else { return [] }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["branch", "--format=%(refname:short)"]
        process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return output.components(separatedBy: .newlines).filter { !$0.isEmpty }
        } catch {
            return []
        }
    }

    // MARK: - Files & Directories

    private func loadFiles() async -> [String] {
        guard !workingDirectory.isEmpty else { return [] }
        let fm = FileManager.default

        do {
            let items = try fm.contentsOfDirectory(atPath: workingDirectory)
            return items
                .filter { !$0.hasPrefix(".") }
                .sorted()
                .prefix(100)
                .map { String($0) }
        } catch {
            return []
        }
    }

    private func loadDirectories() async -> [String] {
        guard !workingDirectory.isEmpty else { return [] }
        let fm = FileManager.default

        do {
            let items = try fm.contentsOfDirectory(atPath: workingDirectory)
            var dirs: [String] = []

            for item in items where !item.hasPrefix(".") {
                var isDir: ObjCBool = false
                let fullPath = (workingDirectory as NSString).appendingPathComponent(item)
                if fm.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue {
                    dirs.append(item)
                }
            }

            return dirs.sorted().prefix(50).map { String($0) }
        } catch {
            return []
        }
    }

    // MARK: - Commit Type Inference

    /// Infer commit type based on staged files
    func inferCommitType() -> String {
        let combined = stagedFiles.joined(separator: " ").lowercased()

        // Test files
        if combined.contains("test") || combined.contains("spec") || combined.contains("__tests__") {
            return "test"
        }

        // Documentation
        if combined.contains("readme") || combined.contains(".md") ||
           combined.contains("doc") || combined.contains("changelog") ||
           combined.contains("license") {
            return "docs"
        }

        // Configuration/build
        if combined.contains("package.json") || combined.contains("podfile") ||
           combined.contains("gemfile") || combined.contains("makefile") ||
           combined.contains("dockerfile") || combined.contains(".yml") ||
           combined.contains(".yaml") || combined.contains("config") ||
           combined.contains(".xcconfig") || combined.contains("pbxproj") {
            return "chore"
        }

        // Styles
        if combined.contains(".css") || combined.contains(".scss") ||
           combined.contains(".less") || combined.contains("theme") ||
           combined.contains("style") {
            return "style"
        }

        // Performance
        if combined.contains("perf") || combined.contains("optim") {
            return "perf"
        }

        // Fix patterns
        if combined.contains("fix") || combined.contains("bug") ||
           combined.contains("patch") || combined.contains("hotfix") {
            return "fix"
        }

        // Refactor patterns
        if combined.contains("refactor") || combined.contains("clean") ||
           combined.contains("rename") || combined.contains("move") {
            return "refactor"
        }

        // CI/CD
        if combined.contains("ci") || combined.contains("github/workflows") ||
           combined.contains("jenkins") || combined.contains("travis") {
            return "ci"
        }

        // Default to feat
        return "feat"
    }

    /// Get suggested commit message based on staged files
    func suggestedCommitMessage() -> String? {
        guard !stagedFiles.isEmpty else { return nil }

        let type = inferCommitType()
        let shortFiles = stagedFiles.prefix(3).map { ($0 as NSString).lastPathComponent }
        let filesDescription = shortFiles.joined(separator: ", ")

        return "\(type): update \(filesDescription)"
    }
}
