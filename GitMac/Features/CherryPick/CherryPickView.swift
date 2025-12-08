import SwiftUI

/// Cherry-pick commits from one branch to another
struct CherryPickView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = CherryPickViewModel()
    @Environment(\.dismiss) private var dismiss

    let commits: [Commit]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "arrow.right.doc.on.clipboard")
                    .foregroundColor(.purple)

                Text("Cherry-Pick")
                    .font(.headline)

                Spacer()

                Text("\(commits.count) commit(s)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.2))
                    .foregroundColor(.purple)
                    .cornerRadius(8)
            }
            .padding()
            .background(Color.purple.opacity(0.1))

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Target branch
                    GroupBox("Target Branch") {
                        HStack {
                            Image(systemName: "arrow.triangle.branch")
                                .foregroundColor(.green)

                            Text(appState.currentRepository?.currentBranch?.name ?? "HEAD")
                                .fontWeight(.medium)

                            Spacer()

                            Text("current")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Commits to cherry-pick
                    GroupBox("Commits to Cherry-Pick") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(commits) { commit in
                                CherryPickCommitRow(commit: commit)
                            }
                        }
                    }

                    // Options
                    GroupBox("Options") {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Create commit automatically", isOn: $viewModel.autoCommit)

                            if viewModel.autoCommit {
                                Toggle("Use original commit message", isOn: $viewModel.useOriginalMessage)
                            }

                            Toggle("Allow empty commits", isOn: $viewModel.allowEmpty)

                            Toggle("Record cherry-pick in message", isOn: $viewModel.recordOrigin)
                        }
                    }

                    // Preview
                    if !viewModel.autoCommit {
                        GroupBox("Note") {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)

                                Text("Changes will be staged but not committed. You can review and modify before committing.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding()
            }

            Divider()

            // Footer
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                if viewModel.isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                }

                if let error = viewModel.error {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(1)
                }

                Button("Cherry-Pick") {
                    Task {
                        await viewModel.cherryPick(commits: commits)
                        if viewModel.error == nil {
                            dismiss()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isProcessing)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .frame(width: 500, height: 500)
    }
}

// MARK: - View Model

@MainActor
class CherryPickViewModel: ObservableObject {
    @Published var autoCommit = true
    @Published var useOriginalMessage = true
    @Published var allowEmpty = false
    @Published var recordOrigin = true
    @Published var isProcessing = false
    @Published var error: String?
    @Published var progress: Int = 0
    @Published var total: Int = 0

    private let shell = ShellExecutor()

    func cherryPick(commits: [Commit]) async {
        isProcessing = true
        error = nil
        progress = 0
        total = commits.count

        for (index, commit) in commits.enumerated() {
            progress = index + 1

            var arguments = ["cherry-pick"]

            if !autoCommit {
                arguments.append("--no-commit")
            }

            if allowEmpty {
                arguments.append("--allow-empty")
            }

            if recordOrigin {
                arguments.append("-x")
            }

            arguments.append(commit.sha)

            let result = await shell.execute("git", arguments: arguments)

            if result.exitCode != 0 {
                // Check for conflicts
                if result.stderr.contains("conflict") {
                    error = "Conflict detected. Please resolve conflicts and continue."
                } else {
                    error = result.stderr
                }
                break
            }
        }

        isProcessing = false
    }

    func continueCheryPick() async {
        isProcessing = true
        error = nil

        let result = await shell.execute("git", arguments: ["cherry-pick", "--continue"])

        if result.exitCode != 0 {
            error = result.stderr
        }

        isProcessing = false
    }

    func abortCherryPick() async {
        _ = await shell.execute("git", arguments: ["cherry-pick", "--abort"])
    }
}

// MARK: - Subviews

struct CherryPickCommitRow: View {
    let commit: Commit
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(Color.purple)
                    .frame(width: 8, height: 8)

                Text(commit.shortSHA)
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)

                Text(commit.summary)
                    .lineLimit(1)

                Spacer()

                Button {
                    withAnimation { isExpanded.toggle() }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    LabeledContent("Author") {
                        Text(commit.author)
                    }

                    LabeledContent("Date") {
                        Text(commit.authorDate, style: .date)
                    }

                    if commit.message.count > commit.summary.count {
                        Text("Message")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(commit.message)
                            .font(.caption)
                            .padding(8)
                            .background(Color(nsColor: .textBackgroundColor))
                            .cornerRadius(4)
                    }
                }
                .font(.caption)
                .padding(.leading, 16)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Quick cherry-pick from context menu
