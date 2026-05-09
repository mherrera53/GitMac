import SwiftUI
import UniformTypeIdentifiers

// MARK: - Modern Grouped Repository Slider
struct RepositoryTabsView: View {
    @Environment(AppState.self) var appState
    @StateObject private var groupsService = RepoGroupsService.shared
    @State private var cachedGroupedTabs: [TabGroup] = []

    // Group model to organize tabs
    struct TabGroup: Identifiable {
        let id: String // Use name or color hex as ID
        let name: String?
        let color: String?
        var tabs: [RepositoryTab]
    }

    private func recomputeGroupedTabs() {
        var groups: [TabGroup] = []
        var currentTabs: [RepositoryTab] = []
        var currentGroupId: String? = nil
        var currentGroupName: String? = nil
        var currentGroupColor: String? = nil

        for tab in appState.openTabs {
            let tabGroups = groupsService.getGroupsForRepo(tab.repository.path)
            let firstGroup = tabGroups.first
            let groupId = firstGroup?.id ?? "ungrouped"

            if currentGroupId != groupId {
                if !currentTabs.isEmpty, let firstTab = currentTabs.first {
                    let stableId = "\(currentGroupId ?? "ungrouped")-\(firstTab.id.uuidString)"
                    groups.append(TabGroup(id: stableId, name: currentGroupName, color: currentGroupColor, tabs: currentTabs))
                }

                currentGroupId = groupId
                currentGroupName = firstGroup?.name
                currentGroupColor = firstGroup?.color
                currentTabs = [tab]
            } else {
                currentTabs.append(tab)
            }
        }

        if !currentTabs.isEmpty, let firstTab = currentTabs.first {
            let stableId = "\(currentGroupId ?? "ungrouped")-\(firstTab.id.uuidString)"
            groups.append(TabGroup(id: stableId, name: currentGroupName, color: currentGroupColor, tabs: currentTabs))
        }

        cachedGroupedTabs = groups
    }

