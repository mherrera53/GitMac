import SwiftUI

/// GitHub Issues list and detail view
struct IssueListView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = IssueListViewModel()
    @State private var selectedIssue: GitHubIssue?
    @State private var showCreateIssueSheet = false
    @State private var filterState: IssueState = .open
    @State private var searchText = ""

    var body: some View {
        HSplitView {
            // Left: Issue List
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Issues")
                        .font(.headline)

                    Spacer()

                    Picker("Filter", selection: $filterState) {
                        Text("Open").tag(IssueState.open)
                        Text("Closed").tag(IssueState.closed)
                        Text("All").tag(IssueState.all)
                    }
                    .frame(width: 180)

                    DSIconButton(iconName: "plus", variant: .primary, size: .sm) {
                        showCreateIssueSheet = true
                    }
                    .help("Create Issue")
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))

                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppTheme.textPrimary)
                    DSSearchField(
                        placeholder: "Search issues...",
                        text: $searchText
                    )
                }
                .padding(DesignTokens.Spacing.sm)
                .background(Color(nsColor: .textBackgroundColor))

                Divider()

                // List
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredIssues.isEmpty {
                    EmptyIssueView(state: filterState)
                } else {
                    List(filteredIssues, selection: $selectedIssue) { issue in
                        IssueRow(issue: issue, isSelected: selectedIssue?.id == issue.id)
                            .tag(issue)
                    }
                    .listStyle(.plain)
                }
            }
            .frame(minWidth: 300, idealWidth: 350)

            // Right: Issue Detail
            if let issue = selectedIssue {
                IssueDetailView(issue: issue, viewModel: viewModel)
            } else {
                VStack {
                    Spacer()
                    Image(systemName: "exclamationmark.circle")
                        .font(DesignTokens.Typography.iconXXXXL)
                        .foregroundColor(AppTheme.textPrimary)
                    Text("Select an issue")
                        .foregroundColor(AppTheme.textPrimary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .sheet(isPresented: $showCreateIssueSheet) {
            CreateIssueSheet(viewModel: viewModel)
        }
        .onChange(of: filterState) { _, newState in
            Task { await viewModel.loadIssues(state: newState) }
        }
        .task {
            if let repo = appState.currentRepository,
               let remote = repo.remotes.first(where: { $0.isGitHub }),
               let ownerRepo = remote.ownerAndRepo {
                viewModel.owner = ownerRepo.owner
                viewModel.repo = ownerRepo.repo
                await viewModel.loadIssues(state: filterState)
            }
        }
    }

    var filteredIssues: [GitHubIssue] {
        if searchText.isEmpty {
            return viewModel.issues
        }
        return viewModel.issues.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            ($0.body?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
}

// MARK: - View Model

@MainActor
class IssueListViewModel: ObservableObject {
    @Published var issues: [GitHubIssue] = []
    @Published var isLoading = false
    @Published var error: String?

    var owner: String = ""
    var repo: String = ""

    private let githubService = GitHubService()

    func loadIssues(state: IssueState = .open) async {
        guard !owner.isEmpty && !repo.isEmpty else { return }

        isLoading = true
        do {
            issues = try await githubService.listIssues(owner: owner, repo: repo, state: state)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func createIssue(title: String, body: String?, labels: [String]?) async {
        do {
            _ = try await githubService.createIssue(
                owner: owner,
                repo: repo,
                title: title,
                body: body,
                labels: labels
            )
            await loadIssues()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Subviews

struct IssueRow: View {
    let issue: GitHubIssue
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs) {
            HStack {
                Image(systemName: issue.state == "open" ? "circle" : "checkmark.circle.fill")
                    .foregroundColor(issue.state == "open" ? AppTheme.success : AppTheme.accentPurple)

                Text("#\(issue.number)")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(AppTheme.textPrimary)

                Text(issue.title)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Spacer()
            }

            // Labels
            if !issue.labels.isEmpty {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    ForEach(issue.labels.prefix(3)) { label in
                        IssueLabelBadge(label: label)
                    }
                    if issue.labels.count > 3 {
                        Text("+\(issue.labels.count - 3)")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(AppTheme.textPrimary)
                    }
                }
            }

            // Meta
            HStack {
                AsyncImage(url: URL(string: issue.user.avatarUrl)) { image in
                    image.resizable()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(AppTheme.textSecondary)
                }
                .frame(width: 16, height: 16)
                .clipShape(Circle())

                Text(issue.user.login)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.textPrimary)

                Text("•")
                    .foregroundColor(AppTheme.textPrimary)

                Text(formatDate(issue.createdAt))
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.textPrimary)
            }
        }
        .padding(.vertical, DesignTokens.Spacing.sm)
        .padding(.horizontal, DesignTokens.Spacing.xs)
        .background(isSelected ? AppTheme.accent.opacity(0.1) : Color.clear)
        .cornerRadius(DesignTokens.CornerRadius.sm)
    }

    func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return dateString }

        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .abbreviated
        return relative.localizedString(for: date, relativeTo: Date())
    }
}

struct IssueLabelBadge: View {
    let label: GitHubLabel

    var body: some View {
        Text(label.name)
            .font(DesignTokens.Typography.caption2)
            .padding(.horizontal, DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
            .padding(.vertical, DesignTokens.Spacing.xxs)
            .background(Color(hex: label.color).opacity(0.3))
            .foregroundColor(Color(hex: label.color))
            .cornerRadius(DesignTokens.CornerRadius.lg + DesignTokens.Spacing.xxs)
    }
}

struct IssueDetailView: View {
    let issue: GitHubIssue
    @ObservedObject var viewModel: IssueListViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                // Header
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    HStack {
                        IssueStatusBadge(state: issue.state)

                        Text("#\(issue.number)")
                            .font(DesignTokens.Typography.title3)
                            .foregroundColor(AppTheme.textPrimary)

                        Spacer()

                        Button {
                            NSWorkspace.shared.open(URL(string: issue.htmlUrl)!)
                        } label: {
                            Label("Open in GitHub", systemImage: "arrow.up.right.square")
                        }
                        .buttonStyle(.borderless)
                    }

                    Text(issue.title)
                        .font(DesignTokens.Typography.title2)
                        .fontWeight(.bold)

                    // Labels
                    if !issue.labels.isEmpty {
                        FlowLayout(spacing: DesignTokens.Spacing.xs) {
                            ForEach(issue.labels) { label in
                                IssueLabelBadge(label: label)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(DesignTokens.CornerRadius.lg)

                // Author info
                HStack {
                    AsyncImage(url: URL(string: issue.user.avatarUrl)) { image in
                        image.resizable()
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())

                    VStack(alignment: .leading) {
                        Text(issue.user.login)
                            .fontWeight(.medium)
                        Text("opened this issue \(formatDate(issue.createdAt))")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(AppTheme.textPrimary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(DesignTokens.CornerRadius.lg)

                // Body
                if let body = issue.body, !body.isEmpty {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Text("Description")
                            .font(DesignTokens.Typography.headline)

                        Text(body)
                            .font(.body)
                            .textSelection(.enabled)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(DesignTokens.CornerRadius.lg)
                }

                // Actions
                if issue.state == "open" {
                    HStack {
                        Button {
                            // Create branch from issue
                        } label: {
                            Label("Create Branch", systemImage: "arrow.triangle.branch")
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        Button {
                            // Close issue
                        } label: {
                            Label("Close Issue", systemImage: "xmark.circle")
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(DesignTokens.CornerRadius.lg)
                }
            }
            .padding()
        }
    }

    func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return dateString }

        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .full
        return relative.localizedString(for: date, relativeTo: Date())
    }
}

struct IssueStatusBadge: View {
    let state: String

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: state == "open" ? "circle" : "checkmark.circle.fill")
                .foregroundColor(AppTheme.textSecondary)
            Text(state.capitalized)
        }
        .font(DesignTokens.Typography.caption)
        .fontWeight(.semibold)
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(color.opacity(0.2))
        .foregroundColor(color)
        .cornerRadius(DesignTokens.CornerRadius.xl)
    }

    var color: Color {
        state == "open" ? AppTheme.success : AppTheme.accentPurple
    }
}

struct EmptyIssueView: View {
    let state: IssueState

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "exclamationmark.circle")
                .font(DesignTokens.Typography.iconXXXXL)
                .foregroundColor(AppTheme.textPrimary)

            Text("No \(state == .all ? "" : state.rawValue) issues")
                .font(DesignTokens.Typography.headline)

            Text("Issues will appear here when they are created")
                .foregroundColor(AppTheme.textPrimary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Create Issue Sheet

struct CreateIssueSheet: View {
    @ObservedObject var viewModel: IssueListViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var issueBody = ""
    @State private var labels: [String] = []

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Text("Create Issue")
                .font(DesignTokens.Typography.title2)
                .fontWeight(.semibold)

            Form {
                DSTextField(placeholder: "Title", text: $title)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Description")

                    DSTextEditor(
                        placeholder: "Enter issue description...",
                        text: $issueBody,
                        minHeight: 150
                    )
                }
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create Issue") {
                    Task {
                        await viewModel.createIssue(
                            title: title,
                            body: issueBody.isEmpty ? nil : issueBody,
                            labels: labels.isEmpty ? nil : labels
                        )
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 500, height: 400)
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = DesignTokens.Spacing.sm

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)

        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var frames: [CGRect] = []

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }

        return (
            size: CGSize(width: maxWidth, height: currentY + lineHeight),
            frames: frames
        )
    }
}

// #Preview {
//     IssueListView()
//         .environmentObject(AppState())
//         .frame(width: 900, height: 600)
// }
