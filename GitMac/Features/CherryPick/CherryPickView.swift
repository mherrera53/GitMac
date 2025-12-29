import SwiftUI

/// Cherry-pick commits from one branch to another
struct CherryPickView: View {
    @StateObject private var themeManager = ThemeManager.shared

    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = CherryPickViewModel()
    @Environment(\.dismiss) private var dismiss

    let commits: [Commit]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "arrow.right.doc.on.clipboard")
                    .foregroundColor(AppTheme.accent)

                Text("Cherry-Pick")
                    .font(.headline)

                Spacer()

                Text("\(commits.count) commit(s)")
                    .font(DesignTokens.Typography.caption)
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, DesignTokens.Spacing.xxs)
                    .background(AppTheme.accent.opacity(0.2))
                    .foregroundColor(AppTheme.accent)
                    .cornerRadius(DesignTokens.CornerRadius.lg)
            }
            .padding()
            .background(AppTheme.accent.opacity(0.1))

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    // Target branch
                    GroupBox("Target Branch") {
                        HStack {
                            Image(systemName: "arrow.triangle.branch")
                                .foregroundColor(AppTheme.success)

                            Text(appState.currentRepository?.currentBranch?.name ?? "HEAD")
                                .fontWeight(.medium)

                            Spacer()

                            Text("current")
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(AppTheme.textPrimary)
                        }
                    }

                    // Commits to cherry-pick
                    GroupBox("Commits to Cherry-Pick") {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                            ForEach(commits) { commit in
                                CherryPickCommitRow(commit: commit)
                            }
                        }
                    }

                    // Options
                    GroupBox("Options") {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                            DSToggle("Create commit automatically", isOn: $viewModel.autoCommit)

                            if viewModel.autoCommit {
                                DSToggle("Use original commit message", isOn: $viewModel.useOriginalMessage)
                            }

                            DSToggle("Allow empty commits", isOn: $viewModel.allowEmpty)

                            DSToggle("Record cherry-pick in message", isOn: $viewModel.recordOrigin)
                        }
                    }

                    // Preview
                    if !viewModel.autoCommit {
                        GroupBox("Note") {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(AppTheme.accent)

                                Text("Changes will be staged but not committed. You can review and modify before committing.")
                                    .font(DesignTokens.Typography.caption)
                                    .foregroundColor(AppTheme.textPrimary)
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
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(AppTheme.error)
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
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack {
                Circle()
                    .fill(AppTheme.accent)
                    .frame(width: 8, height: 8)

                Text(commit.shortSHA)
                    .font(.caption.monospaced())
                    .foregroundColor(AppTheme.textPrimary)

                Text(commit.summary)
                    .lineLimit(1)

                Spacer()

                Button {
                    withAnimation { isExpanded.toggle() }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(AppTheme.textPrimary)
                }
                .buttonStyle(.borderless)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    LabeledContent("Author") {
                        Text(commit.author)
                    }

                    LabeledContent("Date") {
                        Text(commit.authorDate, style: .date)
                    }

                    if commit.message.count > commit.summary.count {
                        Text("Message")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(AppTheme.textPrimary)

                        Text(commit.message)
                            .font(DesignTokens.Typography.caption)
                            .padding(DesignTokens.Spacing.sm)
                            .background(Color(nsColor: .textBackgroundColor))
                            .cornerRadius(DesignTokens.CornerRadius.sm)
                    }
                }
                .font(DesignTokens.Typography.caption)
                .padding(.leading, DesignTokens.Spacing.lg)
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
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
        VStack(spacing: DesignTokens.Spacing.lg) {
            Text("Cherry-Pick Commit")
                .font(.title2)
                .fontWeight(.semibold)

            // Commit info
            GroupBox {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    HStack {
                        Text(commit.shortSHA)
                            .font(DesignTokens.Typography.commitHash)
                            .foregroundColor(AppTheme.textPrimary)

                        Text(commit.summary)
                            .lineLimit(2)
                    }

                    Text(commit.author)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(AppTheme.textPrimary)
                }
            }

            // Target branch picker
            if let repo = appState.currentRepository {
                DSPicker(
                    items: repo.branches.filter { !$0.isRemote },
                    selection: $targetBranch
                ) { branch in
                    HStack {
                        if branch.isCurrent {
                            Image(systemName: "checkmark")
                                .foregroundColor(AppTheme.success)
                        }
                        Text(branch.name)
                    }
                }
            }

            if let error = error {
                Text(error)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.error)
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
            HStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(1...3, id: \.self) { i in
                    Circle()
                        .fill(i <= step ? AppTheme.accent : AppTheme.textSecondary.opacity(0.3))
                        .frame(width: 8, height: 8)

                    if i < 3 {
                        Rectangle()
                            .fill(i < step ? AppTheme.accent : AppTheme.textSecondary.opacity(0.3))
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
        VStack(spacing: DesignTokens.Spacing.lg) {
            Text("Select Source Branch")
                .font(.headline)

            Text("Choose the branch containing commits you want to cherry-pick")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(AppTheme.textPrimary)

            if let repo = appState.currentRepository {
                List(selection: $sourceBranch) {
                    ForEach(repo.branches) { branch in
                        HStack {
                            Image(systemName: "arrow.triangle.branch")
                                .foregroundColor(branch.isRemote ? AppTheme.warning : AppTheme.accent)

                            Text(branch.name)

                            Spacer()

                            if branch.isCurrent {
                                Text("current")
                                    .font(DesignTokens.Typography.caption2)
                                    .foregroundColor(AppTheme.textPrimary)
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
        VStack(spacing: DesignTokens.Spacing.lg) {
            Text("Select Commits")
                .font(.headline)

            Text("Choose which commits to cherry-pick")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(AppTheme.textPrimary)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(commits) { commit in
                        HStack {
                            DSToggle("", isOn: Binding(
                                get: { selectedCommits.contains(commit.sha) },
                                set: { isSelected in
                                    if isSelected {
                                        selectedCommits.insert(commit.sha)
                                    } else {
                                        selectedCommits.remove(commit.sha)
                                    }
                                }
                            ))

                            VStack(alignment: .leading) {
                                HStack {
                                    Text(commit.shortSHA)
                                        .font(DesignTokens.Typography.commitHash)
                                        .foregroundColor(AppTheme.textPrimary)

                                    Text(commit.summary)
                                        .lineLimit(1)
                                }

                                Text(commit.author)
                                    .font(DesignTokens.Typography.caption)
                                    .foregroundColor(AppTheme.textPrimary)
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
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.textPrimary)

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
        VStack(spacing: DesignTokens.Spacing.lg) {
            Text("Confirm Cherry-Pick")
                .font(.headline)

            VStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: "arrow.right.doc.on.clipboard")
                    .font(DesignTokens.Typography.iconXXXXL)
                    .foregroundColor(AppTheme.accent)

                Text("\(selectedCount) commit(s) from \(sourceBranch?.name ?? "unknown")")
                    .font(.title3)

                Text("will be applied to the current branch")
                    .foregroundColor(AppTheme.textPrimary)
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
