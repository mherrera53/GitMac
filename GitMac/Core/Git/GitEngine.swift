import Foundation

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

        let currentHead = try? await getHeadSHA(at: path)

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
                    isHead: isHead || sha == currentHead,
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
                let remoteName = pathParts.count > 0 ? String(pathParts[0]) : "origin"
                _ = pathParts.count > 1 ? String(pathParts[1]) : fullName

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
        let result = await shellExecutor.execute(
            "git",
            arguments: ["status", "--porcelain=v1", "-uall"],
            workingDirectory: path
        )

        guard result.exitCode == 0 else {
            throw GitError.commandFailed("git status", result.stderr)
        }

        var status = RepositoryStatus()

        for line in result.stdout.components(separatedBy: .newlines) where !line.isEmpty {
            guard line.count >= 3 else { continue }

            let index = line.index(line.startIndex, offsetBy: 0)
            let worktree = line.index(line.startIndex, offsetBy: 1)
            let path = String(line.dropFirst(3))

            let indexStatus = String(line[index])
            let worktreeStatus = String(line[worktree])

            // Handle staged changes
            if indexStatus != " " && indexStatus != "?" {
                if let statusType = FileStatusType(rawValue: indexStatus) {
                    status.staged.append(FileStatus(path: path, status: statusType))
                }
            }

            // Handle unstaged changes
            if worktreeStatus != " " && worktreeStatus != "?" {
                if let statusType = FileStatusType(rawValue: worktreeStatus) {
                    status.unstaged.append(FileStatus(path: path, status: statusType))
                }
            }

            // Handle untracked files
            if indexStatus == "?" && worktreeStatus == "?" {
                status.untracked.append(path)
            }

            // Handle conflicts
            if indexStatus == "U" || worktreeStatus == "U" {
                status.conflicted.append(FileStatus(path: path, status: .unmerged))
            }
        }

        return status
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

        guard result.exitCode == 0 else {
            throw GitError.stashApplyFailed(result.stderr)
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

    // MARK: - Diff Operations

    /// Get diff for a file
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

        guard result.exitCode == 0 else {
            throw GitError.commandFailed("git diff", result.stderr)
        }

        return result.stdout
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
    func getCommitFileDiff(sha: String, filePath: String, at path: String) async throws -> String {
        let result = await shellExecutor.execute(
            "git",
            arguments: ["diff", "\(sha)^", sha, "--", filePath],
            workingDirectory: path
        )

        // For initial commits (no parent), try without ^
        if result.exitCode != 0 {
            let fallbackResult = await shellExecutor.execute(
                "git",
                arguments: ["show", sha, "--format=", "--", filePath],
                workingDirectory: path
            )
            return fallbackResult.stdout
        }

        return result.stdout
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
}
