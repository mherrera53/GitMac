import SwiftUI

// MARK: - Branch Row

/// Specialized row for displaying git branches
struct BranchRow: View {
    let branch: Branch
    let isSelected: Bool
    var style: RowStyle = .default
    var showUpstream: Bool = true
    var showAheadBehind: Bool = true
    var showCurrentIndicator: Bool = true
    var contextMenu: (() -> AnyView)? = nil
    var onSelect: (() -> Void)? = nil

    // Branch actions
    var onCheckout: (() async -> Void)? = nil
    var onMerge: (() async -> Void)? = nil
    var onDelete: (() async -> Void)? = nil
    var onPush: (() async -> Void)? = nil
    var onPull: (() async -> Void)? = nil
    var onRebase: (() async -> Void)? = nil

    // Drag and drop
    var onBranchDropped: ((Branch) -> Void)? = nil

    @State private var isDropTarget = false

    var body: some View {
        BaseRow(
            isSelected: isSelected,
            style: style,
            actions: buildActions(),
            contextMenu: contextMenu,
            onSelect: onSelect
        ) {
            branchContent
        }
        .onDrag {
            NSItemProvider(object: branch.name as NSString)
        }
        .onDrop(of: [.text], isTargeted: $isDropTarget) { providers in
            handleDrop(providers: providers)
        }
        .overlay(
            isDropTarget ?
            RoundedRectangle(cornerRadius: 6)
                .stroke(GitKrakenTheme.accent, lineWidth: 2)
                .padding(2)
            : nil
        )
    }

    @ViewBuilder
    private var branchContent: some View {
        // Branch type icon
        Image(systemName: branchIcon)
            .foregroundColor(branchColor)
            .frame(width: 16)

        // Branch name and info
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(branch.name)
                    .lineLimit(1)
                    .fontWeight(branch.isCurrent ? .semibold : .regular)

                if showCurrentIndicator && branch.isCurrent {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(GitKrakenTheme.success)
                }
            }

            if showUpstream, let upstream = branch.upstream {
                Text("↑ \(upstream)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }

        Spacer()

        // Ahead/behind indicators
        if showAheadBehind, let (ahead, behind) = branch.aheadBehind {
            HStack(spacing: 8) {
                if ahead > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up")
                            .font(.caption2)
                        Text("\(ahead)")
                            .font(.caption.monospacedDigit())
                    }
                    .foregroundColor(GitKrakenTheme.success)
                }

                if behind > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.down")
                            .font(.caption2)
                        Text("\(behind)")
                            .font(.caption.monospacedDigit())
                    }
                    .foregroundColor(GitKrakenTheme.warning)
                }
            }
        }
    }

    private var branchIcon: String {
        if branch.isRemote {
            return "cloud"
        } else if branch.isCurrent {
            return "checkmark.circle.fill"
        } else {
            return "arrow.branch"
        }
    }

    private var branchColor: Color {
        if branch.isRemote {
            return GitKrakenTheme.accentCyan
        } else if branch.isCurrent {
            return GitKrakenTheme.success
        } else {
            return GitKrakenTheme.accent
        }
    }

    private func buildActions() -> [RowAction] {
        var actions: [RowAction] = []

        if !branch.isCurrent, let checkout = onCheckout {
            actions.append(
                RowAction(
                    icon: "arrow.uturn.backward",
                    color: GitKrakenTheme.accent,
                    tooltip: "Checkout",
                    action: checkout
                )
            )
        }

        if !branch.isRemote, let push = onPush {
            actions.append(
                RowAction(
                    icon: "arrow.up.doc",
                    color: GitKrakenTheme.success,
                    tooltip: "Push",
                    action: push
                )
            )
        }

        if !branch.isRemote, let pull = onPull {
            actions.append(
                RowAction(
                    icon: "arrow.down.doc",
                    color: GitKrakenTheme.accentCyan,
                    tooltip: "Pull",
                    action: pull
                )
            )
        }

        if let merge = onMerge {
            actions.append(
                RowAction(
                    icon: "arrow.triangle.merge",
                    color: GitKrakenTheme.accentPurple,
                    tooltip: "Merge",
                    action: merge
                )
            )
        }

        if !branch.isCurrent, let delete = onDelete {
            actions.append(
                RowAction(
                    icon: "trash",
                    color: GitKrakenTheme.error,
                    tooltip: "Delete",
                    action: delete
                )
            )
        }

        return actions
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadObject(ofClass: NSString.self) { (droppedBranchName, error) in
            guard let droppedName = droppedBranchName as? String,
                  droppedName != branch.name else {
                return
            }

            // Create a temporary branch object with the dropped name
            // The actual branch will be resolved in BranchListView
            let droppedBranch = Branch(
                name: droppedName,
                fullName: "refs/heads/\(droppedName)",
                isRemote: false,
                targetSHA: ""
            )

            DispatchQueue.main.async {
                onBranchDropped?(droppedBranch)
            }
        }

        return true
    }
}

// MARK: - Branch Row Data Adapter
// TODO: Fix RowData conformance to match actual Branch model

/*
extension Branch: RowData {
    var primaryText: String { name }

    var secondaryText: String? { upstream }

    var leadingIcon: RowIcon? {
        let icon = isRemote ? "cloud" : (isCurrent ? "checkmark.circle.fill" : "arrow.branch")
        let color = isRemote ? GitKrakenTheme.accentCyan : (isCurrent ? GitKrakenTheme.success : GitKrakenTheme.accent)
        return RowIcon(systemName: icon, color: color, size: 16)
    }

    var trailingContent: RowTrailingContent? {
        if let (ahead, behind) = aheadBehind, ahead > 0 || behind > 0 {
            let text = ahead > 0 && behind > 0 ? "↑\(ahead) ↓\(behind)" : (ahead > 0 ? "↑\(ahead)" : "↓\(behind)")
            return .text(text, .secondary)
        }
        return nil
    }
}
*/

// MARK: - Preview
// TODO: Fix preview samples to match actual Branch model initializer

/*
#if DEBUG
struct BranchRow_Previews: PreviewProvider {
    static let currentBranch = Branch(
        name: "main",
        isRemote: false,
        isCurrent: true,
        upstream: "origin/main",
        aheadBehind: (2, 0)
    )

    static let featureBranch = Branch(
        name: "feature/user-auth",
        isRemote: false,
        isCurrent: false,
        upstream: "origin/feature/user-auth",
        aheadBehind: (5, 3)
    )

    static let remoteBranch = Branch(
        name: "origin/develop",
        isRemote: true,
        isCurrent: false,
        upstream: nil,
        aheadBehind: nil
    )

    static var previews: some View {
        VStack(spacing: 8) {
            // Current branch
            BranchRow(
                branch: currentBranch,
                isSelected: false,
                onPush: { print("Push") },
                onPull: { print("Pull") }
            )

            // Feature branch
            BranchRow(
                branch: featureBranch,
                isSelected: true,
                onCheckout: { print("Checkout") },
                onMerge: { print("Merge") },
                onDelete: { print("Delete") }
            )

            // Remote branch
            BranchRow(
                branch: remoteBranch,
                isSelected: false
            )

            // Compact style
            BranchRow(
                branch: featureBranch,
                isSelected: false,
                style: .compact
            )
        }
        .padding()
        .frame(width: 500)
    }
}
#endif
*/
