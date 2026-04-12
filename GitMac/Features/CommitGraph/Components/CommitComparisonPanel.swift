import SwiftUI

// MARK: - Commit Comparison Panel

/// Shows diff between two selected commits
struct CommitComparisonPanel: View {
    let commitA: Commit
    let commitB: Commit
    @Binding var selectedFileDiff: FileDiff?
    let onClose: () -> Void

    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = CommitComparisonViewModel()

    /// Ensures older commit is "from" and newer is "to"
    private var orderedCommits: (from: Commit, to: Commit) {
        if commitA.date < commitB.date {
            return (commitA, commitB)
        }
        return (commitB, commitA)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with commit range info
            comparisonHeader

            Divider()

            // Stats summary
            if !viewModel.changedFiles.isEmpty {
                statsSummary
                Divider()
            }

            // File list
            fileList
        }
        .task(id: "\(commitA.sha)-\(commitB.sha)") {
            guard let path = appState.currentRepository?.path else { return }
            let ordered = orderedCommits
            await viewModel.loadComparison(
                from: ordered.from.sha,
                to: ordered.to.sha,
                at: path
            )
        }
    }

    // MARK: - Subviews

    private var comparisonHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.accent)
                Text("Comparing Commits")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.textMuted)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.textMuted)
                }
                .buttonStyle(.borderless)
            }

            // From commit
            commitBadge(label: "FROM", commit: orderedCommits.from, color: AppTheme.error)

            // To commit
            commitBadge(label: "TO", commit: orderedCommits.to, color: AppTheme.success)
        }
        .padding(12)
        .background(.thinMaterial)
    }

    private func commitBadge(label: String, commit: Commit, color: Color) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 3))

            Text(String(commit.sha.prefix(7)))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(AppTheme.accent)

            Text(commit.message.components(separatedBy: "\n").first ?? "")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)
        }
    }

    private var statsSummary: some View {
        HStack(spacing: 12) {
            Text("\(viewModel.changedFiles.count) files changed")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)

            Spacer()

            if viewModel.totalAdditions > 0 {
                Text("+\(viewModel.totalAdditions)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.success)
            }

            if viewModel.totalDeletions > 0 {
                Text("-\(viewModel.totalDeletions)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.error)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(AppTheme.backgroundSecondary.opacity(0.5))
    }

    private var fileList: some View {
        Group {
            if viewModel.isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if viewModel.changedFiles.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "equal.circle")
                        .font(.system(size: 24))
                        .foregroundStyle(AppTheme.textMuted)
                    Text("No differences found")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textMuted)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.changedFiles) { file in
                            ComparisonFileRow(file: file) {
                                loadDiffForFile(file)
                            }
                        }
                    }
                }
            }
        }
    }

    private func loadDiffForFile(_ file: CommitFile) {
        guard let path = appState.currentRepository?.path else { return }
        let ordered = orderedCommits
        Task {
            if let diff = await viewModel.getDiff(
                for: file,
                from: ordered.from.sha,
                to: ordered.to.sha,
                at: path
            ) {
                selectedFileDiff = diff
            }
        }
    }
}

// MARK: - Comparison File Row

private struct ComparisonFileRow: View {
    let file: CommitFile
    let onSelect: () -> Void
    @State private var isHovered = false

    private var filename: String {
        (file.path as NSString).lastPathComponent
    }

    private var directory: String {
        (file.path as NSString).deletingLastPathComponent
    }

    var body: some View {
        HStack(spacing: 8) {
            // Status icon
            Image(systemName: file.status.icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(file.status.color)
                .frame(width: 16)

            // File path
            VStack(alignment: .leading, spacing: 1) {
                Text(filename)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)

                if !directory.isEmpty {
                    Text(directory)
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textMuted)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Stats
            if file.additions > 0 {
                Text("+\(file.additions)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(AppTheme.success)
            }
            if file.deletions > 0 {
                Text("-\(file.deletions)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(AppTheme.error)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isHovered ? AppTheme.backgroundSecondary.opacity(0.5) : .clear)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture { onSelect() }
    }
}

// MARK: - View Model

@MainActor
class CommitComparisonViewModel: ObservableObject {
    @Published var changedFiles: [CommitFile] = []
    @Published var isLoading = false
    @Published var totalAdditions = 0
    @Published var totalDeletions = 0

    private let engine = GitEngine()

    func loadComparison(from: String, to: String, at path: String) async {
        isLoading = true
        changedFiles = []
        totalAdditions = 0
        totalDeletions = 0

        do {
            // Get list of changed files between two commits
            let result = await ShellExecutor.shared.execute(
                "git",
                arguments: ["diff", "--numstat", "--name-status", from, to],
                workingDirectory: path
            )

            // Parse using name-status + numstat approach
            let statusResult = await ShellExecutor.shared.execute(
                "git",
                arguments: ["diff", "--name-status", from, to],
                workingDirectory: path
            )

            let numstatResult = await ShellExecutor.shared.execute(
                "git",
                arguments: ["diff", "--numstat", from, to],
                workingDirectory: path
            )

            guard statusResult.exitCode == 0 && numstatResult.exitCode == 0 else {
                isLoading = false
                return
            }

            // Parse numstat: additions deletions filepath
            var stats: [String: (Int, Int)] = [:]
            for line in numstatResult.output.split(separator: "\n") {
                let parts = line.split(separator: "\t", maxSplits: 2)
                guard parts.count >= 3 else { continue }
                let adds = Int(parts[0]) ?? 0
                let dels = Int(parts[1]) ?? 0
                let filePath = String(parts[2])
                stats[filePath] = (adds, dels)
            }

            // Parse name-status: STATUS filepath
            var files: [CommitFile] = []
            for line in statusResult.output.split(separator: "\n") {
                let parts = line.split(separator: "\t", maxSplits: 1)
                guard parts.count >= 2 else { continue }
                let statusChar = String(parts[0].prefix(1))
                let filePath = String(parts[1])
                let status: CommitFile.CommitFileStatus = {
                    switch statusChar {
                    case "A": return .added
                    case "D": return .deleted
                    case "R": return .renamed
                    case "C": return .copied
                    default: return .modified
                    }
                }()
                let (adds, dels) = stats[filePath] ?? (0, 0)

                files.append(CommitFile(
                    path: filePath,
                    status: status,
                    additions: adds,
                    deletions: dels
                ))
            }

            changedFiles = files
            totalAdditions = files.reduce(0) { $0 + $1.additions }
            totalDeletions = files.reduce(0) { $0 + $1.deletions }
        }

        isLoading = false
    }

    func getDiff(for file: CommitFile, from: String, to: String, at path: String) async -> FileDiff? {
        do {
            let diffOutput = try await engine.getDiff(from: from, to: to, filePath: file.path, at: path)
            let diffs = await DiffParser.parseAsync(diffOutput)
            return diffs.first
        } catch {
            return nil
        }
    }
}
