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

    var statusColor: Color {
        switch status {
        case "queued": return .orange
        case "in_progress": return .blue
        case "completed":
            switch conclusion {
            case "success": return .green
            case "failure": return .red
            case "cancelled": return .gray
            case "skipped": return .gray
            default: return .secondary
            }
        default: return .secondary
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
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = WorkflowsViewModel()
    @State private var selectedFilter: WorkflowFilter = .all
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("WORKFLOWS")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .disabled(viewModel.isLoading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))

            if viewModel.error != nil {
                errorView
            } else if !viewModel.isConfigured {
                notConfiguredView
            } else {
                // Filters
                HStack(spacing: 8) {
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
                    Spacer()
                }
                .padding(8)

                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Filter workflows...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)
                .padding(.horizontal, 8)

                // Content
                if viewModel.isLoading && viewModel.runs.isEmpty {
                    ProgressView()
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
                }

                // Status bar
                HStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.6)
                    }

                    Text("\(viewModel.runs.count) workflow runs")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    Spacer()

                    if let lastUpdate = viewModel.lastUpdate {
                        Text("Updated \(lastUpdate, style: .relative) ago")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(8)
                .background(Color.gray.opacity(0.05))
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
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundColor(.orange)

            Text("Failed to load workflows")
                .font(.system(size: 13, weight: .medium))

            Text(viewModel.error ?? "")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Retry") {
                Task { await viewModel.refresh() }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var notConfiguredView: some View {
        VStack(spacing: 12) {
            Image(systemName: "gearshape.2")
                .font(.system(size: 32))
                .foregroundColor(.secondary)

            Text("GitHub not configured")
                .font(.system(size: 13, weight: .medium))

            Text("Add a GitHub token in Settings to view workflow runs")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 24))
                .foregroundColor(.secondary)
            Text("No workflow runs")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
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

    var color: Color {
        switch self {
        case .all: return .secondary
        case .success: return .green
        case .failed: return .red
        case .inProgress: return .blue
        }
    }
}

struct FilterButton: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 11))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(isSelected ? Color.white.opacity(0.3) : color.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? color : Color.gray.opacity(0.1))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Workflow Run Row

struct WorkflowRunRow: View {
    let run: WorkflowRun
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            // Status icon
            Image(systemName: run.statusIcon)
                .font(.system(size: 16))
                .foregroundColor(run.statusColor)
                .frame(width: 24)

            // Main content
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(run.name)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)

                    if run.status == "in_progress" {
                        ProgressView()
                            .scaleEffect(0.5)
                    }
                }

                HStack(spacing: 6) {
                    // Event type
                    Label(run.event.replacingOccurrences(of: "_", with: " "), systemImage: eventIcon(for: run.event))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    Text("•")
                        .foregroundColor(.secondary)

                    // Commit
                    Text(run.shortSha)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)

                    if let actor = run.actor {
                        Text("by \(actor.login)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Branch badge
            Text(run.headBranch)
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.15))
                .foregroundColor(.blue)
                .cornerRadius(4)

            // Time info
            VStack(alignment: .trailing, spacing: 2) {
                Text(run.timeAgo)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                if let duration = run.duration {
                    HStack(spacing: 2) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                        Text(duration)
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.secondary)
                }
            }

            // External link
            if isHovered {
                Image(systemName: "arrow.up.forward.square")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHovered ? Color.gray.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
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
    let status: String
    let conclusion: String?

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(displayText)
                .font(.system(size: 10, weight: .medium))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.15))
        .foregroundColor(color)
        .cornerRadius(4)
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

    private var color: Color {
        switch status {
        case "queued": return .orange
        case "in_progress": return .blue
        case "completed":
            switch conclusion {
            case "success": return .green
            case "failure": return .red
            default: return .gray
            }
        default: return .secondary
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
