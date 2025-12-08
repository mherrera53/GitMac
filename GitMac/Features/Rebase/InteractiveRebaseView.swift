import SwiftUI

/// Interactive Rebase View - Drag and drop to reorder, squash, edit, or drop commits
struct InteractiveRebaseView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = InteractiveRebaseViewModel()
    @Environment(\.dismiss) private var dismiss

    let targetBranch: String
    let commits: [Commit]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            RebaseHeader(
                sourceBranch: appState.currentRepository?.currentBranch?.name ?? "HEAD",
                targetBranch: targetBranch,
                commitCount: viewModel.rebaseCommits.count
            )

            Divider()

            HSplitView {
                // Left: Commit list for reordering
                RebaseCommitList(viewModel: viewModel)
                    .frame(minWidth: 400)

                // Right: Commit detail/preview
                RebasePreview(viewModel: viewModel)
                    .frame(minWidth: 300)
            }

            Divider()

            // Footer with actions
            RebaseFooter(
                viewModel: viewModel,
                onCancel: { dismiss() },
                onStart: {
                    Task {
                        await viewModel.startRebase()
                        if viewModel.error == nil {
                            dismiss()
                        }
                    }
                }
            )
        }
        .frame(minWidth: 800, minHeight: 500)
        .onAppear {
            viewModel.setupCommits(commits)
        }
    }
}

// MARK: - View Model

@MainActor
class InteractiveRebaseViewModel: ObservableObject {
    @Published var rebaseCommits: [RebaseCommit] = []
    @Published var selectedCommit: RebaseCommit?
    @Published var isProcessing = false
    @Published var error: String?
    @Published var previewOutput: String = ""

    private let gitService = GitService()

    func setupCommits(_ commits: [Commit]) {
        rebaseCommits = commits.map { commit in
            RebaseCommit(
                original: commit,
                action: .pick,
                newMessage: commit.message
            )
        }
    }

    func moveCommit(from source: IndexSet, to destination: Int) {
        rebaseCommits.move(fromOffsets: source, toOffset: destination)
        updatePreview()
    }

    func setAction(_ action: RebaseAction, for commit: RebaseCommit) {
        if let index = rebaseCommits.firstIndex(where: { $0.id == commit.id }) {
            rebaseCommits[index].action = action
            updatePreview()
        }
    }

    func updateMessage(for commit: RebaseCommit, message: String) {
        if let index = rebaseCommits.firstIndex(where: { $0.id == commit.id }) {
            rebaseCommits[index].newMessage = message
        }
    }

    func squashWithPrevious(_ commit: RebaseCommit) {
        guard let index = rebaseCommits.firstIndex(where: { $0.id == commit.id }),
              index > 0 else { return }

        rebaseCommits[index].action = .squash
        updatePreview()
    }

    func fixupWithPrevious(_ commit: RebaseCommit) {
        guard let index = rebaseCommits.firstIndex(where: { $0.id == commit.id }),
              index > 0 else { return }

        rebaseCommits[index].action = .fixup
        updatePreview()
    }

    func dropCommit(_ commit: RebaseCommit) {
        if let index = rebaseCommits.firstIndex(where: { $0.id == commit.id }) {
            rebaseCommits[index].action = .drop
            updatePreview()
        }
    }

    func resetCommit(_ commit: RebaseCommit) {
        if let index = rebaseCommits.firstIndex(where: { $0.id == commit.id }) {
            rebaseCommits[index].action = .pick
            rebaseCommits[index].newMessage = commit.original.message
            updatePreview()
        }
    }

    private func updatePreview() {
        var preview = "# Rebase plan:\n"
        preview += "# Commands:\n"
        preview += "# p, pick = use commit\n"
        preview += "# r, reword = use commit, but edit the commit message\n"
        preview += "# e, edit = use commit, but stop for amending\n"
        preview += "# s, squash = use commit, but meld into previous commit\n"
        preview += "# f, fixup = like squash, but discard this commit's log message\n"
        preview += "# d, drop = remove commit\n\n"

        for commit in rebaseCommits {
            let actionStr = commit.action.shortName
            let sha = commit.original.shortSHA
            let msg = commit.action == .reword ? commit.newMessage : commit.original.summary
            preview += "\(actionStr) \(sha) \(msg)\n"
        }

        previewOutput = preview
    }

