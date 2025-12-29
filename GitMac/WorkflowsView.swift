import SwiftUI

// MARK: - Workflow Models

struct WorkflowRun: Identifiable, Codable {
    let id: Int
    let name: String
    let headBranch: String
    let headSha: String
    let status: String // queued, in_progress, completed
    let conclusion: String? // success, failure, cancelled, skipped, neutral
    let workflowId: Int
    let runNumber: Int
    let event: String // push, pull_request, workflow_dispatch, etc.
    let createdAt: Date
    let updatedAt: Date
    let htmlUrl: String
    let actor: WorkflowActor?
    let runStartedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, status, conclusion, event
        case headBranch = "head_branch"
        case headSha = "head_sha"
        case workflowId = "workflow_id"
        case runNumber = "run_number"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case htmlUrl = "html_url"
        case actor
        case runStartedAt = "run_started_at"
    }

    var shortSha: String {
        String(headSha.prefix(7))
    }

    var statusIcon: String {
        switch status {
        case "queued": return "clock.fill"
        case "in_progress": return "arrow.triangle.2.circlepath"
        case "completed":
            switch conclusion {
            case "success": return "checkmark.circle.fill"
            case "failure": return "xmark.circle.fill"
            case "cancelled": return "stop.circle.fill"
            case "skipped": return "forward.circle.fill"
            default: return "questionmark.circle.fill"
            }
        default: return "questionmark.circle"
        }
    }

    @MainActor
    var statusColor: Color {
        switch status {
        case "queued": return AppTheme.warning
        case "in_progress": return AppTheme.info
        case "completed":
            switch conclusion {
            case "success": return AppTheme.success
            case "failure": return AppTheme.error
            case "cancelled": return AppTheme.textMuted
            case "skipped": return AppTheme.textMuted
            default: return AppTheme.textSecondary
            }
        default: return AppTheme.textSecondary
        }
    }

    var displayStatus: String {
        switch status {
        case "queued": return "Queued"
        case "in_progress": return "In Progress"
        case "completed":
            switch conclusion {
            case "success": return "Success"
            case "failure": return "Failed"
            case "cancelled": return "Cancelled"
            case "skipped": return "Skipped"
            default: return conclusion ?? "Unknown"
            }
        default: return status
        }
    }

    var duration: String? {
        guard let startedAt = runStartedAt else { return nil }
        let elapsed = updatedAt.timeIntervalSince(startedAt)
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        return "\(minutes)m \(seconds)s"
    }

    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

struct WorkflowActor: Codable {
    let login: String
    let avatarUrl: String

    enum CodingKeys: String, CodingKey {
        case login
        case avatarUrl = "avatar_url"
    }
}

struct Workflow: Identifiable, Codable {
    let id: Int
    let name: String
    let path: String
    let state: String // active, disabled
}

struct WorkflowRunsResponse: Codable {
    let totalCount: Int
    let workflowRuns: [WorkflowRun]

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case workflowRuns = "workflow_runs"
    }
}

struct WorkflowsResponse: Codable {
    let totalCount: Int
    let workflows: [Workflow]

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case workflows
    }
}

// MARK: - Workflows View

