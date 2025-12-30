import SwiftUI

struct BranchSelectorButton: View {
    @Binding var branches: [Branch]
    let currentBranch: Branch?
    let onCheckout: (Branch) -> Void

    @StateObject private var themeManager = ThemeManager.shared
    @State private var searchText = ""

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        return Menu {
            // Local branches
            Section("Local Branches") {
                ForEach(filteredLocalBranches) { branch in
                    Button {
                        onCheckout(branch)
                    } label: {
                        HStack {
                            Image(systemName: branch.isCurrent ? "star.circle.fill" : "arrow.triangle.branch")
                                .foregroundColor(branch.isCurrent ? AppTheme.warning : .primary)
                                .symbolRenderingMode(.hierarchical)
                            Text(branch.name)
                                .fontWeight(branch.isCurrent ? .bold : .regular)
                            Spacer()
                            if branch.isCurrent {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(AppTheme.success)
                                    .symbolRenderingMode(.multicolor)
                            }
                        }
                    }
                }
            }

            // Remote branches (if any)
            if !filteredRemoteBranches.isEmpty {
                Section("Remote Branches") {
                    ForEach(filteredRemoteBranches.prefix(10)) { branch in
                        Button {
                            // Checkout remote branch (creates local tracking branch)
                            onCheckout(branch)
                        } label: {
                            HStack {
                                Image(systemName: "cloud.fill")
                                    .symbolRenderingMode(.hierarchical)
                                Text(branch.name)
                            }
                        }
                    }
                }
            }

            Divider()

            Button {
                // Create new branch
                NotificationCenter.default.post(name: .showCreateBranchSheet, object: nil)
            } label: {
                Label("Create New Branch...", systemImage: "plus.app.fill")
                    .symbolRenderingMode(.hierarchical)
            }
        } label: {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: currentBranch != nil ? "point.3.connected.trianglepath.dotted" : "arrow.triangle.branch")
                    .font(DesignTokens.Typography.callout)
                    .foregroundColor(AppTheme.accent)
                    .symbolRenderingMode(.hierarchical)

                Text(currentBranch?.name ?? "No Branch")
                    .font(DesignTokens.Typography.callout)
                    .fontWeight(currentBranch != nil ? .semibold : .regular)
                    .foregroundColor(theme.text)
                    .lineLimit(1)

                Image(systemName: "chevron.down.circle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.textMuted)
                    .symbolRenderingMode(.hierarchical)
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(theme.backgroundTertiary)
            .cornerRadius(DesignTokens.CornerRadius.md)
        }
        .menuStyle(.borderlessButton)
    }

    private var filteredLocalBranches: [Branch] {
        let locals = branches.filter { !$0.isRemote }
        if searchText.isEmpty {
            return locals
        }
        return locals.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var filteredRemoteBranches: [Branch] {
        let remotes = branches.filter { $0.isRemote }
        if searchText.isEmpty {
            return remotes
        }
        return remotes.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
}

extension Notification.Name {
    static let showCreateBranchSheet = Notification.Name("showCreateBranchSheet")
}
