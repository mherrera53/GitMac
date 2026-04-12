import SwiftUI

// MARK: - Stale Branch Cleanup View

struct StaleBranchCleanupView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = StaleBranchCleanupViewModel()
    @State private var selectedBranches: Set<String> = []
    @State private var showDeleteConfirmation = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Content
            if viewModel.isLoading {
                loadingView
            } else if viewModel.mergedBranches.isEmpty {
                emptyState
            } else {
                branchList
            }

            Divider()

            // Footer with actions
            footer
        }
        .frame(width: 500, height: 450)
        .task {
            guard let path = appState.currentRepository?.path else { return }
            await viewModel.findMergedBranches(at: path)
        }
        .alert("Delete Branches", isPresented: $showDeleteConfirmation) {
            Button("Delete \(selectedBranches.count) Branches", role: .destructive) {
                Task {
                    guard let path = appState.currentRepository?.path else { return }
                    await viewModel.deleteBranches(names: Array(selectedBranches), at: path)
                    selectedBranches.removeAll()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete \(selectedBranches.count) local branches that have been merged. This cannot be undone.")
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "leaf.arrow.triangle.circlepath")
                    .font(.system(size: 20))
                    .foregroundStyle(AppTheme.warning)
                Text("Stale Branch Cleanup")
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.textMuted)
                }
                .buttonStyle(.plain)
            }

            Text("Branches that have been merged into the default branch and can be safely removed.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)

            // Target branch info
            if let targetBranch = viewModel.targetBranch {
                HStack(spacing: 4) {
                    Text("Merged into:")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textMuted)
                    Text(targetBranch)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
        .padding(16)
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
            Text("Scanning branches...")
                .font(.caption)
                .foregroundStyle(AppTheme.textMuted)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(AppTheme.success)
            Text("No stale branches found")
                .font(.headline)
            Text("All branches are either unmerged or currently in use.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private var branchList: some View {
        VStack(spacing: 0) {
            // Select all bar
            HStack {
                Button(action: toggleSelectAll) {
                    Image(systemName: allSelected ? "checkmark.square.fill" : "square")
                        .foregroundStyle(allSelected ? AppTheme.accent : AppTheme.textMuted)
                }
                .buttonStyle(.plain)

                Text("\(viewModel.mergedBranches.count) merged branches")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)

                Spacer()

                if !selectedBranches.isEmpty {
                    Text("\(selectedBranches.count) selected")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.accent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(AppTheme.backgroundSecondary.opacity(0.5))

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.mergedBranches) { branch in
                        StaleBranchRow(
                            branch: branch,
                            isSelected: selectedBranches.contains(branch.name),
                            onToggle: { toggleBranch(branch.name) }
                        )
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            if let error = viewModel.errorMessage {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppTheme.error)
                    .font(.caption)
                Text(error)
                    .font(.caption)
                    .foregroundStyle(AppTheme.error)
                    .lineLimit(1)
            }

            Spacer()

            Button("Refresh") {
                Task {
                    guard let path = appState.currentRepository?.path else { return }
                    await viewModel.findMergedBranches(at: path)
                    selectedBranches.removeAll()
                }
            }
            .buttonStyle(.borderless)

            Button("Delete Selected") {
                showDeleteConfirmation = true
            }
            .disabled(selectedBranches.isEmpty)
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.error)
        }
        .padding(16)
    }

    // MARK: - Actions

    private var allSelected: Bool {
        !viewModel.mergedBranches.isEmpty &&
        selectedBranches.count == viewModel.mergedBranches.count
    }

    private func toggleSelectAll() {
        if allSelected {
            selectedBranches.removeAll()
        } else {
            selectedBranches = Set(viewModel.mergedBranches.map(\.name))
        }
    }

    private func toggleBranch(_ name: String) {
        if selectedBranches.contains(name) {
            selectedBranches.remove(name)
        } else {
            selectedBranches.insert(name)
        }
    }
}

// MARK: - Stale Branch Row

