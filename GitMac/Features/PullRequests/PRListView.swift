import SwiftUI

/// Pull Requests list and detail view
struct PRListView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = PRListViewModel()
    @StateObject private var themeManager = ThemeManager.shared
    @State private var selectedPR: GitHubPullRequest?
    @State private var showCreatePRSheet = false
    @State private var filterState: PRState = .open

    var body: some View {
        HSplitView {
            // Left: PR List
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Pull Requests")
                        .font(.headline)

                    Spacer()

                    Picker("Filter", selection: $filterState) {
                        Text("Open").tag(PRState.open)
                        Text("Closed").tag(PRState.closed)
                        Text("All").tag(PRState.all)
                    }
                    .frame(width: 180)

                    Button {
                        showCreatePRSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(AppTheme.textPrimary)
                    }
                    .buttonStyle(.borderless)
                    .help("Create Pull Request")
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))

                Divider()

                // List
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.pullRequests.isEmpty {
                    EmptyPRView(state: filterState)
                } else {
                    List(viewModel.pullRequests, selection: $selectedPR) { pr in
                        PRRow(
                            pr: pr,
                            isSelected: selectedPR?.id == pr.id,
                            onMerge: { method in
                                Task {
                                    await viewModel.mergePR(pr, method: method)
                                }
                            },
                            onClose: {
                                Task {
                                    await viewModel.closePR(pr)
                                }
                            }
                        )
                        .tag(pr)
                    }
                    .listStyle(.plain)
                }
            }
            .frame(minWidth: 300, idealWidth: 350)

            // Right: PR Detail
            if let pr = selectedPR {
                PRDetailView(pr: pr, viewModel: viewModel)
            } else {
                VStack {
                    Spacer()
                    Image(systemName: "arrow.triangle.pull")
                        .font(DesignTokens.Typography.iconXXXXL)
                        .foregroundColor(AppTheme.textPrimary)
                    Text("Select a pull request")
                        .foregroundColor(AppTheme.textPrimary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .sheet(isPresented: $showCreatePRSheet) {
            CreatePRSheet(viewModel: viewModel)
        }
        .onChange(of: filterState) { _, newState in
            Task { await viewModel.loadPullRequests(state: newState) }
        }
        .task {
            if let repo = appState.currentRepository,
               let remote = repo.remotes.first(where: { $0.isGitHub }),
               let ownerRepo = remote.ownerAndRepo {
                viewModel.owner = ownerRepo.owner
                viewModel.repo = ownerRepo.repo
                await viewModel.loadPullRequests(state: filterState)
            }
        }
    }
}

// MARK: - View Model

@MainActor
class PRListViewModel: ObservableObject {
    @Published var pullRequests: [GitHubPullRequest] = []
    @Published var isLoading = false
    @Published var error: String?

    var owner: String = ""
    var repo: String = ""

    private let githubService = GitHubService()

    func loadPullRequests(state: PRState = .open) async {
        guard !owner.isEmpty && !repo.isEmpty else { return }

        isLoading = true
        do {
            pullRequests = try await githubService.listPullRequests(
                owner: owner,
                repo: repo,
                state: state
            )
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func getPRDetails(_ pr: GitHubPullRequest) async -> GitHubPullRequest? {
        do {
            return try await githubService.getPullRequest(owner: owner, repo: repo, number: pr.number)
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    func getPRFiles(_ pr: GitHubPullRequest) async -> [GitHubPRFile] {
        do {
            return try await githubService.getPullRequestFiles(owner: owner, repo: repo, number: pr.number)
        } catch {
            self.error = error.localizedDescription
            return []
        }
    }

    func getPRComments(_ pr: GitHubPullRequest) async -> [GitHubComment] {
        do {
            return try await githubService.getPullRequestComments(owner: owner, repo: repo, number: pr.number)
        } catch {
            self.error = error.localizedDescription
            return []
        }
    }

    func addComment(_ pr: GitHubPullRequest, body: String) async -> Bool {
        do {
            _ = try await githubService.addPullRequestComment(
                owner: owner,
                repo: repo,
                number: pr.number,
                body: body
            )
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func mergePR(_ pr: GitHubPullRequest, method: MergeMethod = .merge) async {
        do {
            try await githubService.mergePullRequest(
                owner: owner,
                repo: repo,
                number: pr.number,
                mergeMethod: method
            )
            NotificationManager.shared.success(
                "PR #\(pr.number) merged",
                detail: "\(pr.title) merged with \(method.rawValue)"
            )
            await loadPullRequests()
        } catch {
            self.error = error.localizedDescription
            NotificationManager.shared.error(
                "Merge failed",
                detail: error.localizedDescription
            )
        }
    }

    func closePR(_ pr: GitHubPullRequest) async {
        do {
            try await githubService.closePullRequest(
                owner: owner,
                repo: repo,
                number: pr.number
            )
            NotificationManager.shared.success(
                "PR #\(pr.number) closed",
                detail: pr.title
            )
            await loadPullRequests()
        } catch {
            self.error = error.localizedDescription
            NotificationManager.shared.error(
                "Failed to close PR",
                detail: error.localizedDescription
            )
        }
    }

    func createPR(title: String, body: String, head: String, base: String, draft: Bool) async {
        await createPRWithMetadata(
            title: title,
            body: body,
            head: head,
            base: base,
            draft: draft,
            reviewers: [],
            assignees: [],
            labels: []
        )
    }

    func createPRWithMetadata(
        title: String,
        body: String,
        head: String,
        base: String,
        draft: Bool,
        reviewers: [String],
        assignees: [String],
        labels: [String]
    ) async {
        do {
            let newPR = try await githubService.createPullRequest(
                owner: owner,
                repo: repo,
                title: title,
                body: body,
                head: head,
                base: base,
                draft: draft
            )

            // Add reviewers if specified
            if !reviewers.isEmpty {
                try? await githubService.requestReviewers(
                    owner: owner,
                    repo: repo,
                    number: newPR.number,
                    reviewers: reviewers
                )
            }

            // Add assignees if specified
            if !assignees.isEmpty {
                try? await githubService.addAssignees(
                    owner: owner,
                    repo: repo,
                    number: newPR.number,
                    assignees: assignees
                )
            }

            // Add labels if specified
            if !labels.isEmpty {
                try? await githubService.addLabels(
                    owner: owner,
                    repo: repo,
                    number: newPR.number,
                    labels: labels
                )
            }

            NotificationManager.shared.success(
                "PR #\(newPR.number) created",
                detail: title
            )
            await loadPullRequests()
        } catch {
            self.error = error.localizedDescription
            NotificationManager.shared.error(
                "Failed to create PR",
                detail: error.localizedDescription
            )
        }
    }
}

// MARK: - Subviews

struct PRRow: View {
    let pr: GitHubPullRequest
    let isSelected: Bool
    var onMerge: ((MergeMethod) -> Void)?
    var onClose: (() -> Void)?
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        return VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack {
                // PR number and status
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: pr.draft ? "doc.text" : (pr.state == "open" ? "arrow.triangle.pull" : "checkmark.circle"))
                        .foregroundColor(statusColor)

                    Text("#\(pr.number)")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(theme.text)
                }

                Text(pr.title)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Spacer()
            }

            HStack(spacing: DesignTokens.Spacing.sm) {
                // Author
                AsyncImage(url: URL(string: pr.user.avatarUrl)) { image in
                    image.resizable()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(theme.textSecondary)
                }
                .frame(width: DesignTokens.Size.avatarXS, height: DesignTokens.Size.avatarXS)
                .clipShape(Circle())

                Text(pr.user.login)
                    .font(.caption)
                    .foregroundColor(theme.text)

                Text("•")
                    .foregroundColor(theme.text)

                Text(formatDate(pr.updatedAt))
                    .font(.caption)
                    .foregroundColor(theme.text)

                Spacer()

                // Stats
                if let additions = pr.additions, let deletions = pr.deletions {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        Text("+\(additions)")
                            .foregroundColor(AppTheme.success)
                        Text("-\(deletions)")
                            .foregroundColor(AppTheme.error)
                    }
                    .font(.caption.monospacedDigit())
                }
            }

            // Branch info
            HStack(spacing: DesignTokens.Spacing.xs) {
                Text(pr.head.ref)
                    .font(.caption)
                    .padding(.horizontal, DesignTokens.Spacing.sm - 2)
                    .padding(.vertical, DesignTokens.Spacing.xxs)
                    .background(theme.info.opacity(0.2))
                    .foregroundColor(AppTheme.accent)
                    .cornerRadius(DesignTokens.CornerRadius.sm)

                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundColor(theme.text)

                Text(pr.base.ref)
                    .font(.caption)
                    .padding(.horizontal, DesignTokens.Spacing.sm - 2)
                    .padding(.vertical, DesignTokens.Spacing.xxs)
                    .background(theme.success.opacity(0.2))
                    .foregroundColor(AppTheme.success)
                    .cornerRadius(DesignTokens.CornerRadius.sm)
            }
        }
        .padding(.vertical, DesignTokens.Spacing.sm)
        .padding(.horizontal, DesignTokens.Spacing.xs)
        .background(isSelected ? AppTheme.accent.opacity(0.1) : Color.clear)
        .cornerRadius(DesignTokens.CornerRadius.sm)
        .contextMenu {
            if pr.state == "open" && !pr.draft {
                Menu {
                    Button {
                        onMerge?(.merge)
                    } label: {
                        Label("Create a merge commit", systemImage: "arrow.triangle.merge")
                    }

                    Button {
                        onMerge?(.squash)
                    } label: {
                        Label("Squash and merge", systemImage: "square.stack.3d.up")
                    }

                    Button {
                        onMerge?(.rebase)
                    } label: {
                        Label("Rebase and merge", systemImage: "arrow.triangle.branch")
                    }
                } label: {
                    Label("Merge Pull Request", systemImage: "arrow.triangle.merge")
                }

                Divider()
            }

            Button {
                if let url = URL(string: pr.htmlUrl) {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Label("Open in GitHub", systemImage: "safari")
            }

            if pr.state == "open" {
                Divider()

                Button(role: .destructive) {
                    onClose?()
                } label: {
                    Label("Close Pull Request", systemImage: "xmark.circle")
                }
            }
        }
    }

    var statusColor: Color {
        if pr.draft { return AppTheme.textSecondary }
        switch pr.state {
        case "open": return AppTheme.success
        case "closed": return AppTheme.error
        default: return AppTheme.accentPurple
        }
    }

    func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return dateString }

        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .abbreviated
        return relative.localizedString(for: date, relativeTo: Date())
    }
}

struct PRDetailView: View {
    let pr: GitHubPullRequest
    @ObservedObject var viewModel: PRListViewModel
    @StateObject private var themeManager = ThemeManager.shared
    @State private var files: [GitHubPRFile] = []
    @State private var checks: [GitHubCheckRun] = []
    @State private var comments: [GitHubComment] = []
    @State private var selectedMergeMethod: MergeMethod = .merge
    @State private var showMergeConfirm = false
    @State private var showComments = false
    @State private var newCommentText = ""
    @State private var showReviewView = false

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        return ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                // Header
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    HStack {
                        PRStatusBadge(state: pr.state, draft: pr.draft)

                        Text("#\(pr.number)")
                            .font(.title3)
                            .foregroundColor(theme.text)

                        Spacer()

                        // CI/CD Status indicator
                        if !checks.isEmpty {
                            HStack(spacing: DesignTokens.Spacing.xs) {
                                Image(systemName: checksIcon)
                                    .foregroundColor(checksColor)
                                Text(checksStatus)
                                    .font(.caption)
                                    .foregroundColor(checksColor)
                            }
                            .padding(.horizontal, DesignTokens.Spacing.sm)
                            .padding(.vertical, DesignTokens.Spacing.xs)
                            .background(checksColor.opacity(0.1))
                            .cornerRadius(DesignTokens.CornerRadius.xl)
                        }

                        Button {
                            showReviewView = true
                        } label: {
                            Label("Review Changes", systemImage: "text.bubble")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            NSWorkspace.shared.open(URL(string: pr.htmlUrl)!)
                        } label: {
                            Label("Open in GitHub", systemImage: "arrow.up.right.square")
                        }
                        .buttonStyle(.borderless)
                    }

                    Text(pr.title)
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(DesignTokens.CornerRadius.lg)

                // Body
                if let body = pr.body, !body.isEmpty {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Text("Description")
                            .font(.headline)

                        Text(body)
                            .font(.body)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(DesignTokens.CornerRadius.lg)
                }

                // Stats
                HStack(spacing: DesignTokens.Spacing.xl) {
                    StatItem(icon: "doc.text", label: "Files", value: "\(pr.changedFiles ?? 0)")
                    StatItem(icon: "plus", label: "Additions", value: "+\(pr.additions ?? 0)", color: AppTheme.success)
                    StatItem(icon: "minus", label: "Deletions", value: "-\(pr.deletions ?? 0)", color: AppTheme.error)
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(DesignTokens.CornerRadius.lg)

                // CI/CD Checks
                if !checks.isEmpty {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Text("Checks")
                            .font(.headline)

                        ForEach(checks) { check in
                            HStack(spacing: DesignTokens.Spacing.sm) {
                                Image(systemName: checkIcon(for: check))
                                    .foregroundColor(checkColor(for: check))
                                    .frame(width: DesignTokens.Size.iconLG)

                                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                                    Text(check.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)

                                    Text(check.status.capitalized)
                                        .font(.caption)
                                        .foregroundColor(theme.text)
                                }

                                Spacer()

                                if let conclusion = check.conclusion {
                                    Text(conclusion.capitalized)
                                        .font(.caption)
                                        .padding(.horizontal, DesignTokens.Spacing.sm - 2)
                                        .padding(.vertical, DesignTokens.Spacing.xxs)
                                        .background(checkColor(for: check).opacity(0.2))
                                        .foregroundColor(checkColor(for: check))
                                        .cornerRadius(DesignTokens.CornerRadius.sm)
                                }
                            }
                            .padding(.vertical, DesignTokens.Spacing.sm)
                            Divider()
                        }
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(DesignTokens.CornerRadius.lg)
                }

                // Comments
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    HStack {
                        Text("Comments")
                            .font(.headline)

                        Text("(\(comments.count))")
                            .font(.caption)
                            .foregroundColor(theme.text)

                        Spacer()

                        Button {
                            withAnimation {
                                showComments.toggle()
                            }
                        } label: {
                            Image(systemName: showComments ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundColor(theme.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }

                    if showComments {
                        // Existing comments
                        ForEach(comments) { comment in
                            HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                                AsyncImage(url: URL(string: comment.user.avatarUrl)) { image in
                                    image.resizable()
                                } placeholder: {
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .foregroundColor(theme.text)
                                }
                                .frame(width: DesignTokens.Size.avatarLG, height: DesignTokens.Size.avatarLG)
                                .clipShape(Circle())

                                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                                    HStack {
                                        Text(comment.user.login)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)

                                        Text(formatCommentDate(comment.createdAt))
                                            .font(.caption)
                                            .foregroundColor(theme.text)
                                    }

                                    Text(comment.body)
                                        .font(.body)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(.vertical, DesignTokens.Spacing.sm)
                            Divider()
                        }

                        // New comment input
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                            Text("Add comment")
                                .font(.caption)
                                .foregroundColor(theme.text)

                            TextEditor(text: $newCommentText)
                                .font(.body)
                                .frame(minHeight: 80)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                                        .stroke(AppTheme.textSecondary.opacity(0.3), lineWidth: 1)
                                )

                            HStack {
                                Spacer()
                                Button("Add Comment") {
                                    Task { await addComment() }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                        .padding(.top, DesignTokens.Spacing.sm)
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(DesignTokens.CornerRadius.lg)

                // Files changed
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Files Changed")
                        .font(.headline)

                    ForEach(files, id: \.filename) { file in
                        PRFileRow(file: file)
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(DesignTokens.CornerRadius.lg)

                // Actions
                if pr.state == "open" {
                    VStack(spacing: DesignTokens.Spacing.md) {
                        Picker("Merge Method", selection: $selectedMergeMethod) {
                            Text("Create merge commit").tag(MergeMethod.merge)
                            Text("Squash and merge").tag(MergeMethod.squash)
                            Text("Rebase and merge").tag(MergeMethod.rebase)
                        }

                        Button {
                            showMergeConfirm = true
                        } label: {
                            Label("Merge Pull Request", systemImage: "checkmark.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(pr.mergeable == false)
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(DesignTokens.CornerRadius.lg)
                }
            }
            .padding()
        }
        .alert("Merge Pull Request", isPresented: $showMergeConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Merge") {
                Task { await viewModel.mergePR(pr, method: selectedMergeMethod) }
            }
        } message: {
            Text("Are you sure you want to merge this pull request using \(selectedMergeMethod.rawValue)?")
        }
        .sheet(isPresented: $showReviewView) {
            NavigationStack {
                PRReviewView(
                    pr: pr,
                    owner: viewModel.owner,
                    repo: viewModel.repo
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            showReviewView = false
                        }
                    }
                }
            }
            .frame(minWidth: 1000, minHeight: 700)
        }
        .task {
            async let filesTask = viewModel.getPRFiles(pr)
            async let checksTask = loadChecks()
            async let commentsTask = viewModel.getPRComments(pr)

            files = await filesTask
            checks = await checksTask
            comments = await commentsTask
        }
    }

    // MARK: - Helpers

    private func loadChecks() async -> [GitHubCheckRun] {
        let headSha = pr.head.sha
        do {
            let githubService = GitHubService()
            let checkRuns = try await githubService.getCheckRuns(
                owner: viewModel.owner,
                repo: viewModel.repo,
                ref: headSha
            )
            return checkRuns.checkRuns
        } catch {
            print("Failed to load checks: \(error)")
            return []
        }
    }

    private var checksStatus: String {
        let failedChecks = checks.filter { $0.conclusion == "failure" }
        let successChecks = checks.filter { $0.conclusion == "success" }
        let inProgressChecks = checks.filter { $0.status != "completed" }

        if !failedChecks.isEmpty {
            return "\(failedChecks.count) failed"
        } else if !inProgressChecks.isEmpty {
            return "\(inProgressChecks.count) in progress"
        } else if successChecks.count == checks.count {
            return "All checks passed"
        } else {
            return "\(checks.count) checks"
        }
    }

    private var checksIcon: String {
        let hasFailures = checks.contains { $0.conclusion == "failure" }
        let inProgress = checks.contains { $0.status != "completed" }

        if hasFailures {
            return "xmark.circle.fill"
        } else if inProgress {
            return "clock.fill"
        } else {
            return "checkmark.circle.fill"
        }
    }

    private var checksColor: Color {
        let hasFailures = checks.contains { $0.conclusion == "failure" }
        let inProgress = checks.contains { $0.status != "completed" }

        if hasFailures {
            return AppTheme.error
        } else if inProgress {
            return AppTheme.warning
        } else {
            return AppTheme.success
        }
    }

    private func checkIcon(for check: GitHubCheckRun) -> String {
        if check.status != "completed" {
            return "clock"
        }

        switch check.conclusion {
        case "success": return "checkmark.circle.fill"
        case "failure": return "xmark.circle.fill"
        case "cancelled": return "xmark.circle"
        case "skipped": return "arrow.forward.circle"
        default: return "circle"
        }
    }

    private func checkColor(for check: GitHubCheckRun) -> Color {
        if check.status != "completed" {
            return AppTheme.warning
        }

        switch check.conclusion {
        case "success": return AppTheme.success
        case "failure": return AppTheme.error
        case "cancelled": return AppTheme.textSecondary
        case "skipped": return AppTheme.accent
        default: return AppTheme.textSecondary
        }
    }

    private func addComment() async {
        let body = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }

        let success = await viewModel.addComment(pr, body: body)
        if success {
            newCommentText = ""
            // Reload comments
            comments = await viewModel.getPRComments(pr)
        }
    }

    private func formatCommentDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return dateString }

        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .abbreviated
        return relative.localizedString(for: date, relativeTo: Date())
    }
}

