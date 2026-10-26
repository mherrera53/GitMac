import SwiftUI
import UniformTypeIdentifiers

// MARK: - Modern Grouped Repository Slider
struct RepositoryTabsView: View {
    @Environment(AppState.self) var appState
    @StateObject private var groupsService = RepoGroupsService.shared
    @State private var cachedGroupedTabs: [TabGroup] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .disabled(!appState.canGoBack)
                .help("Go Back")
                .accessibilityLabel("Go back to previous repository")

                Button(action: { appState.goForward() }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(appState.canGoForward ? AppTheme.textSecondary : AppTheme.textMuted.opacity(0.3))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .disabled(!appState.canGoForward)
                .help("Go Forward")
                .accessibilityLabel("Go forward to next repository")
            }
            .padding(.trailing, 4)

            // Horizontal Slider for Groups
            ScrollViewReader { proxy in
              ScrollView(.horizontal) {
                HStack(spacing: 4) { // Spacing between groups
                    ForEach(cachedGroupedTabs) { group in
                        GroupContainer(group: group, appState: appState)
                    }

                }
                .padding(.horizontal, 4)
            }
            .scrollIndicators(.hidden)
            .frame(maxWidth: .infinity) // Take all available horizontal space
            .onChange(of: appState.activeTabId, initial: true) { _, id in
                guard let id else { return }
                DispatchQueue.main.async {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
            }

            Button {
                NotificationCenter.default.post(name: .openRepository, object: nil)
            } label: {
                Image(systemName: "plus").frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .help("Open Repository")
            .accessibilityLabel("Open repository")

            // Dropdown for recent repos
            TabsOverflowMenu()
        }
        .frame(height: 32) // Slightly taller for dedicated space
        .onAppear { recomputeGroupedTabs() }
        .onChange(of: appState.openTabs.count) { recomputeGroupedTabs() }
        .onChange(of: appState.openTabs.map(\.id)) { recomputeGroupedTabs() }
        .onChange(of: groupsService.groups.map { [$0.id, $0.name, $0.color] + $0.repos }) { recomputeGroupedTabs() }
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
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(groupColor.opacity(0.8))
                        .lineLimit(1)
                        .frame(maxWidth: 90)
                        .help(name)
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
                    .id(tab.id)
                    // Drag & Drop support
                    .onDrag {
                        NSItemProvider(object: tab.id.uuidString as NSString)
                    }
                    .onDrop(of: [.text], delegate: TabDropDelegate(item: tab, appState: appState))
                }
            }
            .padding(.horizontal, 2)
        }
        .frame(height: 28)
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
    @ObservedObject var tab: RepositoryTab
    let isActive: Bool
    let groupColor: Color?
    let onSelect: () -> Void
    let onClose: () -> Void
    
    @State private var isHovering = false

    private var tabBackground: Color {
        if isActive {
            return tab.repoColor?.opacity(0.15) ?? AppTheme.backgroundTertiary
        }
        if isHovering {
            return tab.repoColor?.opacity(0.08) ?? AppTheme.backgroundTertiary.opacity(0.5)
        }
        return .clear
    }

    var body: some View {
        HStack(spacing: 0) {
          Button(action: onSelect) {
            HStack(spacing: 5) {
                if let color = tab.repoColor {
                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                }

                Text(tab.repository.name)
                    .font(.system(size: 11, weight: isActive ? .medium : .regular))
                    .foregroundStyle(isActive ? AppTheme.textPrimary : AppTheme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(minWidth: 60, maxWidth: 160, alignment: .leading)
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .help(tab.repository.path)
          .accessibilityLabel("Repository \(tab.repository.name)")
          .accessibilityAddTraits(isActive ? [.isSelected] : [])

          Button(action: onClose) {
              Image(systemName: "xmark")
                  .font(.system(size: 9, weight: .semibold))
                  .frame(width: 24, height: 28)
                  .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .foregroundStyle(AppTheme.textSecondary)
          .opacity(isActive || isHovering ? 1 : 0.55)
          .help("Close \(tab.repository.name)")
          .accessibilityLabel("Close repository \(tab.repository.name)")
        }
        .background(RoundedRectangle(cornerRadius: 5).fill(tabBackground))
        .overlay(alignment: .bottom) {
            if isActive { Capsule().fill(groupColor ?? AppTheme.accent).frame(height: 2).padding(.horizontal, 6) }
        }
        .accessibilityElement(children: .contain)
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
    @Environment(AppState.self) private var appState
    @StateObject private var recentManager = RecentRepositoriesManager.shared

    var body: some View {
        Menu {
            Section("Open Repositories") {
                ForEach(appState.openTabs) { tab in
                    Button { appState.selectTab(tab.id) } label: {
                        if appState.activeTabId == tab.id { Label(tab.repository.name, systemImage: "checkmark") }
                        else { Text(tab.repository.name) }
                    }
                }
            }
            if !recentManager.recentRepos.isEmpty {
                Section("Recent") {
                    ForEach(recentManager.recentRepos.prefix(5)) { repo in
                        Button(repo.name) {
                            Task {
                                await appState.openRepository(at: repo.path)
                                if appState.currentRepository?.path == repo.path {
                                    recentManager.addRecent(path: repo.path, name: repo.name)
                                }
                            }
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
                .frame(width: 28, height: 28)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .help("Open and recent repositories")
        .accessibilityLabel("Open and recent repositories")
    }
}