struct QuickCherryPickSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let commit: Commit
    @State private var targetBranch: Branch?
    @State private var isProcessing = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("Cherry-Pick Commit")
                .font(.title2)
                .fontWeight(.semibold)

            // Commit info
            GroupBox {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(commit.shortSHA)
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)

                        Text(commit.summary)
                            .lineLimit(2)
                    }

                    Text(commit.author)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Target branch picker
            if let repo = appState.currentRepository {
                Picker("Target Branch", selection: $targetBranch) {
                    Text("Select branch...").tag(nil as Branch?)

                    ForEach(repo.branches.filter { !$0.isRemote }) { branch in
                        HStack {
                            if branch.isCurrent {
                                Image(systemName: "checkmark")
                            }
                            Text(branch.name)
                        }
                        .tag(branch as Branch?)
                    }
                }
            }

            if let error = error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                }

                Button("Cherry-Pick") {
                    performCherryPick()
                }
                .buttonStyle(.borderedProminent)
                .disabled(targetBranch == nil || isProcessing)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 400)
        .onAppear {
            targetBranch = appState.currentRepository?.currentBranch
        }
    }

    private func performCherryPick() {
        guard let branch = targetBranch else { return }

        isProcessing = true
        error = nil

        Task {
            let shell = ShellExecutor()

            // Switch to target branch if needed
            if branch.name != appState.currentRepository?.currentBranch?.name {
                let checkoutResult = await shell.execute(
                    "git",
                    arguments: ["checkout", branch.name]
                )

                if checkoutResult.exitCode != 0 {
                    error = "Failed to switch to branch: \(checkoutResult.stderr)"
                    isProcessing = false
                    return
                }
            }

            // Cherry-pick
            let result = await shell.execute(
                "git",
                arguments: ["cherry-pick", "-x", commit.sha]
            )

            if result.exitCode != 0 {
                if result.stderr.contains("conflict") {
                    error = "Conflict detected. Please resolve manually."
                } else {
                    error = result.stderr
                }
            } else {
                dismiss()
            }

            isProcessing = false
        }
    }
}

/// Multi-commit cherry-pick wizard
struct CherryPickWizard: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var step = 1
    @State private var sourceBranch: Branch?
    @State private var selectedCommits: Set<String> = []
    @State private var availableCommits: [Commit] = []
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            HStack(spacing: 8) {
                ForEach(1...3, id: \.self) { i in
                    Circle()
                        .fill(i <= step ? Color.purple : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)

                    if i < 3 {
                        Rectangle()
                            .fill(i < step ? Color.purple : Color.secondary.opacity(0.3))
                            .frame(height: 2)
                            .frame(maxWidth: 40)
                    }
                }
            }
            .padding()

            Divider()

            // Step content
            switch step {
            case 1:
                SourceBranchStep(
                    sourceBranch: $sourceBranch,
                    onNext: {
                        step = 2
                        loadCommits()
                    }
                )
            case 2:
                SelectCommitsStep(
                    commits: availableCommits,
                    selectedCommits: $selectedCommits,
                    isLoading: isLoading,
                    onBack: { step = 1 },
                    onNext: { step = 3 }
                )
            case 3:
                ConfirmStep(
                    sourceBranch: sourceBranch,
                    selectedCount: selectedCommits.count,
                    onBack: { step = 2 },
                    onConfirm: { performCherryPick() }
                )
            default:
                EmptyView()
            }
        }
        .frame(width: 500, height: 450)
    }

    private func loadCommits() {
        guard let source = sourceBranch else { return }

        isLoading = true

        Task {
            let shell = ShellExecutor()
            let result = await shell.execute(
                "git",
                arguments: ["log", source.name, "--format=%H|%an|%ai|%s", "-n", "50"]
            )

            if result.exitCode == 0 {
                availableCommits = result.stdout
                    .components(separatedBy: .newlines)
                    .filter { !$0.isEmpty }
                    .compactMap { line -> Commit? in
                        let parts = line.components(separatedBy: "|")
                        guard parts.count >= 4 else { return nil }

                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
                        let date = formatter.date(from: parts[2]) ?? Date()

                        return Commit(
                            sha: parts[0],
                            message: parts[3],
                            author: parts[1],
                            authorEmail: "",
                            authorDate: date,
                            committer: parts[1],
                            committerEmail: "",
                            committerDate: date,
                            parentSHAs: []
                        )
                    }
            }

            isLoading = false
        }
    }

    private func performCherryPick() {
        let commitsToPickSorted = availableCommits.filter { selectedCommits.contains($0.sha) }
        // Cherry-pick in reverse order (oldest first)
        let commits = commitsToPickSorted.reversed()

        Task {
            let shell = ShellExecutor()

            for commit in commits {
                let result = await shell.execute(
                    "git",
                    arguments: ["cherry-pick", "-x", commit.sha]
                )

                if result.exitCode != 0 {
                    // Handle error
                    break
                }
            }

            dismiss()
        }
    }
}

