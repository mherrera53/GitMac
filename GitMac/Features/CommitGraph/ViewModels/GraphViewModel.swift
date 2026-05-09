import SwiftUI

// MARK: - Graph View Model
@MainActor
@Observable
class GraphViewModel {
    var nodes: [GraphNode] = []
    var stashNodes: [StashNode] = []
    var timelineItems: [TimelineItem] = []
    var isLoading = false
    var hasMore = true

    var hasUncommittedChanges = false
    var stagedCount = 0
    var unstagedCount = 0

    var branches: [Branch] = []

    var currentUserEmail: String?

    var maxLane: Int = 0

    var minimapNodes: [MinimapCommitNode] = []
    var totalCommitCount: Int = 0

    private(set) var commitsBySHA: [String: Commit] = [:]

    private let engine = GitEngine()
    private var path: String?
    private var page = 0
    private var commits: [Commit] = []
    private var branchHeads: [String: String] = [:]
    private var currentLoadTask: Task<Void, Never>?

    func load(at p: String) async {
        currentLoadTask?.cancel()
        isLoading = true
        path = p
        page = 0

        do {
            // Sequential but fast (~50ms total for all git ops)
            let loadedBranches = try await engine.getBranches(at: p)
            let loadedCommits = try await engine.getCommitsV2(at: p, limit: 100)

            guard !Task.isCancelled else { return }

            // Prepare branch heads map
            var newBranchHeads: [String: String] = [:]
            for branch in loadedBranches {
                if newBranchHeads[branch.targetSHA] == nil {
                    newBranchHeads[branch.targetSHA] = branch.name
                }
            }

            // Build graph off main thread (CPU-bound)
            commits = loadedCommits
            branchHeads = newBranchHeads
            let newNodes = await buildNodes()

            guard !Task.isCancelled else { return }

            let newMaxLane = newNodes.reduce(0) { maxVal, node in
                let nodeLanes = [node.lane] + Array(node.passThroughLanes) + node.curvesToBottom
                return max(maxVal, nodeLanes.max() ?? 0)
            }

            // Update UI -- show graph immediately
            branches = loadedBranches
            hasMore = loadedCommits.count == 100
            nodes = newNodes
            maxLane = newMaxLane
            buildTimeline()
            isLoading = false

            // Load secondary data after graph is visible (non-blocking)
            Task {
                let status = try? await engine.getStatus(at: p)
                if let status {
                    stagedCount = status.staged.count
                    unstagedCount = status.unstaged.count + status.untracked.count
                    hasUncommittedChanges = stagedCount > 0 || unstagedCount > 0
                    buildTimeline()
                }

                let stashes = try? await engine.getStashes(at: p)
                if let stashes {
                    stashNodes = stashes.map { StashNode(id: "stash-\($0.index)", stash: $0) }
                    buildTimeline()
                }

                let emailResult = await ShellExecutor.shared.execute(
                    "git", arguments: ["config", "user.email"], workingDirectory: p
                )
                if emailResult.exitCode == 0 {
                    currentUserEmail = emailResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }

            Task.detached(priority: .utility) { await self.loadMinimapData(at: p) }
            Task.detached(priority: .utility) { await self.loadAvatarsFromGitHub(at: p) }
        } catch {
            isLoading = false
        }
    }

    /// Load lightweight commit data for the minimap (SHA + parent count only)
    private func loadMinimapData(at repoPath: String) async {
        let result = await ShellExecutor.shared.execute(
            "git",
            arguments: ["log", "--all", "--format=%H %P"],
            workingDirectory: repoPath
        )
        guard result.exitCode == 0 else { return }

        let lines = result.stdout.components(separatedBy: "\n").filter { !$0.isEmpty }

        // First pass: build SHA -> index + lane maps
        var shaToIndex: [String: Int] = [:]
        var shaToLane: [String: Int] = [:]
        var shaToParents: [String: [String]] = [:]
        var nextLane = 0

        for (index, line) in lines.enumerated() {
            let parts = line.components(separatedBy: " ")
            let sha = parts[0]
            let parents = Array(parts.dropFirst())

            shaToIndex[sha] = index
            shaToParents[sha] = parents

            // Assign lane: reuse first parent's lane or create new
            let lane: Int
            if let firstParent = parents.first, let parentLane = shaToLane[firstParent] {
                lane = parentLane
            } else {
                lane = nextLane % 6
                nextLane += 1
            }
            shaToLane[sha] = lane

            // Assign lanes for secondary parents (merge sources)
            for secondaryParent in parents.dropFirst() {
                if shaToLane[secondaryParent] == nil {
                    shaToLane[secondaryParent] = nextLane % 6
                    nextLane += 1
                }
            }
        }

        // Second pass: build nodes with parent references
        var minimapItems: [MinimapCommitNode] = []
        for (index, line) in lines.enumerated() {
            let parts = line.components(separatedBy: " ")
            let sha = parts[0]
            let parents = Array(parts.dropFirst())
            let isMerge = parents.count > 1
            let lane = shaToLane[sha] ?? 0

            let parentIdxs = parents.compactMap { shaToIndex[$0] }
            let parentLns = parents.compactMap { shaToLane[$0] }

            minimapItems.append(MinimapCommitNode(
                index: index,
                lane: lane,
                isMerge: isMerge,
                parentIndices: parentIdxs,
                parentLanes: parentLns
            ))
        }

        await MainActor.run {
            self.minimapNodes = minimapItems
            self.totalCommitCount = lines.count
        }
    }

    /// Load commits up to a specific index (for minimap navigation)
    func loadUpTo(index targetIndex: Int) async {
        guard let p = path else { return }
        let needed = targetIndex + 50 // Load a bit past target
        let currentCount = commits.count

        guard needed > currentCount, hasMore else { return }

        isLoading = true
        do {
            let toLoad = needed - currentCount
            let pages = (toLoad + 99) / 100 // Ceil division

            for _ in 0..<pages {
                guard hasMore else { break }
                page += 1
                let more = try await engine.getCommitsV2(at: p, limit: 100, skip: page * 100)
                commits.append(contentsOf: more)
                hasMore = more.count == 100
            }

            let newNodes = await buildNodes()
            nodes = newNodes
            maxLane = nodes.reduce(0) { maxVal, node in
                let nodeLanes = [node.lane] + Array(node.passThroughLanes) + node.curvesToBottom
                return max(maxVal, nodeLanes.max() ?? 0)
            }
            buildTimeline()
        } catch {
            // Loading failed
        }
        isLoading = false
    }

    /// Load avatars from GitHub repository using commit SHAs
    private func loadAvatarsFromGitHub(at repoPath: String) async {
        // Get GitHub token (optional - will use Gravatar if not available)
        let token = try? await KeychainManager.shared.getGitHubToken()

        do {
            let remotes = try await engine.getRemotes(at: repoPath)
            guard let originRemote = remotes.first(where: { $0.name == "origin" }),
                  let (owner, repo) = extractGitHubOwnerRepo(from: originRemote.fetchURL) else {
                await preloadAvatarsForCommits(token: token)
                return
            }

            if let token = token {
                await loadAvatarsBySHA(owner: owner, repo: repo, token: token)
            }
            await preloadAvatarsForCommits(token: token)
        } catch {
            await preloadAvatarsForCommits(token: nil)
        }
    }

    /// Load avatars by fetching commits from GitHub API, skipping already-cached emails
    private func loadAvatarsBySHA(owner: String, repo: String, token: String) async {
        let uniqueEmails = Set(commits.map { $0.authorEmail.lowercased() })
        var emailsToFetch: [String: String] = [:]
        for commit in commits {
            let email = commit.authorEmail.lowercased()
            guard emailsToFetch[email] == nil else { continue }
            let cached = await AvatarService.shared.hasCachedAvatar(for: email)
            if !cached {
                emailsToFetch[email] = commit.sha
            }
        }

        guard !emailsToFetch.isEmpty else { return }

        let batchSize = 20
        let shaList = Array(emailsToFetch.values)
        for (index, sha) in shaList.enumerated() {
            if index > 0 && index % batchSize == 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }

            guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/commits/\(sha)") else {
                continue
            }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { continue }

                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let author = json["author"] as? [String: Any],
                   let avatarUrl = author["avatar_url"] as? String,
                   let url = URL(string: avatarUrl) {
                    let email = (json["commit"] as? [String: Any])?["author"] as? [String: Any]
                    let authorEmail = (email?["email"] as? String)?.lowercased()
                    await AvatarService.shared.cacheAvatar(url: url, for: authorEmail ?? "")
                }
            } catch {
                // Continue silently
            }
        }
    }

    /// Preload avatars for all unique commit author emails
    private func preloadAvatarsForCommits(token: String?) async {
        let emails = Set(commits.map { $0.authorEmail })
        await AvatarService.shared.preloadAvatars(for: Array(emails), githubToken: token)
    }

    /// Extract owner and repo name from GitHub URL
    private func extractGitHubOwnerRepo(from url: String) -> (owner: String, repo: String)? {
        // Handle various GitHub URL formats:
        // - https://github.com/owner/repo.git
        // - git@github.com:owner/repo.git
        // - https://github.com/owner/repo

        let cleanURL = url
            .replacingOccurrences(of: "git@github.com:", with: "https://github.com/")
            .replacingOccurrences(of: ".git", with: "")

        guard cleanURL.contains("github.com") else { return nil }

        let components = cleanURL.components(separatedBy: "github.com/")
        guard components.count >= 2 else { return nil }

        let pathComponents = components[1].components(separatedBy: "/")
        guard pathComponents.count >= 2 else { return nil }

        return (owner: pathComponents[0], repo: pathComponents[1])
    }

    func loadMore() async {
        guard let p = path, !isLoading else { return }
        isLoading = true
        page += 1

        do {
            let more = try await engine.getCommitsV2(at: p, limit: 100, skip: page * 100)
            commits.append(contentsOf: more)
            hasMore = more.count == 100

            // Build on background thread
            let newNodes = await buildNodes()
            nodes = newNodes

            // Recalculate max lane
            maxLane = nodes.reduce(0) { maxVal, node in
                let nodeLanes = [node.lane] + Array(node.passThroughLanes) + node.curvesToBottom
                return max(maxVal, nodeLanes.max() ?? 0)
            }

            buildTimeline()
        } catch {
            // Loading more failed silently
        }
        isLoading = false
    }

    /// Silently refresh repository status (staged/unstaged counts) without reloading commits
    /// This prevents the graph from flickering on every file change
    func refreshStatus() async {
        guard let p = path else { return }

        do {
            // Only update status counts - don't reload commits
            let status = try await engine.getStatus(at: p)
            let newStagedCount = status.staged.count
            let newUnstagedCount = status.unstaged.count + status.untracked.count
            let newHasChanges = newStagedCount > 0 || newUnstagedCount > 0

            // Only update if counts actually changed
            if stagedCount != newStagedCount || unstagedCount != newUnstagedCount || hasUncommittedChanges != newHasChanges {
                stagedCount = newStagedCount
                unstagedCount = newUnstagedCount
                hasUncommittedChanges = newHasChanges

                buildTimeline()
            }
        } catch {
            // Refresh status failed silently
        }
    }

    private func buildNodes() async -> [GraphNode] {
        // Run expensive computation off main thread
        let localCommits = commits
        let localBranchHeads = branchHeads

        return await Task.detached(priority: .userInitiated) {
            buildCommitGraph(commits: localCommits, branchHeads: localBranchHeads)
        }.value
    }

    private func buildTimeline() {
        // Merge commits and stashes into a single timeline sorted by date (newest first)
        var items: [TimelineItem] = []

        // Add uncommitted changes at the top if present
        if hasUncommittedChanges {
            items.append(.uncommitted(staged: stagedCount, unstaged: unstagedCount))
        }

        // Add all commits
        for node in nodes {
            items.append(.commit(node))
        }

        // Add all stashes
        for stash in stashNodes {
            items.append(.stash(stash))
        }

        // Sort by date (newest first)
        // Note: uncommitted will stay at top since its date is always Date()
        items.sort { $0.date > $1.date }

        timelineItems = items

        // Build O(1) SHA lookup dictionary
        commitsBySHA = Dictionary(uniqueKeysWithValues:
            items.compactMap { item -> (String, Commit)? in
                if case .commit(let node) = item { return (node.commit.sha, node.commit) }
                return nil
            }
        )
    }
}
