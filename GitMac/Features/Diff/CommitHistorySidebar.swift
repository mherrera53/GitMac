import SwiftUI

// MARK: - Commit History Sidebar (Kaleidoscope-style)

/// Right sidebar showing commit history for diff comparison
struct CommitHistorySidebar: View {
    let commits: [Commit]
    @Binding var selectedCommitA: Commit?
    @Binding var selectedCommitB: Commit?
    @State private var filterText: String = ""
    @State private var currentChangeIndex: Int = 0
    @StateObject private var themeManager = ThemeManager.shared

    private var filteredCommits: [Commit] {
        if filterText.isEmpty {
            return commits
        }
        return commits.filter { commit in
            commit.message.localizedCaseInsensitiveContains(filterText) ||
            commit.author.localizedCaseInsensitiveContains(filterText) ||
            commit.shortSHA.localizedCaseInsensitiveContains(filterText)
        }
    }

    private var totalChanges: Int {
        commits.count
    }

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Filter/Search
            searchBarView

            Divider()

            // Commit list
            ScrollView {
                LazyVStack(spacing: DesignTokens.Spacing.xs) {
                    ForEach(filteredCommits) { commit in
                        CommitHistoryRow(
                            commit: commit,
                            isSelectedA: selectedCommitA?.id == commit.id,
                            isSelectedB: selectedCommitB?.id == commit.id,
                            onSelectA: { selectedCommitA = commit },
                            onSelectB: { selectedCommitB = commit }
                        )
                    }
                }
                .padding(DesignTokens.Spacing.sm)
            }
            .background(theme.background)

            Divider()

            // Change navigation footer
            changeNavigationFooter
        }
        .frame(width: 320)
        .background(theme.backgroundSecondary)
    }

    // MARK: - Components

    private var headerView: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "clock.arrow.circlepath")
                .font(DesignTokens.Typography.headline)
                .foregroundColor(AppTheme.accent)

            Text("History")
                .font(DesignTokens.Typography.headline.weight(.semibold))
                .foregroundColor(AppTheme.textPrimary)

            Spacer()

            Text("\(totalChanges)")
                .font(DesignTokens.Typography.caption.monospaced())
                .foregroundColor(AppTheme.textMuted)
                .padding(.horizontal, DesignTokens.Spacing.xs)
                .padding(.vertical, 2)
                .background(AppTheme.backgroundTertiary)
                .cornerRadius(DesignTokens.CornerRadius.sm)
        }
        .padding(DesignTokens.Spacing.md)
    }

    private var searchBarView: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(AppTheme.textMuted)

            TextField("Filter Commits", text: $filterText)
                .textFieldStyle(.plain)
                .font(DesignTokens.Typography.body)
                .foregroundColor(AppTheme.textPrimary)

            if !filterText.isEmpty {
                Button {
                    filterText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(AppTheme.textMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DesignTokens.Spacing.sm)
        .background(AppTheme.backgroundTertiary)
        .cornerRadius(DesignTokens.CornerRadius.md)
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
    }

    private var changeNavigationFooter: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Button {
                if currentChangeIndex > 0 {
                    currentChangeIndex -= 1
                    selectCommitAtIndex(currentChangeIndex)
                }
            } label: {
                Image(systemName: "chevron.up")
                    .font(DesignTokens.Typography.callout)
                    .foregroundColor(currentChangeIndex > 0 ? AppTheme.accent : AppTheme.textMuted)
            }
            .buttonStyle(.plain)
            .disabled(currentChangeIndex <= 0)

            Text("Change \(currentChangeIndex + 1) of \(totalChanges)")
                .font(DesignTokens.Typography.caption.monospaced())
                .foregroundColor(AppTheme.textPrimary)

            Button {
                if currentChangeIndex < totalChanges - 1 {
                    currentChangeIndex += 1
                    selectCommitAtIndex(currentChangeIndex)
                }
            } label: {
                Image(systemName: "chevron.down")
                    .font(DesignTokens.Typography.callout)
                    .foregroundColor(currentChangeIndex < totalChanges - 1 ? AppTheme.accent : AppTheme.textMuted)
            }
            .buttonStyle(.plain)
            .disabled(currentChangeIndex >= totalChanges - 1)
        }
        .padding(DesignTokens.Spacing.sm)
        .background(AppTheme.backgroundTertiary)
    }

    // MARK: - Helpers

    private func selectCommitAtIndex(_ index: Int) {
        guard index >= 0, index < commits.count else { return }
        let commit = commits[index]
        if selectedCommitA == nil {
            selectedCommitA = commit
        } else {
            selectedCommitB = commit
        }
    }
}

// MARK: - Commit History Row

struct CommitHistoryRow: View {
    let commit: Commit
    let isSelectedA: Bool
    let isSelectedB: Bool
    let onSelectA: () -> Void
    let onSelectB: () -> Void

    @State private var isHovered = false
    @StateObject private var themeManager = ThemeManager.shared

