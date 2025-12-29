import Foundation
import os.signpost

// MARK: - Performance Logging

private let gitLog = OSLog(subsystem: "com.gitmac", category: "git")

/// Main wrapper for Git operations
/// Uses git CLI commands as the primary backend for reliability
actor GitEngine {
    private let shellExecutor: ShellExecutor

    init() {
        self.shellExecutor = ShellExecutor()
    }

    // MARK: - Repository Operations

    /// Check if a directory is a Git repository
    func isRepository(at path: String) async -> Bool {
        let result = await shellExecutor.execute(
            "git",
            arguments: ["rev-parse", "--git-dir"],
            workingDirectory: path
        )
        return result.exitCode == 0
    }

    /// Initialize a new repository
    func initRepository(at path: String, bare: Bool = false) async throws -> Repository {
        var args = ["init"]
        if bare {
            args.append("--bare")
        }

        let result = await shellExecutor.execute("git", arguments: args, workingDirectory: path)

        guard result.exitCode == 0 else {
            throw GitError.initFailed(result.stderr)
        }

        return Repository(path: path)
    }

    /// Clone a repository
    func cloneRepository(
        from url: String,
        to path: String,
        options: CloneOptions = CloneOptions(),
        progress: ((CloneProgress) -> Void)? = nil
    ) async throws -> Repository {
        var args = ["clone", "--progress"]
        args.append(contentsOf: options.arguments)
        args.append(url)
        args.append(path)

        let result = await shellExecutor.execute("git", arguments: args)

        guard result.exitCode == 0 else {
            throw GitError.cloneFailed(result.stderr)
        }

        return Repository(path: path)
    }

    /// Open an existing repository
    func openRepository(at path: String) async throws -> Repository {
        guard await isRepository(at: path) else {
            throw GitError.notARepository(path)
        }

        var repo = Repository(path: path)

        // Load repository state
        async let head = getHead(at: path)
        async let branches = getBranches(at: path)
        async let remoteBranches = getRemoteBranches(at: path)
        async let tags = getTags(at: path)
        async let remotes = getRemotes(at: path)
        async let stashes = getStashes(at: path)
        async let status = getStatus(at: path)

        repo.head = try? await head
        repo.branches = (try? await branches) ?? []
        repo.remoteBranches = (try? await remoteBranches) ?? []
        repo.tags = (try? await tags) ?? []
        repo.remotes = (try? await remotes) ?? []
        repo.stashes = (try? await stashes) ?? []
        repo.status = (try? await status) ?? RepositoryStatus()

        return repo
    }

    // MARK: - Reference Operations

    /// Get current HEAD reference
    func getHead(at path: String) async throws -> Reference {
        // Get symbolic ref (branch name)
        let symbolicResult = await shellExecutor.execute(
            "git",
            arguments: ["symbolic-ref", "--short", "HEAD"],
            workingDirectory: path
        )

        let sha = try await getHeadSHA(at: path)

        if symbolicResult.exitCode == 0 {
            let branchName = symbolicResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            return Reference(
                name: branchName,
                fullName: "refs/heads/\(branchName)",
                type: .branch,
                targetSHA: sha
            )
        } else {
            // Detached HEAD
            return Reference(
                name: String(sha.prefix(7)),
                fullName: sha,
                type: .head,
                targetSHA: sha
            )
        }
    }

    /// Get HEAD commit SHA
    func getHeadSHA(at path: String) async throws -> String {
        let result = await shellExecutor.execute(
            "git",
            arguments: ["rev-parse", "HEAD"],
            workingDirectory: path
        )

        guard result.exitCode == 0 else {
            throw GitError.noCommits
        }

        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Branch Operations

    /// Get all local branches
    func getBranches(at path: String) async throws -> [Branch] {
        let result = await shellExecutor.execute(
            "git",
            arguments: [
                "for-each-ref",
                "--format=%(refname:short)|%(objectname)|%(HEAD)|%(upstream:short)|%(upstream:track)",
                "refs/heads"
            ],
            workingDirectory: path
        )

        guard result.exitCode == 0 else {
            throw GitError.commandFailed("git for-each-ref", result.stderr)
        }

        _ = try? await getHeadSHA(at: path)

        return result.stdout
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .compactMap { line -> Branch? in
                let parts = line.components(separatedBy: "|")
                guard parts.count >= 2 else { return nil }

                let name = parts[0]
                let sha = parts[1]
                let isHead = parts.count > 2 && parts[2] == "*"
                let upstream = parts.count > 3 && !parts[3].isEmpty ? parts[3] : nil
                let trackInfo = parts.count > 4 ? parseTrackInfo(parts[4]) : nil

                return Branch(
                    name: name,
                    fullName: "refs/heads/\(name)",
                    isRemote: false,
                    isHead: isHead,  // Only use git's HEAD marker, not SHA comparison
                    trackingBranch: upstream,
                    targetSHA: sha,
                    upstream: trackInfo
                )
            }
    }

    /// Get all remote branches
    func getRemoteBranches(at path: String) async throws -> [Branch] {
        let result = await shellExecutor.execute(
            "git",
            arguments: [
                "for-each-ref",
                "--format=%(refname:short)|%(objectname)",
                "refs/remotes"
            ],
            workingDirectory: path
        )

        guard result.exitCode == 0 else {
            throw GitError.commandFailed("git for-each-ref", result.stderr)
        }

        return result.stdout
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty && !$0.contains("/HEAD") }
            .compactMap { line -> Branch? in
                let parts = line.components(separatedBy: "|")
                guard parts.count >= 2 else { return nil }

                let fullName = parts[0]
                let sha = parts[1]

                // Extract remote name and branch name
                let pathParts = fullName.split(separator: "/", maxSplits: 1)
                guard pathParts.count > 1 else {
                    // Skip refs that don't have a branch name (like bare "origin" from origin/HEAD)
                    return nil
                }

                let remoteName = String(pathParts[0])
                _ = String(pathParts[1])  // branchName - not currently used but parsed for potential future use

                return Branch(
                    name: fullName,
                    fullName: "refs/remotes/\(fullName)",
                    isRemote: true,
                    remoteName: remoteName,
                    targetSHA: sha
                )
            }
    }

    /// Create a new branch
    func createBranch(
        named name: String,
        from startPoint: String = "HEAD",
        checkout: Bool = false,
        at path: String
    ) async throws -> Branch {
        var args = checkout ? ["checkout", "-b"] : ["branch"]
        args.append(name)
        args.append(startPoint)

        let result = await shellExecutor.execute("git", arguments: args, workingDirectory: path)

        guard result.exitCode == 0 else {
            throw GitError.branchCreationFailed(name, result.stderr)
        }

        // Get the new branch info
        let sha = try await resolveSHA(for: name, at: path)

        return Branch(
            name: name,
            fullName: "refs/heads/\(name)",
            isRemote: false,
            isHead: checkout,
            targetSHA: sha
        )
    }

    /// Delete a branch
    func deleteBranch(named name: String, force: Bool = false, at path: String) async throws {
        let flag = force ? "-D" : "-d"
        let result = await shellExecutor.execute(
            "git",
            arguments: ["branch", flag, name],
            workingDirectory: path
        )

        guard result.exitCode == 0 else {
            throw GitError.branchDeletionFailed(name, result.stderr)
        }
    }

    /// Checkout a branch or commit
    func checkout(_ ref: String, at path: String) async throws {
        let result = await shellExecutor.execute(
            "git",
            arguments: ["checkout", ref],
            workingDirectory: path
        )

        guard result.exitCode == 0 else {
            throw GitError.checkoutFailed(ref, result.stderr)
        }
    }

    func checkoutForce(_ ref: String, at path: String) async throws {
        let result = await shellExecutor.execute(
            "git",
            arguments: ["checkout", "-f", ref],
            workingDirectory: path
        )

        guard result.exitCode == 0 else {
            throw GitError.checkoutFailed(ref, result.stderr)
        }
    }

    // MARK: - Commit Operations

    /// Get commits with pagination
    func getCommits(
        at path: String,
        branch: String? = nil,
        limit: Int = 100,
        skip: Int = 0
    ) async throws -> [Commit] {
        var args = [
            "log",
            "--format=%H|%P|%an|%ae|%ai|%cn|%ce|%ci|%s",
            "-n", String(limit),
            "--skip", String(skip)
        ]

        if let branch = branch {
            args.append(branch)
        }

        let result = await shellExecutor.execute("git", arguments: args, workingDirectory: path)

        guard result.exitCode == 0 else {
            throw GitError.commandFailed("git log", result.stderr)
        }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate, .withTime, .withSpaceBetweenDateAndTime]

        return result.stdout
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .compactMap { line -> Commit? in
                let parts = line.components(separatedBy: "|")
                guard parts.count >= 9 else { return nil }

                let sha = parts[0]
                let parentSHAs = parts[1].split(separator: " ").map(String.init)
                let authorName = parts[2]
                let authorEmail = parts[3]
                let authorDateStr = parts[4]
                let committerName = parts[5]
                let committerEmail = parts[6]
                let committerDateStr = parts[7]
                let message = parts[8...].joined(separator: "|")

                let authorDate = parseGitDate(authorDateStr) ?? Date()
                let committerDate = parseGitDate(committerDateStr) ?? Date()

                return Commit(
                    sha: sha,
                    message: message,
                    author: authorName,
                    authorEmail: authorEmail,
                    authorDate: authorDate,
                    committer: committerName,
                    committerEmail: committerEmail,
                    committerDate: committerDate,
                    parentSHAs: parentSHAs
                )
            }
    }

    /// Create a commit
    func commit(message: String, amend: Bool = false, at path: String) async throws -> Commit {
        var args = ["commit", "-m", message]
        if amend {
            args.append("--amend")
        }

        let result = await shellExecutor.execute("git", arguments: args, workingDirectory: path)

        guard result.exitCode == 0 else {
            throw GitError.commitFailed(result.stderr)
        }

        // Get the new commit
        let commits = try await getCommits(at: path, limit: 1)
        guard let commit = commits.first else {
            throw GitError.commitFailed("Could not retrieve new commit")
        }

        return commit
    }

    // MARK: - Staging Operations

    /// Get repository status
    func getStatus(at path: String) async throws -> RepositoryStatus {
        // Get status and diff stats in parallel
        async let statusResult = shellExecutor.execute(
            "git",
            arguments: ["status", "--porcelain=v1", "-uall"],
            workingDirectory: path
        )
        async let unstagedStats = shellExecutor.execute(
            "git",
            arguments: ["diff", "--numstat"],
            workingDirectory: path
        )
        async let stagedStats = shellExecutor.execute(
            "git",
            arguments: ["diff", "--cached", "--numstat"],
            workingDirectory: path
        )

        let result = await statusResult
        guard result.exitCode == 0 else {
            throw GitError.commandFailed("git status", result.stderr)
        }

        // Parse diff stats into dictionaries
        let unstagedOutput = await unstagedStats.stdout
        let stagedOutput = await stagedStats.stdout
        let unstagedDiffStats = parseDiffStats(unstagedOutput)
        let stagedDiffStats = parseDiffStats(stagedOutput)

        // Debug logging
        if !unstagedDiffStats.isEmpty || !stagedDiffStats.isEmpty {
            print("📊 Diff stats - Unstaged: \(unstagedDiffStats.count) files, Staged: \(stagedDiffStats.count) files")
            for (path, stats) in unstagedDiffStats.prefix(3) {
                print("   📄 \(path): +\(stats.0) -\(stats.1)")
            }
        }

        var status = RepositoryStatus()

        for line in result.stdout.components(separatedBy: .newlines) where !line.isEmpty {
            guard line.count >= 3 else { continue }

            let index = line.index(line.startIndex, offsetBy: 0)
            let worktree = line.index(line.startIndex, offsetBy: 1)
            let filePath = String(line.dropFirst(3))

            let indexStatus = String(line[index])
            let worktreeStatus = String(line[worktree])

            // Handle staged changes
            if indexStatus != " " && indexStatus != "?" {
                if let statusType = FileStatusType(rawValue: indexStatus) {
                    let stats = stagedDiffStats[filePath] ?? (0, 0)
                    status.staged.append(FileStatus(path: filePath, status: statusType, additions: stats.0, deletions: stats.1))
                }
            }

            // Handle unstaged changes
            if worktreeStatus != " " && worktreeStatus != "?" {
                if let statusType = FileStatusType(rawValue: worktreeStatus) {
                    let stats = unstagedDiffStats[filePath] ?? (0, 0)
                    status.unstaged.append(FileStatus(path: filePath, status: statusType, additions: stats.0, deletions: stats.1))
                }
            }

            // Handle untracked files
            if indexStatus == "?" && worktreeStatus == "?" {
                status.untracked.append(filePath)
            }

            // Handle conflicts
            if indexStatus == "U" || worktreeStatus == "U" {
                status.conflicted.append(FileStatus(path: filePath, status: .unmerged))
            }
        }

        return status
    }

    /// Parse git diff --numstat output into a dictionary of [path: (additions, deletions)]
    private func parseDiffStats(_ output: String) -> [String: (Int, Int)] {
        var stats: [String: (Int, Int)] = [:]

        for line in output.components(separatedBy: .newlines) where !line.isEmpty {
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard parts.count >= 3 else { continue }

            // Binary files show "-" for additions/deletions
            let additions = Int(parts[0]) ?? 0
            let deletions = Int(parts[1]) ?? 0
            let filePath = String(parts[2])

            stats[filePath] = (additions, deletions)
        }

        return stats
    }

    /// Stage files
    func stage(files: [String], at path: String) async throws {
        var args = ["add", "--"]
        args.append(contentsOf: files)

        let result = await shellExecutor.execute("git", arguments: args, workingDirectory: path)

        guard result.exitCode == 0 else {
            throw GitError.stageFailed(result.stderr)
        }
    }

    /// Stage all changes
    func stageAll(at path: String) async throws {
        let result = await shellExecutor.execute(
            "git",
            arguments: ["add", "-A"],
            workingDirectory: path
        )

        guard result.exitCode == 0 else {
            throw GitError.stageFailed(result.stderr)
        }
    }

    /// Unstage files
    func unstage(files: [String], at path: String) async throws {
        var args = ["reset", "HEAD", "--"]
        args.append(contentsOf: files)

        let result = await shellExecutor.execute("git", arguments: args, workingDirectory: path)

        guard result.exitCode == 0 else {
            throw GitError.unstageFailed(result.stderr)
        }
    }

    /// Discard changes to files
    func discardChanges(files: [String], at path: String) async throws {
        var args = ["checkout", "--"]
        args.append(contentsOf: files)

        let result = await shellExecutor.execute("git", arguments: args, workingDirectory: path)

        guard result.exitCode == 0 else {
            throw GitError.discardFailed(result.stderr)
        }
    }

    /// Stage a patch (for partial staging)
    func stagePatch(_ patch: String, at path: String) async throws {
        // Write patch to temp file
        let tempFile = "/tmp/gitmac_patch_\(UUID().uuidString).patch"
        try patch.write(toFile: tempFile, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(atPath: tempFile)
        }

        let result = await shellExecutor.execute(
            "git",
            arguments: ["apply", "--cached", tempFile],
            workingDirectory: path
        )

        guard result.exitCode == 0 else {
            throw GitError.stageFailed(result.stderr)
        }
    }

    /// Unstage a patch (for partial unstaging)
    func unstagePatch(_ patch: String, at path: String) async throws {
        // Write patch to temp file
        let tempFile = "/tmp/gitmac_patch_\(UUID().uuidString).patch"
        try patch.write(toFile: tempFile, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(atPath: tempFile)
        }

        let result = await shellExecutor.execute(
            "git",
            arguments: ["apply", "--cached", "--reverse", tempFile],
            workingDirectory: path
        )

        guard result.exitCode == 0 else {
            throw GitError.unstageFailed(result.stderr)
        }
    }

    /// Get diff output for a hunk
    func getDiffHunk(file: String, hunkIndex: Int, staged: Bool, at path: String) async throws -> String? {
        let fullDiff = try await getDiff(for: file, staged: staged, at: path)

        // Parse and return specific hunk
        let hunks = parseDiffHunks(fullDiff)
        guard hunkIndex < hunks.count else { return nil }

        return hunks[hunkIndex]
    }

    /// Parse diff output into hunks
    private func parseDiffHunks(_ diffOutput: String) -> [String] {
        var hunks: [String] = []
        var currentHunk = ""
        var inHunk = false
        var header = ""

        for line in diffOutput.components(separatedBy: .newlines) {
            if line.hasPrefix("diff --git") || line.hasPrefix("index ") ||
               line.hasPrefix("--- ") || line.hasPrefix("+++ ") {
                if !header.isEmpty && !currentHunk.isEmpty {
                    hunks.append(header + currentHunk)
                    currentHunk = ""
                }
                header += line + "\n"
            } else if line.hasPrefix("@@") {
                if inHunk && !currentHunk.isEmpty {
                    hunks.append(header + currentHunk)
                }
                currentHunk = line + "\n"
                inHunk = true
            } else if inHunk {
                currentHunk += line + "\n"
            }
        }

        if !currentHunk.isEmpty {
            hunks.append(header + currentHunk)
        }

        return hunks
    }

    // MARK: - Tag Operations

    /// Get all tags
    func getTags(at path: String) async throws -> [Tag] {
        let result = await shellExecutor.execute(
            "git",
            arguments: [
                "for-each-ref",
                "--format=%(refname:short)|%(objectname)|%(objecttype)|%(*objectname)|%(taggername)|%(taggeremail)|%(taggerdate:iso)",
                "--sort=-creatordate",
                "refs/tags"
            ],
            workingDirectory: path
        )

        guard result.exitCode == 0 else {
            throw GitError.commandFailed("git for-each-ref", result.stderr)
        }

        return result.stdout
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .compactMap { line -> Tag? in
                let parts = line.components(separatedBy: "|")
                guard parts.count >= 3 else { return nil }

                let name = parts[0]
                let sha = parts[1]
                let objectType = parts[2]
                let targetSHA = parts.count > 3 && !parts[3].isEmpty ? parts[3] : sha
                let tagger = parts.count > 4 && !parts[4].isEmpty ? parts[4] : nil
                let taggerEmail = parts.count > 5 && !parts[5].isEmpty ? parts[5].replacingOccurrences(of: "<", with: "").replacingOccurrences(of: ">", with: "") : nil
                let dateStr = parts.count > 6 ? parts[6] : nil
                let date = dateStr.flatMap { parseGitDate($0) }

                let isAnnotated = objectType == "tag"

                return Tag(
                    name: name,
                    targetSHA: isAnnotated ? targetSHA : sha,
                    isAnnotated: isAnnotated,
                    tagger: tagger,
                    taggerEmail: taggerEmail,
                    date: date
                )
            }
    }

    /// Create a tag
    func createTag(options: TagOptions, at path: String) async throws -> Tag {
        var args = ["tag"]
        args.append(contentsOf: options.arguments)

        let result = await shellExecutor.execute("git", arguments: args, workingDirectory: path)

        guard result.exitCode == 0 else {
            throw GitError.tagCreationFailed(options.name, result.stderr)
        }

        let sha = try await resolveSHA(for: options.name, at: path)

        return Tag(
            name: options.name,
            targetSHA: sha,
            isAnnotated: options.isAnnotated,
            message: options.message
        )
    }

    /// Delete a tag
    func deleteTag(named name: String, at path: String) async throws {
        let result = await shellExecutor.execute(
            "git",
            arguments: ["tag", "-d", name],
            workingDirectory: path
        )

        guard result.exitCode == 0 else {
            throw GitError.tagDeletionFailed(name, result.stderr)
        }
    }

    // MARK: - Remote Operations

    /// Get all remotes
    func getRemotes(at path: String) async throws -> [Remote] {
        let result = await shellExecutor.execute(
            "git",
            arguments: ["remote", "-v"],
            workingDirectory: path
        )

        guard result.exitCode == 0 else {
            throw GitError.commandFailed("git remote", result.stderr)
        }

        var remoteDict: [String: (fetch: String?, push: String?)] = [:]

        for line in result.stdout.components(separatedBy: .newlines) where !line.isEmpty {
            let parts = line.split(separator: "\t")
            guard parts.count >= 2 else { continue }

            let name = String(parts[0])
            let urlPart = parts[1].split(separator: " ")
            let url = String(urlPart[0])
            let type = urlPart.count > 1 ? String(urlPart[1]) : "(fetch)"

            var entry = remoteDict[name] ?? (nil, nil)
            if type.contains("fetch") {
                entry.fetch = url
            } else if type.contains("push") {
                entry.push = url
            }
            remoteDict[name] = entry
        }

        return remoteDict.map { name, urls in
            Remote(
                name: name,
                fetchURL: urls.fetch ?? urls.push ?? "",
                pushURL: urls.push
            )
        }.sorted { $0.name < $1.name }
    }

    /// Fetch from remote
    func fetch(options: FetchOptions = FetchOptions(), at path: String) async throws {
        var args = ["fetch"]
        args.append(contentsOf: options.arguments)

        if let remote = options.remote {
            args.append(remote)
        }

        let result = await shellExecutor.execute("git", arguments: args, workingDirectory: path)

        guard result.exitCode == 0 else {
            throw GitError.fetchFailed(result.stderr)
        }
    }

    /// Pull from remote
    func pull(options: PullOptions = PullOptions(), at path: String) async throws {
        var args = ["pull"]
        args.append(contentsOf: options.arguments)
        args.append(options.remote)

        if let branch = options.branch {
            args.append(branch)
        }

        let result = await shellExecutor.execute("git", arguments: args, workingDirectory: path)

        guard result.exitCode == 0 else {
            throw GitError.pullFailed(result.stderr)
        }
    }

    /// Push to remote
    func push(options: PushOptions = PushOptions(), at path: String) async throws {
        var args = ["push"]
        args.append(contentsOf: options.arguments)
        args.append(options.remote)

        if let branch = options.branch {
            args.append(branch)
        }

        let result = await shellExecutor.execute("git", arguments: args, workingDirectory: path)

        guard result.exitCode == 0 else {
            throw GitError.pushFailed(result.stderr)
        }
    }

    // MARK: - Stash Operations

    /// Get all stashes
    func getStashes(at path: String) async throws -> [Stash] {
        let result = await shellExecutor.execute(
            "git",
            arguments: ["stash", "list", "--format=%gd|%H|%s|%ai"],
            workingDirectory: path
        )

        guard result.exitCode == 0 else {
            throw GitError.commandFailed("git stash list", result.stderr)
        }

        return result.stdout
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .enumerated()
            .compactMap { index, line -> Stash? in
                let parts = line.components(separatedBy: "|")
                guard parts.count >= 3 else { return nil }

                let sha = parts[1]
                let message = parts[2]
                let dateStr = parts.count > 3 ? parts[3] : nil
                let date = dateStr.flatMap { parseGitDate($0) } ?? Date()

                return Stash(
                    index: index,
                    message: message,
                    sha: sha,
                    date: date
                )
            }
    }

    /// Create a stash
    func stash(options: StashOptions = StashOptions(), at path: String) async throws -> Stash? {
        var args = ["stash"]
        args.append(contentsOf: options.arguments)

        let result = await shellExecutor.execute("git", arguments: args, workingDirectory: path)

        guard result.exitCode == 0 else {
            throw GitError.stashFailed(result.stderr)
        }

        // Check if anything was stashed
        if result.stdout.contains("No local changes to save") {
            return nil
        }

        // Get the new stash
        let stashes = try await getStashes(at: path)
        return stashes.first
    }

    /// Apply a stash
    func stashApply(options: StashApplyOptions = StashApplyOptions(), at path: String) async throws {
        var args = ["stash", "apply"]
        args.append(contentsOf: options.arguments)

        let result = await shellExecutor.execute("git", arguments: args, workingDirectory: path)

        // Exit code 1 with empty stderr can mean "nothing to apply" which is OK
        guard result.exitCode == 0 || (result.exitCode == 1 && result.stderr.isEmpty) else {
            throw GitError.stashApplyFailed(result.stderr.isEmpty ? "Failed to apply stash" : result.stderr)
        }
    }

    /// Pop a stash
    func stashPop(stashRef: String = "stash@{0}", at path: String) async throws {
        let result = await shellExecutor.execute(
            "git",
            arguments: ["stash", "pop", stashRef],
            workingDirectory: path
        )

        guard result.exitCode == 0 else {
            throw GitError.stashApplyFailed(result.stderr)
        }
    }

    /// Drop a stash
    func stashDrop(stashRef: String, at path: String) async throws {
        let result = await shellExecutor.execute(
            "git",
            arguments: ["stash", "drop", stashRef],
            workingDirectory: path
        )

        guard result.exitCode == 0 else {
            throw GitError.stashDropFailed(result.stderr)
        }
    }

    /// Get files changed in a stash (including untracked files)
    func getStashFiles(stashRef: String, at path: String) async throws -> [StashFile] {
        var allFiles: [StashFile] = []

        // 1. Get tracked file changes
        let result = await shellExecutor.execute(
            "git",
            arguments: ["stash", "show", "--name-status", stashRef],
            workingDirectory: path
        )

        if result.exitCode == 0 && !result.stdout.isEmpty {
            let trackedFiles = result.stdout
                .components(separatedBy: .newlines)
                .filter { !$0.isEmpty }
                .compactMap { line -> StashFile? in
                    let parts = line.split(separator: "\t", maxSplits: 1)
                    guard parts.count == 2 else { return nil }

                    let statusChar = String(parts[0]).trimmingCharacters(in: .whitespaces)
                    let filePath = String(parts[1])
                    let filename = URL(fileURLWithPath: filePath).lastPathComponent

                    let status: FileStatusType
                    switch statusChar {
                    case "A": status = .added
                    case "M": status = .modified
                    case "D": status = .deleted
                    case "R": status = .renamed
                    case "C": status = .copied
                    default: status = .modified
                    }

                    return StashFile(path: filePath, filename: filename, status: status)
                }
            allFiles.append(contentsOf: trackedFiles)
        }

        // 2. Get untracked files (stored in stash^3)
        let untrackedResult = await shellExecutor.execute(
            "git",
            arguments: ["show", "--name-status", "--format=", "\(stashRef)^3"],
            workingDirectory: path
        )

        if untrackedResult.exitCode == 0 && !untrackedResult.stdout.isEmpty {
            let untrackedFiles = untrackedResult.stdout
                .components(separatedBy: .newlines)
                .filter { !$0.isEmpty }
                .compactMap { line -> StashFile? in
                    let parts = line.split(separator: "\t", maxSplits: 1)
                    guard parts.count == 2 else { return nil }

                    let filePath = String(parts[1])
                    let filename = URL(fileURLWithPath: filePath).lastPathComponent

                    // Untracked files are always "added"
                    return StashFile(path: filePath, filename: filename, status: .added)
                }
            allFiles.append(contentsOf: untrackedFiles)
        }

        return allFiles
    }

    /// Get stash stat summary (additions/deletions)
    func getStashStats(stashRef: String, at path: String) async throws -> (additions: Int, deletions: Int) {
        let result = await shellExecutor.execute(
            "git",
            arguments: ["stash", "show", "--numstat", stashRef],
            workingDirectory: path
        )

        guard result.exitCode == 0 else {
            return (0, 0)
        }

        var totalAdditions = 0
        var totalDeletions = 0

        for line in result.stdout.components(separatedBy: .newlines) {
            let parts = line.split(separator: "\t")
            if parts.count >= 2 {
                totalAdditions += Int(parts[0]) ?? 0
                totalDeletions += Int(parts[1]) ?? 0
            }
        }

        return (totalAdditions, totalDeletions)
    }

    // MARK: - Diff Operations

    /// Get diff for a file
    /// Truncates output for very large diffs to prevent UI freeze
    func getDiff(for file: String? = nil, staged: Bool = false, at path: String) async throws -> String {
        var args = ["diff"]

        if staged {
            args.append("--cached")
        }

        if let file = file {
            args.append("--")
            args.append(file)
        }

        let result = await shellExecutor.execute("git", arguments: args, workingDirectory: path)

        // git diff returns exit code 0 for success, but sometimes has warnings in stderr
        // If we have stdout content, use it even if there are warnings
        if result.exitCode == 0 || !result.stdout.isEmpty {
            let output = result.stdout

            // Truncate very large diffs early (500KB max)
            let maxBytes = 500_000
            if output.utf8.count > maxBytes {
                let truncated = String(output.utf8.prefix(maxBytes)) ?? String(output.prefix(maxBytes / 4))
                return truncated + "\n\n... [Output truncated - file too large] ..."
            }

            return output
        }

        // Only throw if we have no output and an error
        let errorMessage = result.stderr.isEmpty ? "No diff output" : result.stderr
        throw GitError.commandFailed("git diff", errorMessage)
    }

    /// Get diff between two refs
    func getDiff(from: String, to: String, at path: String) async throws -> String {
        let result = await shellExecutor.execute(
            "git",
            arguments: ["diff", from, to],
            workingDirectory: path
        )

        guard result.exitCode == 0 else {
            throw GitError.commandFailed("git diff", result.stderr)
        }

        return result.stdout
    }

    /// Get files changed in a specific commit
    func getCommitFiles(sha: String, at path: String) async throws -> [CommitFile] {
        let result = await shellExecutor.execute(
            "git",
            arguments: ["diff-tree", "--no-commit-id", "--name-status", "-r", "--numstat", sha],
            workingDirectory: path
        )

        guard result.exitCode == 0 else {
            throw GitError.commandFailed("git diff-tree", result.stderr)
        }

        // First get name-status for file status
        let statusResult = await shellExecutor.execute(
            "git",
            arguments: ["diff-tree", "--no-commit-id", "--name-status", "-r", sha],
            workingDirectory: path
        )

        // Then get numstat for additions/deletions
        let numstatResult = await shellExecutor.execute(
            "git",
            arguments: ["diff-tree", "--no-commit-id", "--numstat", "-r", sha],
            workingDirectory: path
        )

        var fileStats: [String: (additions: Int, deletions: Int)] = [:]
        for line in numstatResult.stdout.components(separatedBy: .newlines) where !line.isEmpty {
            let parts = line.split(separator: "\t")
            if parts.count >= 3 {
                let additions = Int(parts[0]) ?? 0
                let deletions = Int(parts[1]) ?? 0
                let filePath = String(parts[2])
                fileStats[filePath] = (additions, deletions)
            }
        }

        var files: [CommitFile] = []
        for line in statusResult.stdout.components(separatedBy: .newlines) where !line.isEmpty {
            let parts = line.split(separator: "\t", maxSplits: 1)
            guard parts.count >= 2 else { continue }

            let statusChar = String(parts[0])
            let filePath = String(parts[1])

            let status: CommitFile.CommitFileStatus
            switch statusChar.first {
            case "A": status = .added
            case "M": status = .modified
            case "D": status = .deleted
            case "R": status = .renamed
            default: status = .modified
            }

            let stats = fileStats[filePath] ?? (0, 0)
            files.append(CommitFile(
                path: filePath,
                status: status,
                additions: stats.additions,
                deletions: stats.deletions
            ))
        }

        return files
    }

    /// Get diff for a specific file in a commit
    /// Truncates output for very large diffs to prevent UI freeze
    func getCommitFileDiff(sha: String, filePath: String, at path: String) async throws -> String {
        let result = await shellExecutor.execute(
            "git",
            arguments: ["diff", "\(sha)^", sha, "--", filePath],
            workingDirectory: path
        )

        // For initial commits (no parent), try without ^
        var output: String
        if result.exitCode != 0 {
            let fallbackResult = await shellExecutor.execute(
                "git",
                arguments: ["show", sha, "--format=", "--", filePath],
                workingDirectory: path
            )
            output = fallbackResult.stdout
        } else {
            output = result.stdout
        }

        // Truncate very large diffs early (500KB max)
        let maxBytes = 500_000
        if output.utf8.count > maxBytes {
            let truncated = String(output.utf8.prefix(maxBytes)) ?? String(output.prefix(maxBytes / 4))
            return truncated + "\n\n... [Output truncated - file too large] ..."
        }

        return output
    }

    /// Stream diff for a specific file in a commit
    /// Uses `git show` to stream content, allowing for early termination/truncation on large files
    nonisolated func getCommitFileDiffStreaming(
        sha: String,
        filePath: String,
        at path: String
    ) -> AsyncThrowingStream<String, Error> {
        return shellExecutor.executeStreaming(
            "git",
            arguments: ["show", sha, "--format=", "--", filePath],
            workingDirectory: path,
            bufferSize: 100
        )
    }

    // MARK: - Merge Operations

    /// Merge a branch
    func merge(
        branch: String,
        options: MergeOptions = MergeOptions(),
        at path: String
    ) async throws {
        var args = ["merge"]

        if options.noFastForward {
            args.append("--no-ff")
        }

        if options.squash {
            args.append("--squash")
        }

        if let message = options.commitMessage {
            args.append("-m")
            args.append(message)
        }

        args.append(branch)

        let result = await shellExecutor.execute("git", arguments: args, workingDirectory: path)

        guard result.exitCode == 0 else {
            if result.stderr.contains("CONFLICT") || result.stdout.contains("CONFLICT") {
                throw GitError.mergeConflict(result.stdout + result.stderr)
            }
            throw GitError.mergeFailed(result.stderr)
        }
    }

    /// Abort a merge
    func mergeAbort(at path: String) async throws {
        let result = await shellExecutor.execute(
            "git",
            arguments: ["merge", "--abort"],
            workingDirectory: path
        )

        guard result.exitCode == 0 else {
            throw GitError.mergeAbortFailed(result.stderr)
        }
    }

    // MARK: - Rebase Operations

    /// Rebase onto a branch
    func rebase(onto branch: String, options: RebaseOptions = RebaseOptions(), at path: String) async throws {
        var args = ["rebase"]

        if options.interactive {
            args.append("-i")
        }

        if options.autosquash {
            args.append("--autosquash")
        }

        if let onto = options.onto {
            args.append("--onto")
            args.append(onto)
        }

        args.append(branch)

        let result = await shellExecutor.execute("git", arguments: args, workingDirectory: path)

        guard result.exitCode == 0 else {
            if result.stderr.contains("CONFLICT") || result.stdout.contains("CONFLICT") {
                throw GitError.rebaseConflict(result.stdout + result.stderr)
            }
            throw GitError.rebaseFailed(result.stderr)
        }
    }

    /// Continue a rebase
    func rebaseContinue(at path: String) async throws {
        let result = await shellExecutor.execute(
            "git",
            arguments: ["rebase", "--continue"],
            workingDirectory: path
        )

        guard result.exitCode == 0 else {
            throw GitError.rebaseFailed(result.stderr)
        }
    }

    /// Abort a rebase
    func rebaseAbort(at path: String) async throws {
        let result = await shellExecutor.execute(
            "git",
            arguments: ["rebase", "--abort"],
            workingDirectory: path
        )

        guard result.exitCode == 0 else {
            throw GitError.rebaseAbortFailed(result.stderr)
        }
    }

    // MARK: - Worktree Operations

    /// List all worktrees
    func listWorktrees(at path: String) async throws -> [Worktree] {
        let result = await shellExecutor.execute(
            "git",
            arguments: ["worktree", "list", "--porcelain"],
            workingDirectory: path
        )

        guard result.exitCode == 0 else {
            throw GitError.commandFailed("git worktree list", result.stderr)
        }

        return Worktree.parseFromPorcelain(result.stdout)
    }

    /// Add a new worktree
    func addWorktree(
        path worktreePath: String,
        branch: String? = nil,
        newBranch: String? = nil,
        force: Bool = false,
        detach: Bool = false,
        at repoPath: String
    ) async throws -> Worktree {
        var args = ["worktree", "add"]

        if force {
            args.append("--force")
        }

        if detach {
            args.append("--detach")
        }

        if let newBranch = newBranch {
            args.append("-b")
            args.append(newBranch)
        }

        args.append(worktreePath)

        if let branch = branch {
            args.append(branch)
        }

        let result = await shellExecutor.execute("git", arguments: args, workingDirectory: repoPath)

        guard result.exitCode == 0 else {
            throw GitError.worktreeAddFailed(worktreePath, result.stderr)
        }

        // Get the new worktree
        let worktrees = try await listWorktrees(at: repoPath)
        guard let newWorktree = worktrees.first(where: { $0.path == worktreePath }) else {
            throw GitError.worktreeAddFailed(worktreePath, "Could not find created worktree")
        }

        return newWorktree
    }

    /// Remove a worktree
    func removeWorktree(path worktreePath: String, force: Bool = false, at repoPath: String) async throws {
        var args = ["worktree", "remove"]

        if force {
            args.append("--force")
        }

        args.append(worktreePath)

        let result = await shellExecutor.execute("git", arguments: args, workingDirectory: repoPath)

        guard result.exitCode == 0 else {
            throw GitError.worktreeRemoveFailed(worktreePath, result.stderr)
        }
    }

    /// Lock a worktree to prevent removal
    func lockWorktree(path worktreePath: String, reason: String? = nil, at repoPath: String) async throws {
        var args = ["worktree", "lock"]

        if let reason = reason {
            args.append("--reason")
            args.append(reason)
        }

        args.append(worktreePath)

        let result = await shellExecutor.execute("git", arguments: args, workingDirectory: repoPath)

        guard result.exitCode == 0 else {
            throw GitError.worktreeLockFailed(worktreePath, result.stderr)
        }
    }

    /// Unlock a worktree
    func unlockWorktree(path worktreePath: String, at repoPath: String) async throws {
        let result = await shellExecutor.execute(
            "git",
            arguments: ["worktree", "unlock", worktreePath],
            workingDirectory: repoPath
        )

        guard result.exitCode == 0 else {
            throw GitError.worktreeUnlockFailed(worktreePath, result.stderr)
        }
    }

    /// Prune stale worktrees
    func pruneWorktrees(dryRun: Bool = false, at path: String) async throws -> [String] {
        var args = ["worktree", "prune"]

        if dryRun {
            args.append("--dry-run")
        }

        args.append("-v")

        let result = await shellExecutor.execute("git", arguments: args, workingDirectory: path)

        guard result.exitCode == 0 else {
            throw GitError.commandFailed("git worktree prune", result.stderr)
        }

        // Parse output to get list of pruned worktrees
        return result.stdout
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
    }

    // MARK: - Helper Methods

    /// Resolve a reference to its SHA
    func resolveSHA(for ref: String, at path: String) async throws -> String {
        let result = await shellExecutor.execute(
            "git",
            arguments: ["rev-parse", ref],
            workingDirectory: path
        )

        guard result.exitCode == 0 else {
            throw GitError.refNotFound(ref)
        }

        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Parse tracking info string
    private func parseTrackInfo(_ info: String) -> UpstreamInfo? {
        guard !info.isEmpty else { return nil }

        var ahead = 0
        var behind = 0

        // Parse [ahead N, behind M] or [ahead N] or [behind M]
        if let aheadMatch = info.range(of: #"ahead (\d+)"#, options: .regularExpression) {
            let numStr = info[aheadMatch].replacingOccurrences(of: "ahead ", with: "")
            ahead = Int(numStr) ?? 0
        }

        if let behindMatch = info.range(of: #"behind (\d+)"#, options: .regularExpression) {
            let numStr = info[behindMatch].replacingOccurrences(of: "behind ", with: "")
            behind = Int(numStr) ?? 0
        }

        return UpstreamInfo(name: "", ahead: ahead, behind: behind)
    }

    // MARK: - V2 Optimized Methods (Porcelain v2, NUL separators, streaming)

    /// Get repository status using porcelain v2 format with NUL separators
    /// More robust with special characters in filenames and includes branch tracking info
    func getStatusV2(at path: String) async throws -> RepositoryStatus {
        let signpostID = OSSignpostID(log: gitLog)
        os_signpost(.begin, log: gitLog, name: "git.status.v2", signpostID: signpostID)
        defer { os_signpost(.end, log: gitLog, name: "git.status.v2", signpostID: signpostID) }

        let result = await shellExecutor.execute(
            "git",
            arguments: [
                "status",
                "--porcelain=v2",
                "-b",           // Include branch info
                "-z",           // NUL-separated
                "-uall"         // Show all untracked files
            ],
            workingDirectory: path
        )

        guard result.exitCode == 0 else {
            throw GitError.commandFailed("git status", result.stderr)
        }

        return parseStatusV2(result.stdout)
    }

    private func parseStatusV2(_ output: String) -> RepositoryStatus {
        var status = RepositoryStatus()

        // Split by NUL character
        let entries = output.split(separator: "\0", omittingEmptySubsequences: false)

        var i = 0
        while i < entries.count {
            let entry = String(entries[i])
            guard !entry.isEmpty else {
                i += 1
                continue
            }

            // Branch headers: # branch.oid <sha>, # branch.head <name>, etc.
            if entry.hasPrefix("# ") {
                i += 1
                continue
            }

            // Changed entries (ordinary): 1 <XY> <sub> <mH> <mI> <mW> <hH> <hI> <path>
            if entry.hasPrefix("1 ") {
                let parts = entry.split(separator: " ", maxSplits: 8, omittingEmptySubsequences: false)
                if parts.count >= 9 {
                    let xy = String(parts[1])
                    let indexStatus = xy.first ?? "."
                    let worktreeStatus = xy.count > 1 ? xy[xy.index(xy.startIndex, offsetBy: 1)] : Character(".")
                    let filePath = String(parts[8])

                    // Index (staged) changes
                    if indexStatus != "." {
                        if let statusType = statusTypeFromCharV2(indexStatus) {
                            status.staged.append(FileStatus(path: filePath, status: statusType))
                        }
                    }

                    // Worktree (unstaged) changes
                    if worktreeStatus != "." {
                        if let statusType = statusTypeFromCharV2(worktreeStatus) {
                            status.unstaged.append(FileStatus(path: filePath, status: statusType))
                        }
                    }
                }
                i += 1
                continue
            }

            // Renamed/copied entries: 2 <XY> <sub> <mH> <mI> <mW> <hH> <hI> <X><score> <path><sep><origPath>
            if entry.hasPrefix("2 ") {
                let parts = entry.split(separator: " ", maxSplits: 9, omittingEmptySubsequences: false)
                if parts.count >= 10 {
                    let xy = String(parts[1])
                    let indexStatus = xy.first ?? "."
                    let filePath = String(parts[9])

                    if indexStatus == "R" {
                        status.staged.append(FileStatus(path: filePath, status: .renamed))
                    } else if indexStatus == "C" {
                        status.staged.append(FileStatus(path: filePath, status: .copied))
                    }
                }
                // Skip the original path entry that follows
                i += 2
                continue
            }

            // Untracked: ? <path>
            if entry.hasPrefix("? ") {
                let filePath = String(entry.dropFirst(2))
                status.untracked.append(filePath)
                i += 1
                continue
            }

            // Ignored: ! <path>
            if entry.hasPrefix("! ") {
                i += 1
                continue
            }

            // Unmerged (conflict): u <XY> <sub> <m1> <m2> <m3> <mW> <h1> <h2> <h3> <path>
            if entry.hasPrefix("u ") {
                let parts = entry.split(separator: " ", maxSplits: 10, omittingEmptySubsequences: false)
                if parts.count >= 11 {
                    let filePath = String(parts[10])
                    status.conflicted.append(FileStatus(path: filePath, status: .unmerged))
                }
                i += 1
                continue
            }

            i += 1
        }

        return status
    }

    private func statusTypeFromCharV2(_ char: Character) -> FileStatusType? {
        switch char {
        case "M": return .modified
        case "T": return .modified  // Type changed
        case "A": return .added
        case "D": return .deleted
        case "R": return .renamed
        case "C": return .copied
        case "U": return .unmerged
        default: return nil
        }
    }

    /// Get commits with NUL-separated format to safely handle messages with special characters
    func getCommitsV2(
        at path: String,
        branch: String? = nil,
        limit: Int = 100,
        skip: Int = 0
    ) async throws -> [Commit] {
        let signpostID = OSSignpostID(log: gitLog)
        os_signpost(.begin, log: gitLog, name: "git.commits.v2", signpostID: signpostID)
        defer { os_signpost(.end, log: gitLog, name: "git.commits.v2", signpostID: signpostID) }

        // Use %x00 as field separator (NUL byte) and %x01 as record separator
        // Format: sha, parents, author name, author email, author date, committer name, committer email, committer date, subject
        var args = [
            "log",
            "--format=%H%x00%P%x00%an%x00%ae%x00%ai%x00%cn%x00%ce%x00%ci%x00%s%x01",
            "-n", String(limit),
            "--skip", String(skip)
        ]

        if let branch = branch {
            args.append(branch)
        }

        let result = await shellExecutor.execute("git", arguments: args, workingDirectory: path)

        guard result.exitCode == 0 else {
            throw GitError.commandFailed("git log", result.stderr)
        }

        return parseCommitsNUL(result.stdout)
    }

    private func parseCommitsNUL(_ output: String) -> [Commit] {
        var commits: [Commit] = []

        // Split by record separator (0x01) first, then by field separator (0x00)
        let records = output.components(separatedBy: "\u{01}")

        for record in records {
            let trimmed = record.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let fields = trimmed.components(separatedBy: "\u{00}")
            guard fields.count >= 9 else { continue }

            let sha = fields[0]
            guard sha.count == 40 else { continue }

            let parentSHAs = fields[1].split(separator: " ").map(String.init)
            let authorName = fields[2]
            let authorEmail = fields[3]
            let authorDateStr = fields[4]
            let committerName = fields[5]
            let committerEmail = fields[6]
            let committerDateStr = fields[7]
            let subject = fields[8]

            let authorDate = parseGitDate(authorDateStr) ?? Date()
            let committerDate = parseGitDate(committerDateStr) ?? Date()

            commits.append(Commit(
                sha: sha,
                message: subject.trimmingCharacters(in: .whitespacesAndNewlines),
                author: authorName,
                authorEmail: authorEmail,
                authorDate: authorDate,
                committer: committerName,
                committerEmail: committerEmail,
                committerDate: committerDate,
                parentSHAs: parentSHAs
            ))
        }

        return commits
    }

    /// Stream diff output for large files with backpressure support
    /// Returns an AsyncThrowingStream that yields lines as they become available
    nonisolated func getDiffStreaming(
        for file: String? = nil,
        staged: Bool = false,
        at path: String
    ) -> AsyncThrowingStream<String, Error> {
        var args = ["diff", "--no-color", "--no-ext-diff"]

        if staged {
            args.append("--cached")
        }

        if let file = file {
            args.append("--")
            args.append(file)
        }

        return shellExecutor.executeStreaming(
            "git",
            arguments: args,
            workingDirectory: path,
            bufferSize: 100  // Buffer 100 lines before applying backpressure
        )
    }

    /// Get files changed in a commit with unified parsing (single command where possible)
    func getCommitFilesV2(sha: String, at path: String) async throws -> [CommitFile] {
        let signpostID = OSSignpostID(log: gitLog)
        os_signpost(.begin, log: gitLog, name: "git.commit-files.v2", signpostID: signpostID)
        defer { os_signpost(.end, log: gitLog, name: "git.commit-files.v2", signpostID: signpostID) }

        // Run both commands in parallel
        async let statusTask = shellExecutor.execute(
            "git",
            arguments: ["diff-tree", "--no-commit-id", "-r", "-z", "--name-status", sha],
            workingDirectory: path
        )
        async let numstatTask = shellExecutor.execute(
            "git",
            arguments: ["diff-tree", "--no-commit-id", "-r", "-z", "--numstat", sha],
            workingDirectory: path
        )

        let statusResult = await statusTask
        let numstatResult = await numstatTask

        guard statusResult.exitCode == 0 else {
            throw GitError.commandFailed("git diff-tree", statusResult.stderr)
        }

        // Parse numstat into dictionary: path -> (additions, deletions)
        var fileStats: [String: (Int, Int)] = [:]
        let numstatParts = numstatResult.stdout.split(separator: "\0", omittingEmptySubsequences: false)
        var j = 0
        while j + 2 < numstatParts.count {
            let addStr = String(numstatParts[j])
            let delStr = String(numstatParts[j + 1])
            let filePath = String(numstatParts[j + 2])

            // Binary files show "-" for additions/deletions
            let additions = Int(addStr) ?? 0
            let deletions = Int(delStr) ?? 0
            fileStats[filePath] = (additions, deletions)
            j += 3
        }

        // Parse name-status: pairs of (status, path)
        var files: [CommitFile] = []
        let statusParts = statusResult.stdout.split(separator: "\0", omittingEmptySubsequences: false)
        var i = 0
        while i + 1 < statusParts.count {
            let statusChar = String(statusParts[i])
            let filePath = String(statusParts[i + 1])

            guard !statusChar.isEmpty && !filePath.isEmpty else {
                i += 2
                continue
            }

            let status: CommitFile.CommitFileStatus
            switch statusChar.first {
            case "A": status = .added
            case "M": status = .modified
            case "D": status = .deleted
            case "R": status = .renamed
            case "C": status = .copied
            case "T": status = .modified  // Type changed
            default: status = .modified
            }

            let stats = fileStats[filePath] ?? (0, 0)
            files.append(CommitFile(
                path: filePath,
                status: status,
                additions: stats.0,
                deletions: stats.1
            ))

            i += 2
        }

        return files
    }

    /// Get branches using for-each-ref with NUL separators for robustness
    func getBranchesV2(at path: String) async throws -> [Branch] {
        let signpostID = OSSignpostID(log: gitLog)
        os_signpost(.begin, log: gitLog, name: "git.branches.v2", signpostID: signpostID)
        defer { os_signpost(.end, log: gitLog, name: "git.branches.v2", signpostID: signpostID) }

        let result = await shellExecutor.execute(
            "git",
            arguments: [
                "for-each-ref",
                "--format=%(refname:short)%00%(objectname)%00%(HEAD)%00%(upstream:short)%00%(upstream:track)%00",
                "refs/heads"
            ],
            workingDirectory: path
        )

        guard result.exitCode == 0 else {
            throw GitError.commandFailed("git for-each-ref", result.stderr)
        }

        _ = try? await getHeadSHA(at: path)
        var branches: [Branch] = []

        // Each branch record: name, sha, head marker, upstream, track info, then empty (separator)
        let parts = result.stdout.split(separator: "\0", omittingEmptySubsequences: false)
        var i = 0
        while i + 4 < parts.count {
            let name = String(parts[i])
            let sha = String(parts[i + 1])
            let isHeadMarker = String(parts[i + 2])
            let upstream = String(parts[i + 3])
            let trackInfo = String(parts[i + 4])

            guard !name.isEmpty else {
                i += 6
                continue
            }

            let isHead = isHeadMarker == "*"  // Only use git's HEAD marker, not SHA comparison
            let upstreamBranch = upstream.isEmpty ? nil : upstream
            let upstreamInfo = trackInfo.isEmpty ? nil : parseTrackInfo(trackInfo)

            branches.append(Branch(
                name: name,
                fullName: "refs/heads/\(name)",
                isRemote: false,
                isHead: isHead,
                trackingBranch: upstreamBranch,
                targetSHA: sha,
                upstream: upstreamInfo
            ))

            i += 6  // 5 fields + empty separator
        }

        return branches
    }
}