    func startRebase() async {
        isProcessing = true
        error = nil

        // Generate rebase todo file
        let todoContent = rebaseCommits.map { commit in
            let action = commit.action.rawValue
            let sha = commit.original.sha
            let msg = commit.action == .reword ? commit.newMessage : commit.original.message
            return "\(action) \(sha) \(msg)"
        }.joined(separator: "\n")

        // Execute interactive rebase
        let shell = ShellExecutor()

        // First, start the rebase
        let baseCommit = rebaseCommits.last?.original.sha ?? "HEAD~\(rebaseCommits.count)"

        // Set the rebase editor to use our todo
        let result = await shell.execute(
            "git",
            arguments: ["rebase", "-i", "\(baseCommit)^"],
            environment: [
                "GIT_SEQUENCE_EDITOR": "cat > /dev/null && echo '\(todoContent)' > "
            ]
        )

        if result.exitCode != 0 {
            error = "Rebase failed: \(result.stderr)"
        }

        isProcessing = false
    }

    func abortRebase() async {
        let shell = ShellExecutor()
        _ = await shell.execute("git", arguments: ["rebase", "--abort"])
    }

    func continueRebase() async {
        let shell = ShellExecutor()
        _ = await shell.execute("git", arguments: ["rebase", "--continue"])
    }
}

// MARK: - Models

struct RebaseCommit: Identifiable {
    let id = UUID()
    let original: Commit
    var action: RebaseAction
    var newMessage: String
}

enum RebaseAction: String, CaseIterable {
    case pick = "pick"
    case reword = "reword"
    case edit = "edit"
    case squash = "squash"
    case fixup = "fixup"
    case drop = "drop"

    var shortName: String {
        switch self {
        case .pick: return "p"
        case .reword: return "r"
        case .edit: return "e"
        case .squash: return "s"
        case .fixup: return "f"
        case .drop: return "d"
        }
    }

    var description: String {
        switch self {
        case .pick: return "Use this commit"
        case .reword: return "Edit commit message"
        case .edit: return "Stop for amending"
        case .squash: return "Meld into previous"
        case .fixup: return "Meld, discard message"
        case .drop: return "Remove commit"
        }
    }

    var color: Color {
        switch self {
        case .pick: return .green
        case .reword: return .blue
        case .edit: return .orange
        case .squash: return .purple
        case .fixup: return .purple.opacity(0.7)
        case .drop: return .red
        }
    }

    var icon: String {
        switch self {
        case .pick: return "checkmark.circle"
        case .reword: return "pencil.circle"
        case .edit: return "pause.circle"
        case .squash: return "arrow.up.and.down.square"
        case .fixup: return "arrow.up.square"
        case .drop: return "trash.circle"
        }
    }
}

// MARK: - Subviews

struct RebaseHeader: View {
    let sourceBranch: String
    let targetBranch: String
    let commitCount: Int

    var body: some View {
        HStack {
            Image(systemName: "arrow.triangle.swap")
                .foregroundColor(.orange)

            Text("Interactive Rebase")
                .font(.headline)

            Spacer()

            HStack(spacing: 4) {
                Text(sourceBranch)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(4)

                Image(systemName: "arrow.right")
                    .foregroundColor(.secondary)

                Text(targetBranch)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.2))
                    .foregroundColor(.green)
                    .cornerRadius(4)
            }
            .font(.caption)

            Text("\(commitCount) commits")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
    }
}

struct RebaseCommitList: View {
    @ObservedObject var viewModel: InteractiveRebaseViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Commits")
                    .font(.headline)

                Spacer()

                Text("Drag to reorder")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            List {
                ForEach(viewModel.rebaseCommits) { commit in
                    RebaseCommitRow(
                        commit: commit,
                        isSelected: viewModel.selectedCommit?.id == commit.id,
                        onActionChange: { action in
                            viewModel.setAction(action, for: commit)
                        },
                        onSelect: {
                            viewModel.selectedCommit = commit
                        }
                    )
                }
                .onMove { source, destination in
                    viewModel.moveCommit(from: source, to: destination)
                }
            }
            .listStyle(.plain)
        }
    }
}

