import SwiftUI

// Type aliases for convenience
typealias PullRequest = GitHubPullRequest
typealias Issue = GitHubIssue

/// Launchpad - Dashboard view showing repository overview, PRs, Issues, and recent activity
struct LaunchpadView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = LaunchpadViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Repository Header
                if let repo = appState.currentRepository {
                    RepositoryHeaderCard(repository: repo)
                }

                // Quick Stats
                QuickStatsView(viewModel: viewModel)

                // Main Grid
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    // Pull Requests Card
                    PullRequestsCard(viewModel: viewModel)

                    // Issues Card
                    IssuesCard(viewModel: viewModel)

                    // Recent Commits Card
                    RecentCommitsCard(viewModel: viewModel)

                    // Branch Overview Card
                    BranchOverviewCard(viewModel: viewModel)
                }

                // Actions Row
                ActionsCard(viewModel: viewModel)
            }
            .padding()
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            if let repo = appState.currentRepository {
                await viewModel.loadData(for: repo)
            }
        }
    }
}

// MARK: - View Model

@MainActor
class LaunchpadViewModel: ObservableObject {
    @Published var pullRequests: [PullRequest] = []
    @Published var issues: [Issue] = []
    @Published var recentCommits: [Commit] = []
    @Published var branchCount = 0
    @Published var tagCount = 0
    @Published var stashCount = 0
    @Published var contributorCount = 0
    @Published var isLoading = false
    @Published var error: String?

    private let gitHubService = GitHubService()

    func loadData(for repo: Repository) async {
        isLoading = true

        // Load local data
        branchCount = repo.branches.count
        tagCount = repo.tags.count
        stashCount = repo.stashes.count
        recentCommits = Array(repo.commits.prefix(5))

        // Count unique contributors
        let authors = Set(repo.commits.map { $0.author })
        contributorCount = authors.count

        // Load GitHub data if connected
        if let ownerRepo = repo.remotes.first?.ownerAndRepo {
            do {
                pullRequests = try await gitHubService.listPullRequests(
                    owner: ownerRepo.owner,
                    repo: ownerRepo.repo
                )
                issues = try await gitHubService.listIssues(
                    owner: ownerRepo.owner,
                    repo: ownerRepo.repo
                )
            } catch {
                self.error = error.localizedDescription
            }
        }

        isLoading = false
    }

    func refresh(for repo: Repository) async {
        await loadData(for: repo)
    }
}

// MARK: - Repository Header Card

struct RepositoryHeaderCard: View {
    let repository: Repository