/// Parse git date format
private func parseGitDate(_ dateString: String) -> Date? {
    let formatters = [
        "yyyy-MM-dd HH:mm:ss Z",
        "yyyy-MM-dd HH:mm:ss",
        "EEE MMM d HH:mm:ss yyyy Z"
    ]

    for format in formatters {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "en_US_POSIX")

        if let date = formatter.date(from: dateString) {
            return date
        }
    }

    return nil
}

// MARK: - Git Errors

enum GitError: LocalizedError {
    case notARepository(String)
    case noCommits
    case initFailed(String)
    case cloneFailed(String)
    case commandFailed(String, String)
    case branchCreationFailed(String, String)
    case branchDeletionFailed(String, String)
    case checkoutFailed(String, String)
    case commitFailed(String)
    case stageFailed(String)
    case unstageFailed(String)
    case discardFailed(String)
    case tagCreationFailed(String, String)
    case tagDeletionFailed(String, String)
    case fetchFailed(String)
    case pullFailed(String)
    case pushFailed(String)
    case stashFailed(String)
    case stashApplyFailed(String)
    case stashDropFailed(String)
    case mergeFailed(String)
    case mergeConflict(String)
    case mergeAbortFailed(String)
    case rebaseFailed(String)
    case rebaseConflict(String)
    case rebaseAbortFailed(String)
    case refNotFound(String)
    case worktreeAddFailed(String, String)
    case worktreeRemoveFailed(String, String)
    case worktreeLockFailed(String, String)
    case worktreeUnlockFailed(String, String)

