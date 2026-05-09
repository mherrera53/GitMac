import SwiftUI
import UniformTypeIdentifiers

// MARK: - Branch Row

// Note: UTType.branchData is defined in CommitGraphView.swift

/// Specialized row for displaying git branches
struct BranchRow: View {
    let branch: Branch
    let isSelected: Bool
    var style: RowStyle = .default
    var showUpstream: Bool = true
    var showAheadBehind: Bool = true
    var showCurrentIndicator: Bool = true
    var onSelect: (() -> Void)? = nil

    // Branch actions
    var onCheckout: (() async -> Void)? = nil
    var onMerge: (() async -> Void)? = nil
    var onDelete: (() async -> Void)? = nil
    var onPush: (() async -> Void)? = nil
    var onPull: (() async -> Void)? = nil
    var onRebase: (() async -> Void)? = nil

    // PR actions - observe tracker directly for reactive updates
    @StateObject private var prTracker = BranchPRTracker.shared
    var onCreatePR: (() -> Void)? = nil
    var onViewPR: ((GitHubPullRequest) -> Void)? = nil
    var onMergePR: ((GitHubPullRequest, MergeMethod) async -> Void)? = nil

    // Drag and drop
    var onBranchDropped: ((Branch) -> Void)? = nil

    @State private var isDropTarget = false
    @State private var isDragging = false

    /// Get PR directly from tracker (reactive - updates when tracker changes)
    private var pullRequest: GitHubPullRequest? {
        prTracker.getPR(for: branch.name)
    }