    var body: some View {
        HStack(spacing: 16) {
            // Repo icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 64, height: 64)

                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(repository.name)
                    .font(.title)
                    .fontWeight(.bold)

                Text(repository.path)
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    if let branch = repository.currentBranch {
                        Label(branch.name, systemImage: "arrow.triangle.branch")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                    }

                    if repository.status.isDirty {
                        Label("\(repository.status.totalChanges) changes", systemImage: "pencil.circle")
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else {
                        Label("Clean", systemImage: "checkmark.circle")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }

            Spacer()

            // Quick actions
            VStack(spacing: 8) {
                Button {
                    NotificationCenter.default.post(name: .fetch, object: nil)
                } label: {
                    Label("Fetch", systemImage: "arrow.down")
                        .frame(width: 80)
                }
                .buttonStyle(.bordered)

                Button {
                    NotificationCenter.default.post(name: .pull, object: nil)
                } label: {
                    Label("Pull", systemImage: "arrow.down.circle")
                        .frame(width: 80)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Quick Stats View

struct QuickStatsView: View {
    @ObservedObject var viewModel: LaunchpadViewModel

    var body: some View {
        HStack(spacing: 16) {
            StatCard(
                title: "Branches",
                value: "\(viewModel.branchCount)",
                icon: "arrow.triangle.branch",
                color: .blue
            )

            StatCard(
                title: "Tags",
                value: "\(viewModel.tagCount)",
                icon: "tag",
                color: .orange
            )

            StatCard(
                title: "Stashes",
                value: "\(viewModel.stashCount)",
                icon: "archivebox",
                color: .purple
            )

            StatCard(
                title: "Contributors",
                value: "\(viewModel.contributorCount)",
                icon: "person.2",
                color: .green
            )

            StatCard(
                title: "Open PRs",
                value: "\(viewModel.pullRequests.filter { $0.state == "open" }.count)",
                icon: "arrow.triangle.pull",
                color: .cyan
            )

            StatCard(
                title: "Open Issues",
                value: "\(viewModel.issues.filter { $0.state == "open" }.count)",
                icon: "exclamationmark.circle",
                color: .red
            )
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }

            HStack {
                Text(value)
                    .font(.title)
                    .fontWeight(.bold)
                Spacer()
            }

            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Pull Requests Card

struct PullRequestsCard: View {
    @ObservedObject var viewModel: LaunchpadViewModel

    private var displayedPRs: [GitHubPullRequest] {
        Array(viewModel.pullRequests.prefix(4))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.triangle.pull")
                    .foregroundColor(.green)
                Text("Pull Requests")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.pullRequests.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(8)
            }

            Divider()

            if viewModel.pullRequests.isEmpty {
                VStack {
                    Text("No pull requests")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ForEach(displayedPRs) { pr in
                    PRRowView(pr: pr)
                }

                if viewModel.pullRequests.count > 4 {
                    Text("+ \(viewModel.pullRequests.count - 4) more")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - PR Row View

private struct PRRowView: View {
    let pr: GitHubPullRequest

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(pr.state == "open" ? Color.green : Color.purple)
                .frame(width: 8, height: 8)

            Text("#\(pr.number)")
                .font(.caption.monospaced())
                .foregroundColor(.secondary)

            Text(pr.title)
                .lineLimit(1)

            Spacer()

            AsyncImage(url: URL(string: pr.user.avatarUrl)) { image in
                image.resizable()
            } placeholder: {
                Circle().fill(Color.secondary.opacity(0.3))
            }
            .frame(width: 20, height: 20)
            .clipShape(Circle())
        }
        .font(.caption)
    }
}

// MARK: - Issues Card

struct IssuesCard: View {
    @ObservedObject var viewModel: LaunchpadViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.circle")
                    .foregroundColor(.red)
                Text("Issues")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.issues.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(8)
            }

            Divider()

            if viewModel.issues.isEmpty {
                VStack {
                    Text("No issues")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                let displayedIssues: [GitHubIssue] = Array(viewModel.issues.prefix(4))
                ForEach(displayedIssues, id: \.id) { issue in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(issue.state == "open" ? Color.green : Color.purple)
                            .frame(width: 8, height: 8)

                        Text("#\(issue.number)")
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)

                        Text(issue.title)
                            .lineLimit(1)

                        Spacer()

                        let displayedLabels: [GitHubLabel] = Array(issue.labels.prefix(2))
                        ForEach(displayedLabels, id: \.name) { label in
                            Text(label.name)
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color(hex: label.color).opacity(0.3))
                                .cornerRadius(4)
                        }
                    }
                    .font(.caption)
                }

                if viewModel.issues.count > 4 {
                    Text("+ \(viewModel.issues.count - 4) more")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Recent Commits Card

struct RecentCommitsCard: View {
    @ObservedObject var viewModel: LaunchpadViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.blue)
                Text("Recent Commits")
                    .font(.headline)
                Spacer()
            }

            Divider()

            if viewModel.recentCommits.isEmpty {
                VStack {
                    Text("No commits yet")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ForEach(viewModel.recentCommits) { commit in
                    HStack(spacing: 8) {
                        Text(commit.shortSHA)
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)

                        Text(commit.summary)
                            .lineLimit(1)

                        Spacer()

                        Text(commit.relativeDate)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Branch Overview Card

struct BranchOverviewCard: View {
    @ObservedObject var viewModel: LaunchpadViewModel
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.triangle.branch")
                    .foregroundColor(.purple)
                Text("Branch Overview")
                    .font(.headline)
                Spacer()
            }

            Divider()

            if let repo = appState.currentRepository {
                // Current branch
                if let current = repo.currentBranch {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(current.name)
                            .fontWeight(.medium)
                        Spacer()
                        Text("current")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                    .font(.caption)
                }

                Divider()

                // Other branches
                let otherBranches: [Branch] = Array(repo.branches.filter { !$0.isCurrent }.prefix(4))
                ForEach(otherBranches, id: \.id) { branch in
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.branch")
                            .foregroundColor(.secondary)

                        Text(branch.name)

                        Spacer()

                        if branch.isRemote {
                            Text("remote")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        if let ahead = branch.aheadBehind?.ahead, ahead > 0 {
                            Text("+\(ahead)")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }

                        if let behind = branch.aheadBehind?.behind, behind > 0 {
                            Text("-\(behind)")
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                    }
                    .font(.caption)
                }

                if repo.branches.count > 5 {
                    Text("+ \(repo.branches.count - 5) more branches")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("No repository loaded")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Actions Card

struct ActionsCard: View {
    @ObservedObject var viewModel: LaunchpadViewModel

    var body: some View {
        HStack(spacing: 16) {
            ActionButton(
                title: "New Branch",
                icon: "plus.circle",
                color: .blue
            ) {
                NotificationCenter.default.post(name: .newBranch, object: nil)
            }

            ActionButton(
                title: "Stash Changes",
                icon: "archivebox",
                color: .purple
            ) {
                NotificationCenter.default.post(name: .stash, object: nil)
            }

            ActionButton(
                title: "Create Tag",
                icon: "tag",
                color: .orange
            ) {
                // Create tag action
            }

            ActionButton(
                title: "Open Terminal",
                icon: "terminal",
                color: .green
            ) {
                // Switch to terminal view
            }

            Spacer()

            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Button {
                    // Refresh
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)

                Text(title)
                    .font(.caption)
            }
            .frame(width: 80, height: 60)
        }
        .buttonStyle(.plain)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

// #Preview {
//     LaunchpadView()
//         .environmentObject(AppState())
//         .frame(width: 900, height: 700)
// }