    var errorDescription: String? {
        switch self {
        case .notARepository(let path):
            return "'\(path)' is not a Git repository"
        case .noCommits:
            return "Repository has no commits"
        case .initFailed(let message):
            return "Failed to initialize repository: \(message)"
        case .cloneFailed(let message):
            return "Failed to clone repository: \(message)"
        case .commandFailed(let command, let message):
            return "\(command) failed: \(message)"
        case .branchCreationFailed(let name, let message):
            return "Failed to create branch '\(name)': \(message)"
        case .branchDeletionFailed(let name, let message):
            return "Failed to delete branch '\(name)': \(message)"
        case .checkoutFailed(let ref, let message):
            return "Failed to checkout '\(ref)': \(message)"
        case .commitFailed(let message):
            return "Commit failed: \(message)"
        case .stageFailed(let message):
            return "Failed to stage files: \(message)"
        case .unstageFailed(let message):
            return "Failed to unstage files: \(message)"
        case .discardFailed(let message):
            return "Failed to discard changes: \(message)"
        case .tagCreationFailed(let name, let message):
            return "Failed to create tag '\(name)': \(message)"
        case .tagDeletionFailed(let name, let message):
            return "Failed to delete tag '\(name)': \(message)"
        case .fetchFailed(let message):
            return "Fetch failed: \(message)"
        case .pullFailed(let message):
            return "Pull failed: \(message)"
        case .pushFailed(let message):
            return "Push failed: \(message)"
        case .stashFailed(let message):
            return "Stash failed: \(message)"
        case .stashApplyFailed(let message):
            return "Failed to apply stash: \(message)"
        case .stashDropFailed(let message):
            return "Failed to drop stash: \(message)"
        case .mergeFailed(let message):
            return "Merge failed: \(message)"
        case .mergeConflict(let message):
            return "Merge conflict: \(message)"
        case .mergeAbortFailed(let message):
            return "Failed to abort merge: \(message)"
        case .rebaseFailed(let message):
            return "Rebase failed: \(message)"
        case .rebaseConflict(let message):
            return "Rebase conflict: \(message)"
        case .rebaseAbortFailed(let message):
            return "Failed to abort rebase: \(message)"
        case .refNotFound(let ref):
            return "Reference '\(ref)' not found"
        case .worktreeAddFailed(let path, let message):
            return "Failed to add worktree at '\(path)': \(message)"
        case .worktreeRemoveFailed(let path, let message):
            return "Failed to remove worktree at '\(path)': \(message)"
        case .worktreeLockFailed(let path, let message):
            return "Failed to lock worktree at '\(path)': \(message)"
        case .worktreeUnlockFailed(let path, let message):
            return "Failed to unlock worktree at '\(path)': \(message)"
        }
    }
    