    var body: some View {
        BaseRow(
            isSelected: isSelected,
            style: style,
            actions: buildActions(),
            onSelect: onSelect,
            content: { branchContent },
            contextMenu: { branchContextMenu }
        )
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                // Double-click to checkout (if not already current)
                if !branch.isCurrent, let checkout = onCheckout {
                    Task { await checkout() }
                }
            }
        )
        .draggable(branch.name) {
            // Drag preview
            HStack(spacing: 8) {
                Image(systemName: branchIcon)
                    .foregroundStyle(.white)
                Text(branch.name)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppTheme.accent)
                    .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
            )
        }
        // Accept drops from both String (intra-panel) and BranchTransferable (from CommitGraph)
        .onDrop(of: [.text, .branchData], isTargeted: Binding(
            get: { isDropTarget },
            set: { newValue in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isDropTarget = newValue
                }
            }
        )) { providers in
            handleDrop(providers: providers)
        }
        .background(
            // Drop target highlight background
            RoundedRectangle(cornerRadius: 6)
                .fill(isDropTarget ? AppTheme.accent.opacity(0.15) : Color.clear)
                .animation(.easeInOut(duration: 0.15), value: isDropTarget)
        )
        .overlay(
            // Drop target border with glow effect
            Group {
                if isDropTarget {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(AppTheme.accent, lineWidth: 2)
                        .shadow(color: AppTheme.accent.opacity(0.5), radius: 4, x: 0, y: 0)
                        .padding(1)
                }
            }
        )
        .overlay(alignment: .top) {
            // Drop indicator line at top
            if isDropTarget {
                Rectangle()
                    .fill(AppTheme.accent)
                    .frame(height: 3)
                    .clipShape(.rect(cornerRadius: 1.5))
                    .padding(.horizontal, 4)
                    .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .top)))
            }
        }
        .scaleEffect(isDropTarget ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDropTarget)
    }

    @ViewBuilder
    private var branchContent: some View {
        // Branch type icon
        Image(systemName: branchIcon)
            .foregroundStyle(branchColor)
            .frame(width: 16)

        // Branch name and info
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Text(branch.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .fontWeight(branch.isCurrent ? .semibold : .regular)
                    .font(.system(size: 11))

                if showCurrentIndicator && branch.isCurrent {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(AppTheme.success)
                }

                // PR badge
                if let pr = pullRequest {
                    HStack(spacing: 3) {
                        Image(systemName: pr.draft ? "doc.text" : "arrow.triangle.pull")
                            .font(.system(size: 9))
                        Text("#\(pr.number)")
                            .font(.system(size: 10, weight: .medium).monospacedDigit())
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(prBadgeColor(for: pr).opacity(0.2))
                    .foregroundStyle(prBadgeColor(for: pr))
                    .clipShape(.rect(cornerRadius: 4))
                }
            }

            if showUpstream, let upstream = branch.upstream {
                Text("↑ " + upstream.name)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
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
                            .foregroundStyle(AppTheme.success)
                        Text("\(ahead)")
                            .font(.caption.monospacedDigit())
                    }
                    .foregroundStyle(AppTheme.success)
                }

                if behind > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.down")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.warning)
                        Text("\(behind)")
                            .font(.caption.monospacedDigit())
                    }
                    .foregroundStyle(AppTheme.warning)
                }
            }
        }
    }

    private func prBadgeColor(for pr: GitHubPullRequest) -> Color {
        if pr.draft { return AppTheme.textSecondary }
        switch pr.state {
        case "open": return AppTheme.success
        case "closed": return AppTheme.error
        default: return AppTheme.accentPurple
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
            return AppTheme.accentCyan
        } else if branch.isCurrent {
            return AppTheme.success
        } else {
            return AppTheme.accent
        }
    }

    @ViewBuilder
    private var branchContextMenu: some View {
        if !branch.isCurrent, let checkout = onCheckout {
            Button {
                Task { await checkout() }
            } label: {
                Label("Checkout", systemImage: "arrow.uturn.backward")
            }
        }

        if !branch.isRemote {
            if let push = onPush {
                Button {
                    Task { await push() }
                } label: {
                    Label("Push", systemImage: "arrow.up.doc")
                }
            }

            if let pull = onPull {
                Button {
                    Task { await pull() }
                } label: {
                    Label("Pull", systemImage: "arrow.down.doc")
                }
            }
        }

        // PR Section
        if !branch.isRemote {
            Divider()

            if let pr = pullRequest {
                // Has an open PR
                Button {
                    onViewPR?(pr)
                } label: {
                    Label("View PR #\(pr.number)", systemImage: "arrow.triangle.pull")
                }

                if pr.state == "open", let url = URL(string: pr.htmlUrl) {
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        Label("Open in GitHub", systemImage: "safari")
                    }
                }

                if pr.state == "open" && !pr.draft, let mergePR = onMergePR {
                    Menu {
                        Button {
                            Task { await mergePR(pr, .merge) }
                        } label: {
                            Label("Create merge commit", systemImage: "arrow.triangle.merge")
                        }

                        Button {
                            Task { await mergePR(pr, .squash) }
                        } label: {
                            Label("Squash and merge", systemImage: "square.stack.3d.up")
                        }

                        Button {
                            Task { await mergePR(pr, .rebase) }
                        } label: {
                            Label("Rebase and merge", systemImage: "arrow.triangle.branch")
                        }
                    } label: {
                        Label("Merge PR #\(pr.number)", systemImage: "checkmark.circle")
                    }
                }
            } else if let createPR = onCreatePR {
                // No PR - show create option
                Button {
                    createPR()
                } label: {
                    Label("Create Pull Request", systemImage: "plus.circle")
                }
            }
        }

        if let merge = onMerge {
            Divider()
            Button {
                Task { await merge() }
            } label: {
                Label("Merge into current", systemImage: "arrow.triangle.merge")
            }
        }

        if let rebase = onRebase {
            Button {
                Task { await rebase() }
            } label: {
                Label("Rebase onto current", systemImage: "arrow.triangle.swap")
            }
        }

        if !branch.isCurrent, let delete = onDelete {
            Divider()
            Button(role: .destructive) {
                Task { await delete() }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func buildActions() -> [RowAction] {
        var actions: [RowAction] = []

        if !branch.isCurrent, let checkout = onCheckout {
            actions.append(
                RowAction(
                    icon: "arrow.uturn.backward",
                    color: AppTheme.accent,
                    tooltip: "Checkout",
                    action: checkout
                )
            )
        }

        if !branch.isRemote, let push = onPush {
            actions.append(
                RowAction(
                    icon: "arrow.up.doc",
                    color: AppTheme.success,
                    tooltip: "Push",
                    action: push
                )
            )
        }

        if !branch.isRemote, let pull = onPull {
            actions.append(
                RowAction(
                    icon: "arrow.down.doc",
                    color: AppTheme.accentCyan,
                    tooltip: "Pull",
                    action: pull
                )
            )
        }

        if let merge = onMerge {
            actions.append(
                RowAction(
                    icon: "arrow.triangle.merge",
                    color: AppTheme.accentPurple,
                    tooltip: "Merge",
                    action: merge
                )
            )
        }

        if !branch.isCurrent, let delete = onDelete {
            actions.append(
                RowAction(
                    icon: "trash",
                    color: AppTheme.error,
                    tooltip: "Delete",
                    action: delete
                )
            )
        }

        return actions
    }

    // MARK: - Drop Handling

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        // Try to load as BranchTransferable first (from CommitGraph)
        if provider.hasItemConformingToTypeIdentifier(UTType.branchData.identifier) {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.branchData.identifier) { data, error in
                guard let data = data,
                      let branchData = try? JSONDecoder().decode(BranchTransferable.self, from: data),
                      branchData.name != branch.name else {
                    return
                }

                let droppedBranch = Branch(
                    name: branchData.name,
                    fullName: "refs/heads/\(branchData.name)",
                    isRemote: false,
                    targetSHA: branchData.targetSHA ?? ""
                )

                DispatchQueue.main.async {
                    onBranchDropped?(droppedBranch)
                }
            }
            return true
        }

        // Fall back to String (intra-panel drag)
        provider.loadObject(ofClass: NSString.self) { (droppedBranchName, error) in
            guard let droppedName = droppedBranchName as? String,
                  droppedName != branch.name else {
                return
            }

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

// Note: BranchTransferable is defined in CommitGraphView.swift
// We use it directly for decoding cross-panel drops

// MARK: - Branch Row Data Adapter
// TODO: Fix RowData conformance to match actual Branch model

/*
extension Branch: RowData {
    var primaryText: String { name }

    var secondaryText: String? { upstream }

    var leadingIcon: RowIcon? {
        let icon = isRemote ? "cloud" : (isCurrent ? "checkmark.circle.fill" : "arrow.branch")
        let color = isRemote ? AppTheme.accentCyan : (isCurrent ? AppTheme.success : AppTheme.accent)
        return RowIcon(systemName: icon, color: color, size: 16)
    }

    var trailingContent: RowTrailingContent? {
        if let (ahead, behind) = aheadBehind, ahead > 0 || behind > 0 {
            let text = ahead > 0 && behind > 0 ? "↑\(ahead) ↓\(behind)" : (ahead > 0 ? "↑\(ahead)" : "↓\(behind)")
            return .text(text, AppTheme.textSecondary)
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
                onPush: { Logger.debug("Push") },
                onPull: { Logger.debug("Pull") }
            )

            // Feature branch
            BranchRow(
                branch: featureBranch,
                isSelected: true,
                onCheckout: { Logger.debug("Checkout") },
                onMerge: { Logger.debug("Merge") },
                onDelete: { Logger.debug("Delete") }
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