    private var initials: String {
        let components = commit.author.components(separatedBy: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1)) + String(components[1].prefix(1))
        }
        return String(commit.author.prefix(2))
    }

    private var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: commit.authorDate, relativeTo: Date())
    }

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        HStack(spacing: DesignTokens.Spacing.sm) {
            // Version labels (A/B)
            VStack(spacing: 4) {
                Button {
                    onSelectA()
                } label: {
                    Text("A")
                        .font(DesignTokens.Typography.caption2.weight(.bold))
                        .foregroundColor(isSelectedA ? .white : AppTheme.textMuted)
                        .frame(width: 20, height: 20)
                        .background(isSelectedA ? AppTheme.accent : AppTheme.backgroundTertiary)
                        .cornerRadius(DesignTokens.CornerRadius.sm)
                }
                .buttonStyle(.plain)

                Button {
                    onSelectB()
                } label: {
                    Text("B")
                        .font(DesignTokens.Typography.caption2.weight(.bold))
                        .foregroundColor(isSelectedB ? .white : AppTheme.textMuted)
                        .frame(width: 20, height: 20)
                        .background(isSelectedB ? AppTheme.info : AppTheme.backgroundTertiary)
                        .cornerRadius(DesignTokens.CornerRadius.sm)
                }
                .buttonStyle(.plain)
            }

            // Author avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [avatarColor, avatarColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text(initials.uppercased())
                    .font(DesignTokens.Typography.caption2.weight(.semibold))
                    .foregroundColor(.white)
            }
            .frame(width: 32, height: 32)

            // Commit info
            VStack(alignment: .leading, spacing: 2) {
                // Author name and time
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Text(commit.author)
                        .font(DesignTokens.Typography.caption.weight(.medium))
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    Text(relativeTime)
                        .font(DesignTokens.Typography.caption2)
                        .foregroundColor(AppTheme.textMuted)
                }

                // Commit message
                Text(commit.summary)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.textSecondary)
                    .lineLimit(2)

                // Commit hash
                Text(commit.shortSHA)
                    .font(DesignTokens.Typography.caption2.monospaced())
                    .foregroundColor(AppTheme.textMuted)
            }
        }
        .padding(DesignTokens.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                .fill(backgroundForState)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                .stroke(borderForState, lineWidth: (isSelectedA || isSelectedB) ? 2 : 1)
        )
        .onHover { isHovered = $0 }
    }

    // MARK: - Helpers

    private var avatarColor: Color {
        // Generate consistent color from author name
        let hash = commit.author.hashValue
        let colors: [Color] = [
            Color(red: 0.3, green: 0.6, blue: 0.9),
            Color(red: 0.9, green: 0.4, blue: 0.5),
            Color(red: 0.5, green: 0.8, blue: 0.4),
            Color(red: 0.9, green: 0.6, blue: 0.3),
            Color(red: 0.7, green: 0.4, blue: 0.9),
            Color(red: 0.4, green: 0.7, blue: 0.7),
        ]
        return colors[abs(hash) % colors.count]
    }

    private var backgroundForState: Color {
        if isSelectedA || isSelectedB {
            return AppTheme.backgroundSecondary
        }
        if isHovered {
            return AppTheme.hover
        }
        return Color.clear
    }

    private var borderForState: Color {
        if isSelectedA {
            return AppTheme.accent
        }
        if isSelectedB {
            return AppTheme.info
        }
        if isHovered {
            return AppTheme.border
        }
        return Color.clear
    }
}

// MARK: - Preview

#if DEBUG
struct CommitHistorySidebar_Previews: PreviewProvider {
    static var previews: some View {
        CommitHistorySidebar(
            commits: [
                Commit(
                    id: UUID(),
                    sha: "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0",
                    shortSHA: "a1b2c3d",
                    message: "Add new feature for user authentication",
                    summary: "Add new feature for user authentication",
                    body: nil,
                    author: "Luke Sandberg",
                    authorEmail: "luke@example.com",
                    authorDate: Date().addingTimeInterval(-3600),
                    committer: "Luke Sandberg",
                    committerEmail: "luke@example.com",
                    committerDate: Date().addingTimeInterval(-3600),
                    parentSHAs: []
                ),
                Commit(
                    id: UUID(),
                    sha: "b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1",
                    shortSHA: "b2c3d4e",
                    message: "Fix authentication bug in login flow",
                    summary: "Fix authentication bug in login flow",
                    body: nil,
                    author: "Niklas Mischkulnig",
                    authorEmail: "niklas@example.com",
                    authorDate: Date().addingTimeInterval(-7200),
                    committer: "Niklas Mischkulnig",
                    committerEmail: "niklas@example.com",
                    committerDate: Date().addingTimeInterval(-7200),
                    parentSHAs: []
                ),
            ],
            selectedCommitA: .constant(nil),
            selectedCommitB: .constant(nil)
        )
        .frame(height: 600)
    }
}
#endif