    // MARK: - Error Recovery Suggestions
    
    /// Suggested fix for the error with title and command/action
    var suggestedFix: (title: String, command: String?, hint: String)? {
        switch self {
        // Push errors
        case .pushFailed(let msg):
            if msg.contains("non-fast-forward") || msg.contains("fetch first") || msg.contains("rejected") {
                return ("Pull First", "git pull --rebase", "Remote has changes you don't have locally. Pull and rebase first.")
            }
            if msg.contains("permission denied") || msg.contains("403") {
                return ("Check Permissions", nil, "You may not have push access to this repository. Check your credentials.")
            }
            if msg.contains("no upstream") || msg.contains("no tracking") {
                return ("Set Upstream", "git push -u origin HEAD", "No upstream branch configured. Push with -u to set tracking.")
            }
            return nil
            
        // Pull errors
        case .pullFailed(let msg):
            if msg.contains("uncommitted changes") || msg.contains("would be overwritten") {
                return ("Stash Changes", "git stash", "You have uncommitted changes. Stash them first, then pull.")
            }
            if msg.contains("diverged") {
                return ("Rebase or Merge", "git pull --rebase", "Your branch has diverged from remote. Try pull with rebase.")
            }
            if msg.contains("Connection") || msg.contains("Could not resolve") {
                return ("Check Connection", nil, "Network error. Check your internet connection and try again.")
            }
            return nil
            
        // Fetch errors
        case .fetchFailed(let msg):
            if msg.contains("Connection") || msg.contains("Could not resolve") {
                return ("Check Connection", nil, "Network error. Check your internet connection.")
            }
            if msg.contains("authentication") || msg.contains("permission") {
                return ("Re-authenticate", nil, "Authentication failed. Check your credentials in Settings.")
            }
            return nil
            
        // Checkout errors
        case .checkoutFailed(_, let msg):
            if msg.contains("uncommitted changes") || msg.contains("would be overwritten") {
                return ("Stash or Commit", "git stash", "You have uncommitted changes. Stash or commit them first.")
            }
            if msg.contains("pathspec") || msg.contains("did not match") {
                return ("Fetch First", "git fetch --all", "Branch not found locally. Try fetching from remote first.")
            }
            return nil
            
        // Merge errors
        case .mergeFailed(let msg):
            if msg.contains("uncommitted changes") {
                return ("Stash Changes", "git stash", "Stash your changes before merging.")
            }
            return ("Abort Merge", "git merge --abort", "Merge failed. You can abort and try again.")
            
        case .mergeConflict:
            return ("Resolve Conflicts", nil, "Merge has conflicts. Resolve them in the conflicted files, then commit.")
            
        // Rebase errors
        case .rebaseFailed(let msg):
            if msg.contains("uncommitted changes") {
                return ("Stash Changes", "git stash", "Stash your changes before rebasing.")
            }
            return ("Abort Rebase", "git rebase --abort", "Rebase failed. You can abort and try again.")
            
        case .rebaseConflict:
            return ("Resolve or Skip", "git rebase --continue", "Resolve conflicts, stage files, then continue rebase. Or skip with --skip.")
            
        // Stash errors
        case .stashApplyFailed(let msg):
            if msg.contains("conflict") {
                return ("Resolve Conflicts", nil, "Stash apply has conflicts. Resolve them manually.")
            }
            if msg.contains("uncommitted changes") {
                return ("Commit First", nil, "Commit or stash current changes before applying another stash.")
            }
            return nil
            
        // Commit errors
        case .commitFailed(let msg):
            if msg.contains("nothing to commit") {
                return ("Stage Files", "git add .", "No staged changes to commit. Stage some files first.")
            }
            if msg.contains("empty message") || msg.contains("Aborting commit") {
                return ("Add Message", nil, "Commit message is required.")
            }
            return nil
            
        // Stage errors
        case .stageFailed(let msg):
            if msg.contains("pathspec") || msg.contains("did not match") {
                return ("Check Path", nil, "File not found. It may have been moved or deleted.")
            }
            return nil
            
        default:
            return nil
        }
    }
}