struct RebaseCommitRow: View {
    let commit: RebaseCommit
    let isSelected: Bool
    var onActionChange: (RebaseAction) -> Void = { _ in }
    var onSelect: () -> Void = {}

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // Drag handle
            Image(systemName: "line.3.horizontal")
                .foregroundColor(.secondary)
                .opacity(isHovered ? 1 : 0.5)

            // Action picker
            Menu {
                ForEach(RebaseAction.allCases, id: \.self) { action in
                    Button {
                        onActionChange(action)
                    } label: {
                        Label(action.rawValue.capitalized, systemImage: action.icon)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: commit.action.icon)
                    Text(commit.action.rawValue)
                        .font(.caption)
                }
                .foregroundColor(commit.action.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(commit.action.color.opacity(0.1))
                .cornerRadius(4)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 90)

            // Commit info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(commit.original.shortSHA)
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)

                    Text(commit.action == .reword ? commit.newMessage : commit.original.summary)
                        .lineLimit(1)
                        .strikethrough(commit.action == .drop)
                        .opacity(commit.action == .drop ? 0.5 : 1)
                }

                HStack {
                    Text(commit.original.author)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text("•")
                        .foregroundColor(.secondary)

                    Text(commit.original.relativeDate)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(isSelected ? Color.accentColor.opacity(0.1) : (isHovered ? Color.secondary.opacity(0.05) : Color.clear))
        .cornerRadius(4)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture { onSelect() }
    }
}

struct RebasePreview: View {
    @ObservedObject var viewModel: InteractiveRebaseViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Preview")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            if let selected = viewModel.selectedCommit {
                // Show selected commit details
                VStack(alignment: .leading, spacing: 16) {
                    // Commit info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Commit Details")
                            .font(.headline)

                        LabeledContent("SHA") {
                            Text(selected.original.sha)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                        }

                        LabeledContent("Author") {
                            Text(selected.original.author)
                        }

                        LabeledContent("Date") {
                            Text(selected.original.authorDate, style: .date)
                        }
                    }

                    Divider()

                    // Action specific content
                    if selected.action == .reword {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("New Commit Message")
                                .font(.headline)

                            TextEditor(text: Binding(
                                get: { selected.newMessage },
                                set: { viewModel.updateMessage(for: selected, message: $0) }
                            ))
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Commit Message")
                                .font(.headline)

                            Text(selected.original.message)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                        }
                    }

                    Spacer()
                }
                .padding()
            } else {
                // Show rebase script preview
                ScrollView {
                    Text(viewModel.previewOutput)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            }
        }
    }
}

struct RebaseFooter: View {
    @ObservedObject var viewModel: InteractiveRebaseViewModel
    var onCancel: () -> Void = {}
    var onStart: () -> Void = {}

    var body: some View {
        HStack {
            Button("Cancel") {
                onCancel()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            // Stats
            HStack(spacing: 16) {
                StatBadge(
                    count: viewModel.rebaseCommits.filter { $0.action == .pick }.count,
                    label: "pick",
                    color: .green
                )

                StatBadge(
                    count: viewModel.rebaseCommits.filter { $0.action == .reword }.count,
                    label: "reword",
                    color: .blue
                )

                StatBadge(
                    count: viewModel.rebaseCommits.filter { $0.action == .squash || $0.action == .fixup }.count,
                    label: "squash",
                    color: .purple
                )

                StatBadge(
                    count: viewModel.rebaseCommits.filter { $0.action == .drop }.count,
                    label: "drop",
                    color: .red
                )
            }

            Spacer()

            if viewModel.isProcessing {
                ProgressView()
                    .scaleEffect(0.8)
            }

            Button("Start Rebase") {
                onStart()
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isProcessing)
            .keyboardShortcut(.defaultAction)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct StatBadge: View {
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        if count > 0 {
            HStack(spacing: 4) {
                Text("\(count)")
                    .fontWeight(.semibold)
                Text(label)
            }
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(8)
        }
    }
}

// #Preview {
//     InteractiveRebaseView(
//         targetBranch: "main",
//         commits: []
//     )
//     .environmentObject(AppState())
//     .frame(width: 900, height: 600)
// }
