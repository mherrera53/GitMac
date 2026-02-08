import SwiftUI

// MARK: - Graph View Model
@MainActor
class GraphViewModel: ObservableObject {
    @Published var nodes: [GraphNode] = []
    @Published var stashNodes: [StashNode] = []
    @Published var timelineItems: [TimelineItem] = []
    @Published var isLoading = false
    @Published var hasMore = true

    // Uncommitted changes state
    @Published var hasUncommittedChanges = false
    @Published var stagedCount = 0
    @Published var unstagedCount = 0

    // Ghost Branches support
    @Published var branches: [Branch] = []

    // Current user email for @me filter
    @Published var currentUserEmail: String?

    // Maximum lane number for dynamic graph width calculation
    @Published var maxLane: Int = 0

    private let engine = GitEngine()
    private var path: String?
    private var page = 0
    private var commits: [Commit] = []
    private var branchHeads: [String: String] = [:]

    func load(at p: String) async {
        isLoading = true
        path = p
        page = 0
        commits = []

        do {
            // Load branches (use original method - V2 has same output)
            let loadedBranches = try await engine.getBranches(at: p)
            branches = loadedBranches  // Save for Ghost Branches
            branchHeads = [:]
            for branch in loadedBranches {
                if branchHeads[branch.targetSHA] == nil {
                    branchHeads[branch.targetSHA] = branch.name
                }
            }

            // Load current user email for @me filter
            let result = await ShellExecutor().execute(
                "git",
                arguments: ["config", "user.email"],
                workingDirectory: p
            )
            if result.exitCode == 0 {
                currentUserEmail = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            // Load commits using V2 (NUL-separated, handles special chars in messages)
            commits = try await engine.getCommitsV2(at: p, limit: 100)
            hasMore = commits.count == 100

            // Load status for uncommitted changes
            let status = try await engine.getStatus(at: p)
            stagedCount = status.staged.count
            unstagedCount = status.unstaged.count + status.untracked.count
            hasUncommittedChanges = stagedCount > 0 || unstagedCount > 0

            // Load stashes
            let stashes = try await engine.getStashes(at: p)
            stashNodes = stashes.map { StashNode(id: "stash-\($0.index)", stash: $0) }

            // Build nodes on background thread
            let newNodes = await buildNodes()
            nodes = newNodes

            // Calculate max lane for dynamic graph width
            maxLane = nodes.reduce(0) { maxVal, node in
                let nodeLanes = [node.lane] + Array(node.passThroughLanes) + node.curvesToBottom
                return max(maxVal, nodeLanes.max() ?? 0)
            }

            // Build merged timeline (commits + stashes sorted by date)
            buildTimeline()

            // Load avatars from GitHub repository in background
            Task.detached(priority: .utility) {
                await self.loadAvatarsFromGitHub(at: p)
            }
        } catch {
            // Loading failed silently
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

    /// Load avatars by fetching commits from GitHub API using their SHA
    private func loadAvatarsBySHA(owner: String, repo: String, token: String) async {
        let batchSize = 20
        for (index, commit) in commits.enumerated() {
            if index > 0 && index % batchSize == 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }

            guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/commits/\(commit.sha)") else {
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
                    await AvatarService.shared.cacheAvatar(url: url, for: commit.authorEmail.lowercased())
                }
            } catch {
                // Continue silently on error
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
    }
}