struct SourceBranchStep: View {
    @Binding var sourceBranch: Branch?
    @EnvironmentObject var appState: AppState
    var onNext: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Select Source Branch")
                .font(.headline)

            Text("Choose the branch containing commits you want to cherry-pick")
                .font(.caption)
                .foregroundColor(.secondary)

            if let repo = appState.currentRepository {
                List(selection: $sourceBranch) {
                    ForEach(repo.branches) { branch in
                        HStack {
                            Image(systemName: "arrow.triangle.branch")
                                .foregroundColor(branch.isRemote ? .orange : .blue)

                            Text(branch.name)

                            Spacer()

                            if branch.isCurrent {
                                Text("current")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tag(branch)
                    }
                }
                .listStyle(.plain)
            }

            Spacer()

            HStack {
                Spacer()

                Button("Next") {
                    onNext()
                }
                .buttonStyle(.borderedProminent)
                .disabled(sourceBranch == nil)
            }
            .padding()
        }
    }
}

struct SelectCommitsStep: View {
    let commits: [Commit]
    @Binding var selectedCommits: Set<String>
    let isLoading: Bool
    var onBack: () -> Void
    var onNext: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Select Commits")
                .font(.headline)

            Text("Choose which commits to cherry-pick")
                .font(.caption)
                .foregroundColor(.secondary)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(commits) { commit in
                        HStack {
                            Toggle("", isOn: Binding(
                                get: { selectedCommits.contains(commit.sha) },
                                set: { isSelected in
                                    if isSelected {
                                        selectedCommits.insert(commit.sha)
                                    } else {
                                        selectedCommits.remove(commit.sha)
                                    }
                                }
                            ))
                            .labelsHidden()

                            VStack(alignment: .leading) {
                                HStack {
                                    Text(commit.shortSHA)
                                        .font(.caption.monospaced())
                                        .foregroundColor(.secondary)

                                    Text(commit.summary)
                                        .lineLimit(1)
                                }

                                Text(commit.author)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }

            HStack {
                Button("Back") { onBack() }

                Spacer()

                Text("\(selectedCommits.count) selected")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button("Next") { onNext() }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedCommits.isEmpty)
            }
            .padding()
        }
    }
}

struct ConfirmStep: View {
    let sourceBranch: Branch?
    let selectedCount: Int
    var onBack: () -> Void
    var onConfirm: () -> Void

    @State private var isProcessing = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Confirm Cherry-Pick")
                .font(.headline)

            VStack(spacing: 12) {
                Image(systemName: "arrow.right.doc.on.clipboard")
                    .font(.system(size: 48))
                    .foregroundColor(.purple)

                Text("\(selectedCount) commit(s) from \(sourceBranch?.name ?? "unknown")")
                    .font(.title3)

                Text("will be applied to the current branch")
                    .foregroundColor(.secondary)
            }
            .padding()

            Spacer()

            HStack {
                Button("Back") { onBack() }

                Spacer()

                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                }

                Button("Cherry-Pick") {
                    isProcessing = true
                    onConfirm()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isProcessing)
            }
            .padding()
        }
    }
}

// #Preview {
//     CherryPickView(commits: [])
//         .environmentObject(AppState())
// }
