import SwiftUI

// MARK: - Commit Row
// TODO: Fix entire CommitRow to match actual Commit model properties
// (Current implementation assumes properties like isMerge, subject, abbreviatedHash that don't exist)

/*
/// Specialized row for displaying git commits
struct CommitRow: View {
    let commit: Commit
    let isSelected: Bool
    var style: RowStyle = .default
    var showAvatar: Bool = false
    var showHash: Bool = true
    var showDate: Bool = true
    var showAuthor: Bool = true
    var contextMenu: (() -> AnyView)? = nil
    var onSelect: (() -> Void)? = nil

    // Commit actions
    var onCheckout: (() async -> Void)? = nil
    var onCherryPick: (() async -> Void)? = nil
    var onRevert: (() async -> Void)? = nil

    var body: some View {
        BaseRow(
            isSelected: isSelected,
            style: style,
            actions: buildActions(),
            contextMenu: contextMenu,
            onSelect: onSelect
        ) {
            commitContent
        }
    }

    @ViewBuilder
    private var commitContent: some View {
        // Graph/indicator (could be customized)
        Circle()
            .fill(commit.isMerge ? AppTheme.accentPurple : AppTheme.accent)
            .frame(width: 8, height: 8)

        // Commit info
        VStack(alignment: .leading, spacing: 2) {
            // Subject line
            HStack(spacing: 6) {
                if showHash {
                    Text(commit.abbreviatedHash)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(AppTheme.textSecondary)
                }

                Text(commit.subject)
                    .lineLimit(1)
                    .fontWeight(.medium)
            }

            // Metadata
            HStack(spacing: 8) {
                if showAuthor {
                    Text(commit.author)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if showDate {
                    Text(commit.date, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }

        Spacer()

        // Merge indicator
        if commit.isMerge {
            Image(systemName: "arrow.triangle.merge")
                .font(.caption)
                .foregroundColor(AppTheme.accentPurple)
        }
    }

    private func buildActions() -> [RowAction] {
        var actions: [RowAction] = []

        if let checkout = onCheckout {
            actions.append(
                RowAction(
                    icon: "arrow.uturn.backward",
                    color: AppTheme.accent,
                    tooltip: "Checkout",
                    action: checkout
                )
            )
        }

        if let cherryPick = onCherryPick {
            actions.append(
                RowAction(
                    icon: "doc.on.doc",
                    color: AppTheme.success,
                    tooltip: "Cherry-pick",
                    action: cherryPick
                )
            )
        }

        if let revert = onRevert {
            actions.append(
                RowAction(
                    icon: "arrow.counterclockwise",
                    color: AppTheme.warning,
                    tooltip: "Revert",
                    action: revert
                )
            )
        }

        return actions
    }
}
*/

// MARK: - Commit Row Data Adapter
// TODO: Fix RowData conformance to match actual Commit model

/*
extension Commit: RowData {
    var primaryText: String { subject }

    var secondaryText: String? {
        "\(author) • \(date.formatted(.relative(presentation: .named)))"
    }

    var leadingIcon: RowIcon? {
        RowIcon(
            systemName: isMerge ? "arrow.triangle.merge" : "circle.fill",
            color: isMerge ? AppTheme.accentPurple : AppTheme.accent,
            size: 8
        )
    }

    var trailingContent: RowTrailingContent? {
        .text(abbreviatedHash, AppTheme.textSecondary)
    }
}
*/

// MARK: - Preview
// TODO: Fix preview samples to match actual Commit model initializer

/*
#if DEBUG
struct CommitRow_Previews: PreviewProvider {
    static let sampleCommit = Commit(
        hash: "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0",
        abbreviatedHash: "a1b2c3d",
        subject: "Add new feature for user authentication",
        body: "This commit adds OAuth2 support",
        author: "John Doe",
        authorEmail: "john@example.com",
        date: Date().addingTimeInterval(-3600),
        parents: ["parent1"]
    )

    static let mergeCommit = Commit(
        hash: "b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0a1",
        abbreviatedHash: "b2c3d4e",
        subject: "Merge branch 'feature/login' into main",
        body: nil,
        author: "Jane Smith",
        authorEmail: "jane@example.com",
        date: Date().addingTimeInterval(-7200),
        parents: ["parent1", "parent2"]
    )

    static var previews: some View {
        VStack(spacing: 8) {
            // Regular commit
            CommitRow(
                commit: sampleCommit,
                isSelected: false,
                onCheckout: { print("Checkout") },
                onCherryPick: { print("Cherry-pick") }
            )

            // Selected commit
            CommitRow(
                commit: sampleCommit,
                isSelected: true
            )

            // Merge commit
            CommitRow(
                commit: mergeCommit,
                isSelected: false,
                onRevert: { print("Revert") }
            )

            // Compact style
            CommitRow(
                commit: sampleCommit,
                isSelected: false,
                style: .compact
            )
        }
        .padding()
        .frame(width: 600)
    }
}
#endif
*/