struct PRStatusBadge: View {
    let state: String
    let draft: Bool
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        return HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: icon)
                .foregroundColor(theme.textSecondary)
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(color.opacity(0.2))
        .foregroundColor(color)
        .cornerRadius(DesignTokens.CornerRadius.xl)
    }

    var icon: String {
        if draft { return "doc.text" }
        switch state {
        case "open": return "arrow.triangle.pull"
        case "closed": return "xmark.circle"
        default: return "checkmark.circle"
        }
    }

    var text: String {
        if draft { return "Draft" }
        return state.capitalized
    }

    var color: Color {
        if draft { return AppTheme.textSecondary }
        switch state {
        case "open": return AppTheme.success
        case "closed": return AppTheme.error
        default: return AppTheme.accentPurple
        }
    }
}

struct StatItem: View {
    let icon: String
    let label: String
    let value: String
    var color: Color = .primary
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        return VStack(spacing: DesignTokens.Spacing.xs) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: icon)
                Text(value)
                    .fontWeight(.semibold)
            }
            .font(.title3)
            .foregroundColor(color)

            Text(label)
                .font(.caption)
                .foregroundColor(theme.text)
        }
    }
}

struct PRFileRow: View {
    @StateObject private var themeManager = ThemeManager.shared
    let file: GitHubPRFile

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            StatusIcon(status: statusType)