private struct StaleBranchRow: View {
    let branch: MergedBranch
    let isSelected: Bool
    let onToggle: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.textMuted)
            }
            .buttonStyle(.plain)

            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textMuted)

            Text(branch.name)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)

            Spacer()

            if let author = branch.lastAuthor {
                Text(author)
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textMuted)
                    .lineLimit(1)
            }

            if let date = branch.lastCommitDate {
                Text(date)
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textMuted)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(isHovered ? AppTheme.backgroundSecondary.opacity(0.5) : .clear)
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
        .onTapGesture { onToggle() }
    }
}

// MARK: - View Model

@MainActor
class StaleBranchCleanupViewModel: ObservableObject {
    @Published var mergedBranches: [MergedBranch] = []
    @Published var targetBranch: String?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let engine = GitEngine()

    func findMergedBranches(at path: String) async {
        isLoading = true
        errorMessage = nil
        mergedBranches = []

        do {
            // Detect default branch
            let defaultBranch = try await detectDefaultBranch(at: path)
            targetBranch = defaultBranch

            // Get current branch to exclude it
            let currentResult = await ShellExecutor.shared.execute(
                "git", arguments: ["branch", "--show-current"], workingDirectory: path
            )
            let currentBranch = currentResult.output.trimmingCharacters(in: .whitespacesAndNewlines)

            // Get merged branches
            let result = await ShellExecutor.shared.execute(
                "git",
                arguments: ["branch", "--merged", defaultBranch, "--format=%(refname:short)|%(authorname)|%(committerdate:relative)"],
                workingDirectory: path
            )

            guard result.exitCode == 0 else {
                errorMessage = result.stderr
                isLoading = false
                return
            }

            let protectedNames = Set(["main", "master", "develop", "development", defaultBranch, currentBranch])

            mergedBranches = result.output
                .split(separator: "\n")
                .compactMap { line -> MergedBranch? in
                    let parts = line.split(separator: "|", maxSplits: 2).map(String.init)
                    guard let name = parts.first else { return nil }

                    // Skip protected branches and current branch
                    if protectedNames.contains(name) { return nil }

                    return MergedBranch(
                        name: name,
                        lastAuthor: parts.count > 1 ? parts[1] : nil,
                        lastCommitDate: parts.count > 2 ? parts[2] : nil
                    )
                }
                .sorted { ($0.name) < ($1.name) }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func deleteBranches(names: [String], at path: String) async {
        errorMessage = nil
        var failed: [String] = []

        for name in names {
            let result = await ShellExecutor.shared.execute(
                "git", arguments: ["branch", "-d", name], workingDirectory: path
            )
            if result.exitCode != 0 {
                failed.append(name)
            }
        }

        if failed.isEmpty {
            NotificationManager.shared.success(
                "Branches deleted",
                detail: "Removed \(names.count) merged branches"
            )
        } else {
            errorMessage = "Failed to delete: \(failed.joined(separator: ", "))"
        }

        // Refresh list
        await findMergedBranches(at: path)
    }

    private func detectDefaultBranch(at path: String) async throws -> String {
        // Check origin/HEAD
        let result = await ShellExecutor.shared.execute(
            "git", arguments: ["symbolic-ref", "refs/remotes/origin/HEAD", "--short"],
            workingDirectory: path
        )
        if result.exitCode == 0 {
            let ref = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            // "origin/main" -> "main"
            if let slash = ref.lastIndex(of: "/") {
                return String(ref[ref.index(after: slash)...])
            }
            return ref
        }

        // Fallback: check for main or master
        for name in ["main", "master"] {
            let check = await ShellExecutor.shared.execute(
                "git", arguments: ["rev-parse", "--verify", name],
                workingDirectory: path
            )
            if check.exitCode == 0 { return name }
        }

        return "main"
    }
}

// MARK: - Model

struct MergedBranch: Identifiable {
    let name: String
    let lastAuthor: String?
    let lastCommitDate: String?
    var id: String { name }
}
