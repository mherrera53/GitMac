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
                    .pickerStyle(.segmented)
                    .frame(width: 180)

                    Button {
                        showCreateIssueSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)
                    .help("Create Issue")
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))

                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search issues...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
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
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Select an issue")
                        .foregroundColor(.secondary)
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
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: issue.state == "open" ? "circle" : "checkmark.circle.fill")
                    .foregroundColor(issue.state == "open" ? .green : .purple)

                Text("#\(issue.number)")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)

                Text(issue.title)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Spacer()
            }

            // Labels
            if !issue.labels.isEmpty {
                HStack(spacing: 4) {
                    ForEach(issue.labels.prefix(3)) { label in
                        IssueLabelBadge(label: label)
                    }
                    if issue.labels.count > 3 {
                        Text("+\(issue.labels.count - 3)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Meta
            HStack {
                AsyncImage(url: URL(string: issue.user.avatarUrl)) { image in
                    image.resizable()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                }
                .frame(width: 16, height: 16)
                .clipShape(Circle())

                Text(issue.user.login)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("•")
                    .foregroundColor(.secondary)

                Text(formatDate(issue.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(4)
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
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(hex: label.color).opacity(0.3))
            .foregroundColor(Color(hex: label.color))
            .cornerRadius(10)
    }
}

struct IssueDetailView: View {
    let issue: GitHubIssue
    @ObservedObject var viewModel: IssueListViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        IssueStatusBadge(state: issue.state)

                        Text("#\(issue.number)")
                            .font(.title3)
                            .foregroundColor(.secondary)

                        Spacer()

                        Button {
                            NSWorkspace.shared.open(URL(string: issue.htmlUrl)!)
                        } label: {
                            Label("Open in GitHub", systemImage: "arrow.up.right.square")
                        }
                        .buttonStyle(.borderless)
                    }

                    Text(issue.title)
                        .font(.title2)
                        .fontWeight(.bold)

                    // Labels
                    if !issue.labels.isEmpty {
                        FlowLayout(spacing: 4) {
                            ForEach(issue.labels) { label in
                                IssueLabelBadge(label: label)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)

                // Author info
                HStack {
                    AsyncImage(url: URL(string: issue.user.avatarUrl)) { image in
                        image.resizable()
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())

                    VStack(alignment: .leading) {
                        Text(issue.user.login)
                            .fontWeight(.medium)
                        Text("opened this issue \(formatDate(issue.createdAt))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)

                // Body
                if let body = issue.body, !body.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)

                        Text(body)
                            .font(.body)
                            .textSelection(.enabled)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
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
                    .cornerRadius(8)
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
        HStack(spacing: 4) {
            Image(systemName: state == "open" ? "circle" : "checkmark.circle.fill")
            Text(state.capitalized)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.2))
        .foregroundColor(color)
        .cornerRadius(12)
    }

    var color: Color {
        state == "open" ? .green : .purple
    }
}

struct EmptyIssueView: View {
    let state: IssueState

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No \(state == .all ? "" : state.rawValue) issues")
                .font(.headline)

            Text("Issues will appear here when they are created")
                .foregroundColor(.secondary)
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
        VStack(spacing: 16) {
            Text("Create Issue")
                .font(.title2)
                .fontWeight(.semibold)

            Form {
                TextField("Title", text: $title)
                    .textFieldStyle(.roundedBorder)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Description")

                    TextEditor(text: $issueBody)
                        .font(.system(.body))
                        .frame(minHeight: 150)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
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
    var spacing: CGFloat = 8

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