            Image(systemName: "doc.fill")
                .foregroundColor(AppTheme.accent)

            Text(file.filename)
                .lineLimit(1)

            Spacer()

            HStack(spacing: DesignTokens.Spacing.xs) {
                Text("+\(file.additions)")
                    .foregroundColor(AppTheme.success)
                Text("-\(file.deletions)")
                    .foregroundColor(AppTheme.error)
            }
            .font(.caption.monospacedDigit())
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }

    var statusType: FileStatusType {
        switch file.status {
        case "added": return .added
        case "removed": return .deleted
        case "modified": return .modified
        case "renamed": return .renamed
        default: return .modified
        }
    }
}

struct EmptyPRView: View {
    let state: PRState
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        return VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "arrow.triangle.pull")
                .font(.system(size: DesignTokens.Size.iconXL))
                .foregroundColor(theme.text)

            Text("No \(state == .all ? "" : state.rawValue) pull requests")
                .font(.headline)

            Text("Pull requests will appear here when they are created")
                .foregroundColor(theme.text)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Create PR Sheet

struct CreatePRSheet: View {
    @ObservedObject var viewModel: PRListViewModel
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var themeManager = ThemeManager.shared

    @State private var title = ""
    @State private var prBody = ""
    @State private var headBranch = ""
    @State private var baseBranch = "main"
    @State private var isDraft = false
    @State private var isGenerating = false
    @State private var selectedReviewers: Set<String> = []
    @State private var selectedAssignees: Set<String> = []
    @State private var selectedLabels: Set<String> = []
    @State private var availableReviewers: [GitHubUser] = []
    @State private var availableLabels: [GitHubLabel] = []
    @State private var prTemplate: String?