struct WorkflowsView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = WorkflowsViewModel()
    @State private var selectedFilter: WorkflowFilter = .all
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header usando componentes custom con Design System
            HStack {
                DSText("WORKFLOWS", variant: .caption, color: AppTheme.textPrimary)
                    .fontWeight(.semibold)

                Spacer()

                DSIconButton(
                    iconName: "arrow.clockwise",
                    size: .sm,
                    isDisabled: viewModel.isLoading
                ) {
                    Task { await viewModel.refresh() }
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(AppTheme.backgroundSecondary)

            if viewModel.error != nil {
                errorView
            } else if !viewModel.isConfigured {
                notConfiguredView
            } else {
                // Filters usando HStack con botones DS
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        ForEach(WorkflowFilter.allCases, id: \.self) { filter in
                            FilterButton(
                                title: filter.title,
                                count: viewModel.count(for: filter),
                                isSelected: selectedFilter == filter,
                                color: filter.color
                            ) {
                                selectedFilter = filter
                            }
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, DesignTokens.Spacing.sm)
                }

                // Search usando DSSearchField
                DSSearchField(
                    placeholder: "Filter workflows...",
                    text: $searchText
                )
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.bottom, DesignTokens.Spacing.xs)

                // Content
                if viewModel.isLoading && viewModel.runs.isEmpty {
                    DSLoadingState(message: "Loading workflows...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredRuns.isEmpty {
                    emptyView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredRuns) { run in
                                WorkflowRunRow(run: run)
                                    .onTapGesture {
                                        if let url = URL(string: run.htmlUrl) {
                                            NSWorkspace.shared.open(url)
                                        }
                                    }
                            }
                        }
                    }
                    .background(AppTheme.background)
                }

                // Status bar
                HStack(spacing: DesignTokens.Spacing.sm) {
                    if viewModel.isLoading {
                        DSSpinner(size: .sm)
                    }

                    DSText(
                        "\(viewModel.runs.count) workflow runs",
                        variant: .caption2,
                        color: AppTheme.textSecondary
                    )

                    Spacer()

                    if let lastUpdate = viewModel.lastUpdate {
                        Text("Updated \(lastUpdate, style: .relative) ago")
                            .font(DesignTokens.Typography.caption2)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
                .padding(DesignTokens.Spacing.sm)
                .background(AppTheme.backgroundSecondary.opacity(0.3))
            }
        }
        .task {
            await viewModel.configure(with: appState)
            await viewModel.refresh()
        }
        .onChange(of: appState.currentRepository?.path) { _, _ in
            Task {
                await viewModel.configure(with: appState)
                await viewModel.refresh()
            }
        }
    }

    private var filteredRuns: [WorkflowRun] {
        var runs = viewModel.runs

        // Apply status filter
        switch selectedFilter {
        case .all:
            break
        case .success:
            runs = runs.filter { $0.conclusion == "success" }
        case .failed:
            runs = runs.filter { $0.conclusion == "failure" }
        case .inProgress:
            runs = runs.filter { $0.status == "in_progress" || $0.status == "queued" }
        }

        // Apply search filter
        if !searchText.isEmpty {
            runs = runs.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.headBranch.localizedCaseInsensitiveContains(searchText) ||
                $0.actor?.login.localizedCaseInsensitiveContains(searchText) == true
            }
        }

        return runs
    }

    private var errorView: some View {
        DSErrorState(
            title: "Failed to load workflows",
            message: viewModel.error ?? "Unknown error",
            onRetry: {
                Task { await viewModel.refresh() }
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var notConfiguredView: some View {
        DSEmptyState(
            icon: "gearshape.2",
            title: "GitHub not configured",
            description: "Add a GitHub token in Settings to view workflow runs"
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        DSEmptyState(
            icon: "tray",
            title: "No workflow runs",
            description: searchText.isEmpty ? "No workflow runs found" : "Try adjusting your filters"
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Filter

enum WorkflowFilter: CaseIterable {
    case all, success, failed, inProgress

    var title: String {
        switch self {
        case .all: return "All"
        case .success: return "Success"
        case .failed: return "Failed"
        case .inProgress: return "Running"
        }
    }

    @MainActor
    var color: Color {
        switch self {
        case .all: return AppTheme.textSecondary
        case .success: return AppTheme.success
        case .failed: return AppTheme.error
        case .inProgress: return AppTheme.info
        }
    }
}

struct FilterButton: View {
    @StateObject private var themeManager = ThemeManager.shared

    let title: String
    let count: Int
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        DSButton(
            variant: isSelected ? .primary : .ghost,
            size: .sm
        ) {
            action()
        } label: {
            HStack(spacing: DesignTokens.Spacing.xxs) {
                DSText(title, variant: .caption)

                if count > 0 {
                    DSBadge(
                        "\(count)",
                        variant: isSelected ? .neutral : .info
                    )
                }
            }
        }
    }
}

// MARK: - Workflow Run Row

struct WorkflowRunRow: View {
    @StateObject private var themeManager = ThemeManager.shared

    let run: WorkflowRun
    @State private var isHovered = false

    var body: some View {
        DSListItem(
            title: run.name,
            subtitle: subtitleText,
            leading: {
                DSIcon(
                    run.statusIcon,
                    size: .md,
                    color: run.statusColor
                )
            },
            trailing: {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    // Branch badge
                    DSBadge(run.headBranch, variant: .info)

                    // Time info
                    VStack(alignment: .trailing, spacing: DesignTokens.Spacing.xxs) {
                        DSText(
                            run.timeAgo,
                            variant: .caption2,
                            color: AppTheme.textSecondary
                        )

                        if let duration = run.duration {
                            HStack(spacing: DesignTokens.Spacing.xxs) {
                                DSIcon("clock", size: .sm, color: AppTheme.textMuted)
                                DSText(
                                    duration,
                                    variant: .caption2,
                                    color: AppTheme.textSecondary
                                )
                            }
                        }
                    }

                    // External link on hover
                    if isHovered {
                        DSIcon(
                            "arrow.up.forward.square",
                            size: .sm,
                            color: AppTheme.accent
                        )
                    }
                }
            }
        )
        .onHover { isHovered = $0 }
    }

    private var subtitleText: String {
        var components: [String] = []

        // Event type
        components.append(run.event.replacingOccurrences(of: "_", with: " "))

        // Commit SHA
        components.append(run.shortSha)

        // Actor
        if let actor = run.actor {
            components.append("by \(actor.login)")
        }

        return components.joined(separator: " • ")
    }

    private func eventIcon(for event: String) -> String {
        switch event {
        case "push": return "arrow.up.circle"
        case "pull_request": return "arrow.triangle.pull"
        case "workflow_dispatch": return "play.circle"
        case "schedule": return "clock"
        case "release": return "tag"
        default: return "bolt.circle"
        }
    }
}

// MARK: - View Model

@MainActor
class WorkflowsViewModel: ObservableObject {
    @Published var runs: [WorkflowRun] = []
    @Published var workflows: [Workflow] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var isConfigured = false
    @Published var lastUpdate: Date?

    private var owner: String = ""
    private var repo: String = ""
    private var token: String = ""

    func configure(with appState: AppState) async {
        // Get GitHub token from keychain
        token = (try? await KeychainManager.shared.getGitHubToken()) ?? ""

        guard !token.isEmpty else {
            isConfigured = false
            return
        }

        // Parse owner/repo from remote URL
        guard let remote = appState.currentRepository?.remotes.first,
              let url = URL(string: remote.fetchURL) else {
            isConfigured = false
            return
        }

        let pathComponents = url.path
            .replacingOccurrences(of: ".git", with: "")
            .split(separator: "/")
            .map(String.init)

        guard pathComponents.count >= 2 else {
            isConfigured = false
            return
        }

        owner = pathComponents[pathComponents.count - 2]
        repo = pathComponents[pathComponents.count - 1]
        isConfigured = true
    }

    func refresh() async {
        guard isConfigured else { return }

        isLoading = true
        error = nil

        do {
            runs = try await fetchWorkflowRuns()
            lastUpdate = Date()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    private func fetchWorkflowRuns() async throws -> [WorkflowRun] {
        let urlString = "https://api.github.com/repos/\(owner)/\(repo)/actions/runs?per_page=50"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "Invalid GitHub token"])
            } else if httpResponse.statusCode == 404 {
                throw NSError(domain: "", code: 404, userInfo: [NSLocalizedDescriptionKey: "Repository not found or no workflows"])
            }
            throw NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"])
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let result = try decoder.decode(WorkflowRunsResponse.self, from: data)
        return result.workflowRuns
    }

    func count(for filter: WorkflowFilter) -> Int {
        switch filter {
        case .all: return runs.count
        case .success: return runs.filter { $0.conclusion == "success" }.count
        case .failed: return runs.filter { $0.conclusion == "failure" }.count
        case .inProgress: return runs.filter { $0.status == "in_progress" || $0.status == "queued" }.count
        }
    }
}

// MARK: - Workflow Status Badge (for use in other views)

struct WorkflowStatusBadge: View {
    @StateObject private var themeManager = ThemeManager.shared

    let status: String
    let conclusion: String?

    var body: some View {
        DSStatusBadge(
            displayText,
            icon: icon,
            variant: badgeVariant
        )
    }

    private var icon: String {
        switch status {
        case "queued": return "clock.fill"
        case "in_progress": return "arrow.triangle.2.circlepath"
        case "completed":
            switch conclusion {
            case "success": return "checkmark.circle.fill"
            case "failure": return "xmark.circle.fill"
            default: return "minus.circle.fill"
            }
        default: return "questionmark.circle"
        }
    }

    private var badgeVariant: DSStatusVariant {
        switch status {
        case "queued": return .warning
        case "in_progress": return .info
        case "completed":
            switch conclusion {
            case "success": return .success
            case "failure": return .error
            default: return .neutral
            }
        default: return .neutral
        }
    }

    private var displayText: String {
        switch status {
        case "queued": return "Queued"
        case "in_progress": return "Running"
        case "completed":
            switch conclusion {
            case "success": return "Success"
            case "failure": return "Failed"
            case "cancelled": return "Cancelled"
            default: return conclusion ?? "Done"
            }
        default: return status
        }
    }
}
