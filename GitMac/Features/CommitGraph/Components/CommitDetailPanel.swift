import SwiftUI

struct CommitDetailPanel: View {
    private static let displayDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    let commit: Commit?
    let onClose: () -> Void
    var onOpenDiff: ((Commit) -> Void)? = nil

    @Environment(ThemeManager.self) private var themeManager
    @Environment(AppState.self) private var appState
    @State private var selectedTab: DetailTab = .info
    @State private var commitFiles: [CommitFileInfo] = []
    @State private var isLoadingFiles = false

    enum DetailTab: String, CaseIterable {
        case info = "Info"
        case files = "Files"
        case diff = "Diff"
    }

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        if let commit = commit {
            VStack(spacing: 0) {
                detailHeader(commit: commit, theme: theme)

                Divider()

                HStack(spacing: 0) {
                    ForEach(DetailTab.allCases, id: \.self) { tab in
                        Button {
                            selectedTab = tab
                        } label: {
                            Text(tab.rawValue)
                                .font(DesignTokens.Typography.callout)
                                .fontWeight(selectedTab == tab ? .semibold : .regular)
                                .foregroundStyle(
                                    selectedTab == tab ? AppTheme.accent : theme.textSecondary
                                )
                                .padding(.horizontal, DesignTokens.Spacing.md)
                                .padding(.vertical, DesignTokens.Spacing.sm)
                                .background(
                                    selectedTab == tab ? theme.backgroundSecondary : Color.clear
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                }
                .background(theme.background)

                Divider()

                Group {
                    switch selectedTab {
                    case .info:
                        commitInfoView(commit: commit, theme: theme)
                    case .files:
                        commitFilesView(commit: commit, theme: theme)
                    case .diff:
                        commitDiffView(commit: commit, theme: theme)
                    }
                }
            }
            .frame(width: 400)
            .background(theme.background)
        } else {
            VStack {
                Spacer()
                Text("No commit selected")
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(theme.textMuted)
                Spacer()
            }
            .frame(width: 400)
            .background(theme.background)
        }
    }

    private func detailHeader(commit: Commit, theme: Color.Theme) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                Text("COMMIT DETAILS")
                    .font(DesignTokens.Typography.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(theme.text)

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(theme.textMuted)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .help("Close")
            }

            // Commit summary
            Text(commit.summary)
                .font(DesignTokens.Typography.body)
                .fontWeight(.semibold)
                .foregroundStyle(theme.text)
                .lineLimit(2)

            // Metadata with enhanced icons
            HStack(spacing: DesignTokens.Spacing.sm) {
                Label {
                    Text(commit.author)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(theme.textSecondary)
                } icon: {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.accent)
                        .symbolRenderingMode(.hierarchical)
                }

                Label {
                    Text(commit.shortSHA)
                        .font(DesignTokens.Typography.caption.monospaced())
                        .foregroundStyle(theme.textSecondary)
                } icon: {
                    Image(systemName: "number.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.textMuted)
                        .symbolRenderingMode(.hierarchical)
                }
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(theme.backgroundSecondary)
    }

    private func commitInfoView(commit: Commit, theme: Color.Theme) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                // Message
                if let body = commit.body, !body.isEmpty {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("Message")
                            .font(DesignTokens.Typography.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(theme.textMuted)

                        Text(body)
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(theme.text)
                    }
                }

                Divider()

                // Author info
                infoRow(label: "Author", value: commit.author, theme: theme)
                infoRow(
                    label: "Date",
                    value: formatDate(commit.authorDate),
                    theme: theme
                )
                infoRow(label: "SHA", value: commit.sha, theme: theme)

                if !commit.parentSHAs.isEmpty {
                    infoRow(
                        label: "Parents",
                        value: commit.parentSHAs.map { String($0.prefix(7)) }.joined(separator: ", "),
                        theme: theme
                    )
                }

                // Branches/Tags
                if !commit.branches.isEmpty {
                    infoRow(
                        label: "Branches",
                        value: commit.branches.map { $0.name }.joined(separator: ", "),
                        theme: theme
                    )
                }

                if !commit.tags.isEmpty {
                    infoRow(
                        label: "Tags",
                        value: commit.tags.map { $0.name }.joined(separator: ", "),
                        theme: theme
                    )
                }
            }
            .padding(DesignTokens.Spacing.md)
        }
    }

    private func commitFilesView(commit: Commit, theme: Color.Theme) -> some View {
        VStack(spacing: 0) {
            if isLoadingFiles {
                ProgressView()
                    .padding()
            } else if commitFiles.isEmpty {
                Text("No files changed")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(theme.textMuted)
                    .padding()
            } else {
                // Summary bar
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Text("\(commitFiles.count) files")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(theme.text)
                    Spacer()
                    let totalAdd = commitFiles.reduce(0) { $0 + $1.additions }
                    let totalDel = commitFiles.reduce(0) { $0 + $1.deletions }
                    if totalAdd > 0 {
                        Text("+\(totalAdd)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(AppTheme.diffAddition)
                    }
                    if totalDel > 0 {
                        Text("-\(totalDel)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(AppTheme.diffDeletion)
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.sm)
                .background(theme.backgroundSecondary)

                Divider()

                // File list
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(commitFiles) { file in
                            HStack(spacing: DesignTokens.Spacing.sm) {
                                // Status icon
                                Image(systemName: file.statusIcon)
                                    .font(.system(size: 10))
                                    .foregroundStyle(file.statusColor)
                                    .frame(width: 14)

                                // File name
                                Text(file.filename)
                                    .font(DesignTokens.Typography.caption)
                                    .foregroundStyle(theme.text)
                                    .lineLimit(1)
                                    .truncationMode(.middle)

                                Spacer()

                                // Stats
                                HStack(spacing: 3) {
                                    if file.additions > 0 {
                                        Text("+\(file.additions)")
                                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                                            .foregroundStyle(AppTheme.diffAddition)
                                    }
                                    if file.deletions > 0 {
                                        Text("-\(file.deletions)")
                                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                                            .foregroundStyle(AppTheme.diffDeletion)
                                    }
                                }
                            }
                            .padding(.horizontal, DesignTokens.Spacing.md)
                            .padding(.vertical, 4)

                            Divider().padding(.leading, DesignTokens.Spacing.xl)
                        }
                    }
                }
            }
        }
        .task(id: commit.sha) {
            await loadCommitFiles(sha: commit.sha)
        }
    }

    private func loadCommitFiles(sha: String) async {
        guard let repoPath = appState.currentRepository?.path else { return }
        isLoadingFiles = true
        commitFiles = []

        let result = await ShellExecutor.shared.execute(
            "git",
            arguments: ["diff-tree", "--no-commit-id", "-r", "--numstat", "--diff-filter=ACDMRT", sha],
            workingDirectory: repoPath
        )

        if result.exitCode == 0 {
            commitFiles = result.stdout
                .components(separatedBy: "\n")
                .filter { !$0.isEmpty }
                .compactMap { line -> CommitFileInfo? in
                    let parts = line.components(separatedBy: "\t")
                    guard parts.count >= 3 else { return nil }
                    let add = Int(parts[0]) ?? 0
                    let del = Int(parts[1]) ?? 0
                    let path = parts[2]
                    return CommitFileInfo(path: path, additions: add, deletions: del)
                }
        }
        isLoadingFiles = false
    }

    private func commitDiffView(commit: Commit, theme: Color.Theme) -> some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(theme.textMuted)

            Text("View Detailed Diff")
                .font(DesignTokens.Typography.body.weight(.semibold))
                .foregroundStyle(theme.text)

            Text("Open this commit in the full Kaleidoscope view to inspect changes.")
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

             Button {
                onOpenDiff?(commit)
            } label: {
                Text("Open Diff")
                    .font(DesignTokens.Typography.callout.weight(.medium))
                    .foregroundStyle(AppTheme.buttonTextOnColor)
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .background(AppTheme.accent)
                    .clipShape(.rect(cornerRadius: DesignTokens.CornerRadius.md))
            }
            .buttonStyle(.plain)
        }
        .padding()
        .frame(maxHeight: .infinity)
    }

    private func infoRow(label: String, value: String, theme: Color.Theme) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            Text(label)
                .font(DesignTokens.Typography.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(theme.textMuted)

            Text(value)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(theme.text)
                .textSelection(.enabled)
        }
    }

    private func formatDate(_ date: Date) -> String {
        Self.displayDateFormatter.string(from: date)
    }
}

// MARK: - Commit File Info

@MainActor
struct CommitFileInfo: Identifiable {
    let id: String
    let path: String
    let additions: Int
    let deletions: Int

    var filename: String {
        (path as NSString).lastPathComponent
    }

    var directory: String {
        let dir = (path as NSString).deletingLastPathComponent
        return dir.isEmpty ? "" : dir
    }

    var statusIcon: String {
        if additions > 0 && deletions > 0 { return "pencil.circle.fill" }
        if additions > 0 { return "plus.circle.fill" }
        if deletions > 0 { return "minus.circle.fill" }
        return "doc.circle.fill"
    }

    var statusColor: Color {
        if additions > 0 && deletions > 0 { return AppTheme.info }
        if additions > 0 { return AppTheme.diffAddition }
        if deletions > 0 { return AppTheme.diffDeletion }
        return AppTheme.textMuted
    }

    init(path: String, additions: Int, deletions: Int) {
        self.id = path
        self.path = path
        self.additions = additions
        self.deletions = deletions
    }
}