    private let aiService = AIService()

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        return VStack(spacing: DesignTokens.Spacing.lg) {
            HStack {
                Text("Create Pull Request")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                // AI Generate Button - Prominent placement
                Button {
                    Task { await generateTitleAndDescription() }
                } label: {
                    HStack(spacing: DesignTokens.Spacing.sm - 2) {
                        if isGenerating {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Generating...")
                        } else {
                            Image(systemName: "sparkles")
                                .foregroundColor(theme.accent)
                            Text("Generate with AI")
                        }
                    }
                    .font(.subheadline)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isGenerating || headBranch.isEmpty)
            }

            ScrollView {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    // Branches
                    HStack {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text("From").font(.caption).foregroundColor(theme.text)
                            Picker("", selection: $headBranch) {
                                ForEach(appState.currentRepository?.branches ?? [], id: \.id) { branch in
                                    Text(branch.name).tag(branch.name)
                                }
                            }
                            .labelsHidden()
                        }

                        Image(systemName: "arrow.right")
                            .foregroundColor(theme.text)
                            .padding(.horizontal, DesignTokens.Spacing.sm)

                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text("To").font(.caption).foregroundColor(theme.text)
                            Picker("", selection: $baseBranch) {
                                Text("main").tag("main")
                                Text("master").tag("master")
                                Text("develop").tag("develop")
                            }
                            .labelsHidden()
                        }
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(DesignTokens.CornerRadius.lg)

                    // Title
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("Title").font(.caption).foregroundColor(theme.text)
                        DSTextField(placeholder: "Enter PR title", text: $title)
                    }

                    // Description
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("Description").font(.caption).foregroundColor(theme.text)
                        DSTextEditor(
                            placeholder: "Enter PR description...",
                            text: $prBody,
                            minHeight: 150
                        )

