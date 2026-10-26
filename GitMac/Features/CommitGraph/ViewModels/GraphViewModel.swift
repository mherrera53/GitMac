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
    private(set) var lastError: String?

    var hasUncommittedChanges = false
    var stagedCount = 0
    var unstagedCount = 0
    var conflictedCount = 0

    var branches: [Branch] = []

    var currentUserEmail: String?

    var maxLane: Int = 0

    var minimapNodes: [MinimapCommitNode] = []
    private(set) var minimapDrawingNodes: [MinimapCommitNode] = []
    private(set) var minimapIndexBySHA = MinimapSHAIndex()
    private(set) var minimapMaxLane = 0
    private(set) var isLoadingMinimap = false
    private(set) var minimapError: String?
    var totalCommitCount: Int = 0
    var isShallowClone: Bool = false
    var isDeepeningHistory: Bool = false

    private(set) var commitsBySHA: [String: Commit] = [:]

    private let engine = GitEngine()
    private var path: String?
    private var page = 0
    private var commits: [Commit] = []
    private var branchHeads: [String: String] = [:]
    private var currentLoadTask: Task<Void, Never>?
    private var generation = UUID()
    var historySnapshotID: UUID { generation }
    private var historyTipSHA: String?
    private var supplementaryTasks: [Task<Void, Never>] = []

    private func debugLog(_ msg: String) {
        Logger.debug("Graph: \(msg)")
    }

    func load(at p: String) {
        currentLoadTask?.cancel()
        supplementaryTasks.forEach { $0.cancel() }
        supplementaryTasks.removeAll()
        generation = UUID()
        isLoadingMinimap = false
        minimapError = nil
        let requestGeneration = generation
        let changingRepository = path != p
        path = p
        page = 0
        isLoading = true
        lastError = nil
        if changingRepository {
            commits = []
            historyTipSHA = nil
            nodes = []
            branchHeads = [:]
            branches = []
            stashNodes = []
            minimapNodes = []
            minimapDrawingNodes = []
            minimapIndexBySHA = MinimapSHAIndex()
            minimapMaxLane = 0
            isLoadingMinimap = false
            minimapError = nil
            totalCommitCount = 0
            maxLane = 0
            stagedCount = 0
            unstagedCount = 0
            conflictedCount = 0
            hasUncommittedChanges = false
            currentUserEmail = nil
            isShallowClone = false
            isDeepeningHistory = false
            hasMore = true
            buildTimeline()
        }
        debugLog("load() called for: \(p)")
        currentLoadTask = Task { @MainActor [weak self] in
            guard let self else { self?.debugLog("weak self is nil"); return }
            defer { if generation == requestGeneration { isLoading = false } }
            debugLog("starting getBranches...")

            do {
                let loadedBranches = try await engine.getBranches(at: p)
                debugLog("getBranches done: \(loadedBranches.count) branches")
                guard !Task.isCancelled, generation == requestGeneration else { return }

                let shallowCheck = await ShellExecutor.shared.execute(
                    "git", arguments: ["rev-parse", "--is-shallow-repository"],
                    workingDirectory: p
                )
                guard !Task.isCancelled, generation == requestGeneration else { return }
                isShallowClone = shallowCheck.isSuccess && shallowCheck.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
                // Viewing history must never trigger an implicit fetch/reload loop.

                debugLog("calling getCommitsV2...")
                let loadedCommits = try await engine.getCommitsV2(at: p, limit: 100)
                debugLog("getCommitsV2 done: \(loadedCommits.count) commits")
                guard !Task.isCancelled, generation == requestGeneration else { return }

                var newBranchHeads: [String: String] = [:]
                for branch in loadedBranches {
                    if newBranchHeads[branch.targetSHA] == nil {
                        newBranchHeads[branch.targetSHA] = branch.name
                    }
                }

                commits = loadedCommits
                historyTipSHA = loadedCommits.first?.sha
                branchHeads = newBranchHeads
                debugLog("starting buildNodes...")
                let newNodes = await buildNodes()
                debugLog("buildNodes done: \(newNodes.count) nodes")
                guard !Task.isCancelled, generation == requestGeneration else { return }

                let newMaxLane = newNodes.reduce(0) { maxVal, node in
                    let nodeLanes = [node.lane] + Array(node.passThroughLanes) + node.curvesToBottom
                    return max(maxVal, nodeLanes.max() ?? 0)
                }

                branches = loadedBranches
                hasMore = loadedCommits.count == 100
                nodes = newNodes
                maxLane = newMaxLane
                buildTimeline()
                isLoading = false
                PerformanceProbe.record("graph-loaded", counts: ["commits": commits.count, "rows": timelineItems.count])
                debugLog("DONE: \(timelineItems.count) items, isLoading=false")

                supplementaryTasks.append(Task { [weak self] in
                    guard let self else { return }
                    let status = try? await self.engine.getStatus(at: p)
                    guard !Task.isCancelled, self.generation == requestGeneration else { return }
                    if let status {
                        let counts = GraphWorkingCopyCounts(status: status)
                        self.stagedCount = counts.staged
                        self.unstagedCount = counts.unstaged
                        self.conflictedCount = counts.conflicted
                        self.hasUncommittedChanges = counts.hasChanges
                        self.buildTimeline()
                    }
                    let stashes = try? await self.engine.getStashes(at: p)
                    guard !Task.isCancelled, self.generation == requestGeneration else { return }
                    if let stashes {
                        self.stashNodes = stashes.map { StashNode(id: "stash-\($0.index)", stash: $0) }
                        self.buildTimeline()
                    }
                    let emailResult = await ShellExecutor.shared.execute(
                        "git", arguments: ["config", "user.email"], workingDirectory: p
                    )
                    guard !Task.isCancelled, self.generation == requestGeneration else { return }
                    if emailResult.exitCode == 0 {
                        self.currentUserEmail = emailResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                })
                supplementaryTasks.append(Task { [weak self] in
                    await self?.loadMinimapData(at: p, requestGeneration: requestGeneration)
                })
                supplementaryTasks.append(Task { [weak self] in
                    await self?.loadAvatarsFromGitHub(at: p)
                })
            } catch {
                debugLog("ERROR: \(error)")
                if !Task.isCancelled, generation == requestGeneration { lastError = error.localizedDescription }
            }
        }
    }

    func reloadMinimap() async {
        guard let path, !isLoadingMinimap else { return }
        await loadMinimapData(at: path, requestGeneration: generation)
    }

    /// Load the complete locally reachable history of the same frozen tip as
    /// pagination. Never fetch/deepen implicitly, or publish a partial command.
    private func loadMinimapData(at repoPath: String, requestGeneration: UUID) async {
        guard let tip = historyTipSHA, generation == requestGeneration else { return }
        isLoadingMinimap = true
        minimapError = nil
        defer { if generation == requestGeneration { isLoadingMinimap = false } }
        let result = await ShellExecutor.shared.execute(
            "git",
            arguments: ["log", "--format=%H %P", tip, "--"],
            workingDirectory: repoPath
        )
        guard !Task.isCancelled, generation == requestGeneration else { return }
        guard result.isSuccess else {
            minimapError = "History overview unavailable (\(result.termination)). Retry without changing the repository."
            return
        }
        let snapshot = await Task.detached(priority: .utility) {
            let items = MinimapLayout.build(log: result.stdout)
            let indexBySHA = MinimapSHAIndex(nodes: items)
            var maximumLane = 0
            for item in items {
                maximumLane = max(maximumLane, item.lane)
            }
            return (items, MinimapLayout.drawingSample(items),
                    indexBySHA, maximumLane)
        }.value
        guard !Task.isCancelled, generation == requestGeneration else { return }
        minimapNodes = snapshot.0
        minimapDrawingNodes = snapshot.1
        minimapIndexBySHA = snapshot.2
        minimapMaxLane = snapshot.3
        totalCommitCount = snapshot.0.count
        PerformanceProbe.record("minimap-loaded", counts: ["commits": totalCommitCount, "drawn": minimapDrawingNodes.count])
    }

    /// Load commits up to a specific index (for minimap navigation)
    func loadUpTo(index targetIndex: Int) async {
        guard let p = path, let tip = historyTipSHA, !isLoading else { return }
        let requestGeneration = generation
        let needed = targetIndex + 50 // Load a bit past target
        let currentCount = commits.count

        guard needed > currentCount, hasMore else { return }

        isLoading = true
        lastError = nil
        defer { if generation == requestGeneration { isLoading = false } }
        do {
            while commits.count < needed && hasMore {
                guard !Task.isCancelled else { return }
                // Up to ten pages per Git invocation for distant seeks; keep
                // the 100-row cursor contract used by normal pagination.
                let pages = min(10, (needed - commits.count + 99) / 100)
                let nextPage = page + 1
                let more = try await engine.getCommitsV2(at: p, branch: tip, limit: pages * 100, skip: nextPage * 100)
                guard !Task.isCancelled, generation == requestGeneration else { return }
                commits.append(contentsOf: more)
                page += pages
                hasMore = more.count == pages * 100
            }

            let newNodes = await buildNodes()
            guard !Task.isCancelled, generation == requestGeneration else { return }
            nodes = newNodes
            maxLane = nodes.reduce(0) { maxVal, node in
                let nodeLanes = [node.lane] + Array(node.passThroughLanes) + node.curvesToBottom
                return max(maxVal, nodeLanes.max() ?? 0)
            }
            buildTimeline()
        } catch {
            if generation == requestGeneration { lastError = error.localizedDescription }
        }
    }

    /// Load avatars from GitHub repository using commit SHAs
    private func loadAvatarsFromGitHub(at repoPath: String) async {
        guard !PerformanceProbe.isEnabled else { return }
        // Get GitHub token (optional - will use Gravatar if not available)
        let token = try? await KeychainManager.shared.getGitHubToken()
        guard !Task.isCancelled else { return }

        do {
            let remotes = try await engine.getRemotes(at: repoPath)
            guard !Task.isCancelled else { return }
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
            guard !Task.isCancelled else { return }
            await preloadAvatarsForCommits(token: nil)
        }
    }

    /// Load avatars by fetching commits from GitHub API, skipping already-cached emails
    private func loadAvatarsBySHA(owner: String, repo: String, token: String) async {
        _ = Set(commits.map { $0.authorEmail.lowercased() })
        var emailsToFetch: [String: String] = [:]
        for commit in commits {
            guard !Task.isCancelled else { return }
            let email = commit.authorEmail.lowercased()
            guard emailsToFetch[email] == nil else { continue }
            let cached = await AvatarService.shared.hasCachedAvatar(for: email)
            guard !Task.isCancelled else { return }
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
            guard !Task.isCancelled else { return }

            guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/commits/\(sha)") else {
                continue
            }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard !Task.isCancelled else { return }
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
        guard !Task.isCancelled else { return }
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
        guard let p = path, let tip = historyTipSHA, !isLoading, hasMore else { return }
        let requestGeneration = generation
        isLoading = true
        lastError = nil
        defer { if generation == requestGeneration { isLoading = false } }
        let nextPage = page + 1

        do {
            let more = try await engine.getCommitsV2(at: p, branch: tip, limit: 100, skip: nextPage * 100)
            guard !Task.isCancelled, generation == requestGeneration else { return }
            commits.append(contentsOf: more)
            page = nextPage
            hasMore = more.count == 100

            // Build on background thread
            let newNodes = await buildNodes()
            guard !Task.isCancelled, generation == requestGeneration else { return }
            nodes = newNodes

            // Recalculate max lane
            maxLane = nodes.reduce(0) { maxVal, node in
                let nodeLanes = [node.lane] + Array(node.passThroughLanes) + node.curvesToBottom
                return max(maxVal, nodeLanes.max() ?? 0)
            }

            buildTimeline()
        } catch {
            if generation == requestGeneration { lastError = error.localizedDescription }
        }
    }

    /// Silently refresh repository status (staged/unstaged counts) without reloading commits
    /// This prevents the graph from flickering on every file change
    func refreshStatus() async {
        guard let p = path else { return }
        let requestGeneration = generation

        do {
            // Only update status counts - don't reload commits
            let status = try await engine.getStatus(at: p)
            guard !Task.isCancelled, generation == requestGeneration else { return }
            let counts = GraphWorkingCopyCounts(status: status)

            // Only update if counts actually changed
            if stagedCount != counts.staged || unstagedCount != counts.unstaged || conflictedCount != counts.conflicted || hasUncommittedChanges != counts.hasChanges {
                stagedCount = counts.staged
                unstagedCount = counts.unstaged
                conflictedCount = counts.conflicted
                hasUncommittedChanges = counts.hasChanges

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
        // Keep the commit rows contiguous and in Git's graph order. Author dates
        // are untrusted and can place a parent before its child. Auxiliary rows
        // must not be inserted between rows whose edges were laid out together.
        var items: [TimelineItem] = []

        // Add uncommitted changes at the top if present
        if hasUncommittedChanges {
            items.append(.uncommitted(staged: stagedCount, unstaged: unstagedCount))
        }

        // Group stashes above the commit graph, newest first.
        for stash in stashNodes.sorted(by: { $0.stash.date > $1.stash.date }) {
            items.append(.stash(stash))
        }

        for node in nodes {
            items.append(.commit(node))
        }

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
