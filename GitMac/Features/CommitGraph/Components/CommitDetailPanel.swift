import SwiftUI

struct CommitDetailPanel: View {
    let commit: Commit?
    let onClose: () -> Void

    @StateObject private var themeManager = ThemeManager.shared
    @State private var selectedTab: DetailTab = .info

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
                                Text(tab.rawValue)
                                    .font(DesignTokens.Typography.callout)
                                    .fontWeight(selectedTab == tab ? .semibold : .regular)
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

    private func detailHeader(commit: Commit, theme: Color.Theme) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                Text("COMMIT DETAILS")
                    .font(DesignTokens.Typography.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.text)

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(theme.textMuted)
                }
                .buttonStyle(.plain)
                .help("Close")
            }

            // Commit summary
            Text(commit.summary)
                .font(DesignTokens.Typography.body)
                .fontWeight(.semibold)
                .foregroundColor(theme.text)
                .lineLimit(2)

            // Metadata
            HStack(spacing: DesignTokens.Spacing.sm) {
                Label {
                    Text(commit.author)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(theme.textSecondary)
                } icon: {
                    Image(systemName: "person.fill")
                        .font(.system(size: 10))
                        .foregroundColor(theme.textMuted)
                }

                Label {
                    Text(commit.shortSHA)
                        .font(DesignTokens.Typography.caption.monospaced())
                        .foregroundColor(theme.textSecondary)
                } icon: {
                    Image(systemName: "number")
                        .font(.system(size: 10))
                        .foregroundColor(theme.textMuted)
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
        VStack {
            Text("Files changed")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(theme.textMuted)

            if let filesChanged = commit.filesChanged, filesChanged > 0 {
                FileChangesIndicator(
                    additions: commit.additions ?? 0,
                    deletions: commit.deletions ?? 0,
                    filesChanged: filesChanged
                )
                .padding()
            } else {
                Text("No file change information")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(theme.textMuted)
                    .padding()
            }
        }
    }

    private func commitDiffView(commit: Commit, theme: Color.Theme) -> some View {
        VStack {
            Text("Diff view")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(theme.textMuted)
                .padding()

            Text("(Integration with DiffView needed)")
                .font(DesignTokens.Typography.caption2)
                .foregroundColor(theme.textMuted)
        }
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