                        if prTemplate != nil {
                            Text("Using template")
                                .font(.caption2)
                                .foregroundColor(AppTheme.accent)
                        }
                    }

                    // Reviewers
                    if !availableReviewers.isEmpty {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text("Reviewers (optional)").font(.caption).foregroundColor(theme.text)
                            FlowLayout(spacing: DesignTokens.Spacing.sm - 2) {
                                ForEach(availableReviewers.prefix(10), id: \.id) { user in
                                    Button {
                                        toggleSelection(user.login, in: &selectedReviewers)
                                    } label: {
                                        HStack(spacing: DesignTokens.Spacing.xs) {
                                            AsyncImage(url: URL(string: user.avatarUrl)) { image in
                                                image.resizable()
                                            } placeholder: {
                                                Image(systemName: "person.circle.fill")
                                                    .foregroundColor(theme.textSecondary)
                                            }
                                            .frame(width: DesignTokens.Size.avatarXS, height: DesignTokens.Size.avatarXS)
                                            .clipShape(Circle())

                                            Text(user.login)
                                                .font(.caption)
                                        }
                                        .padding(.horizontal, DesignTokens.Spacing.sm)
                                        .padding(.vertical, DesignTokens.Spacing.xs)
                                        .background(selectedReviewers.contains(user.login) ? AppTheme.accent : theme.textMuted.opacity(0.2))
                                        .foregroundColor(selectedReviewers.contains(user.login) ? .white : .primary)
                                        .cornerRadius(DesignTokens.CornerRadius.xl)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Labels
                    if !availableLabels.isEmpty {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text("Labels (optional)").font(.caption).foregroundColor(theme.text)
                            FlowLayout(spacing: DesignTokens.Spacing.sm - 2) {
                                ForEach(availableLabels.prefix(15), id: \.id) { label in
                                    Button {
                                        toggleSelection(label.name, in: &selectedLabels)
                                    } label: {
                                        Text(label.name)
                                            .font(.caption)
                                            .padding(.horizontal, DesignTokens.Spacing.sm)
                                            .padding(.vertical, DesignTokens.Spacing.xs)
                                            .background(selectedLabels.contains(label.name) ? theme.info : theme.textMuted.opacity(0.2))
                                            .foregroundColor(selectedLabels.contains(label.name) ? .white : .primary)
                                            .cornerRadius(DesignTokens.CornerRadius.xl)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Options
                    Toggle("Create as draft", isOn: $isDraft)
                        .padding(.vertical, DesignTokens.Spacing.sm)
                }
                .padding(.horizontal)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create Pull Request") {
                    Task {
                        await createPullRequest()
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.isEmpty || headBranch.isEmpty || isGenerating)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 700, height: 650)
        .task {
            await loadMetadata()
            if let currentBranch = appState.currentRepository?.head?.name {
                headBranch = currentBranch
            }
        }
    }

    // MARK: - Actions

    private func generateTitleAndDescription() async {
        isGenerating = true
        do {
            let diff = try await GitService().getDiff(from: baseBranch, to: headBranch)
            let commits = try await GitService().getCommits(branch: headBranch, limit: 20)

            // Generate both in parallel
            async let generatedTitle = aiService.generatePRTitle(commits: commits, diff: diff)
            async let generatedDescription = aiService.generatePRDescription(
                diff: diff,
                commits: commits,
                template: prTemplate
            )

            title = try await generatedTitle
            prBody = try await generatedDescription
        } catch {
            print("Failed to generate PR content: \(error)")
        }
        isGenerating = false
    }

    private func createPullRequest() async {
        await viewModel.createPRWithMetadata(
            title: title,
            body: prBody,
            head: headBranch,
            base: baseBranch,
            draft: isDraft,
            reviewers: Array(selectedReviewers),
            assignees: Array(selectedAssignees),
            labels: Array(selectedLabels)
        )
    }

    private func loadMetadata() async {
        guard let repo = appState.currentRepository,
              let remote = repo.remotes.first(where: { $0.isGitHub }),
              let ownerRepo = remote.ownerAndRepo else { return }

        // Load PR template
        await loadPRTemplate()

        // Load collaborators (potential reviewers)
        do {
            let githubService = GitHubService()
            availableReviewers = try await githubService.getCollaborators(
                owner: ownerRepo.owner,
                repo: ownerRepo.repo
            )
        } catch {
            print("Failed to load collaborators: \(error)")
        }

        // Load labels
        do {
            let githubService = GitHubService()
            availableLabels = try await githubService.getLabels(
                owner: ownerRepo.owner,
                repo: ownerRepo.repo
            )
        } catch {
            print("Failed to load labels: \(error)")
        }
    }

    private func loadPRTemplate() async {
        guard let repoPath = appState.currentRepository?.path else { return }

        let templatePaths = [
            ".github/PULL_REQUEST_TEMPLATE.md",
            ".github/pull_request_template.md",
            "PULL_REQUEST_TEMPLATE.md",
            "docs/PULL_REQUEST_TEMPLATE.md"
        ]

        for templatePath in templatePaths {
            let fullPath = (repoPath as NSString).appendingPathComponent(templatePath)
            if FileManager.default.fileExists(atPath: fullPath),
               let content = try? String(contentsOfFile: fullPath, encoding: .utf8) {
                prTemplate = content
                prBody = content
                break
            }
        }
    }

    private func toggleSelection(_ item: String, in set: inout Set<String>) {
        if set.contains(item) {
            set.remove(item)
        } else {
            set.insert(item)
        }
    }
}

/// PR code review interface with inline comments and AI suggestions
struct PRReviewView: View {
    let pr: GitHubPullRequest
    let owner: String
    let repo: String

    @StateObject private var viewModel = PRReviewViewModel()
    @StateObject private var themeManager = ThemeManager.shared
    @State private var selectedFile: GitHubPRFile?
    @State private var showAIPanel = false
    @State private var selectedLines: Set<Int> = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        return HSplitView {
            // Left: File list
            VStack(spacing: 0) {
                fileListHeader
                Divider()
                fileList
            }
            .frame(minWidth: 250, idealWidth: 300)

            // Right: Code viewer with inline comments
            if let file = selectedFile {
                codeReviewPanel(file: file)
            } else {
                emptyStateView
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await submitReview() }
                } label: {
                    Label("Submit Review", systemImage: "checkmark.circle")
                }
                .disabled(viewModel.pendingComments.isEmpty)
            }
        }
        .task {
            await viewModel.loadReviewData(pr: pr, owner: owner, repo: repo)
            if let firstFile = viewModel.files.first {
                selectedFile = firstFile
            }
        }
    }

    // MARK: - File List Header

    private var fileListHeader: some View {
        let theme = Color.Theme(themeManager.colors)

        return HStack {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("Files Changed")
                    .font(.headline)

                Text("\(viewModel.files.count) files")
                    .font(.caption)
                    .foregroundColor(theme.text)
            }

            Spacer()

            // Review type picker
            Menu {
                Button {
                    viewModel.reviewEvent = .approve
                } label: {
                    Label("Approve", systemImage: "checkmark.circle")
                }

                Button {
                    viewModel.reviewEvent = .requestChanges
                } label: {
                    Label("Request Changes", systemImage: "exclamationmark.triangle")
                }

                Button {
                    viewModel.reviewEvent = .comment
                } label: {
                    Label("Comment", systemImage: "text.bubble")
                }
            } label: {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: reviewEventIcon)
                        .foregroundColor(reviewEventColor)
                    Text(reviewEventText)
                        .font(.caption)
                }
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .background(reviewEventColor.opacity(0.2))
                .cornerRadius(DesignTokens.CornerRadius.xl)
            }
            .menuStyle(.borderlessButton)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var reviewEventIcon: String {
        switch viewModel.reviewEvent {
        case .approve: return "checkmark.circle.fill"
        case .requestChanges: return "exclamationmark.triangle.fill"
        case .comment: return "text.bubble.fill"
        }
    }

    private var reviewEventColor: Color {
        switch viewModel.reviewEvent {
        case .approve: return AppTheme.success
        case .requestChanges: return AppTheme.error
        case .comment: return AppTheme.accent
        }
    }

    private var reviewEventText: String {
        switch viewModel.reviewEvent {
        case .approve: return "Approve"
        case .requestChanges: return "Request Changes"
        case .comment: return "Comment"
        }
    }

    // MARK: - File List

    private var fileList: some View {
        ScrollView {
            LazyVStack(spacing: DesignTokens.Spacing.xs) {
                ForEach(viewModel.files, id: \.filename) { file in
                    ReviewFileRow(
                        file: file,
                        isSelected: selectedFile?.filename == file.filename,
                        commentCount: viewModel.commentCountForFile(file.filename),
                        onSelect: { selectedFile = file }
                    )
                }
            }
            .padding(DesignTokens.Spacing.sm)
        }
    }

    // MARK: - Code Review Panel

    private func codeReviewPanel(file: GitHubPRFile) -> some View {
        let theme = Color.Theme(themeManager.colors)

        return VStack(spacing: 0) {
            // File header
            HStack {
                Image(systemName: fileIcon(for: file))
                    .foregroundColor(fileColor(for: file))

                Text(file.filename)
                    .font(.headline)

                Spacer()

                // Stats
                HStack(spacing: DesignTokens.Spacing.md) {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        Text("+\(file.additions)")
                            .foregroundColor(AppTheme.success)
                        Text("-\(file.deletions)")
                            .foregroundColor(AppTheme.error)
                    }
                    .font(.caption.monospacedDigit())

                    // AI Suggest Button
                    Button {
                        Task { await suggestImprovements(for: file) }
                    } label: {
                        HStack(spacing: DesignTokens.Spacing.xs) {
                            if viewModel.isGeneratingAI {
                                ProgressView()
                                    .scaleEffect(0.6)
                            } else {
                                Image(systemName: "sparkles")
                                    .foregroundColor(theme.accent)
                            }
                            Text("AI Suggestions")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(viewModel.isGeneratingAI)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Code diff view with inline comments
            ScrollView {
                if let patch = file.patch {
                    DiffCodeView(
                        patch: patch,
                        filename: file.filename,
                        reviewComments: viewModel.reviewComments.filter { $0.path == file.filename },
                        pendingComments: viewModel.pendingComments.filter { $0.path == file.filename },
                        selectedLines: $selectedLines,
                        onAddComment: { line in
                            viewModel.selectedLine = line
                            viewModel.selectedFile = file.filename
                            viewModel.showAddComment = true
                        },
                        onDeletePendingComment: { commentId in
                            viewModel.deletePendingComment(commentId)
                        }
                    )
                } else {
                    VStack(spacing: DesignTokens.Spacing.lg) {
                        Image(systemName: "doc.text")
                            .font(DesignTokens.Typography.iconXXXXL)
                            .foregroundColor(theme.text)
                        Text("No diff available for this file")
                            .foregroundColor(theme.text)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                }
            }
        }
        .sheet(isPresented: $viewModel.showAddComment) {
            AddReviewCommentSheet(
                filename: viewModel.selectedFile ?? "",
                line: viewModel.selectedLine ?? 1,
                onAdd: { body in
                    viewModel.addPendingComment(
                        path: viewModel.selectedFile ?? "",
                        line: viewModel.selectedLine ?? 1,
                        body: body
                    )
                }
            )
        }
        .sheet(isPresented: $viewModel.showAISuggestions) {
            if let suggestions = viewModel.aiSuggestions {
                AISuggestionsSheet(
                    suggestions: suggestions,
                    onAccept: { suggestion in
                        viewModel.addPendingComment(
                            path: file.filename,
                            line: suggestion.line,
                            body: suggestion.comment
                        )
                    }
                )
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        let theme = Color.Theme(themeManager.colors)

        return VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: DesignTokens.Size.iconXL * 2.66))
                .foregroundColor(theme.text)

            Text("Select a file to review")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Choose a file from the list to view changes and add review comments")
                .font(.callout)
                .foregroundColor(theme.text)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func fileIcon(for file: GitHubPRFile) -> String {
        switch file.status {
        case "added": return "plus.circle.fill"
        case "removed": return "minus.circle.fill"
        case "renamed": return "arrow.triangle.2.circlepath"
        default: return "pencil.circle.fill"
        }
    }

    private func fileColor(for file: GitHubPRFile) -> Color {
        switch file.status {
        case "added": return AppTheme.success
        case "removed": return AppTheme.error
        case "renamed": return AppTheme.accent
        default: return AppTheme.warning
        }
    }

    private func suggestImprovements(for file: GitHubPRFile) async {
        await viewModel.generateAISuggestions(for: file)
    }

    private func submitReview() async {
        await viewModel.submitReview(pr: pr, owner: owner, repo: repo)
        dismiss()
    }
}

// MARK: - View Model

@MainActor
class PRReviewViewModel: ObservableObject {
    @Published var files: [GitHubPRFile] = []
    @Published var reviewComments: [GitHubReviewComment] = []
    @Published var pendingComments: [PendingReviewComment] = []
    @Published var reviewEvent: ReviewEvent = .comment
    @Published var reviewBody: String = ""
    @Published var isLoading = false
    @Published var isGeneratingAI = false
    @Published var showAddComment = false
    @Published var showAISuggestions = false
    @Published var selectedLine: Int?
    @Published var selectedFile: String?
    @Published var aiSuggestions: [AISuggestion]?

    private var commitId: String?
    private let githubService = GitHubService()
    private let aiService = AIService()

    func loadReviewData(pr: GitHubPullRequest, owner: String, repo: String) async {
        isLoading = true
        commitId = pr.head.sha

        do {
            async let filesTask = githubService.getPullRequestFiles(owner: owner, repo: repo, number: pr.number)
            async let commentsTask = githubService.getPullRequestReviewComments(owner: owner, repo: repo, number: pr.number)

            files = try await filesTask
            reviewComments = try await commentsTask
        } catch {
            print("Failed to load review data: \(error)")
        }

        isLoading = false
    }

    func addPendingComment(path: String, line: Int, body: String) {
        let comment = PendingReviewComment(
            id: UUID(),
            path: path,
            line: line,
            body: body
        )
        pendingComments.append(comment)
        showAddComment = false
    }

    func deletePendingComment(_ id: UUID) {
        pendingComments.removeAll { $0.id == id }
    }

    func commentCountForFile(_ filename: String) -> Int {
        let existing = reviewComments.filter { $0.path == filename }.count
        let pending = pendingComments.filter { $0.path == filename }.count
        return existing + pending
    }

    func generateAISuggestions(for file: GitHubPRFile) async {
        guard let patch = file.patch else { return }

        isGeneratingAI = true

        do {
            let suggestions = try await aiService.suggestCodeImprovements(
                filename: file.filename,
                patch: patch
            )
            aiSuggestions = suggestions
            showAISuggestions = true
        } catch {
            print("Failed to generate AI suggestions: \(error)")
        }

        isGeneratingAI = false
    }

    func submitReview(pr: GitHubPullRequest, owner: String, repo: String) async {
        guard let commitId = commitId else { return }

        isLoading = true

        do {
            let commentInputs = pendingComments.map { comment in
                ReviewCommentInput(
                    path: comment.path,
                    line: comment.line,
                    body: comment.body
                )
            }

            _ = try await githubService.createReview(
                owner: owner,
                repo: repo,
                number: pr.number,
                commitId: commitId,
                body: reviewBody.isEmpty ? nil : reviewBody,
                event: reviewEvent,
                comments: commentInputs.isEmpty ? nil : commentInputs
            )

            NotificationManager.shared.success(
                "Review submitted",
                detail: "Your review has been posted to PR #\(pr.number)"
            )

            pendingComments.removeAll()
        } catch {
            NotificationManager.shared.error(
                "Failed to submit review",
                detail: error.localizedDescription
            )
        }

        isLoading = false
    }
}

// MARK: - Supporting Views

struct ReviewFileRow: View {
    let file: GitHubPRFile
    let isSelected: Bool
    let commentCount: Int
    let onSelect: () -> Void
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        return HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
                .frame(width: DesignTokens.Size.iconLG)

            Text(file.filename)
                .font(.caption)
                .lineLimit(2)

            Spacer()

            if commentCount > 0 {
                Text("\(commentCount)")
                    .font(.caption2)
                    .padding(.horizontal, DesignTokens.Spacing.sm - 2)
                    .padding(.vertical, DesignTokens.Spacing.xxs)
                    .background(theme.info.opacity(0.2))
                    .foregroundColor(AppTheme.accent)
                    .cornerRadius(DesignTokens.CornerRadius.lg)
            }

            HStack(spacing: DesignTokens.Spacing.xs) {
                Text("+\(file.additions)")
                    .foregroundColor(AppTheme.success)
                Text("-\(file.deletions)")
                    .foregroundColor(AppTheme.error)
            }
            .font(.caption2.monospacedDigit())
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(isSelected ? AppTheme.accent.opacity(0.2) : Color.clear)
        .cornerRadius(DesignTokens.CornerRadius.md)
        .onTapGesture { onSelect() }
    }

    private var statusIcon: String {
        switch file.status {
        case "added": return "plus.circle.fill"
        case "removed": return "minus.circle.fill"
        case "renamed": return "arrow.triangle.2.circlepath"
        default: return "pencil.circle.fill"
        }
    }

    private var statusColor: Color {
        switch file.status {
        case "added": return AppTheme.success
        case "removed": return AppTheme.error
        case "renamed": return AppTheme.accent
        default: return AppTheme.warning
        }
    }
}

struct DiffCodeView: View {
    let patch: String
    let filename: String
    let reviewComments: [GitHubReviewComment]
    let pendingComments: [PendingReviewComment]
    @Binding var selectedLines: Set<Int>
    let onAddComment: (Int) -> Void
    let onDeletePendingComment: (UUID) -> Void
    @StateObject private var themeManager = ThemeManager.shared

    @State private var hoveredLine: Int?

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        return VStack(alignment: .leading, spacing: 0) {
            ForEach(parsedDiffLines, id: \.lineNumber) { diffLine in
                HStack(spacing: 0) {
                    // Line number
                    HStack(spacing: 4) {
                        Text(diffLine.oldLineNumber.map { "\($0)" } ?? "")
                            .frame(width: 40, alignment: .trailing)
                            .foregroundColor(theme.text)

                        Text(diffLine.newLineNumber.map { "\($0)" } ?? "")
                            .frame(width: 40, alignment: .trailing)
                            .foregroundColor(theme.text)
                    }
                    .font(.system(.caption, design: .monospaced))
                    .padding(.horizontal, 8)
                    .background(Color(nsColor: .controlBackgroundColor))

                    // Add comment button (on hover)
                    if hoveredLine == diffLine.lineNumber, diffLine.type != .context {
                        Button {
                            if let lineNum = diffLine.newLineNumber {
                                onAddComment(lineNum)
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(AppTheme.accent)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, DesignTokens.Spacing.xs)
                    } else {
                        Spacer().frame(width: 28)
                    }

                    // Code content
                    Text(diffLine.content)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(lineBackground(for: diffLine))
                }
                .onHover { isHovered in
                    hoveredLine = isHovered ? diffLine.lineNumber : nil
                }

                // Show existing comments
                if let lineNum = diffLine.newLineNumber {
                    ForEach(reviewComments.filter { $0.line == lineNum }, id: \.id) { comment in
                        ReviewCommentRow(comment: comment)
                    }

                    ForEach(pendingComments.filter { $0.line == lineNum }, id: \.id) { comment in
                        PendingReviewCommentRow(
                            comment: comment,
                            onDelete: { onDeletePendingComment(comment.id) }
                        )
                    }
                }
            }
        }
        .padding()
    }

    private var parsedDiffLines: [ReviewDiffLine] {
        ReviewDiffParser.parse(patch)
    }

    private func lineBackground(for diffLine: ReviewDiffLine) -> Color {
        let theme = Color.Theme(themeManager.colors)
        switch diffLine.type {
        case .addition: return theme.diffAdditionBg
        case .deletion: return theme.diffDeletionBg
        case .context: return .clear
        }
    }
}

struct ReviewCommentRow: View {
    let comment: GitHubReviewComment
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        return HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            AsyncImage(url: URL(string: comment.user.avatarUrl)) { image in
                image.resizable()
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(theme.text)
            }
            .frame(width: DesignTokens.Size.avatarMD, height: DesignTokens.Size.avatarMD)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                HStack {
                    Text(comment.user.login)
                        .font(.caption)
                        .fontWeight(.semibold)

                    Text(formatDate(comment.createdAt))
                        .font(.caption2)
                        .foregroundColor(theme.text)
                }

                Text(comment.body)
                    .font(.callout)
            }
        }
        .padding()
        .background(theme.info.opacity(0.05))
        .cornerRadius(DesignTokens.CornerRadius.lg)
        .padding(.leading, 100)
        .padding(.trailing, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.xs)
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return dateString }

        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .abbreviated
        return relative.localizedString(for: date, relativeTo: Date())
    }
}

