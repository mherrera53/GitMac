import SwiftUI

/// Pull Requests list and detail view
struct PRListView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = PRListViewModel()
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
                    .pickerStyle(.segmented)
                    .frame(width: 180)

                    Button {
                        showCreatePRSheet = true
                    } label: {
                        Image(systemName: "plus")
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
                        PRRow(pr: pr, isSelected: selectedPR?.id == pr.id)
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
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Select a pull request")
                        .foregroundColor(.secondary)
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

    func mergePR(_ pr: GitHubPullRequest, method: MergeMethod = .merge) async {
        do {
            try await githubService.mergePullRequest(
                owner: owner,
                repo: repo,
                number: pr.number,
                mergeMethod: method
            )
            await loadPullRequests()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func createPR(title: String, body: String, head: String, base: String, draft: Bool) async {
        do {
            _ = try await githubService.createPullRequest(
                owner: owner,
                repo: repo,
                title: title,
                body: body,
                head: head,
                base: base,
                draft: draft
            )
            await loadPullRequests()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Subviews

struct PRRow: View {
    let pr: GitHubPullRequest
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // PR number and status
                HStack(spacing: 4) {
                    Image(systemName: pr.draft ? "doc.text" : (pr.state == "open" ? "arrow.triangle.pull" : "checkmark.circle"))
                        .foregroundColor(statusColor)

                    Text("#\(pr.number)")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }

                Text(pr.title)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Spacer()
            }

            HStack(spacing: 8) {
                // Author
                AsyncImage(url: URL(string: pr.user.avatarUrl)) { image in
                    image.resizable()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                }
                .frame(width: 16, height: 16)
                .clipShape(Circle())

                Text(pr.user.login)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("•")
                    .foregroundColor(.secondary)

                Text(formatDate(pr.updatedAt))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                // Stats
                if let additions = pr.additions, let deletions = pr.deletions {
                    HStack(spacing: 4) {
                        Text("+\(additions)")
                            .foregroundColor(.green)
                        Text("-\(deletions)")
                            .foregroundColor(.red)
                    }
                    .font(.caption.monospacedDigit())
                }
            }

            // Branch info
            HStack(spacing: 4) {
                Text(pr.head.ref)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(4)

                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(pr.base.ref)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.2))
                    .foregroundColor(.green)
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(4)
    }

    var statusColor: Color {
        if pr.draft { return .gray }
        switch pr.state {
        case "open": return .green
        case "closed": return .red
        default: return .purple
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
    @State private var files: [GitHubPRFile] = []
    @State private var selectedMergeMethod: MergeMethod = .merge
    @State private var showMergeConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        PRStatusBadge(state: pr.state, draft: pr.draft)

                        Text("#\(pr.number)")
                            .font(.title3)
                            .foregroundColor(.secondary)

                        Spacer()

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
                .cornerRadius(8)

                // Body
                if let body = pr.body, !body.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)

                        Text(body)
                            .font(.body)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                }

                // Stats
                HStack(spacing: 24) {
                    StatItem(icon: "doc.text", label: "Files", value: "\(pr.changedFiles ?? 0)")
                    StatItem(icon: "plus", label: "Additions", value: "+\(pr.additions ?? 0)", color: .green)
                    StatItem(icon: "minus", label: "Deletions", value: "-\(pr.deletions ?? 0)", color: .red)
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)

                // Files changed
                VStack(alignment: .leading, spacing: 8) {
                    Text("Files Changed")
                        .font(.headline)

                    ForEach(files, id: \.filename) { file in
                        PRFileRow(file: file)
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)

                // Actions
                if pr.state == "open" {
                    VStack(spacing: 12) {
                        Picker("Merge Method", selection: $selectedMergeMethod) {
                            Text("Create merge commit").tag(MergeMethod.merge)
                            Text("Squash and merge").tag(MergeMethod.squash)
                            Text("Rebase and merge").tag(MergeMethod.rebase)
                        }
                        .pickerStyle(.segmented)

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
                    .cornerRadius(8)
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
        .task {
            files = await viewModel.getPRFiles(pr)
        }
    }
}

struct PRStatusBadge: View {
    let state: String
    let draft: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.2))
        .foregroundColor(color)
        .cornerRadius(12)
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
        if draft { return .gray }
        switch state {
        case "open": return .green
        case "closed": return .red
        default: return .purple
        }
    }
}

struct StatItem: View {
    let icon: String
    let label: String
    let value: String
    var color: Color = .primary

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(value)
                    .fontWeight(.semibold)
            }
            .font(.title3)
            .foregroundColor(color)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct PRFileRow: View {
    let file: GitHubPRFile

    var body: some View {
        HStack(spacing: 8) {
            StatusIcon(status: statusType)

            Image(systemName: FileTypeIcon.systemIcon(for: file.filename))
                .foregroundColor(FileTypeIcon.color(for: file.filename))

            Text(file.filename)
                .lineLimit(1)

            Spacer()

            HStack(spacing: 4) {
                Text("+\(file.additions)")
                    .foregroundColor(.green)
                Text("-\(file.deletions)")
                    .foregroundColor(.red)
            }
            .font(.caption.monospacedDigit())
        }
        .padding(.vertical, 4)
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

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.triangle.pull")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No \(state == .all ? "" : state.rawValue) pull requests")
                .font(.headline)

            Text("Pull requests will appear here when they are created")
                .foregroundColor(.secondary)
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

    @State private var title = ""
    @State private var prBody = ""
    @State private var headBranch = ""
    @State private var baseBranch = "main"
    @State private var isDraft = false
    @State private var isGeneratingBody = false

    private let aiService = AIService()

    var body: some View {
        VStack(spacing: 16) {
            Text("Create Pull Request")
                .font(.title2)
                .fontWeight(.semibold)

            Form {
                // Branches
                HStack {
                    Picker("From", selection: $headBranch) {
                        ForEach(appState.currentRepository?.branches ?? [], id: \.id) { branch in
                            Text(branch.name).tag(branch.name)
                        }
                    }

                    Image(systemName: "arrow.right")
                        .foregroundColor(.secondary)

                    Picker("To", selection: $baseBranch) {
                        Text("main").tag("main")
                        Text("master").tag("master")
                        Text("develop").tag("develop")
                    }
                }

                TextField("Title", text: $title)
                    .textFieldStyle(.roundedBorder)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Description")
                        Spacer()
                        Button {
                            Task { await generateDescription() }
                        } label: {
                            if isGeneratingBody {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Label("Generate with AI", systemImage: "sparkles")
                            }
                        }
                        .buttonStyle(.borderless)
                        .disabled(isGeneratingBody)
                    }

                    TextEditor(text: $prBody)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 150)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                }

                Toggle("Create as draft", isOn: $isDraft)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create Pull Request") {
                    Task {
                        await viewModel.createPR(
                            title: title,
                            body: prBody,
                            head: headBranch,
                            base: baseBranch,
                            draft: isDraft
                        )
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.isEmpty || headBranch.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 600, height: 500)
        .onAppear {
            if let currentBranch = appState.currentRepository?.head?.name {
                headBranch = currentBranch
            }
        }
    }

    private func generateDescription() async {
        isGeneratingBody = true
        do {
            let diff = try await GitService().getDiff(from: baseBranch, to: headBranch)
            let commits = try await GitService().getCommits(branch: headBranch, limit: 20)
            prBody = try await aiService.generatePRDescription(diff: diff, commits: commits)
        } catch {
            // Handle error
        }
        isGeneratingBody = false
    }
}

// #Preview {
//     PRListView()
//         .environmentObject(AppState())
//         .frame(width: 900, height: 600)
// }