    var body: some View {
        HStack(spacing: 0) {
            // Navigation Buttons (Integrated Arrows)
            HStack(spacing: 0) {
                Button(action: { appState.goBack() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(appState.canGoBack ? AppTheme.textSecondary : AppTheme.textMuted.opacity(0.3))
                        .frame(width: 18, height: 28)
                }
                .buttonStyle(.plain)
                .disabled(!appState.canGoBack)
                .help("Go Back")
                .accessibilityLabel("Go back to previous repository")

                Button(action: { appState.goForward() }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(appState.canGoForward ? AppTheme.textSecondary : AppTheme.textMuted.opacity(0.3))
                        .frame(width: 18, height: 28)
                }
                .buttonStyle(.plain)
                .disabled(!appState.canGoForward)
                .help("Go Forward")
                .accessibilityLabel("Go forward to next repository")
            }
            .padding(.trailing, 4)

            // Horizontal Slider for Groups
            ScrollView(.horizontal) {
                HStack(spacing: 4) { // Spacing between groups
                    ForEach(cachedGroupedTabs) { group in
                        GroupContainer(group: group, appState: appState)
                    }

                    // Add Button
                    Button(action: {
                        NotificationCenter.default.post(name: .openRepository, object: nil)
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(AppTheme.textMuted)
                            .frame(width: 28, height: 28)
                            .background(AppTheme.backgroundSecondary.opacity(0.3))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 4)
                    .help("Open Repository")
                }
                .padding(.horizontal, 4)
            }
            .scrollIndicators(.hidden)
            .frame(maxWidth: .infinity) // Take all available horizontal space

            // Dropdown for recent repos
            TabsOverflowMenu()
        }
        .frame(height: 32) // Slightly taller for dedicated space
        .onAppear { recomputeGroupedTabs() }
        .onChange(of: appState.openTabs.count) { recomputeGroupedTabs() }
        .onChange(of: appState.openTabs.map(\.id)) { recomputeGroupedTabs() }
        .onChange(of: groupsService.groups.count) { recomputeGroupedTabs() }
    }
}

// MARK: - Components

private struct GroupContainer: View {
    let group: RepositoryTabsView.TabGroup
    var appState: AppState
    
    var groupColor: Color {
        if let hex = group.color {
            return SwiftUI.Color(hex: hex)
        }
        return AppTheme.border // Fallback for ungrouped
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Group Header Label (if grouped)
            if let name = group.name {
                HStack(spacing: 2) {
                    Circle()
                        .fill(groupColor)
                        .frame(width: 3, height: 3)
                    
                    Text(name)
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(groupColor.opacity(0.8))
                }
                .padding(.leading, 4)
                .padding(.trailing, 1)
            }
            
            // Tabs in this group
            HStack(spacing: 1) {
                ForEach(group.tabs) { tab in
                    CompactTabPill(
                        tab: tab,
                        isActive: appState.activeTabId == tab.id,
                        groupColor: group.name != nil ? groupColor : nil,
                        onSelect: { appState.selectTab(tab.id) },
                        onClose: { appState.closeTab(tab.id) }
                    )
                    // Drag & Drop support
                    .onDrag {
                        NSItemProvider(object: tab.id.uuidString as NSString)
                    }
                    .onDrop(of: [.text], delegate: TabDropDelegate(item: tab, appState: appState))
                }
            }
            .padding(.horizontal, 2)
        }
        .frame(height: 24)
        // Visual container style for valid groups
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(group.name != nil ? groupColor.opacity(0.08) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(group.name != nil ? groupColor.opacity(0.2) : Color.clear, lineWidth: 1)
        )
    }
}

private struct CompactTabPill: View {
    let tab: RepositoryTab
    let isActive: Bool
    let groupColor: Color?
    let onSelect: () -> Void
    let onClose: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 4) {
                // Repo name
                Text(tab.repository.name)
                    .font(.system(size: 11, weight: isActive ? .medium : .regular))
                    .foregroundStyle(isActive ? AppTheme.textPrimary : AppTheme.textSecondary)
                    .lineLimit(1)
                    .fixedSize() // Allow text to determine width, but compress if needed in future
                
                // Close button (visible on hover or active)
                if isActive || isHovering {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(isActive ? AppTheme.textPrimary.opacity(0.7) : AppTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 2)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isActive ? AppTheme.backgroundTertiary : (isHovering ? AppTheme.backgroundTertiary.opacity(0.5) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Repository \(tab.repository.name)\(isActive ? ", active" : "")")
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
        .onHover { isHovering = $0 }
    }
}

// MARK: - Drop Delegate (Reused)
struct TabDropDelegate: DropDelegate {
    let item: RepositoryTab
    let appState: AppState

    func dropEntered(info: DropInfo) {
        // Optional reordering preview
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let itemProvider = info.itemProviders(for: [.text]).first else { return false }
        let targetId = item.id
        itemProvider.loadObject(ofClass: NSString.self) { string, error in
            guard let uuidString = string as? String,
                  let sourceId = UUID(uuidString: uuidString),
                  sourceId != targetId else { return }
            
            DispatchQueue.main.async {
                withAnimation {
                    appState.reorderTab(from: sourceId, to: item.id)
                }
            }
        }
        return true
    }
}

// MARK: - Tabs Overflow Menu

private struct TabsOverflowMenu: View {
    @StateObject private var recentManager = RecentRepositoriesManager.shared

    var body: some View {
        Menu {
            if !recentManager.recentRepos.isEmpty {
                Section("Recent") {
                    ForEach(recentManager.recentRepos.prefix(5)) { repo in
                        Button(repo.name) {
                            NotificationCenter.default.post(name: .openRepository, object: repo.path)
                        }
                    }
                }
                Divider()
            }

            Button {
                NotificationCenter.default.post(name: .openRepository, object: nil)
            } label: {
                Label("Open Repository...", systemImage: "folder.badge.plus")
            }
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(AppTheme.textMuted)
                .frame(width: 20, height: 28)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .help("More tabs")
    }
}