struct PendingReviewCommentRow: View {
    let comment: PendingReviewComment
    let onDelete: () -> Void
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        return HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            Image(systemName: "person.circle.fill")
                .resizable()
                .foregroundColor(theme.text)
                .frame(width: DesignTokens.Size.avatarMD, height: DesignTokens.Size.avatarMD)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                HStack {
                    Text("You")
                        .font(.caption)
                        .fontWeight(.semibold)

                    Text("Pending")
                        .font(.caption2)
                        .padding(.horizontal, DesignTokens.Spacing.sm - 2)
                        .padding(.vertical, DesignTokens.Spacing.xxs)
                        .background(theme.warning.opacity(0.2))
                        .foregroundColor(AppTheme.warning)
                        .cornerRadius(DesignTokens.CornerRadius.sm)

                    Spacer()

                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(AppTheme.error)
                }

                Text(comment.body)
                    .font(.callout)
            }
        }
        .padding()
        .background(theme.warning.opacity(0.05))
        .cornerRadius(DesignTokens.CornerRadius.lg)
        .padding(.leading, 100)
        .padding(.trailing, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.xs)
    }
}

struct AddReviewCommentSheet: View {
    let filename: String
    let line: Int
    @State private var commentText = ""
    let onAdd: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        return VStack(spacing: DesignTokens.Spacing.lg) {
            HStack {
                Text("Add Review Comment")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                HStack {
                    Text(filename)
                        .font(.caption)
                        .foregroundColor(theme.text)

                    Text("Line \(line)")
                        .font(.caption)
                        .padding(.horizontal, DesignTokens.Spacing.sm - 2)
                        .padding(.vertical, DesignTokens.Spacing.xxs)
                        .background(theme.info.opacity(0.2))
                        .foregroundColor(AppTheme.accent)
                        .cornerRadius(DesignTokens.CornerRadius.sm)
                }

                TextEditor(text: $commentText)
                    .font(.body)
                    .frame(minHeight: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                            .stroke(AppTheme.textSecondary.opacity(0.3), lineWidth: 1)
                    )
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add Comment") {
                    onAdd(commentText)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 500, height: 300)
    }
}

