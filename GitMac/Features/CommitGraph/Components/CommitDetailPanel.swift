import SwiftUI

struct CommitDetailPanel: View {
    let commit: Commit?
    let onClose: () -> Void
    var onOpenDiff: ((Commit) -> Void)? = nil

    @EnvironmentObject var appState: AppState
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var selectedTab: DetailTab = .info
    @State private var changedFiles: [CommitFile] = []
    @State private var isLoadingFiles = false

    private let gitEngine = GitEngine()

    enum DetailTab: String, CaseIterable {
        case info = "Info"
        case files = "Files"
        case diff = "Diff"
    }

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        if let commit = commit {
            return AnyView(
                VStack(spacing: 0) {
                    // Header
                    detailHeader(commit: commit, theme: theme)

                    Divider()

                    // Tab bar
                    HStack(spacing: 0) {
                        ForEach(DetailTab.allCases, id: \.self) { tab in
                            Button {
                                selectedTab = tab
                            } label: {
                                HStack(spacing: 4) {
                                    Text(tab.rawValue)
                                        .font(DesignTokens.Typography.callout)
                                        .fontWeight(selectedTab == tab ? .semibold : .regular)
                                    if tab == .files && !changedFiles.isEmpty {
                                        Text("\(changedFiles.count)")
                                            .font(DesignTokens.Typography.caption2)
                                            .foregroundColor(theme.textMuted)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(theme.backgroundSecondary)
                                            .cornerRadius(4)
                                    }
                                }
                                .foregroundColor(
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

                    // Tab content
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
                .task(id: commit.sha) {
                    await loadFiles(for: commit)
                }
            )
        } else {
            return AnyView(
                VStack {
                    Spacer()
                    Text("No commit selected")
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(theme.textMuted)
                    Spacer()
                }
                .frame(width: 400)
                .background(theme.background)
            )
        }
    }

    private func loadFiles(for commit: Commit) async {
        guard let path = appState.currentRepository?.path else { return }
        isLoadingFiles = true
        defer { isLoadingFiles = false }

        do {
            let files = try await gitEngine.getCommitFiles(sha: commit.sha, at: path)
            await MainActor.run {
                changedFiles = files
            }
        } catch {
            await MainActor.run {
                changedFiles = []
            }
        }
    }

    private func detailHeader(commit: Commit, theme: Color.Theme) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                Text("COMMIT DETAILS")
                    .font(DesignTokens.Typography.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.text)

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(theme.textMuted)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .help("Close")
            }

            // Commit summary
            Text(commit.cleanSummary)
                .font(DesignTokens.Typography.body)
                .fontWeight(.semibold)
                .foregroundColor(theme.text)
                .lineLimit(2)

            // Metadata with avatar
            HStack(spacing: DesignTokens.Spacing.sm) {
                AvatarImageView(
                    email: commit.authorEmail,
                    size: 20,
                    fallbackInitial: String(commit.author.prefix(1))
                )

                Text(commit.author)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(theme.textSecondary)

                Spacer()

                Text(commit.shortSHA)
                    .font(DesignTokens.Typography.caption.monospaced())
                    .foregroundColor(theme.textMuted)
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
                            .foregroundColor(theme.textMuted)

                        Text(body)
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(theme.text)
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
            // Header
            HStack {
                Text("Changed Files")
                    .font(DesignTokens.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.textMuted)
                Spacer()
                if !changedFiles.isEmpty {
                    FileChangesIndicator(
                        additions: changedFiles.reduce(0) { $0 + $1.additions },
                        deletions: changedFiles.reduce(0) { $0 + $1.deletions },
                        filesChanged: changedFiles.count,
                        compact: true
                    )
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)

            Divider()

            if isLoadingFiles {
                Spacer()
                ProgressView()
                    .scaleEffect(0.8)
                Spacer()
            } else if changedFiles.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 24))
                        .foregroundColor(theme.textMuted)
                    Text("No files changed")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(theme.textMuted)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(changedFiles) { file in
                            commitFileRow(file: file, theme: theme)
                        }
                    }
                }
            }
        }
    }

    private func commitFileRow(file: CommitFile, theme: Color.Theme) -> some View {
        HStack(spacing: 8) {
            // Status icon
            Image(systemName: file.status.icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(file.status.color)
                .frame(width: 16)

            // File name
            Text((file.path as NSString).lastPathComponent)
                .font(DesignTokens.Typography.caption)
                .foregroundColor(theme.text)
                .lineLimit(1)

            Spacer()

            // Additions/deletions
            HStack(spacing: 4) {
                if file.additions > 0 {
                    Text("+\(file.additions)")
                        .font(DesignTokens.Typography.caption2.monospaced())
                        .foregroundColor(AppTheme.success)
                }
                if file.deletions > 0 {
                    Text("-\(file.deletions)")
                        .font(DesignTokens.Typography.caption2.monospaced())
                        .foregroundColor(AppTheme.error)
                }
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(theme.background)
    }

    private func commitDiffView(commit: Commit, theme: Color.Theme) -> some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Spacer()

            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 32))
                .foregroundColor(theme.textMuted)

            Text("View Detailed Diff")
                .font(DesignTokens.Typography.body.weight(.semibold))
                .foregroundColor(theme.text)

            Text("Open this commit in the full diff view to inspect changes.")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(theme.textSecondary)
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
                    .cornerRadius(DesignTokens.CornerRadius.md)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding()
    }

    private func infoRow(label: String, value: String, theme: Color.Theme) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            Text(label)
                .font(DesignTokens.Typography.caption2)
                .fontWeight(.semibold)
                .foregroundColor(theme.textMuted)

            Text(value)
                .font(DesignTokens.Typography.caption)
                .foregroundColor(theme.text)
                .textSelection(.enabled)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
