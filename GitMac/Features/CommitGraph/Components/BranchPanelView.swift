import SwiftUI

struct BranchPanelView: View {
    @Binding var branches: [Branch]
    let currentBranch: Branch?
    let onSelectBranch: (Branch) -> Void
    let onCheckout: (Branch) -> Void

    @State private var searchText = ""
    @State private var expandedSections: Set<String> = ["local", "remote"]
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        return VStack(spacing: 0) {
            // Header
            HStack {
                Text("BRANCHES")
                    .font(DesignTokens.Typography.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.text)

                Spacer()

                Button(action: {
                    NotificationCenter.default.post(name: .showCreateBranchSheet, object: nil)
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(theme.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Create branch")
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(theme.backgroundSecondary)

            Divider()

            // Search
            DSSearchField(
                placeholder: "Filter branches...",
                text: $searchText
            )
            .padding(DesignTokens.Spacing.sm)

            // Branch tree
            ScrollView {
                VStack(spacing: 0) {
                    // Local branches
                    BranchSection(
                        title: "Local",
                        icon: "laptopcomputer",
                        count: localBranches.count,
                        isExpanded: expandedSections.contains("local"),
                        onToggle: { toggleSection("local") }
                    )

                    if expandedSections.contains("local") {
                        ForEach(filteredLocalBranches) { branch in
                            BranchRow(
                                branch: branch,
                                isCurrent: branch.isCurrent,
                                isSelected: false,
                                onSelect: { onSelectBranch(branch) },
                                onCheckout: { onCheckout(branch) }
                            )
                        }
                    }

                    // Remote branches
                    BranchSection(
                        title: "Remote",
                        icon: "cloud",
                        count: remoteBranches.count,
                        isExpanded: expandedSections.contains("remote"),
                        onToggle: { toggleSection("remote") }
                    )

                    if expandedSections.contains("remote") {
                        ForEach(filteredRemoteBranches) { branch in
                            BranchRow(
                                branch: branch,
                                isCurrent: false,
                                isSelected: false,
                                onSelect: { onSelectBranch(branch) },
                                onCheckout: { onCheckout(branch) }
                            )
                        }
                    }
                }
            }
        }
        .frame(width: 260)
        .background(theme.background)
    }

    private var localBranches: [Branch] {
        branches.filter { !$0.isRemote }
    }

    private var remoteBranches: [Branch] {
        branches.filter { $0.isRemote }
    }

    private var filteredLocalBranches: [Branch] {
        if searchText.isEmpty {
            return localBranches.sorted { $0.isCurrent && !$1.isCurrent }
        }
        return localBranches.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var filteredRemoteBranches: [Branch] {
        if searchText.isEmpty {
            return remoteBranches
        }
        return remoteBranches.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func toggleSection(_ section: String) {
        if expandedSections.contains(section) {
            expandedSections.remove(section)
        } else {
            expandedSections.insert(section)
        }
    }
}

struct BranchSection: View {
    let title: String
    let icon: String
    let count: Int
    let isExpanded: Bool
    let onToggle: () -> Void

    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        return Button(action: onToggle) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(theme.textMuted)
                    .frame(width: 12)

                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(theme.textMuted)

                Text(title)
                    .font(DesignTokens.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(theme.text)

                Spacer()

                Text("\(count)")
                    .font(DesignTokens.Typography.caption2)
                    .foregroundColor(theme.textMuted)
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct BranchRow: View {
    let branch: Branch
    let isCurrent: Bool
    let isSelected: Bool
    let onSelect: () -> Void
    let onCheckout: () -> Void

    @State private var isHovered = false
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        return HStack(spacing: DesignTokens.Spacing.xs) {
            // Current indicator
            if isCurrent {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.success)
            } else {
                Circle()
                    .fill(Color.branchColor(0))
                    .frame(width: 8, height: 8)
                    .opacity(isHovered ? 1.0 : 0.5)
            }

            // Branch name
            Text(branch.displayName)
                .font(DesignTokens.Typography.caption)
                .foregroundColor(isCurrent ? AppTheme.success : theme.text)
                .lineLimit(1)

            Spacer()

            // Ahead/Behind indicators
            if branch.ahead > 0 || branch.behind > 0 {
                HStack(spacing: DesignTokens.Spacing.xxs) {
                    if branch.ahead > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 8))
                            Text("\(branch.ahead)")
                                .font(DesignTokens.Typography.caption2)
                        }
                        .foregroundColor(AppTheme.success)
                    }

                    if branch.behind > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 8))
                            Text("\(branch.behind)")
                                .font(DesignTokens.Typography.caption2)
                        }
                        .foregroundColor(AppTheme.warning)
                    }
                }
            }
        }
        .padding(.leading, DesignTokens.Spacing.lg)
        .padding(.trailing, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(isSelected ? theme.selection : (isHovered ? theme.hover : Color.clear))
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onSelect()
        }
        .contextMenu {
            Button {
                onCheckout()
            } label: {
                Label("Checkout", systemImage: "arrow.uturn.backward")
            }

            if !isCurrent {
                Divider()

                Button(role: .destructive) {
                    // Delete branch action
                } label: {
                    Label("Delete Branch...", systemImage: "trash")
                }
            }
        }
    }
}