struct AISuggestionsSheet: View {
    let suggestions: [AISuggestion]
    let onAccept: (AISuggestion) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        return VStack(spacing: DesignTokens.Spacing.lg) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.title)
                    .foregroundColor(AppTheme.accent)

                Text("AI Code Suggestions")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()
            }

            ScrollView {
                VStack(spacing: DesignTokens.Spacing.md) {
                    ForEach(suggestions) { suggestion in
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                            HStack {
                                Text("Line \(suggestion.line)")
                                    .font(.caption)
                                    .padding(.horizontal, DesignTokens.Spacing.sm - 2)
                                    .padding(.vertical, DesignTokens.Spacing.xxs)
                                    .background(theme.info.opacity(0.2))
                                    .foregroundColor(AppTheme.accent)
                                    .cornerRadius(DesignTokens.CornerRadius.sm)

                                Text(suggestion.category)
                                    .font(.caption)
                                    .padding(.horizontal, DesignTokens.Spacing.sm - 2)
                                    .padding(.vertical, DesignTokens.Spacing.xxs)
                                    .background(categoryColor(suggestion.category).opacity(0.2))
                                    .foregroundColor(categoryColor(suggestion.category))
                                    .cornerRadius(DesignTokens.CornerRadius.sm)

                                Spacer()

                                Button("Add as Comment") {
                                    onAccept(suggestion)
                                    dismiss()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }

                            Text(suggestion.comment)
                                .font(.body)
                        }
                        .padding()
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(DesignTokens.CornerRadius.lg)
                    }
                }
            }

            HStack {
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding()
        .frame(width: 600, height: 500)
    }

    private func categoryColor(_ category: String) -> Color {
        switch category.lowercased() {
        case "performance": return AppTheme.warning
        case "security": return AppTheme.error
        case "style": return AppTheme.accent
        case "bug": return AppTheme.accentPurple
        default: return AppTheme.textSecondary
        }
    }
}

// MARK: - Models

struct PendingReviewComment: Identifiable {
    let id: UUID
    let path: String
    let line: Int
    let body: String
}

// MARK: - Diff Parser

struct ReviewDiffLine {
    let lineNumber: Int
    let oldLineNumber: Int?
    let newLineNumber: Int?
    let type: ReviewDiffLineType
    let content: String
}

enum ReviewDiffLineType {
    case addition
    case deletion
    case context
}

struct ReviewDiffParser {
    static func parse(_ patch: String) -> [ReviewDiffLine] {
        var result: [ReviewDiffLine] = []
        var lineNumber = 0
        var oldLine = 0
        var newLine = 0

        let lines = patch.components(separatedBy: .newlines)

        for line in lines {
            if line.hasPrefix("@@") {
                // Parse hunk header
                let components = line.components(separatedBy: " ")
                if components.count >= 3 {
                    let oldRange = components[1].dropFirst()
                    let newRange = components[2]

                    if let oldStart = oldRange.components(separatedBy: ",").first.flatMap({ Int($0) }) {
                        oldLine = oldStart
                    }

                    if let newStart = newRange.components(separatedBy: ",").first.flatMap({ Int($0) }) {
                        newLine = newStart
                    }
                }
                continue
            }

            lineNumber += 1

            if line.hasPrefix("+") && !line.hasPrefix("+++") {
                result.append(ReviewDiffLine(
                    lineNumber: lineNumber,
                    oldLineNumber: nil,
                    newLineNumber: newLine,
                    type: .addition,
                    content: String(line.dropFirst())
                ))
                newLine += 1
            } else if line.hasPrefix("-") && !line.hasPrefix("---") {
                result.append(ReviewDiffLine(
                    lineNumber: lineNumber,
                    oldLineNumber: oldLine,
                    newLineNumber: nil,
                    type: .deletion,
                    content: String(line.dropFirst())
                ))
                oldLine += 1
            } else if !line.hasPrefix("\\") {
                result.append(ReviewDiffLine(
                    lineNumber: lineNumber,
                    oldLineNumber: oldLine,
                    newLineNumber: newLine,
                    type: .context,
                    content: line.hasPrefix(" ") ? String(line.dropFirst()) : line
                ))
                oldLine += 1
                newLine += 1
            }
        }

        return result
    }
}
