import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var recentReposManager: RecentRepositoriesManager
    @StateObject private var themeManager = ThemeManager.shared
    @ObservedObject var bottomPanelManager: BottomPanelManager
    @StateObject private var gitOperationHandler = GitOperationHandler()
    @State private var showCloneSheet = false
    @State private var showOpenPanel = false
    @State private var showNewBranchSheet = false
    @State private var showMergeSheet = false
    @State private var leftPanelWidth: CGFloat = 260
    @State private var rightPanelWidth: CGFloat = 380
    @State private var showRevertSheet = false
    @State private var revertCommits: [Commit] = []
    @State private var showDetachedHeadAlert = false
    @State private var themeRefreshTrigger = UUID()

    init() {
        _bottomPanelManager = ObservedObject(wrappedValue: BottomPanelManager.shared)
    }

    var body: some View {
        attachGitListeners(to: mainLayout)
            .background(AppTheme.background)
            .withToastNotifications()
            .sheet(isPresented: $showCloneSheet) {
                CloneRepositorySheet()
            }
            .fileImporter(
                isPresented: $showOpenPanel,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        Task {
                            await appState.openRepository(at: url.path)
                            if appState.currentRepository != nil {
                                recentReposManager.addRecent(path: url.path, name: url.lastPathComponent)
                            }
                        }
                    }
                case .failure(let error):
                    appState.errorMessage = error.localizedDescription
                }
            }
            .sheet(isPresented: $showNewBranchSheet) {
                CreateBranchSheet(isPresented: $showNewBranchSheet)
                    .environmentObject(appState)
            }
            .sheet(isPresented: $showRevertSheet) {
                RevertView(targetCommits: revertCommits)
                    .environmentObject(appState)
            }
            .sheet(isPresented: $showMergeSheet) {
                MergeBranchSheet(isPresented: $showMergeSheet)
                    .environmentObject(appState)
            }
            .overlay {
                if gitOperationHandler.isOperationInProgress {
                    OperationProgressOverlay(message: gitOperationHandler.operationMessage)
                }
            }
            .alert("Error", isPresented: .constant(appState.errorMessage != nil)) {
                Button("OK") {
                    appState.errorMessage = nil
                }
            } message: {
                Text(appState.errorMessage ?? "")
            }
            .alert("Pull Failed: Detached HEAD", isPresented: $showDetachedHeadAlert) {
                Button("Create Branch") {
                    showNewBranchSheet = true
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("You are not currently on a branch. Please create a new branch to save your work before pulling.")
            }
            .onAppear {
                gitOperationHandler.appState = appState
            }
            .onChange(of: themeManager.currentTheme) { _, _ in
                themeRefreshTrigger = UUID()
            }
            .onChange(of: themeManager.customColors) { _, _ in
                themeRefreshTrigger = UUID()
            }
    }

    @ViewBuilder
    private var mainLayout: some View {
        // Main content
        if appState.currentRepository != nil {
            MainLayout(
                leftPanelWidth: $leftPanelWidth,
                rightPanelWidth: $rightPanelWidth,
                themeRefreshTrigger: themeRefreshTrigger,
                bottomPanelManager: bottomPanelManager
            )
        } else {
            WelcomeView(
                onOpen: { showOpenPanel = true },
                onClone: { showCloneSheet = true }
            )
        }
    }
    
    private func attachGitListeners<Content: View>(to content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .openRepository)) { _ in
                showOpenPanel = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .cloneRepository)) { _ in
                showCloneSheet = true
            }
            // Git operation notifications
            .onReceive(NotificationCenter.default.publisher(for: .fetch)) { _ in
                Task { await gitOperationHandler.handleFetch() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .pull)) { _ in
                Task { await gitOperationHandler.handlePull() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .push)) { _ in
                Task { await gitOperationHandler.handlePush() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .stash)) { _ in
                Task { await gitOperationHandler.handleStash() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .popStash)) { _ in
                Task { await gitOperationHandler.handlePopStash() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .newBranch)) { _ in
                showNewBranchSheet = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .merge)) { _ in
                showMergeSheet = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .revertCommit)) { notification in
                if let commits = notification.object as? [Commit] {
                    revertCommits = commits
                    showRevertSheet = true
                }
            }
            // File ignore/tracking handlers
            .onReceive(NotificationCenter.default.publisher(for: .ignoreFile)) { notification in
                handleIgnoreFile(notification)
            }
            .onReceive(NotificationCenter.default.publisher(for: .assumeUnchanged)) { notification in
                handleAssumeUnchanged(notification)
            }
            .onReceive(NotificationCenter.default.publisher(for: .stopTrackingFile)) { notification in
                handleStopTrackingFile(notification)
            }
    }

    // MARK: - File Ignore/Tracking Notification Handlers

    private func handleIgnoreFile(_ notification: Notification) {
        guard let repoPath = appState.currentRepository?.path else { return }

        var ignoreType: IgnoreType = .file
        var filePath = ""

        if let info = notification.object as? [String: String] {
            let type = info["type"] ?? "file"
            filePath = info["path"] ?? ""

            switch type {
            case "extension":
                let ext = info["extension"] ?? URL(fileURLWithPath: filePath).pathExtension
                ignoreType = .fileExtension(ext)
            case "directory":
                ignoreType = .directory
            default:
                ignoreType = .file
            }
        } else if let path = notification.object as? String {
            filePath = path
            ignoreType = .file
        }

        Task {
            await gitOperationHandler.handleIgnoreFile(
                filePath: filePath,
                type: ignoreType,
                repoPath: repoPath
            )
        }
    }

    private func handleAssumeUnchanged(_ notification: Notification) {
        guard let repoPath = appState.currentRepository?.path,
              let filePath = notification.object as? String else { return }

        Task {
            await gitOperationHandler.handleAssumeUnchanged(
                filePath: filePath,
                repoPath: repoPath
            )
        }
    }

    private func handleStopTrackingFile(_ notification: Notification) {
        guard let repoPath = appState.currentRepository?.path,
              let filePath = notification.object as? String else { return }

        Task {
            await gitOperationHandler.handleStopTrackingFile(
                filePath: filePath,
                repoPath: repoPath
            )
        }
    }
}

// MARK: - Modern 3-Panel Layout
struct MainLayout: View {
    @EnvironmentObject var appState: AppState
    @Binding var leftPanelWidth: CGFloat
    @Binding var rightPanelWidth: CGFloat
    let themeRefreshTrigger: UUID
    @ObservedObject var bottomPanelManager: BottomPanelManager
    @State private var selectedFileDiff: FileDiff?
    @State private var isLoadingDiff = false
    @State private var searchText = ""

    // Helper function for group colors
    private func getGroupColor(for repoPath: String) -> Color? {
        let groups = RepoGroupsService.shared.getGroupsForRepo(repoPath)
        return groups.first.map { Color(hex: $0.color) }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left Panel - Branches/Remotes/Tags
            LeftSidebarPanel()
                .frame(width: leftPanelWidth)
                .background(AppTheme.backgroundSecondary)

            // Resizer
            UniversalResizer(
                dimension: $leftPanelWidth,
                minDimension: 240,
                maxDimension: 400,
                orientation: .horizontal
            )

            // Center Area - Graph/Diff + Bottom Panel
            VStack(spacing: 0) {
                // Center Panel - Graph OR Diff
                CenterPanel(selectedFileDiff: $selectedFileDiff, isLoadingDiff: $isLoadingDiff)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.background)

                // Unified Bottom Panel with Tabs (always visible, collapses to thin bar)
                UnifiedBottomPanel(panelManager: bottomPanelManager)
                    .environmentObject(appState)
            }

            // Resizer
            UniversalResizer(
                dimension: $rightPanelWidth,
                minDimension: 300,
                maxDimension: 500,
                orientation: .horizontal,
                invertDirection: true  // Right panel: drag left to increase width
            )

            // Right Panel - Staging/Commit
            RightStagingPanel(selectedFileDiff: $selectedFileDiff, isLoadingDiff: $isLoadingDiff)
                .frame(width: rightPanelWidth)
                .background(AppTheme.backgroundSecondary)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    XcodeToolbarButton(icon: "arrow.uturn.backward") { }
                        .help("Undo")

                    XcodeToolbarButton(icon: "arrow.uturn.forward") { }
                        .help("Redo")
                }
            }

            // Principal area - Repository selector dropdown
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    if !appState.openTabs.isEmpty {
                        // Repository dropdown (like Xcode schemes)
                        Menu {
                            ForEach(appState.openTabs) { tab in
                                Button {
                                    appState.selectTab(tab.id)
                                } label: {
                                    HStack {
                                        if let color = getGroupColor(for: tab.repository.path) {
                                            Circle()
                                                .fill(color)
                                                .frame(width: 8, height: 8)
                                        }
                                        Text(tab.repository.name)
                                        if appState.activeTabId == tab.id {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }

                            Divider()

                            Button {
                                NotificationCenter.default.post(name: .openRepository, object: nil)
                            } label: {
                                Label("Open Repository...", systemImage: "folder")
                            }

                            Button {
                                NotificationCenter.default.post(name: .cloneRepository, object: nil)
                            } label: {
                                Label("Clone Repository...", systemImage: "arrow.down.circle")
                            }
                        } label: {
                            HStack(spacing: 6) {
                                if let repo = appState.currentRepository {
                                    if let color = getGroupColor(for: repo.path) {
                                        Circle()
                                            .fill(color)
                                            .frame(width: 6, height: 6)
                                    }

                                    Text(repo.name)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(AppTheme.textPrimary)

                                    if let branch = repo.currentBranch {
                                        Text("•")
                                            .foregroundColor(AppTheme.textMuted)
                                        Text(branch.name)
                                            .font(.system(size: 11))
                                            .foregroundColor(AppTheme.textSecondary)
                                    }

                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(AppTheme.backgroundSecondary)
                            .cornerRadius(6)
                        }
                        .menuStyle(.borderlessButton)
                        .help("Switch Repository")

                        // Close current repo button
                        if appState.currentRepository != nil {
                            Button {
                                if let activeId = appState.activeTabId {
                                    appState.closeTab(activeId)
                                }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(AppTheme.textMuted)
                                    .frame(width: 22, height: 22)
                            }
                            .buttonStyle(.plain)
                            .help("Close Repository")
                        }
                    } else {
                        Button {
                            NotificationCenter.default.post(name: .openRepository, object: nil)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "folder")
                                    .font(.system(size: 11))
                                Text("Open Repository")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(AppTheme.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(AppTheme.backgroundSecondary)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Plugin buttons
            ToolbarItemGroup(placement: .automatic) {
                XcodeToolbarButton(icon: "terminal.fill") {
                    bottomPanelManager.openTab(type: .terminal)
                }
                .help("Terminal")

                XcodeToolbarButton(icon: "tag.fill", color: AppTheme.success) {
                    bottomPanelManager.openTab(type: .taiga)
                }
                .help("Taiga")

                XcodeToolbarButton(icon: "checklist", color: AppTheme.warning) {
                    bottomPanelManager.openTab(type: .planner)
                }
                .help("Planner")

                XcodeToolbarButton(icon: "lineweight", color: AppTheme.accent) {
                    bottomPanelManager.openTab(type: .linear)
                }
                .help("Linear")

                XcodeToolbarButton(icon: "square.stack.3d.up", color: AppTheme.accent) {
                    bottomPanelManager.openTab(type: .jira)
                }
                .help("Jira")

                XcodeToolbarButton(icon: "doc.text.fill") {
                    bottomPanelManager.openTab(type: .notion)
                }
                .help("Notion")

                XcodeToolbarButton(icon: "person.3", color: AppTheme.accent) {
                    bottomPanelManager.openTab(type: .teamActivity)
                }
                .help("Team Activity")
            }
        }
        .toolbarBackground(.clear, for: .windowToolbar)
        .background(VisualEffectBlur.toolbar.ignoresSafeArea(edges: .top))
        .toolbarColorScheme(ThemeManager.shared.currentTheme == .light ? .light : .dark, for: .windowToolbar)
        .id(themeRefreshTrigger)
        .onChange(of: appState.activeTabId) { _, _ in
            // Clear diff when switching repositories
            selectedFileDiff = nil
        }
    }
}

// MARK: - Terminal Panel
struct TerminalPanel: View {
    @Binding var height: CGFloat
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Resizer handle
            UniversalResizer(
                dimension: $height,
                minDimension: 150,
                maxDimension: 500,
                orientation: .vertical
            )

            // Terminal content - Ghostty Native
            #if GHOSTTY_AVAILABLE
            GhosttyNativeView()
                .frame(height: height)
            #else
            TerminalView()
                .frame(height: height)
            #endif
        }
        .background(AppTheme.background)
    }
}

// MARK: - Center Panel (Graph or Diff)
struct CenterPanel: View {
    @EnvironmentObject var appState: AppState
    @Binding var selectedFileDiff: FileDiff?
    @Binding var isLoadingDiff: Bool

    var body: some View {
        VStack(spacing: 0) {
            if isLoadingDiff {
                // Loading indicator
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading preview...")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.background)
            } else if let fileDiff = selectedFileDiff {
                // Diff View with close button
                DiffViewWithClose(fileDiff: fileDiff, repoPath: appState.currentRepository?.path) {
                    selectedFileDiff = nil
                }
            } else {
                // Graph View
                if appState.currentRepository != nil {
                    CommitGraphView()
                } else {
                    DSEmptyState(
                        icon: "folder.badge.questionmark",
                        title: "No Repository",
                        description: "Open a repository to get started"
                    )
                }
            }
        }
    }
}

// MARK: - Diff View with Close
struct DiffViewWithClose: View {
    let fileDiff: FileDiff
    var repoPath: String? = nil
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Close button overlay
            HStack {
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppTheme.textMuted)
                }
                .buttonStyle(.plain)
                .padding(8)
            }
            .background(AppTheme.backgroundSecondary.opacity(0.8))

            // Use standard diff viewer
            DiffView(fileDiff: fileDiff, repoPath: repoPath)
        }
    }
}

// MARK: - EmptyStateView moved to UI/Components/States/EmptyStateView.swift

// MARK: - Left Sidebar Panel (Modern)
struct LeftSidebarPanel: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedNavigator: SidebarNavigator = .branches
    @State private var branchSearchText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Xcode-style horizontal navigator tabs
            XcodeSidebarNavigatorBar(selectedNavigator: $selectedNavigator)

            // Navigator content
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    navigatorContent
                }
                .padding(.top, 8)
            }
        }
    }

    @ViewBuilder
    private var navigatorContent: some View {
        switch selectedNavigator {
        case .repositories:
            RepositoryHierarchicalNavigator()

        case .branches:
            // Branch search bar
            if appState.currentRepository != nil {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textMuted)

                    DSTextField(placeholder: "Search branches...", text: $branchSearchText)
                        .font(.system(size: 11))

                    if !branchSearchText.isEmpty {
                        Button(action: { branchSearchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.textMuted)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppTheme.backgroundSecondary)
                .cornerRadius(6)
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }

            // Local branches
            if let repo = appState.currentRepository {
                let allLocal = repo.branches.filter { !$0.isRemote }
                let localBranches = branchSearchText.isEmpty ? allLocal : allLocal.filter {
                    $0.name.localizedCaseInsensitiveContains(branchSearchText)
                }

                let mainBranch = localBranches.first { $0.name == "master" || $0.name == "main" }
                let currentBranch = localBranches.first { $0.isCurrent && $0.name != "master" && $0.name != "main" }
                let otherBranches = localBranches
                    .filter { !$0.isCurrent && $0.name != "master" && $0.name != "main" }

                if let main = mainBranch {
                    SidebarBranchRow(branch: main)
                }

                if let current = currentBranch {
                    SidebarBranchRow(branch: current)
                }

                ForEach(Array(otherBranches)) { branch in
                    SidebarBranchRow(branch: branch)
                }
            }

        case .remote:
            if let repo = appState.currentRepository {
                let allRemote = repo.remoteBranches
                let filteredRemote = branchSearchText.isEmpty ? allRemote : allRemote.filter {
                    $0.name.localizedCaseInsensitiveContains(branchSearchText)
                }
                let remoteBranches = filteredRemote.sorted { $0.name < $1.name }
                ForEach(remoteBranches) { branch in
                    SidebarBranchRow(branch: branch)
                }
            }

        case .stashes:
            if let repo = appState.currentRepository {
                ForEach(repo.stashes) { stash in
                    StashSidebarRow(stash: stash)
                }
            }

        case .tags:
            if let repo = appState.currentRepository {
                ForEach(repo.tags) { tag in
                    TagSidebarRow(tag: tag)
                }
            }

        case .worktrees:
            WorktreeSidebarSection()

        case .submodules:
            SubmoduleSidebarSection()

        case .hooks:
            GitHooksSidebarSection()

        case .cicd:
            CICDSidebarSection()
        }
    }
}

// MARK: - CI/CD Sidebar Section
struct CICDSidebarSection: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = CICDSidebarViewModel()
    @StateObject private var themeManager = ThemeManager.shared
    @State private var showCICDPanel = false
    @State private var selectedTab: CICDTab = .github

    enum CICDTab: String, CaseIterable {
        case github = "GitHub Actions"
        case aws = "AWS CodeBuild"

        var icon: String {
            switch self {
            case .github: return "bolt.circle.fill"
            case .aws: return "cloud.fill"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // GitHub Actions
            if viewModel.hasGitHub {
                CICDProviderRow(
                    icon: "bolt.circle.fill",
                    name: "GitHub Actions",
                    status: viewModel.githubStatus,
                    statusColor: viewModel.githubStatusColor,
                    count: viewModel.githubRunningCount
                ) {
                    selectedTab = .github
                    showCICDPanel = true
                }
            }

            // AWS CodeBuild
            if viewModel.hasAWS {
                CICDProviderRow(
                    icon: "cloud.fill",
                    name: "AWS CodeBuild",
                    status: viewModel.awsStatus,
                    statusColor: viewModel.awsStatusColor,
                    count: viewModel.awsRunningCount
                ) {
                    selectedTab = .aws
                    showCICDPanel = true
                }
            }

            if !viewModel.hasGitHub && !viewModel.hasAWS {
                HStack {
                    Text("No CI/CD configured")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }
        }
        .task {
            await viewModel.refresh(appState: appState)
        }
        .sheet(isPresented: $showCICDPanel) {
            UnifiedCICDPanel(selectedTab: $selectedTab, hasGitHub: viewModel.hasGitHub, hasAWS: viewModel.hasAWS)
                .environmentObject(appState)
        }
    }
}

// MARK: - Unified CI/CD Panel with Tabs

struct UnifiedCICDPanel: View {
    @Binding var selectedTab: CICDSidebarSection.CICDTab
    let hasGitHub: Bool
    let hasAWS: Bool
    @Environment(\.dismiss) private var dismiss

    private var tabs: [DSTabInfo] {
        var result: [DSTabInfo] = []
        if hasGitHub {
            result.append(DSTabInfo(id: "github", title: "GitHub", icon: "arrow.triangle.branch"))
        }
        if hasAWS {
            result.append(DSTabInfo(id: "aws", title: "AWS", icon: "cloud.fill"))
        }
        return result
    }

    private var selectedTabId: Binding<String> {
        Binding(
            get: { selectedTab == .github ? "github" : "aws" },
            set: { newValue in
                selectedTab = newValue == "github" ? .github : .aws
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header usando Design System
            HStack(spacing: DesignTokens.Spacing.md) {
                DSText(
                    "CI/CD",
                    variant: .headline,
                    color: AppTheme.textPrimary
                )

                Spacer()

                DSIconButton(
                    iconName: "xmark.circle.fill",
                    size: .md
                ) {
                    dismiss()
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.md)
            .background(AppTheme.backgroundSecondary)

            // Tab container con Design System
            DSTabContainer(
                tabs: tabs,
                selectedTab: selectedTabId
            ) { tabId in
                tabContent(for: tabId)
            }
        }
        .frame(width: 900, height: 600)
        .background(AppTheme.background)
    }

    @ViewBuilder
    private func tabContent(for tabId: String) -> some View {
        switch tabId {
        case "github":
            WorkflowsView()
                .background(AppTheme.background)
        case "aws":
            AWSCodeBuildPanel()
        default:
            DSEmptyState(
                icon: "exclamationmark.triangle",
                title: "Unknown Tab",
                description: "Tab not found"
            )
        }
    }
}

struct CICDProviderRow: View {
    let icon: String
    let name: String
    let status: String
    let statusColor: Color
    let count: Int
    let action: () -> Void

    @StateObject private var themeManager = ThemeManager.shared
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.warning)

                Text(name)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()

                if count > 0 {
                    HStack(spacing: 2) {
                        ProgressView()
                            .scaleEffect(0.4)
                        Text("\(count)")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundColor(AppTheme.info)
                }

                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isHovered ? AppTheme.backgroundSecondary : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - CI/CD Sidebar ViewModel
@MainActor
class CICDSidebarViewModel: ObservableObject {
    @Published var hasGitHub = false
    @Published var hasAWS = false
    @Published var githubStatus = "unknown"
    @Published var awsStatus = "unknown"
    @Published var githubRunningCount = 0
    @Published var awsRunningCount = 0

    var githubStatusColor: Color {
        switch githubStatus {
        case "success": return AppTheme.success
        case "failure": return AppTheme.error
        case "running": return AppTheme.accent
        default: return AppTheme.textSecondary
        }
    }

    var awsStatusColor: Color {
        switch awsStatus {
        case "success": return AppTheme.success
        case "failure": return AppTheme.error
        case "running": return AppTheme.accent
        default: return AppTheme.textSecondary
        }
    }

    func refresh(appState: AppState) async {
        // Check GitHub
        let githubToken = (try? await KeychainManager.shared.getGitHubToken()) ?? ""
        hasGitHub = !githubToken.isEmpty

        // Check AWS (look for AWS credentials)
        let awsConfigured = FileManager.default.fileExists(atPath: NSHomeDirectory() + "/.aws/credentials")
        hasAWS = awsConfigured

        if hasGitHub {
            await fetchGitHubStatus(appState: appState, token: githubToken)
        }
    }

    private func fetchGitHubStatus(appState: AppState, token: String) async {
        guard let remote = appState.currentRepository?.remotes.first,
              let url = URL(string: remote.fetchURL) else { return }

        let pathComponents = url.path
            .replacingOccurrences(of: ".git", with: "")
            .split(separator: "/")
            .map(String.init)

        guard pathComponents.count >= 2 else { return }

        let owner = pathComponents[pathComponents.count - 2]
        let repo = pathComponents[pathComponents.count - 1]

        let urlString = "https://api.github.com/repos/\(owner)/\(repo)/actions/runs?per_page=10"
        guard let apiURL = URL(string: urlString) else { return }

        var request = URLRequest(url: apiURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            struct Response: Codable {
                let workflowRuns: [Run]
                enum CodingKeys: String, CodingKey { case workflowRuns = "workflow_runs" }
                struct Run: Codable {
                    let status: String
                    let conclusion: String?
                }
            }

            let response = try decoder.decode(Response.self, from: data)

            // Count running
            githubRunningCount = response.workflowRuns.filter { $0.status == "in_progress" || $0.status == "queued" }.count

            // Get latest status
            if let latest = response.workflowRuns.first {
                if latest.status == "in_progress" || latest.status == "queued" {
                    githubStatus = "running"
                } else if latest.conclusion == "success" {
                    githubStatus = "success"
                } else if latest.conclusion == "failure" {
                    githubStatus = "failure"
                }
            }
        } catch {
            // Ignore errors silently
        }
    }
}

// MARK: - Workflows Panel (Sheet)
struct WorkflowsPanel: View {
    @StateObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header usando Design System
            HStack(spacing: DesignTokens.Spacing.md) {
                DSText(
                    "GitHub Actions",
                    variant: .headline,
                    color: AppTheme.textPrimary
                )

                Spacer()

                DSButton(variant: .primary, size: .sm) {
                    dismiss()
                } label: {
                    Text("Done")
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.md)
            .background(AppTheme.backgroundSecondary)

            DSDivider()

            WorkflowsView()
        }
        .frame(width: 700, height: 500)
        .background(AppTheme.background)
    }
}

// MARK: - Worktree Sidebar Section
struct WorktreeSidebarSection: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = WorktreeListViewModel()
    @State private var showAddSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.6)
                    Spacer()
                }
                .padding(.vertical, 8)
            } else {
                ForEach(viewModel.worktrees) { worktree in
                    WorktreeSidebarRow(worktree: worktree)
                }

                if viewModel.worktrees.isEmpty {
                    Text("No worktrees")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textMuted)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                }

                // Add worktree button
                Button {
                    showAddSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10))
                        Text("Add Worktree")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(AppTheme.textMuted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .task {
            await viewModel.refresh(at: appState.currentRepository?.path)
        }
        .onChange(of: appState.currentRepository?.path) { _, newPath in
            Task { await viewModel.refresh(at: newPath) }
        }
        .sheet(isPresented: $showAddSheet) {
            AddWorktreeSheet(viewModel: viewModel)
        }
    }
}

// MARK: - Worktree Sidebar Row
struct WorktreeSidebarRow: View {
    let worktree: Worktree
    @EnvironmentObject var appState: AppState
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: worktree.isMain ? "house.fill" : "folder.fill")
                .font(.system(size: 11))
                .foregroundColor(worktree.isMain ? AppTheme.accent : AppTheme.accent)

            Text(worktree.name)
                .font(.system(size: 11))
                .foregroundColor(worktree.isMain ? AppTheme.textPrimary : AppTheme.textSecondary)
                .lineLimit(1)

            if worktree.isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9))
                    .foregroundColor(AppTheme.warning)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(isHovered ? AppTheme.hover : Color.clear)
        .onHover { isHovered = $0 }
        .onTapGesture(count: 2) {
            // Open worktree in new tab
            Task {
                await appState.openRepository(at: worktree.path)
            }
        }
    }
}

// MARK: - Submodule Sidebar Section
struct SubmoduleSidebarSection: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = SubmoduleViewModel()
    @State private var showSubmoduleView = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if viewModel.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Loading...")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textMuted)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            } else if viewModel.submodules.isEmpty {
                Button(action: { showSubmoduleView = true }) {
                    HStack {
                        Image(systemName: "cube.transparent")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.textMuted)
                        Text("No submodules")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textMuted)
                        Spacer()
                        Image(systemName: "plus.circle")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.accent)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            } else {
                ForEach(viewModel.submodules.prefix(3)) { submodule in
                    SubmoduleSidebarRow(submodule: submodule)
                }

                if viewModel.submodules.count > 3 {
                    Button(action: { showSubmoduleView = true }) {
                        HStack {
                            Text("View all \(viewModel.submodules.count) submodules")
                                .font(.system(size: 10))
                                .foregroundColor(AppTheme.accent)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9))
                                .foregroundColor(AppTheme.accent)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .task {
            await loadSubmodules()
        }
        .sheet(isPresented: $showSubmoduleView) {
            SubmoduleView()
                .environmentObject(appState)
                .frame(minWidth: 600, minHeight: 500)
        }
    }

    private func loadSubmodules() async {
        guard let repoPath = appState.currentRepository?.path else { return }
        await viewModel.loadSubmodules(at: repoPath)
    }
}

// MARK: - Submodule Sidebar Row
struct SubmoduleSidebarRow: View {
    let submodule: GitSubmodule
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: submodule.status == .initialized ? "cube.fill" : "cube.transparent")
                .font(.system(size: 11))
                .foregroundColor(submodule.status == .initialized ? AppTheme.accent : AppTheme.textMuted)

            Text(submodule.displayName)
                .font(.system(size: 11))
                .foregroundColor(AppTheme.textSecondary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(isHovered ? AppTheme.hover : Color.clear)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Git Hooks Sidebar Section
struct GitHooksSidebarSection: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = GitHooksViewModel()
    @State private var showHooksView = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if viewModel.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Loading...")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textMuted)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            } else {
                Button(action: { showHooksView = true }) {
                    HStack {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.textSecondary)
                        Text("\(viewModel.enabledCount) of \(viewModel.hooks.count) enabled")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textSecondary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9))
                            .foregroundColor(AppTheme.accent)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .task {
            await loadHooks()
        }
        .sheet(isPresented: $showHooksView) {
            GitHooksView()
                .environmentObject(appState)
                .frame(minWidth: 700, minHeight: 600)
        }
    }

    private func loadHooks() async {
        guard let repoPath = appState.currentRepository?.path else { return }
        await viewModel.loadHooks(at: repoPath)
    }
}

// MARK: - Recent Repositories List
struct RecentRepositoriesList: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var recentReposManager: RecentRepositoriesManager
    @ObservedObject private var groupsService = RepoGroupsService.shared

    @State private var expandedGroups: Set<String> = ["favorites", "recent"]
    @State private var showCloneSheet = false
    @State private var showInitSheet = false
    @State private var showGroupManagement = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // FAVORITES Section
            if !groupsService.favorites.isEmpty {
                MiniSidebarSection(
                    title: "FAVORITES",
                    icon: "star.fill",
                    iconColor: .yellow,
                    isExpanded: expandedGroups.contains("favorites")
                ) {
                    expandedGroups.toggle("favorites")
                } content: {
                    ForEach(Array(groupsService.favorites), id: \.self) { repoPath in
                        if let repo = recentReposManager.recentRepos.first(where: { $0.path == repoPath }) {
                            SidebarRepoRow(
                                repoPath: repoPath,
                                repoName: repo.name,
                                isActive: appState.currentRepository?.path == repoPath,
                                isFavorite: true
                            )
                        } else {
                            SidebarRepoRow(
                                repoPath: repoPath,
                                repoName: URL(fileURLWithPath: repoPath).lastPathComponent,
                                isActive: appState.currentRepository?.path == repoPath,
                                isFavorite: true
                            )
                        }
                    }
                }
            }

            // GROUPS Sections
            ForEach(groupsService.groups.sorted(by: { $0.sortOrder < $1.sortOrder })) { group in
                if !group.repos.isEmpty {
                    MiniSidebarSection(
                        title: group.name.uppercased(),
                        icon: "folder.fill",
                        iconColor: Color(hex: group.color),
                        isExpanded: expandedGroups.contains(group.id)
                    ) {
                        expandedGroups.toggle(group.id)
                    } content: {
                        ForEach(group.repos, id: \.self) { repoPath in
                            if let repo = recentReposManager.recentRepos.first(where: { $0.path == repoPath }) {
                                SidebarRepoRow(
                                    repoPath: repoPath,
                                    repoName: repo.name,
                                    isActive: appState.currentRepository?.path == repoPath,
                                    isFavorite: groupsService.isFavorite(repoPath),
                                    groupBadge: GroupBadge(group: group)
                                )
                            } else {
                                SidebarRepoRow(
                                    repoPath: repoPath,
                                    repoName: URL(fileURLWithPath: repoPath).lastPathComponent,
                                    isActive: appState.currentRepository?.path == repoPath,
                                    isFavorite: groupsService.isFavorite(repoPath),
                                    groupBadge: GroupBadge(group: group)
                                )
                            }
                        }
                    }
                }
            }

            // RECENT Section
            if !recentReposManager.recentRepos.isEmpty {
                MiniSidebarSection(
                    title: "RECENT",
                    icon: "clock.fill",
                    iconColor: .secondary,
                    isExpanded: expandedGroups.contains("recent")
                ) {
                    expandedGroups.toggle("recent")
                } content: {
                    ForEach(recentReposManager.recentRepos.filter { repo in
                        // Only show repos not in favorites or groups
                        !groupsService.favorites.contains(repo.path) &&
                        groupsService.getGroupsForRepo(repo.path).isEmpty
                    }) { repo in
                        SidebarRepoRow(
                            repoPath: repo.path,
                            repoName: repo.name,
                            isActive: appState.currentRepository?.path == repo.path,
                            isFavorite: false
                        )
                    }
                }
            }

            // Empty State
            if recentReposManager.recentRepos.isEmpty && groupsService.favorites.isEmpty && groupsService.groups.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 24))
                        .foregroundColor(AppTheme.textMuted)
                    Text("No repositories yet")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }

            Divider()
                .padding(.vertical, 4)

            // Action Buttons
            VStack(spacing: 4) {
                ActionButton(icon: "folder.badge.plus", title: "Open Repository") {
                    openRepository()
                }

                ActionButton(icon: "arrow.down.circle", title: "Clone Repository") {
                    showCloneSheet = true
                }

                ActionButton(icon: "plus.circle", title: "Init Repository") {
                    showInitSheet = true
                }

                ActionButton(icon: "folder.badge.gearshape", title: "Manage Groups") {
                    showGroupManagement = true
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
        }
        .sheet(isPresented: $showCloneSheet) {
            CloneRepositorySheet()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showInitSheet) {
            InitRepositorySheet()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showGroupManagement) {
            GroupManagementSheet()
                .environmentObject(appState)
        }
    }

    private func openRepository() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a Git repository folder"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            Task { @MainActor in
                await appState.openRepository(at: url.path)
            }
        }
    }
}

// MARK: - Mini Sidebar Section (for repository groups)
struct MiniSidebarSection<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    let isExpanded: Bool
    let onToggle: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: 4) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(AppTheme.textMuted)
                        .frame(width: 10)
                    Image(systemName: icon)
                        .font(.system(size: 9))
                        .foregroundColor(iconColor)
                    Text(title)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppTheme.textMuted)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            if isExpanded {
                content
            }
        }
    }
}

// MARK: - Sidebar Repo Row (unified for all repo types)
struct SidebarRepoRow: View {
    let repoPath: String
    let repoName: String
    let isActive: Bool
    let isFavorite: Bool
    var groupBadge: GroupBadge? = nil

    @EnvironmentObject var appState: AppState
    @ObservedObject private var groupsService = RepoGroupsService.shared
    @State private var isHovered = false
    @State private var showGroupPicker = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "folder.fill")
                .font(.system(size: 10))
                .foregroundColor(isActive ? AppTheme.accent : AppTheme.info)

            Text(repoName)
                .font(.system(size: 10))
                .foregroundColor(isActive ? AppTheme.accent : AppTheme.textSecondary)
                .lineLimit(1)

            if let badge = groupBadge {
                badge
            }

            Spacer()

            if isHovered {
                Button {
                    groupsService.toggleFavorite(repoPath)
                } label: {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.system(size: 9))
                        .foregroundColor(isFavorite ? .yellow : AppTheme.textMuted)
                }
                .buttonStyle(.plain)
            }

            if isActive {
                Circle()
                    .fill(AppTheme.success)
                    .frame(width: 5, height: 5)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(isHovered ? AppTheme.hover : (isActive ? AppTheme.hover.opacity(0.5) : Color.clear))
        .cornerRadius(DesignTokens.CornerRadius.sm)
        .onHover { isHovered = $0 }
        .onTapGesture {
            Task {
                await appState.openRepository(at: repoPath)
            }
        }
        .contextMenu {
            Button("Toggle Favorite") {
                groupsService.toggleFavorite(repoPath)
            }

            Menu("Add to Group") {
                ForEach(groupsService.groups) { group in
                    Button(group.name) {
                        groupsService.addRepoToGroup(repoPath, groupId: group.id)
                    }
                }

                Divider()

                Button("Create New Group...") {
                    showGroupPicker = true
                }
            }

            if !groupsService.getGroupsForRepo(repoPath).isEmpty {
                Menu("Remove from Group") {
                    ForEach(groupsService.getGroupsForRepo(repoPath)) { group in
                        Button(group.name) {
                            groupsService.removeRepoFromGroup(repoPath, groupId: group.id)
                        }
                    }
                }
            }

            Divider()

            Button("Open in Finder") {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: repoPath)
            }

            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(repoPath, forType: .string)
            }

            Divider()

            Button("Remove from List", role: .destructive) {
                RecentRepositoriesManager.shared.removeRecent(path: repoPath)
            }
        }
    }
}

// MARK: - Action Button
struct ActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(.system(size: 10))
                Spacer()
            }
            .foregroundColor(isHovered ? AppTheme.textPrimary : AppTheme.textMuted)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(isHovered ? AppTheme.hover : Color.clear)
            .cornerRadius(DesignTokens.CornerRadius.sm)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct SidebarRecentRepoRow: View {
    let repo: RecentRepository
    let isActive: Bool
    @EnvironmentObject var appState: AppState
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.fill.badge.gearshape")
                .font(.system(size: 11))
                .foregroundColor(isActive ? AppTheme.accent : AppTheme.info)

            Text(repo.name)
                .font(.system(size: 11))
                .foregroundColor(isActive ? AppTheme.accent : AppTheme.textSecondary)
                .lineLimit(1)

            Spacer()

            if isActive {
                Circle()
                    .fill(AppTheme.success)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(isHovered ? AppTheme.hover : (isActive ? AppTheme.hover.opacity(0.5) : Color.clear))
        .onHover { isHovered = $0 }
        .onTapGesture {
            Task {
                await appState.openRepository(at: repo.path)
            }
        }
        .contextMenu {
            Button("Open in Finder") {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: repo.path)
            }
            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(repo.path, forType: .string)
            }
            Divider()
            Button("Remove from List", role: .destructive) {
                RecentRepositoriesManager.shared.removeRecent(path: repo.path)
            }
        }
    }
}

// MARK: - Sidebar Section
struct SidebarSection<Content: View>: View {
    let title: String
    let isExpanded: Bool
    let onToggle: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(AppTheme.textMuted)
                        .frame(width: 12)
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppTheme.textMuted)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            if isExpanded {
                content
                    .padding(.leading, 8)
            }
        }
    }
}

// MARK: - Sidebar Branch Row
struct SidebarBranchRow: View {
    let branch: Branch
    @EnvironmentObject var appState: AppState
    @State private var isHovered = false
    @State private var showPRSheet = false
    @State private var branchPRs: [GitHubPullRequest] = []
    @State private var isLoadingPRs = false
    @State private var showUncommittedAlert = false
    @State private var showForceCheckoutAlert = false

    private let githubService = GitHubService()

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(branch.isCurrent ? AppTheme.success : AppTheme.textMuted)
                .frame(width: 8, height: 8)

            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 12))
                .foregroundColor(branch.isCurrent ? AppTheme.success : AppTheme.textSecondary)

            Text(branch.name)
                .font(.system(size: 12))
                .foregroundColor(branch.isCurrent ? AppTheme.textPrimary : AppTheme.textSecondary)
                .lineLimit(1)

            Spacer()

            if branch.isCurrent {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(AppTheme.success)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(isHovered ? AppTheme.hover : Color.clear)
        .onHover { isHovered = $0 }
        .onTapGesture {
            appState.selectedBranch = branch
        }
        .contextMenu {
            Button {
                Task {
                    await performCheckout()
                }
            } label: {
                Label("Checkout", systemImage: "arrow.right.circle")
            }
            .disabled(branch.isCurrent)

            Divider()

            // Existing PRs for this branch
            if !branchPRs.isEmpty {
                ForEach(branchPRs) { pr in
                    Menu {
                        if pr.state == "open" {
                            Button {
                                Task { await mergePR(pr, method: .merge) }
                            } label: {
                                Label("Merge", systemImage: "arrow.triangle.merge")
                            }

                            Button {
                                Task { await mergePR(pr, method: .squash) }
                            } label: {
                                Label("Squash and Merge", systemImage: "square.stack.3d.up")
                            }

                            Button {
                                Task { await mergePR(pr, method: .rebase) }
                            } label: {
                                Label("Rebase and Merge", systemImage: "arrow.triangle.branch")
                            }

                            Divider()
                        }

                        Button {
                            if let url = URL(string: pr.htmlUrl) {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            Label("Open in GitHub", systemImage: "safari")
                        }
                    } label: {
                        HStack {
                            Image(systemName: pr.state == "open" ? "arrow.triangle.pull" : "checkmark.circle.fill")
                                .foregroundColor(pr.state == "open" ? .green : .purple)
                            Text("PR #\(pr.number): \(pr.title)")
                        }
                    }
                }

                Divider()
            }

            Button {
                showPRSheet = true
            } label: {
                Label("Start a Pull Request", systemImage: "plus.circle")
            }

            Divider()

            Button {
                // TODO: Implement merge
            } label: {
                Label("Merge into current branch", systemImage: "arrow.triangle.merge")
            }
            .disabled(branch.isCurrent)

            Divider()

            Button(role: .destructive) {
                Task {
                    try? await appState.gitService.deleteBranch(named: branch.name)
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .disabled(branch.isCurrent)
        }
        .onAppear {
            loadBranchPRs()
        }
        .sheet(isPresented: $showPRSheet) {
            CreatePullRequestSheet(branch: branch)
                .environmentObject(appState)
        }
        .alert("Uncommitted Changes", isPresented: $showUncommittedAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Stash & Checkout") {
                Task {
                    do {
                        _ = try await appState.gitService.stash(message: "Auto-stash before checkout to \(branch.name)")
                        try await appState.gitService.checkout(branch.name)
                    } catch {
                        print("Stash & checkout failed: \(error)")
                    }
                }
            }
            Button("Force Checkout", role: .destructive) {
                Task {
                    do {
                        try await appState.gitService.checkoutForce(branch.name)
                    } catch {
                        print("Force checkout failed: \(error)")
                    }
                }
            }
        } message: {
            Text("You have uncommitted changes. Commit them first, stash them, or force checkout (will discard changes).")
        }
    }

    private func performCheckout() async {
        // Check for uncommitted changes
        if let status = appState.currentRepository?.status {
            let hasChanges = !status.staged.isEmpty || !status.unstaged.isEmpty || !status.untracked.isEmpty
            if hasChanges {
                // Auto stash → checkout → pop (to avoid accumulating stashes)
                await performCheckoutWithAutoStash()
                return
            }
        }

        // No changes, proceed with checkout
        do {
            try await appState.gitService.checkout(branch.name)
            await appState.refresh()
            NotificationCenter.default.post(name: .repositoryDidRefresh, object: appState.currentRepository?.path)
        } catch {
            print("Checkout failed: \(error)")
        }
    }

    private func performCheckoutWithAutoStash() async {
        guard let path = appState.currentRepository?.path else { return }

        let shell = ShellExecutor()

        // 1. Stash changes (including untracked files with -u)
        let stashResult = await shell.execute(
            "git",
            arguments: ["stash", "push", "-u", "-m", "Auto-stash for checkout to \(branch.name)"],
            workingDirectory: path
        )

        let didStash = stashResult.isSuccess && !stashResult.stdout.contains("No local changes")

        // 2. Perform checkout
        do {
            try await appState.gitService.checkout(branch.name)

            // 3. Pop stash if we stashed something
            if didStash {
                let popResult = await shell.execute(
                    "git",
                    arguments: ["stash", "pop"],
                    workingDirectory: path
                )

                if !popResult.isSuccess {
                    print("Stash pop failed - changes remain in stash")
                }
            }

            // 4. Refresh UI to update graph and branch indicator
            await appState.refresh()
            NotificationCenter.default.post(name: .repositoryDidRefresh, object: path)
        } catch {
            // Checkout failed - restore stash if we made one
            if didStash {
                _ = await shell.execute(
                    "git",
                    arguments: ["stash", "pop"],
                    workingDirectory: path
                )
            }
            print("Checkout failed: \(error)")
        }
    }

    private func loadBranchPRs() {
        guard !isLoadingPRs else { return }
        isLoadingPRs = true

        Task {
            guard let repo = appState.currentRepository,
                  let remoteURL = repo.remotes.first?.fetchURL else {
                isLoadingPRs = false
                return
            }

            let (owner, repoName) = parseGitHubURL(remoteURL)
            guard !owner.isEmpty, !repoName.isEmpty else {
                isLoadingPRs = false
                return
            }

            do {
                let allPRs = try await githubService.listPullRequests(
                    owner: owner,
                    repo: repoName,
                    state: .all
                )
                // Filter PRs that have this branch as head
                branchPRs = allPRs.filter { $0.head.ref == branch.name }
            } catch {
                // Silently fail
            }

            isLoadingPRs = false
        }
    }

    private func parseGitHubURL(_ url: String) -> (owner: String, repo: String) {
        let cleanURL = url
            .replacingOccurrences(of: "git@github.com:", with: "")
            .replacingOccurrences(of: "https://github.com/", with: "")
            .replacingOccurrences(of: ".git", with: "")

        let parts = cleanURL.components(separatedBy: "/")
        guard parts.count >= 2 else { return ("", "") }

        return (parts[0], parts[1])
    }

    private func mergePR(_ pr: GitHubPullRequest, method: MergeMethod) async {
        guard let repo = appState.currentRepository,
              let remoteURL = repo.remotes.first?.fetchURL else {
            return
        }

        let (owner, repoName) = parseGitHubURL(remoteURL)
        guard !owner.isEmpty, !repoName.isEmpty else {
            return
        }

        do {
            try await githubService.mergePullRequest(
                owner: owner,
                repo: repoName,
                number: pr.number,
                mergeMethod: method
            )
            // Reload PRs after merge
            loadBranchPRs()
            // Refresh git status
            try? await appState.gitService.refresh()
        } catch {
            print("Failed to merge PR: \(error)")
        }
    }
}

// MARK: - Remote Sidebar Row
struct RemoteSidebarRow: View {
    let remote: Remote
    @State private var isExpanded = false
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9))
                    .foregroundColor(AppTheme.textMuted)
                    .frame(width: 12)

                Image(systemName: "network")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.textSecondary)

                Text(remote.name)
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.textSecondary)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(isHovered ? AppTheme.hover : Color.clear)
            .onHover { isHovered = $0 }
            .onTapGesture { isExpanded.toggle() }

            if isExpanded {
                ForEach(remote.branches) { branch in
                    SidebarBranchRow(branch: branch)
                        .padding(.leading, 20)
                }
            }
        }
    }
}

// MARK: - Stash Sidebar Row
struct StashSidebarRow: View {
    let stash: Stash
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "archivebox")
                .font(.system(size: 12))
                .foregroundColor(AppTheme.accent)

            Text(stash.message)
                .font(.system(size: 12))
                .foregroundColor(AppTheme.textSecondary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(isHovered ? AppTheme.hover : Color.clear)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Tag Sidebar Row
struct TagSidebarRow: View {
    let tag: Tag
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "tag")
                .font(.system(size: 12))
                .foregroundColor(AppTheme.warning)

            Text(tag.name)
                .font(.system(size: 12))
                .foregroundColor(AppTheme.textSecondary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(isHovered ? AppTheme.hover : Color.clear)
        .onHover { isHovered = $0 }
    }
}


// MARK: - Right Staging Panel
struct RightStagingPanel: View {
    @EnvironmentObject var appState: AppState
    @Binding var selectedFileDiff: FileDiff?
    @Binding var isLoadingDiff: Bool
    @State private var commitMessage = ""
    @StateObject private var stagingVM = StagingViewModel()
    @StateObject private var commitDetailVM = CommitDetailViewModel()
    @StateObject private var stashDetailVM = StashDetailViewModel()
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        VStack(spacing: 0) {
            if let selectedCommit = appState.selectedCommit {
                // Show commit details when a commit is selected
                CommitDetailPanel(
                    commit: selectedCommit,
                    viewModel: commitDetailVM,
                    selectedFileDiff: $selectedFileDiff,
                    onClose: { appState.selectedCommit = nil }
                )
            } else if let selectedStash = appState.selectedStash {
                // Show stash details when a stash is selected
                StashDetailPanel(
                    stash: selectedStash,
                    viewModel: stashDetailVM,
                    selectedFileDiff: $selectedFileDiff,
                    onClose: { appState.selectedStash = nil }
                )
            } else {
                // Show staging area when no commit/stash is selected (WIP mode)
                StagingAreaPanel(
                    stagingVM: stagingVM,
                    selectedFileDiff: $selectedFileDiff,
                    isLoadingDiff: $isLoadingDiff,
                    commitMessage: $commitMessage
                )
            }
        }
        .task {
            if let path = appState.currentRepository?.path {
                await stagingVM.loadStatus(at: path)
            }
        }
        .onChange(of: appState.currentRepository?.path) { _, newPath in
            if let path = newPath {
                Task { await stagingVM.loadStatus(at: path) }
            }
        }
        .onReceive(Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()) { _ in
            // Auto-refresh WIP changes every 2 seconds
            if let path = appState.currentRepository?.path {
                Task {
                    await stagingVM.loadStatus(at: path)
                }
            }
        }
        .onChange(of: appState.selectedCommit) { _, newCommit in
            if let commit = newCommit, let path = appState.currentRepository?.path {
                Task { await commitDetailVM.loadCommitFiles(sha: commit.sha, at: path) }
            }
        }
        .onChange(of: appState.selectedStash) { _, newStash in
            if let stash = newStash, let path = appState.currentRepository?.path {
                Task { await stashDetailVM.loadStashFiles(stashRef: stash.reference, at: path) }
            }
        }
        .task(id: appState.selectedStash?.sha) {
            // Load stash files when stash is selected (initial load)
            if let stash = appState.selectedStash, let path = appState.currentRepository?.path {
                await stashDetailVM.loadStashFiles(stashRef: stash.reference, at: path)
            }
        }
    }
}

// MARK: - Staging Area Panel (when no commit selected)
struct StagingAreaPanel: View {
    @ObservedObject var stagingVM: StagingViewModel
    @Binding var selectedFileDiff: FileDiff?
    @Binding var isLoadingDiff: Bool
    @Binding var commitMessage: String
    @EnvironmentObject var appState: AppState
    @StateObject private var themeManager = ThemeManager.shared
    @State private var viewMode: StagingViewMode = .tree
    @State private var extensionFilter: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar with view mode and filter
            stagingToolbar

            // Unstaged Files
            StagingSectionWithTree(
                title: "Unstaged Files",
                count: filteredUnstagedFiles.count,
                actionIcon: "plus.circle.fill",
                actionColor: AppTheme.success,
                onAction: { stagingVM.stageAll() },
                viewMode: viewMode,
                files: stagingVM.unstagedFiles,  // Pass ALL files
                isStaged: false,
                selectedFilePath: selectedFileDiff?.newPath,
                extensionFilter: extensionFilter,  // Pass filter separately
                onSelect: loadDiff,
                onStage: { stagingVM.stage(file: $0) },
                onStageFolder: { stagingVM.stageFolder($0) },
                onDiscard: { stagingVM.discard(file: $0) },
                onDelete: { stagingVM.deleteFile($0) }
            )

            Rectangle().fill(AppTheme.border).frame(height: 1)

            // Staged Files
            StagingSectionWithTree(
                title: "Staged Files",
                count: filteredStagedFiles.count,
                actionIcon: "minus.circle.fill",
                actionColor: AppTheme.error,
                onAction: { stagingVM.unstageAll() },
                viewMode: viewMode,
                files: stagingVM.stagedFiles,  // Pass ALL files
                isStaged: true,
                selectedFilePath: selectedFileDiff?.newPath,
                extensionFilter: extensionFilter,  // Pass filter separately
                onSelect: loadDiff,
                onStage: { stagingVM.unstage(file: $0) },
                onStageFolder: { stagingVM.unstageFolder($0) }
            )

            Spacer()

            // Commit Section
            CommitSection(
                commitMessage: $commitMessage,
                canCommit: !stagingVM.stagedFiles.isEmpty,
                repositoryPath: appState.currentRepository?.path,
                onCommit: { stagingVM.commit(message: commitMessage) { commitMessage = "" } }
            )
        }
    }

    private var stagingToolbar: some View {
        let theme = Color.Theme(self.themeManager.colors)
        return HStack(spacing: 8) {
            // View mode toggle with custom buttons
            HStack(spacing: 2) {
                Button(action: { viewMode = .flat }) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 12))
                        .foregroundColor(viewMode == .flat ? theme.accent : theme.text)
                        .frame(width: 28, height: 22)
                        .background(viewMode == .flat ? theme.accent.opacity(0.15) : Color.clear)
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help("List View")

                Button(action: { viewMode = .tree }) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 12))
                        .foregroundColor(viewMode == .tree ? theme.accent : theme.text)
                        .frame(width: 28, height: 22)
                        .background(viewMode == .tree ? theme.accent.opacity(0.15) : Color.clear)
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help("Tree View")
            }
            .padding(2)
            .background(theme.backgroundTertiary)
            .cornerRadius(6)

            // Extension filter - Separado: Menu (icono) + Text
            HStack(spacing: 4) {
                Menu {
                    Button("All Files") { extensionFilter = nil }
                    if !availableExtensions.isEmpty {
                        Divider()
                        ForEach(availableExtensions, id: \.self) { ext in
                            Button {
                                extensionFilter = ext
                            } label: {
                                HStack {
                                    Text(".\(ext)")
                                    Spacer()
                                    Text("\(fileCountForExtension(ext))")
                                        .foregroundColor(theme.textSecondary)
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
                .tint(extensionFilter != nil ? theme.accent : theme.textSecondary)
                .menuStyle(.borderlessButton)

                Text(extensionFilter.map { ".\($0)" } ?? "All")
                    .font(.system(size: 10))
                    .foregroundColor(extensionFilter != nil ? theme.accent : theme.text)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(extensionFilter != nil ? theme.accent.opacity(0.15) : theme.backgroundTertiary)
            .cornerRadius(4)

            Spacer()

            Text("\(stagingVM.unstagedFiles.count + stagingVM.stagedFiles.count)")
                .font(.system(size: 10))
                .foregroundColor(theme.textMuted)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(theme.backgroundSecondary)
    }

    private var availableExtensions: [String] {
        var exts = Set<String>()
        for file in stagingVM.unstagedFiles + stagingVM.stagedFiles {
            let ext = (file.path as NSString).pathExtension.lowercased()
            if !ext.isEmpty { exts.insert(ext) }
        }
        return exts.sorted()
    }

    private func fileCountForExtension(_ ext: String) -> Int {
        (stagingVM.unstagedFiles + stagingVM.stagedFiles).filter {
            ($0.path as NSString).pathExtension.lowercased() == ext
        }.count
    }

    private var filteredUnstagedFiles: [StagingFile] {
        guard let ext = extensionFilter else { return stagingVM.unstagedFiles }
        return stagingVM.unstagedFiles.filter {
            ($0.path as NSString).pathExtension.lowercased() == ext
        }
    }

    private var filteredStagedFiles: [StagingFile] {
        guard let ext = extensionFilter else { return stagingVM.stagedFiles }
        return stagingVM.stagedFiles.filter {
            ($0.path as NSString).pathExtension.lowercased() == ext
        }
    }

    private func loadDiff(for file: StagingFile) {
        guard let path = appState.currentRepository?.path else { return }

        // Don't clear selectedFileDiff if we're reloading the same file
        // This prevents the need for double-clicking
        if selectedFileDiff?.newPath != file.path {
            isLoadingDiff = true
            selectedFileDiff = nil
        }

        Task {
            if let diff = await stagingVM.getDiff(for: file, at: path) {
                selectedFileDiff = diff
            }
            isLoadingDiff = false
        }
    }
}

// MARK: - Staging View Mode
enum StagingViewMode {
    case flat
    case tree
}

// MARK: - Staging Section with Tree Support
struct StagingSectionWithTree: View {
    let title: String
    let count: Int
    let actionIcon: String
    let actionColor: Color
    let onAction: () -> Void
    let viewMode: StagingViewMode
    let files: [StagingFile]
    let isStaged: Bool
    let selectedFilePath: String?
    let extensionFilter: String?
    let onSelect: (StagingFile) -> Void
    let onStage: (StagingFile) -> Void
    let onStageFolder: (String) -> Void
    var onDiscard: ((StagingFile) -> Void)? = nil
    var onDelete: ((StagingFile) -> Void)? = nil

    @State private var isExpanded = true

    /// Files filtered by extension (for flat view and empty check)
    private var filteredFiles: [StagingFile] {
        guard let ext = extensionFilter else { return files }
        return files.filter { ($0.path as NSString).pathExtension.lowercased() == ext.lowercased() }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(AppTheme.textMuted)
                }
                .buttonStyle(.plain)

                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.textMuted)

                Text("\(count)")
                    .font(.system(size: 10))
                    .foregroundColor(AppTheme.textMuted)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppTheme.backgroundTertiary)
                    .cornerRadius(4)

                Spacer()

                Button(action: onAction) {
                    Image(systemName: actionIcon)
                        .font(.system(size: 14))
                        .foregroundColor(actionColor)
                }
                .buttonStyle(.plain)
                .help(isStaged ? "Unstage All" : "Stage All")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(AppTheme.backgroundSecondary)

            // Content
            if isExpanded {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if filteredFiles.isEmpty {
                            Text(isStaged ? "No staged changes" : "No unstaged changes")
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.textMuted)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        } else if viewMode == .tree {
                            StagingTreeView(
                                files: files,  // Pass ALL files to build full tree
                                isStaged: isStaged,
                                selectedFilePath: selectedFilePath,
                                extensionFilter: extensionFilter,  // Filter applied in tree
                                onSelect: onSelect,
                                onStage: onStage,
                                onStageFolder: onStageFolder,
                                onDiscard: onDiscard,
                                onDelete: onDelete
                            )
                        } else {
                            ForEach(filteredFiles) { file in
                                ClickableFileRow(
                                    file: file,
                                    isStaged: isStaged,
                                    isSelected: file.path == selectedFilePath,
                                    onSelect: { onSelect(file) },
                                    onStage: { onStage(file) }
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Staging Tree View (Now using GenericFileTreeView)
struct StagingTreeView: View {
    let files: [StagingFile]
    let isStaged: Bool
    let selectedFilePath: String?
    let extensionFilter: String?
    let onSelect: (StagingFile) -> Void
    let onStage: (StagingFile) -> Void
    let onStageFolder: (String) -> Void
    var onDiscard: ((StagingFile) -> Void)? = nil
    var onDelete: ((StagingFile) -> Void)? = nil

    var body: some View {
        GenericFileTreeView<StagingFile, StagingTreeNodeView>.forStagingFiles(
            files: files,
            selectedPath: .constant(selectedFilePath),
            section: isStaged ? "staged" : "unstaged",
            extensionFilter: extensionFilter,
            pathExtractor: { $0.path }
        ) { node, isSelected, section in
            StagingTreeNodeView(
                node: node,
                isStaged: isStaged,
                isSelected: isSelected,
                extensionFilter: extensionFilter,
                onSelect: onSelect,
                onStage: onStage,
                onStageFolder: onStageFolder,
                onDiscard: onDiscard,
                onDelete: onDelete
            )
        }
    }
}

// MARK: - Staging Tree Node View (Renders single node - recursion handled by GenericFileTreeView)
struct StagingTreeNodeView: View {
    @ObservedObject var node: GenericTreeNode<StagingFile>
    let isStaged: Bool
    let isSelected: Bool  // Now passed from GenericFileTreeView
    let extensionFilter: String?
    let onSelect: (StagingFile) -> Void
    let onStage: (StagingFile) -> Void
    let onStageFolder: (String) -> Void
    var onDiscard: ((StagingFile) -> Void)? = nil
    var onDelete: ((StagingFile) -> Void)? = nil

    @State private var isHovered = false
    @State private var showDiscardAlert = false
    @State private var showDeleteAlert = false
    @State private var fileToDiscard: StagingFile? = nil
    @State private var fileToDelete: StagingFile? = nil

    /// Count of files matching the filter (for folder display)
    private var filteredFileCount: Int {
        countMatchingFiles(in: node)
    }

    var body: some View {
        if node.isFolder {
            folderView
        } else {
            fileView
        }
    }

    private var folderView: some View {
        // Note: Chevron and recursion are handled by GenericTreeNodeView
        // This view only renders the folder content (icon, name, actions)
        HStack(spacing: 8) {
            Image(systemName: "folder.fill")
                .font(.system(size: 13))
                .foregroundColor(AppTheme.warning)

            Text(node.name)
                .font(.system(size: 11, weight: isHovered ? .medium : .regular))
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(1)

            Text("(\(filteredFileCount))")
                .font(.system(size: 10))
                .foregroundColor(AppTheme.textMuted)

            Spacer()

            if isHovered {
                Button {
                    onStageFolder(node.path)
                } label: {
                    Image(systemName: isStaged ? "minus.circle" : "plus.circle")
                        .font(.system(size: 12))
                        .foregroundColor(isStaged ? AppTheme.error : AppTheme.success)
                }
                .buttonStyle(.plain)
                .help(isStaged ? "Unstage Folder" : "Stage Folder")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .contextMenu {
            Button {
                onStageFolder(node.path)
            } label: {
                Label(isStaged ? "Unstage Folder" : "Stage Folder",
                      systemImage: isStaged ? "minus.circle" : "plus.circle")
            }
        }
    }

    /// Count files matching the filter in a node and its descendants
    private func countMatchingFiles(in node: GenericTreeNode<StagingFile>) -> Int {
        if node.isFolder {
            return node.children.reduce(0) { $0 + countMatchingFiles(in: $1) }
        } else {
            return nodeMatchesFilter(node) ? 1 : 0
        }
    }

    /// Check if a node or any of its descendants match the extension filter
    private func nodeMatchesFilter(_ node: GenericTreeNode<StagingFile>) -> Bool {
        guard let ext = extensionFilter else { return true }

        if node.isFolder {
            return node.children.contains { nodeMatchesFilter($0) }
        } else {
            let fileExt = (node.path as NSString).pathExtension.lowercased()
            return fileExt == ext.lowercased()
        }
    }

    private var fileView: some View {
        Button(action: {
            if let file = node.data { onSelect(file) }
        }) {
            HStack(spacing: 6) {
                // Status icon
                if let file = node.data {
                    StatusIcon(stagingStatus: file.status, size: .small)
                }

                // File type icon based on extension
                FileTypeIcon(fileName: node.name, size: .small)

                // Filename
                Text(node.name)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)

                Spacer()

                // Diff stats (additions/deletions) - always show if file has changes
                if let file = node.data, file.hasChanges {
                    DiffStatsView(additions: file.additions, deletions: file.deletions, size: .small, style: .compact)
                }

                if isHovered, let file = node.data {
                    Button {
                        onStage(file)
                    } label: {
                        Image(systemName: isStaged ? "minus.circle" : "plus.circle")
                            .font(.system(size: 12))
                            .foregroundColor(isStaged ? AppTheme.error : AppTheme.success)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? AppTheme.accent.opacity(0.3) : (isHovered ? AppTheme.hover : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .contextMenu {
            if let file = node.data {
                Button {
                    onStage(file)
                } label: {
                    Label(isStaged ? "Unstage File" : "Stage File",
                          systemImage: isStaged ? "minus.circle" : "plus.circle")
                }

                // Discard changes for unstaged modified files (not untracked)
                if !isStaged, onDiscard != nil, file.status != .untracked {
                    Divider()
                    Button(role: .destructive) {
                        fileToDiscard = file
                        showDiscardAlert = true
                    } label: {
                        Label("Revert Changes", systemImage: "arrow.uturn.backward")
                    }
                }

                // Delete option for untracked files
                if !isStaged, file.status == .untracked {
                    Divider()
                    Button(role: .destructive) {
                        fileToDelete = file
                        showDeleteAlert = true
                    } label: {
                        Label("Delete File", systemImage: "trash")
                    }
                }

                Divider()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(file.path, forType: .string)
                } label: {
                    Label("Copy Path", systemImage: "doc.on.doc")
                }

                Button {
                    NSWorkspace.shared.selectFile(file.path, inFileViewerRootedAtPath: "")
                } label: {
                    Label("Reveal in Finder", systemImage: "folder")
                }
            }
        }
        .alert("Discard Changes?", isPresented: $showDiscardAlert) {
            Button("Cancel", role: .cancel) {
                fileToDiscard = nil
            }
            Button("Discard", role: .destructive) {
                if let file = fileToDiscard {
                    onDiscard?(file)
                }
                fileToDiscard = nil
            }
        } message: {
            if let file = fileToDiscard {
                Text("This will permanently discard all changes to '\(URL(fileURLWithPath: file.path).lastPathComponent)'. This action cannot be undone.")
            }
        }
        .alert("Delete File?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {
                fileToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let file = fileToDelete {
                    onDelete?(file)
                }
                fileToDelete = nil
            }
        } message: {
            if let file = fileToDelete {
                Text("This will permanently delete '\(URL(fileURLWithPath: file.path).lastPathComponent)'. This action cannot be undone.")
            }
        }
    }
}

// MARK: - Commit Detail Panel (when commit is selected)
struct CommitDetailPanel: View {
    let commit: Commit
    @ObservedObject var viewModel: CommitDetailViewModel
    @Binding var selectedFileDiff: FileDiff?
    let onClose: () -> Void
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Commit header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Commit Details")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppTheme.textMuted)
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.textMuted)
                    }
                    .buttonStyle(.borderless)
                    .frame(width: 24, height: 24)
                    .help("Close")
                }

                // Commit message
                Text(commit.message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(3)

                // Author and date
                HStack(spacing: 8) {
                    AuthorAvatar(name: commit.author, size: 20)
                    Text(commit.author)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textSecondary)
                    Spacer()
                    Text(commit.relativeDate)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textMuted)
                }

                // SHA
                HStack {
                    Text(String(commit.sha.prefix(8)))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(AppTheme.accent)
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(commit.sha, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
            }
            .padding(12)
            .background(AppTheme.backgroundSecondary)

            Rectangle().fill(AppTheme.border).frame(height: 1)

            // Changed files
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Changed Files")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppTheme.textMuted)
                    Spacer()
                    Text("\(viewModel.changedFiles.count)")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textMuted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.backgroundTertiary)
                        .cornerRadius(4)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppTheme.backgroundSecondary)

                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.8)
                        Spacer()
                    }
                    .padding(.vertical, 20)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.changedFiles) { file in
                                CommitFileRow(
                                    file: file,
                                    repositoryPath: appState.currentRepository?.path ?? "",
                                    onSelect: { loadCommitFileDiff(file) }
                                )
                            }
                            if viewModel.changedFiles.isEmpty {
                                Text("No files changed")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppTheme.textMuted)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                            }
                        }
                    }
                }
            }

            Spacer()
        }
    }

    private func loadCommitFileDiff(_ file: CommitFile) {
        guard let path = appState.currentRepository?.path else { return }
        Task {
            if let diff = await viewModel.getDiff(for: file, commit: commit, at: path) {
                selectedFileDiff = diff
            }
        }
    }
}

// MARK: - Commit Detail ViewModel
@MainActor
class CommitDetailViewModel: ObservableObject {
    @Published var changedFiles: [CommitFile] = []
    @Published var isLoading = false

    private let engine = GitEngine()

    func loadCommitFiles(sha: String, at path: String) async {
        isLoading = true
        do {
            let files = try await engine.getCommitFiles(sha: sha, at: path)
            changedFiles = files
        } catch {
            print("Error loading commit files: \(error)")
            changedFiles = []
        }
        isLoading = false
    }

    func getDiff(for file: CommitFile, commit: Commit, at path: String) async -> FileDiff? {
        // Use streaming to load diffs, aborting early for very large files to prevent UI freeze
        do {
            let maxLines = 100000
            var diffLines: [String] = []
            var lineCount = 0

            print("DEBUG: Starting diff stream for \(file.path)")

            // Stream the diff
            for try await line in engine.getCommitFileDiffStreaming(sha: commit.sha, filePath: file.path, at: path) {
                diffLines.append(line)
                lineCount += 1

                if lineCount >= maxLines {
                    diffLines.append("\n... [Output truncated - file too large] ...")
                    print("DEBUG: Truncated diff at \(maxLines) lines")
                    break
                }
            }
            
            print("DEBUG: Diff stream complete. Caught \(lineCount) lines. Parsing...")
            
            // Use joined() for O(N) instead of O(N^2) loop concatenation
            let diffString = diffLines.joined(separator: "\n")
            
            // Use async parser
            let diffs = await DiffParser.parseAsync(diffString)
            print("DEBUG: Parsing complete. Found \(diffs.first?.hunks.count ?? 0) hunks")
            return diffs.first
        } catch {
            print("Error getting streaming diff: \(error)")
            return nil
        }
    }
}

// MARK: - Stash Detail Panel
struct StashDetailPanel: View {
    let stash: Stash
    @ObservedObject var viewModel: StashDetailViewModel
    @Binding var selectedFileDiff: FileDiff?
    let onClose: () -> Void
    @EnvironmentObject var appState: AppState

    private var stashColor: Color { AppTheme.info }

    var body: some View {
        VStack(spacing: 0) {
            // Stash header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(stashColor)
                        Text("Stash Details")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppTheme.textMuted)
                    }
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(AppTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                }

                // Stash message
                Text(stash.displayMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(3)

                // Branch and date
                HStack(spacing: 8) {
                    if let branch = stash.branchName {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.system(size: 10))
                            Text(branch)
                        }
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textSecondary)
                    }
                    Spacer()
                    Text(stash.relativeDate)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textMuted)
                }

                // Reference
                HStack {
                    Text(stash.reference)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(stashColor)
                    Spacer()
                }
            }
            .padding(12)
            .background(AppTheme.backgroundSecondary)

            Rectangle().fill(AppTheme.border).frame(height: 1)

            // Stash files
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Stashed Files")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppTheme.textMuted)
                    Spacer()
                    Text("\(viewModel.stashFiles.count)")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textMuted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.backgroundTertiary)
                        .cornerRadius(4)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppTheme.backgroundSecondary)

                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.8)
                        Spacer()
                    }
                    .padding(.vertical, 20)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.stashFiles) { file in
                                StashDetailFileRow(
                                    file: file,
                                    onSelect: { loadStashFileDiff(file) }
                                )
                            }
                            if viewModel.stashFiles.isEmpty {
                                Text("No files in stash")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppTheme.textMuted)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                            }
                        }
                    }
                }
            }

            Spacer()

            // Actions
            HStack(spacing: 8) {
                Button {
                    NotificationCenter.default.post(name: .applyStash, object: stash.index)
                    onClose()
                } label: {
                    Label("Apply", systemImage: "arrow.down.doc")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)

                Button {
                    NotificationCenter.default.post(name: .popStashAtIndex, object: stash.index)
                    onClose()
                } label: {
                    Label("Pop", systemImage: "arrow.up.doc")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(role: .destructive) {
                    NotificationCenter.default.post(name: .dropStash, object: stash.index)
                    onClose()
                } label: {
                    Label("Drop", systemImage: "trash")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
            }
            .padding(12)
            .background(AppTheme.backgroundSecondary)
        }
        .task {
            // Load files when panel appears
            if let path = appState.currentRepository?.path {
                await viewModel.loadStashFiles(stashRef: stash.reference, at: path)
            }
        }
    }

    private func loadStashFileDiff(_ file: StashFile) {
        guard let path = appState.currentRepository?.path else { return }
        Task {
            if let diff = await viewModel.getDiff(for: file, stash: stash, at: path) {
                selectedFileDiff = diff
            }
        }
    }
}

// MARK: - Stash Detail ViewModel
@MainActor
class StashDetailViewModel: ObservableObject {
    @Published var stashFiles: [StashFile] = []
    @Published var isLoading = false

    private let engine = GitEngine()

    func loadStashFiles(stashRef: String, at path: String) async {
        var log = "DEBUG: Loading stash files for \(stashRef) at \(path)\n"

        isLoading = true
        do {
            let files = try await engine.getStashFiles(stashRef: stashRef, at: path)
            log += "DEBUG: Loaded \(files.count) stash files\n"
            stashFiles = files
        } catch {
            log += "ERROR loading stash files: \(error)\n"
            stashFiles = []
        }
        isLoading = false

        // Write to temp file for debugging
        try? log.write(toFile: "/tmp/gitmac_debug.log", atomically: true, encoding: .utf8)
    }

    func getDiff(for file: StashFile, stash: Stash, at path: String) async -> FileDiff? {
        let shell = ShellExecutor()
        let result = await shell.execute(
            "git",
            arguments: ["stash", "show", "-p", stash.reference, "--", file.path],
            workingDirectory: path
        )

        if result.exitCode == 0 && !result.stdout.isEmpty {
            // Use async parser to avoid UI freeze on large files
            let diffs = await DiffParser.parseAsync(result.stdout)
            return diffs.first
        }
        return nil
    }
}

// MARK: - Stash Detail File Row
struct StashDetailFileRow: View {
    let file: StashFile
    let onSelect: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                // Status icon
                Image(systemName: statusIcon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(file.statusColor)
                    .frame(width: 14)

                // File icon
                Image(systemName: fileIcon(for: file.filename))
                    .font(.system(size: 10))
                    .foregroundColor(AppTheme.textMuted)

                // File path
                Text(file.filename)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                // Directory path
                if file.path != file.filename {
                    Text(String(file.path.dropLast(file.filename.count + 1)))
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textMuted)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isHovered ? AppTheme.hover : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(file.path, forType: .string)
            } label: {
                Label("Copy Path", systemImage: "doc.on.doc")
            }
        }
    }

    private var statusIcon: String {
        switch file.status {
        case .added: return "plus"
        case .modified: return "pencil"
        case .deleted: return "minus"
        case .renamed: return "arrow.right"
        default: return "circle"
        }
    }

    private func fileIcon(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "js", "ts", "jsx", "tsx": return "curlybraces"
        case "json": return "curlybraces.square"
        case "md": return "doc.text"
        case "png", "jpg", "jpeg", "gif", "svg": return "photo"
        case "css", "scss": return "paintbrush"
        case "html": return "chevron.left.forwardslash.chevron.right"
        default: return "doc"
        }
    }
}

// MARK: - Commit File Model
struct CommitFile: Identifiable {
    let id = UUID()
    let path: String
    let status: CommitFileStatus
    let additions: Int
    let deletions: Int

    enum CommitFileStatus {
        case added, modified, deleted, renamed, copied

        @MainActor
        var color: Color {
            switch self {
            case .added: return AppTheme.success
            case .modified: return AppTheme.warning
            case .deleted: return AppTheme.error
            case .renamed: return AppTheme.accent
            case .copied: return AppTheme.accent
            }
        }

        var icon: String {
            switch self {
            case .added: return "plus"
            case .modified: return "pencil"
            case .deleted: return "minus"
            case .renamed: return "arrow.right"
            case .copied: return "doc.on.doc"
            }
        }
    }
}

// MARK: - Commit File Row
struct CommitFileRow: View {
    let file: CommitFile
    var repositoryPath: String = ""
    let onSelect: () -> Void
    @State private var isHovered = false
    @State private var showPreview = false

    private var filename: String {
        (file.path as NSString).lastPathComponent
    }

    private var canPreview: Bool {
        FilePreviewHelper.canPreview(filename: file.path)
    }

    var body: some View {
        HStack(spacing: 8) {
            // Status icon
            Image(systemName: file.status.icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(file.status.color)
                .frame(width: 16)

            // File icon
            Image(systemName: "doc.fill")
                .font(.system(size: 12))
                .foregroundColor(AppTheme.accent)

            // Filename
            Text(filename)
                .font(.system(size: 12))
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(1)

            Spacer()

            // Additions/Deletions
            if file.additions > 0 {
                Text("+\(file.additions)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(AppTheme.success)
            }
            if file.deletions > 0 {
                Text("-\(file.deletions)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(AppTheme.error)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isHovered ? AppTheme.hover : Color.clear)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture { onSelect() }
        .contextMenu {
            // Preview and Copy Content (for text files)
            if canPreview {
                Button {
                    showPreview = true
                } label: {
                    Label("Preview File", systemImage: "eye")
                }

                Button {
                    copyFileContent()
                } label: {
                    Label("Copy Content", systemImage: "doc.on.clipboard")
                }

                Divider()
            }

            // Copy path options
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(file.path, forType: .string)
            } label: {
                Label("Copy Path", systemImage: "doc.on.doc")
            }

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(filename, forType: .string)
            } label: {
                Label("Copy Filename", systemImage: "doc.text")
            }

            Divider()

            // Open/Reveal options
            Button {
                let fullPath = (repositoryPath as NSString).appendingPathComponent(file.path)
                NSWorkspace.shared.selectFile(fullPath, inFileViewerRootedAtPath: "")
            } label: {
                Label("Reveal in Finder", systemImage: "folder")
            }

            Button {
                let fullPath = (repositoryPath as NSString).appendingPathComponent(file.path)
                NSWorkspace.shared.open(URL(fileURLWithPath: fullPath))
            } label: {
                Label("Open with Default App", systemImage: "arrow.up.forward.app")
            }
        }
        .sheet(isPresented: $showPreview) {
            FilePreviewView(filePath: file.path, repositoryPath: repositoryPath)
        }
    }

    private func copyFileContent() {
        let fullPath = (repositoryPath as NSString).appendingPathComponent(file.path)
        if let content = try? String(contentsOfFile: fullPath, encoding: .utf8) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(content, forType: .string)
        }
    }
}

// MARK: - Author Avatar
struct AuthorAvatar: View {
    let name: String
    let size: CGFloat

    var color: Color {
        let colors = AppTheme.laneColors
        let hash = abs(name.hashValue)
        return colors[hash % colors.count]
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
            Text(String(name.prefix(1)).uppercased())
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Staging ViewModel
@MainActor
class StagingViewModel: ObservableObject {
    @Published var unstagedFiles: [StagingFile] = []
    @Published var stagedFiles: [StagingFile] = []

    private let engine = GitEngine()
    private var currentPath: String?

    func loadStatus(at path: String) async {
        currentPath = path
        do {
            let status = try await engine.getStatus(at: path)
            unstagedFiles = status.unstaged.map { StagingFile(from: $0, staged: false) } +
                           status.untracked.map { StagingFile(path: $0, status: .untracked, isStaged: false) }
            stagedFiles = status.staged.map { StagingFile(from: $0, staged: true) }
        } catch {
            print("Error loading status: \(error)")
        }
    }

    func stage(file: StagingFile) {
        guard let path = currentPath else { return }
        Task {
            do {
                try await engine.stage(files: [file.path], at: path)
                await loadStatus(at: path)
            } catch {
                print("Error staging: \(error)")
            }
        }
    }

    func unstage(file: StagingFile) {
        guard let path = currentPath else { return }
        Task {
            do {
                try await engine.unstage(files: [file.path], at: path)
                await loadStatus(at: path)
            } catch {
                print("Error unstaging: \(error)")
            }
        }
    }

    func stageAll() {
        guard let path = currentPath else { return }
        Task {
            do {
                try await engine.stageAll(at: path)
                await loadStatus(at: path)
            } catch {
                print("Error staging all: \(error)")
            }
        }
    }

    func unstageAll() {
        guard let path = currentPath else { return }
        Task {
            do {
                let files = stagedFiles.map { $0.path }
                try await engine.unstage(files: files, at: path)
                await loadStatus(at: path)
            } catch {
                print("Error unstaging all: \(error)")
            }
        }
    }

    func stageFolder(_ folder: String) {
        guard let path = currentPath else { return }
        Task {
            do {
                let filesToStage = unstagedFiles.filter {
                    $0.path.hasPrefix(folder + "/") || $0.path == folder
                }.map { $0.path }
                if !filesToStage.isEmpty {
                    try await engine.stage(files: filesToStage, at: path)
                    await loadStatus(at: path)
                }
            } catch {
                print("Error staging folder: \(error)")
            }
        }
    }

    func unstageFolder(_ folder: String) {
        guard let path = currentPath else { return }
        Task {
            do {
                let filesToUnstage = stagedFiles.filter {
                    $0.path.hasPrefix(folder + "/") || $0.path == folder
                }.map { $0.path }
                if !filesToUnstage.isEmpty {
                    try await engine.unstage(files: filesToUnstage, at: path)
                    await loadStatus(at: path)
                }
            } catch {
                print("Error unstaging folder: \(error)")
            }
        }
    }

    func discard(file: StagingFile) {
        guard let path = currentPath else { return }
        Task {
            do {
                try await engine.discardChanges(files: [file.path], at: path)
                await loadStatus(at: path)
            } catch {
                print("Error discarding changes: \(error)")
            }
        }
    }

    func deleteFile(_ file: StagingFile) {
        guard let repoPath = currentPath else { return }
        let absolutePath = URL(fileURLWithPath: repoPath).appendingPathComponent(file.path).path
        Task {
            do {
                try FileManager.default.removeItem(atPath: absolutePath)
                await loadStatus(at: repoPath)
            } catch {
                print("Error deleting file: \(error)")
            }
        }
    }

    func commit(message: String, onSuccess: @escaping () -> Void) {
        guard let path = currentPath, !message.isEmpty else { return }
        Task {
            do {
                _ = try await engine.commit(message: message, at: path)
                await loadStatus(at: path)
                onSuccess()
            } catch {
                print("Error committing: \(error)")
            }
        }
    }

    func getDiff(for file: StagingFile, at path: String) async -> FileDiff? {
        // For untracked files, show file content as new additions
        if file.status == .untracked {
            return await getUntrackedFileDiff(for: file, at: path)
        }

        do {
            let diffString = try await engine.getDiff(for: file.path, staged: file.isStaged, at: path)
            // Use async parser to avoid UI freeze on large files
            let diffs = await DiffParser.parseAsync(diffString)
            return diffs.first
        } catch {
            print("Error getting diff: \(error)")
            return nil
        }
    }

    private func getUntrackedFileDiff(for file: StagingFile, at repoPath: String) async -> FileDiff? {
        let fullPath = (repoPath as NSString).appendingPathComponent(file.path)

        // Read file content
        guard let content = try? String(contentsOfFile: fullPath, encoding: .utf8) else {
            // Try to read as binary/image indicator
            if FileManager.default.fileExists(atPath: fullPath) {
                return FileDiff(
                    oldPath: "/dev/null",
                    newPath: file.path,
                    status: .untracked,
                    hunks: [DiffHunk(
                        header: "@@ -0,0 +1 @@",
                        oldStart: 0,
                        oldLines: 0,
                        newStart: 1,
                        newLines: 1,
                        lines: [DiffLine(type: .context, content: "[Binary or unreadable file]", oldLineNumber: nil, newLineNumber: 1)]
                    )],
                    isBinary: true,
                    additions: 0,
                    deletions: 0
                )
            }
            return nil
        }

        // Create diff lines showing all content as additions
        let lines = content.components(separatedBy: .newlines)
        var diffLines: [DiffLine] = []

        for (index, line) in lines.enumerated() {
            diffLines.append(DiffLine(
                type: .addition,
                content: line,
                oldLineNumber: nil,
                newLineNumber: index + 1
            ))
        }

        let hunk = DiffHunk(
            header: "@@ -0,0 +1,\(lines.count) @@",
            oldStart: 0,
            oldLines: 0,
            newStart: 1,
            newLines: lines.count,
            lines: diffLines
        )

        return FileDiff(
            oldPath: "/dev/null",
            newPath: file.path,
            status: .untracked,
            hunks: [hunk],
            isBinary: false,
            additions: lines.count,
            deletions: 0
        )
    }
}

// MARK: - Staging File Model
struct StagingFile: Identifiable {
    let id = UUID()
    let path: String
    let status: StagingFileStatus
    var isStaged: Bool = false
    var additions: Int = 0
    var deletions: Int = 0

    var hasChanges: Bool {
        additions > 0 || deletions > 0
    }

    enum StagingFileStatus {
        case added, modified, deleted, renamed, untracked, conflicted

        @MainActor
        var color: Color {
            switch self {
            case .added: return AppTheme.success
            case .modified: return AppTheme.warning
            case .deleted: return AppTheme.error
            case .renamed: return AppTheme.accent
            case .untracked: return AppTheme.textMuted
            case .conflicted: return AppTheme.error
            }
        }

        var icon: String {
            switch self {
            case .added: return "plus"
            case .modified: return "pencil"
            case .deleted: return "minus"
            case .renamed: return "arrow.right"
            case .untracked: return "questionmark"
            case .conflicted: return "exclamationmark.triangle"
            }
        }
    }

    init(path: String, status: StagingFileStatus, isStaged: Bool = false, additions: Int = 0, deletions: Int = 0) {
        self.path = path
        self.status = status
        self.isStaged = isStaged
        self.additions = additions
        self.deletions = deletions
    }

    init(from fileStatus: FileStatus, staged: Bool = false) {
        self.path = fileStatus.path
        self.isStaged = staged
        self.additions = fileStatus.additions
        self.deletions = fileStatus.deletions
        switch fileStatus.status {
        case .added: self.status = .added
        case .modified: self.status = .modified
        case .deleted: self.status = .deleted
        case .renamed: self.status = .renamed
        default: self.status = .modified
        }
    }
}

// MARK: - Staging Section
struct StagingSection<Content: View>: View {
    let title: String
    let count: Int
    let actionIcon: String
    let actionColor: Color
    let onAction: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.textMuted)
                Spacer()
                Text("\(count)")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textMuted)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppTheme.backgroundTertiary)
                    .cornerRadius(4)
                Button(action: onAction) {
                    Image(systemName: actionIcon)
                        .foregroundColor(actionColor)
                }
                .buttonStyle(.plain)
                .disabled(count == 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppTheme.backgroundSecondary)

            ScrollView {
                LazyVStack(spacing: 0) {
                    content
                }
            }
            .frame(minHeight: 80, maxHeight: 200)
        }
    }
}

// MARK: - Clickable File Row
struct ClickableFileRow: View {
    let file: StagingFile
    let isStaged: Bool
    var isSelected: Bool = false
    let onSelect: () -> Void
    let onStage: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                // Status icon
                Image(systemName: file.status.icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(file.status.color)
                    .frame(width: 14)

                // File path
                Text(file.path)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                if isHovered {
                    Button(action: onStage) {
                        Image(systemName: isStaged ? "minus.circle" : "plus.circle")
                            .font(.system(size: 12))
                            .foregroundColor(isStaged ? AppTheme.error : AppTheme.success)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? AppTheme.accent.opacity(0.3) : (isHovered ? AppTheme.hover : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button {
                onStage()
            } label: {
                Label(isStaged ? "Unstage File" : "Stage File",
                      systemImage: isStaged ? "minus.circle" : "plus.circle")
            }
            Divider()
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(file.path, forType: .string)
            } label: {
                Label("Copy Path", systemImage: "doc.on.doc")
            }
        }
    }
}

// MARK: - Commit Section
struct CommitSection: View {
    @Binding var commitMessage: String
    let canCommit: Bool
    let repositoryPath: String?
    let onCommit: () -> Void

    @State private var linkedTaigaRef: String?
    @State private var linkedTaigaSubject: String?
    @State private var showStatusPicker = false
    @State private var isGeneratingAI = false
    @State private var aiError: String?

    var body: some View {
        VStack(spacing: 8) {
            // Linked Taiga ticket indicator
            if let ref = linkedTaigaRef {
                HStack(spacing: 6) {
                    Image(systemName: "ticket.fill")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.success)

                    Text(ref)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(AppTheme.success)

                    if let subject = linkedTaigaSubject {
                        Text(subject)
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Status picker
                    Menu {
                        Button("No status change") {
                            updateCommitWithTaiga(ref: ref, status: nil)
                        }
                        Divider()
                        Button("#new") { updateCommitWithTaiga(ref: ref, status: "new") }
                        Button("#in-progress") { updateCommitWithTaiga(ref: ref, status: "in-progress") }
                        Button("#ready-for-test") { updateCommitWithTaiga(ref: ref, status: "ready-for-test") }
                        Button("#closed") { updateCommitWithTaiga(ref: ref, status: "closed") }
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.accent)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 20)
                    .help("Change status with commit")

                    // Remove link
                    Button {
                        removeTaigaLink()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                    .help("Remove Taiga link")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(AppTheme.success.opacity(0.1))
                .cornerRadius(4)
            }

            ZStack(alignment: .topLeading) {
                if commitMessage.isEmpty {
                    Text("Commit message...")
                        .foregroundColor(AppTheme.textMuted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 10)
                }
                TextEditor(text: $commitMessage)
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(minHeight: 60, maxHeight: 100)
                
                // AI Generation Button
                HStack {
                    if let error = aiError {
                        Text(error)
                            .font(.system(size: 9))
                            .foregroundColor(AppTheme.error)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button {
                        generateAICommitMessage()
                    } label: {
                        if isGeneratingAI {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 22, height: 22)
                        } else {
                            Image(systemName: "sparkles")
                                .font(.system(size: 10))
                                .foregroundColor(AppTheme.accent)
                                .padding(6)
                                .background(AppTheme.background.opacity(0.8))
                                .clipShape(Circle())
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(4)
                    .disabled(isGeneratingAI)
                    .help("Generate commit message with AI")
                }
            }
            .padding(4)
            .background(AppTheme.backgroundTertiary)
            .cornerRadius(6)

            Button(action: onCommit) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Commit")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(canCommit && !commitMessage.isEmpty ? AppTheme.success : AppTheme.backgroundTertiary)
                .foregroundColor(canCommit && !commitMessage.isEmpty ? AppTheme.textPrimary : AppTheme.textMuted)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(!canCommit || commitMessage.isEmpty)
        }
        .padding(12)
        .background(AppTheme.backgroundSecondary)
        .onReceive(NotificationCenter.default.publisher(for: .insertTaigaRef)) { notification in
            if let userInfo = notification.userInfo,
               let ref = userInfo["ref"] as? String {
                linkedTaigaRef = ref
                linkedTaigaSubject = userInfo["subject"] as? String

                // Insert at the end of commit message
                if !commitMessage.contains(ref) {
                    if commitMessage.isEmpty {
                        commitMessage = "\(ref) "
                    } else {
                        commitMessage += " \(ref)"
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .insertPlannerRef)) { notification in
            if let userInfo = notification.userInfo,
               let title = userInfo["title"] as? String {
                
                // Insert title at the end of commit message
                if commitMessage.isEmpty {
                    commitMessage = title
                } else {
                    commitMessage += "\n\n" + title
                }
            }
        }
    }

    private func updateCommitWithTaiga(ref: String, status: String?) {
        // Remove any existing TG reference with status
        let pattern = "\(ref)(\\s+#[a-z-]+)?"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let range = NSRange(commitMessage.startIndex..., in: commitMessage)
            commitMessage = regex.stringByReplacingMatches(in: commitMessage, range: range, withTemplate: "")
            commitMessage = commitMessage.trimmingCharacters(in: .whitespaces)
        }

        // Add new reference with status
        let newRef = status != nil ? "\(ref) #\(status!)" : ref
        if commitMessage.isEmpty {
            commitMessage = "\(newRef) "
        } else {
            commitMessage += " \(newRef)"
        }
    }

    private func removeTaigaLink() {
        if let ref = linkedTaigaRef {
            // Remove TG reference from message
            let pattern = "\(ref)(\\s+#[a-z-]+)?"
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(commitMessage.startIndex..., in: commitMessage)
                commitMessage = regex.stringByReplacingMatches(in: commitMessage, range: range, withTemplate: "")
                commitMessage = commitMessage.trimmingCharacters(in: .whitespaces)
            }
        }
        linkedTaigaRef = nil
        linkedTaigaSubject = nil
    }

    private func generateAICommitMessage() {
        Task {
            await MainActor.run {
                isGeneratingAI = true
                aiError = nil
            }

            guard let path = repositoryPath else {
                await MainActor.run {
                    isGeneratingAI = false
                    aiError = "No repository selected"
                }
                return
            }

            do {
                // First check if there are staged changes using git diff --cached --stat
                let shell = ShellExecutor()
                let statResult = await shell.execute("git", arguments: ["diff", "--cached", "--stat"], workingDirectory: path)

                if statResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    await MainActor.run {
                        isGeneratingAI = false
                        aiError = "No staged changes"
                    }
                    return
                }

                // Get staged diff with limited output for AI
                let diffResult = await shell.execute(
                    "git",
                    arguments: ["diff", "--cached", "-U2", "--no-color"],  // -U2 = less context
                    workingDirectory: path
                )

                let diff = diffResult.stdout
                if diff.isEmpty {
                    await MainActor.run {
                        isGeneratingAI = false
                        aiError = "No staged changes"
                    }
                    return
                }

                // Generate message using shared instance
                let message = try await AIService.shared.generateCommitMessage(diff: diff)

                await MainActor.run {
                    isGeneratingAI = false
                    if commitMessage.isEmpty {
                        commitMessage = message
                    } else {
                        commitMessage = message + "\n\n" + commitMessage
                    }
                }
            } catch {
                await MainActor.run {
                    isGeneratingAI = false
                    if let err = error as? AIError {
                        switch err {
                        case .noAPIKey:
                            self.aiError = "No API key configured"
                        case .invalidProvider:
                            self.aiError = "Invalid AI provider"
                        case .requestFailed(let msg):
                            self.aiError = msg
                        case .invalidResponse:
                            self.aiError = "Invalid AI response"
                        }
                    } else {
                        self.aiError = error.localizedDescription
                    }
                }
                print("Error generating AI commit message: \(error)")
            }
        }
    }
}

// MARK: - Tab Button
private struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? AppTheme.textPrimary : AppTheme.textMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? AppTheme.backgroundSecondary : Color.clear)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Staging View (Modern)
struct StagingView: View {
    @EnvironmentObject var appState: AppState
    @Binding var commitMessage: String
    @State private var unstagedFiles: [FileChange] = []
    @State private var stagedFiles: [FileChange] = []

    var body: some View {
        VStack(spacing: 0) {
            // Unstaged Files
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Unstaged Files")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppTheme.textMuted)
                    Spacer()
                    Text("\(unstagedFiles.count)")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textMuted)
                    Button {
                        // Stage all
                    } label: {
                        Image(systemName: "plus.circle")
                            .foregroundColor(AppTheme.success)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppTheme.backgroundSecondary)

                FileListView(files: unstagedFiles, isStaged: false)
                    .frame(minHeight: 100)
            }

            Divider()
                .background(AppTheme.border)

            // Staged Files
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Staged Files")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppTheme.textMuted)
                    Spacer()
                    Text("\(stagedFiles.count)")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textMuted)
                    Button {
                        // Unstage all
                    } label: {
                        Image(systemName: "minus.circle")
                            .foregroundColor(AppTheme.error)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppTheme.backgroundSecondary)

                FileListView(files: stagedFiles, isStaged: true)
                    .frame(minHeight: 100)
            }

            Spacer()

            // Commit Section
            VStack(spacing: 8) {
                // Commit message
                ZStack(alignment: .topLeading) {
                    if commitMessage.isEmpty {
                        Text("Commit message...")
                            .foregroundColor(AppTheme.textMuted)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 10)
                    }
                    TextEditor(text: $commitMessage)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textPrimary)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .frame(minHeight: 60, maxHeight: 100)
                }
                .padding(4)
                .background(AppTheme.backgroundTertiary)
                .cornerRadius(6)

                // Commit button
                Button {
                    // Commit action
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Commit")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(stagedFiles.isEmpty ? AppTheme.backgroundTertiary : AppTheme.success)
                    .foregroundColor(stagedFiles.isEmpty ? AppTheme.textMuted : AppTheme.textPrimary)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(stagedFiles.isEmpty || commitMessage.isEmpty)
            }
            .padding(12)
            .background(AppTheme.backgroundSecondary)
        }
    }
}

// MARK: - File Change Model
struct FileChange: Identifiable {
    let id = UUID()
    let path: String
    let status: FileStatus

    enum FileStatus {
        case added, modified, deleted, renamed, untracked
    }
}

// MARK: - File List View
struct FileListView: View {
    let files: [FileChange]
    let isStaged: Bool

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(files) { file in
                    StagingFileRow(file: file, isStaged: isStaged)
                }

                if files.isEmpty {
                    Text(isStaged ? "No staged files" : "No unstaged files")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                }
            }
        }
        .background(AppTheme.backgroundSecondary)
    }
}

// MARK: - Staging File Row
struct StagingFileRow: View {
    let file: FileChange
    let isStaged: Bool
    @State private var isHovered = false

    var statusColor: Color {
        switch file.status {
        case .added: return AppTheme.success
        case .modified: return AppTheme.warning
        case .deleted: return AppTheme.error
        case .renamed: return AppTheme.accent
        case .untracked: return AppTheme.textMuted
        }
    }

    var statusIcon: String {
        switch file.status {
        case .added: return "plus"
        case .modified: return "pencil"
        case .deleted: return "minus"
        case .renamed: return "arrow.right"
        case .untracked: return "questionmark"
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: statusIcon)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(statusColor)
                .frame(width: 16)

            Image(systemName: "doc.fill")
                .font(.system(size: 12))
                .foregroundColor(AppTheme.accent)

            Text((file.path as NSString).lastPathComponent)
                .font(.system(size: 12))
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(1)

            Spacer()

            if isHovered {
                Button {
                    // Stage/Unstage file
                } label: {
                    Image(systemName: isStaged ? "minus.circle" : "plus.circle")
                        .foregroundColor(isStaged ? AppTheme.error : AppTheme.success)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isHovered ? AppTheme.hover : Color.clear)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Diff Panel View
struct DiffPanelView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack {
            if let commit = appState.selectedCommit {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(commit.message)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)

                        HStack {
                            Text(commit.author)
                                .foregroundColor(AppTheme.textSecondary)
                            Text("•")
                                .foregroundColor(AppTheme.textMuted)
                            Text(commit.date, style: .relative)
                                .foregroundColor(AppTheme.textMuted)
                        }
                        .font(.system(size: 12))

                        Text(commit.sha)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(AppTheme.textMuted)

                        Divider()
                            .background(AppTheme.border)

                        Text("Changes will appear here...")
                            .foregroundColor(AppTheme.textMuted)
                    }
                    .padding()
                }
            } else {
                VStack {
                    Spacer()
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(AppTheme.textMuted)
                    Text("Select a commit to view diff")
                        .foregroundColor(AppTheme.textMuted)
                    Spacer()
                }
            }
        }
        .background(AppTheme.backgroundSecondary)
    }
}

// MARK: - Welcome View (Modern)
struct WelcomeView: View {
    let onOpen: () -> Void
    let onClone: () -> Void
    @EnvironmentObject var recentReposManager: RecentRepositoriesManager
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 0) {
            // Left side - Actions
            VStack(spacing: 24) {
                Spacer()

                // App Icon
                if let appIcon = NSImage(named: NSImage.applicationIconName) {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                } else {
                    // Fallback to SF Symbol if app icon not found
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppTheme.accent, AppTheme.info],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                Text("GitMac")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)

                Text("A Git client for Mac")
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.textSecondary)

                HStack(spacing: 16) {
                    WelcomeButton(icon: "folder", title: "Open", color: AppTheme.accent, action: onOpen)
                    WelcomeButton(icon: "arrow.down.circle", title: "Clone", color: AppTheme.success, action: onClone)
                    WelcomeButton(icon: "plus.circle", title: "Init", color: AppTheme.accent) {
                        NotificationCenter.default.post(name: .initRepository, object: nil)
                    }
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(AppTheme.background)

            // Right side - Recent repos
            VStack(alignment: .leading, spacing: 0) {
                Text("RECENT REPOSITORIES")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.textMuted)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                ScrollView {
                    VStack(spacing: 0) {
                        if recentReposManager.recentRepos.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "clock")
                                    .font(.system(size: 32))
                                    .foregroundColor(AppTheme.textMuted)
                                Text("No recent repositories")
                                    .foregroundColor(AppTheme.textMuted)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                        } else {
                            ForEach(recentReposManager.recentRepos) { repo in
                                RecentRepoRow(repo: repo)
                            }
                        }
                    }
                }
            }
            .frame(width: 320)
            .background(AppTheme.backgroundSecondary)
        }
    }
}

// MARK: - Welcome Button
struct WelcomeButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(isHovered ? .white : color)
            .frame(width: 80, height: 80)
            .background(isHovered ? color : color.opacity(0.15))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Recent Repo Row
struct RecentRepoRow: View {
    let repo: RecentRepository
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var recentReposManager: RecentRepositoriesManager
    @State private var isHovered = false

    var body: some View {
        Button {
            Task {
                await appState.openRepository(at: repo.path)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 20))
                    .foregroundColor(AppTheme.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(repo.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.textPrimary)
                    Text(repo.path)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textMuted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(isHovered ? AppTheme.hover : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Clone Repository Sheet
struct CloneRepositorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @State private var repoURL = ""
    @State private var destinationPath = ""
    @State private var isCloning = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Clone Repository")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Repository URL")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.textMuted)
                    DSTextField(placeholder: "https://github.com/user/repo.git", text: $repoURL)
                        .padding(10)
                        .background(AppTheme.backgroundTertiary)
                        .cornerRadius(6)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Destination")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.textMuted)
                    HStack {
                        DSTextField(placeholder: "Select destination folder", text: $destinationPath)
                            .padding(10)
                            .background(AppTheme.backgroundTertiary)
                            .cornerRadius(6)

                        Button("Browse") {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = false
                            panel.canChooseDirectories = true

                            panel.begin { response in
                                if response == .OK {
                                    Task { @MainActor in
                                        destinationPath = panel.url?.path ?? ""
                                    }
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)

                Spacer()

                Button("Clone") {
                    Task {
                        isCloning = true
                        await appState.cloneRepository(from: repoURL, to: destinationPath)
                        isCloning = false
                        if appState.errorMessage == nil { dismiss() }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(repoURL.isEmpty || destinationPath.isEmpty || isCloning)
            }
        }
        .padding(24)
        .frame(width: 480)
        .background(AppTheme.backgroundSecondary)
    }
}

// MARK: - Compact Repo Tab (for toolbar)
struct CompactRepoTab: View {
    let tab: RepositoryTab
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovered = false
    @ObservedObject private var groupsService = RepoGroupsService.shared

    var groupColor: Color? {
        let groups = groupsService.getGroupsForRepo(tab.repository.path)
        guard let firstGroup = groups.first else { return nil }
        return Color(hex: firstGroup.color)
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 4) {
                // Group color indicator
                if let color = groupColor {
                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                }

                // Repo name
                Text(tab.repository.name)
                    .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                    .foregroundColor(isActive ? AppTheme.textPrimary : AppTheme.textSecondary)
                    .lineLimit(1)

                // Close button (on hover)
                if isHovered {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(AppTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isActive ? AppTheme.backgroundSecondary : (isHovered ? AppTheme.hover : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Repository Tab Bar (Modern)
struct RepositoryTabBar: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var recentReposManager: RecentRepositoriesManager
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        HStack(spacing: 0) {
            // Tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 1) {
                    ForEach(appState.openTabs) { tab in
                        RepoTab(tab: tab)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Repository info (current branch, status)
            if let repo = appState.currentRepository {
                HStack(spacing: 8) {
                    // Current branch
                    if let branch = repo.currentBranch {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.system(size: 10))
                                .foregroundColor(AppTheme.accent)
                            Text(branch.name)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(AppTheme.textPrimary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(AppTheme.backgroundSecondary)
                        .cornerRadius(3)
                    }

                    // Uncommitted changes indicator
                    if !repo.status.staged.isEmpty || !repo.status.unstaged.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 5))
                                .foregroundColor(AppTheme.warning)
                            Text("\(repo.status.staged.count + repo.status.unstaged.count)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .background(AppTheme.warning.opacity(0.15))
                        .cornerRadius(3)
                    }
                }
                .padding(.horizontal, 8)
            }

            // Add new tab button
            Button {
                openNewRepository()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(AppTheme.accent)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .help("Open Repository")
        }
        .frame(height: 32)
        .background(AppTheme.background)
        .overlay(
            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private func openNewRepository() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a Git repository folder"
        panel.prompt = "Open"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            Task { @MainActor in
                await appState.openRepository(at: url.path)
                recentReposManager.addRecent(path: url.path, name: url.lastPathComponent)
            }
        }
    }
}

// MARK: - Single Repo Tab
struct RepoTab: View {
    let tab: RepositoryTab
    @EnvironmentObject var appState: AppState
    @StateObject private var themeManager = ThemeManager.shared
    @ObservedObject private var groupsService = RepoGroupsService.shared
    @State private var isHovered = false

    var isActive: Bool {
        appState.activeTabId == tab.id
    }

    var groupColor: Color? {
        let groups = groupsService.getGroupsForRepo(tab.repository.path)
        guard let firstGroup = groups.first else { return nil }
        return Color(hex: firstGroup.color)
    }

    var body: some View {
        HStack(spacing: 6) {
            // Group color indicator (left side)
            if let color = groupColor {
                Rectangle()
                    .fill(color)
                    .frame(width: 2)
            }

            HStack(spacing: 6) {
                // Repo name - compact
                Text(tab.repository.name)
                    .font(.system(size: 11, weight: isActive ? .medium : .regular))
                    .foregroundColor(isActive ? AppTheme.textPrimary : AppTheme.textSecondary)
                    .lineLimit(1)

                // Close button (show on hover or if active)
                if isHovered || isActive {
                    Button {
                        appState.closeTab(tab.id)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(AppTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(isActive ? AppTheme.backgroundSecondary : (isHovered ? AppTheme.hover : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(isActive ? AppTheme.border : Color.clear, lineWidth: 0.5)
        )
        .onHover { isHovered = $0 }
        .onTapGesture {
            appState.selectTab(tab.id)
        }
    }
}

// MARK: - Helpers
extension Set where Element == String {
    mutating func toggle(_ element: String) {
        if contains(element) {
            remove(element)
        } else {
            insert(element)
        }
    }
}

// MARK: - Create Branch Sheet (Standalone)
struct CreateBranchSheet: View {
    @EnvironmentObject var appState: AppState
    @Binding var isPresented: Bool

    @State private var branchName = ""
    @State private var baseBranch = "HEAD"
    @State private var checkoutAfterCreate = true
    @State private var isCreating = false
    @State private var errorMessage: String?

    var localBranches: [Branch] {
        appState.currentRepository?.branches ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Create New Branch")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.textMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(AppTheme.backgroundSecondary)

            Rectangle().fill(AppTheme.border).frame(height: 1)

            // Content
            VStack(alignment: .leading, spacing: 16) {
                // Branch name
                VStack(alignment: .leading, spacing: 6) {
                    Text("Branch Name")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)

                    DSTextField(placeholder: "feature/my-branch", text: $branchName)
                        .font(.system(size: 13))
                        .padding(8)
                        .background(AppTheme.backgroundSecondary)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(AppTheme.border, lineWidth: 1)
                        )
                }

                // Base branch
                VStack(alignment: .leading, spacing: 6) {
                    Text("Based On")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)

                    Picker("", selection: $baseBranch) {
                        Text("Current HEAD").tag("HEAD")
                        ForEach(localBranches) { branch in
                            Text(branch.name).tag(branch.name)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                // Checkout toggle
                Toggle(isOn: $checkoutAfterCreate) {
                    Text("Checkout after creating")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textSecondary)
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.error)
                }
            }
            .padding(16)

            Spacer()

            Rectangle().fill(AppTheme.border).frame(height: 1)

            // Footer
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.plain)
                .foregroundColor(AppTheme.textSecondary)

                Spacer()

                Button {
                    createBranch()
                } label: {
                    if isCreating {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 60)
                    } else {
                        Text("Create")
                            .frame(minWidth: 60)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(branchName.isEmpty || isCreating)
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 380, height: 320)
        .background(AppTheme.backgroundSecondary)
    }

    private func createBranch() {
        isCreating = true
        errorMessage = nil

        Task {
            do {
                _ = try await appState.gitService.createBranch(
                    named: branchName,
                    from: baseBranch,
                    checkout: checkoutAfterCreate
                )
                await appState.refresh()
                await MainActor.run {
                    isPresented = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isCreating = false
                }
            }
        }
    }
}

// MARK: - Operation Progress Overlay
struct OperationProgressOverlay: View {
    let message: String

    var body: some View {
        ZStack {
            AppTheme.background.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(.circular)

                Text(message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.backgroundSecondary)
                    .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
            )
        }
    }
}

// MARK: - Merge Branch Sheet
struct MergeBranchSheet: View {
    @EnvironmentObject var appState: AppState
    @Binding var isPresented: Bool

    @State private var selectedBranch: String = ""
    @State private var noFastForward = false
    @State private var isMerging = false
    @State private var errorMessage: String?
    @State private var isLoadingBranches = false
    @State private var availableBranches: [Branch] = []

    var currentBranchName: String {
        appState.currentRepository?.currentBranch?.name ?? "current branch"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Merge Branch")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()

                if isLoadingBranches {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 20, height: 20)
                }

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.textMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(AppTheme.backgroundSecondary)

            Rectangle().fill(AppTheme.border).frame(height: 1)

            // Content
            VStack(alignment: .leading, spacing: 16) {
                // Source branch
                VStack(alignment: .leading, spacing: 6) {
                    Text("Merge Branch")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)

                    Picker("", selection: $selectedBranch) {
                        Text("Select a branch...").tag("")
                        ForEach(availableBranches) { branch in
                            Text(branch.name).tag(branch.name)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .disabled(isLoadingBranches)
                }

                // Info
                if !selectedBranch.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.merge")
                            .foregroundColor(AppTheme.accent)
                        Text("Merge '\(selectedBranch)' into '\(currentBranchName)'")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .padding(10)
                    .background(AppTheme.backgroundSecondary)
                    .cornerRadius(6)
                }

                // Options
                Toggle(isOn: $noFastForward) {
                    Text("Create merge commit (no fast-forward)")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textSecondary)
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.error)
                }
            }
            .padding(16)

            Spacer()

            Rectangle().fill(AppTheme.border).frame(height: 1)

            // Footer
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.plain)
                .foregroundColor(AppTheme.textSecondary)

                Spacer()

                Button {
                    mergeBranch()
                } label: {
                    if isMerging {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 60)
                    } else {
                        Text("Merge")
                            .frame(minWidth: 60)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedBranch.isEmpty || isMerging)
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 400, height: 300)
        .background(AppTheme.backgroundSecondary)
        .task {
            await loadBranches()
        }
    }

    private func loadBranches() async {
        isLoadingBranches = true
        do {
            // Force refresh to get latest branches after pull
            try await appState.gitService.refresh()
            let branches = try await appState.gitService.getBranches()
            await MainActor.run {
                // Filter out current branch (can't merge into itself)
                availableBranches = branches.filter { !$0.isHead && !$0.isCurrent }
                isLoadingBranches = false
            }
        } catch {
            await MainActor.run {
                // Fallback to cached branches
                availableBranches = appState.currentRepository?.branches.filter { !$0.isHead } ?? []
                isLoadingBranches = false
            }
        }
    }

    private func mergeBranch() {
        guard !selectedBranch.isEmpty else { return }
        let currentBranch = appState.currentRepository?.currentBranch?.name ?? "HEAD"
        isMerging = true
        errorMessage = nil

        Task {
            do {
                try await appState.gitService.merge(branch: selectedBranch, noFastForward: noFastForward)
                await appState.refresh()

                // Track successful merge
                RemoteOperationTracker.shared.recordMerge(
                    success: true,
                    sourceBranch: selectedBranch,
                    targetBranch: currentBranch
                )

                await MainActor.run {
                    isPresented = false
                }
            } catch {
                // Track failed merge
                RemoteOperationTracker.shared.recordMerge(
                    success: false,
                    sourceBranch: selectedBranch,
                    targetBranch: currentBranch,
                    error: error.localizedDescription
                )

                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isMerging = false
                }
            }
        }
    }
}

// MARK: - Team Activity Panel

struct TeamActivityPanel: View {
    @Binding var height: CGFloat
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Resizer handle
            UniversalResizer(
                dimension: $height,
                minDimension: 150,
                maxDimension: 500,
                orientation: .vertical
            )

            // Team Activity content
            TeamActivityView()
                .frame(height: height)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

/// Team activity view to prevent merge conflicts
struct TeamActivityView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = TeamActivityViewModel()
    @State private var selectedMember: TeamMember?
    @State private var showConflictAlert = false

    var body: some View {
        HSplitView {
            // Left: Team members list
            VStack(spacing: 0) {
                teamListHeader
                Divider()
                teamMembersList
            }
            .frame(minWidth: 280, idealWidth: 320)

            // Right: Member activity detail
            if let member = selectedMember {
                memberDetailView(member)
            } else {
                emptyStateView
            }
        }
        .task {
            if let repo = appState.currentRepository,
               let remote = repo.remotes.first(where: { $0.isGitHub }),
               let ownerRepo = remote.ownerAndRepo {
                await viewModel.loadTeamActivity(
                    owner: ownerRepo.owner,
                    repo: ownerRepo.repo,
                    localChanges: []
                )
                if let firstMember = viewModel.teamMembers.first {
                    selectedMember = firstMember
                }
            }
        }
        .alert("Potential Conflicts Detected", isPresented: $showConflictAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.conflictMessage)
        }
    }

    // MARK: - Team List Header

    private var teamListHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Team Activity")
                    .font(.headline)

                Text("\(viewModel.teamMembers.count) active members")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()

            // Refresh button
            Button {
                Task { await refreshActivity() }
            } label: {
                Image(systemName: viewModel.isLoading ? "arrow.clockwise" : "arrow.clockwise")
                    .rotationEffect(.degrees(viewModel.isLoading ? 360 : 0))
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.isLoading)

            // Conflict indicator
            if viewModel.hasConflicts {
                Button {
                    showConflictAlert = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("\(viewModel.conflictCount)")
                    }
                    .foregroundColor(AppTheme.warning)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Team Members List

    private var teamMembersList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.teamMembers) { member in
                    TeamMemberRow(
                        member: member,
                        isSelected: selectedMember?.id == member.id,
                        onSelect: { selectedMember = member }
                    )
                }
            }
            .padding()
        }
    }

    // MARK: - Member Detail View

    private func memberDetailView(_ member: TeamMember) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Member header
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: member.user.avatarUrl)) { image in
                        image.resizable()
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(member.user.login)
                            .font(.title2)
                            .fontWeight(.bold)

                        HStack(spacing: 12) {
                            Label("\(member.activePRs.count) PRs", systemImage: "arrow.triangle.pull")
                                .font(.caption)
                                .foregroundColor(AppTheme.accent)

                            Label("\(member.filesBeingModified.count) files", systemImage: "doc.text")
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }

                    Spacer()

                    if let lastActive = member.lastActiveDate {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Last active")
                                .font(.caption2)
                                .foregroundColor(AppTheme.textSecondary)
                            Text(formatDate(lastActive))
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)

                // Active PRs
                if !member.activePRs.isEmpty {
                    activePRsSection(member)
                }

                // Files being modified
                if !member.filesBeingModified.isEmpty {
                    filesBeingModifiedSection(member)
                }

                // Recent commits
                if !member.recentCommits.isEmpty {
                    recentCommitsSection(member)
                }
            }
            .padding()
        }
    }

    private func activePRsSection(_ member: TeamMember) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Active Pull Requests")
                .font(.headline)

            ForEach(member.activePRs, id: \.number) { pr in
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.pull")
                        .foregroundColor(AppTheme.success)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("#\(pr.number) \(pr.title)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)

                        HStack(spacing: 8) {
                            Text(pr.head.ref)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppTheme.accent.opacity(0.2))
                                .foregroundColor(AppTheme.accent)
                                .cornerRadius(4)

                            Image(systemName: "arrow.right")
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)

                            Text(pr.base.ref)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppTheme.success.opacity(0.2))
                                .foregroundColor(AppTheme.success)
                                .cornerRadius(4)
                        }
                    }

                    Spacer()

                    Button {
                        if let url = URL(string: pr.htmlUrl) {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                    }
                    .buttonStyle(.borderless)
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
            }
        }
    }

    private func filesBeingModifiedSection(_ member: TeamMember) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Files Being Modified")
                .font(.headline)

            ForEach(member.filesBeingModified) { file in
                HStack(spacing: 8) {
                    StatusIcon(status: fileStatus(file.status))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(file.filename)
                            .font(.caption)
                            .fontWeight(.medium)

                        if let source = file.source {
                            Text("in \(source)")
                                .font(.caption2)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }

                    Spacer()

                    // Conflict warning
                    if file.hasConflict {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text("Conflict")
                        }
                        .font(.caption2)
                        .foregroundColor(AppTheme.warning)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(4)
                    }

                    HStack(spacing: 4) {
                        Text("+\(file.additions)")
                            .foregroundColor(AppTheme.success)
                        Text("-\(file.deletions)")
                            .foregroundColor(AppTheme.error)
                    }
                    .font(.caption2.monospacedDigit())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(file.hasConflict ? Color.orange.opacity(0.05) : Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
            }
        }
    }

    private func recentCommitsSection(_ member: TeamMember) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Commits")
                .font(.headline)

            ForEach(member.recentCommits) { commit in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 8))
                        .foregroundColor(AppTheme.accent)
                        .padding(.top, 6)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(commit.commit.message.components(separatedBy: "\n").first ?? commit.commit.message)
                            .font(.caption)
                            .lineLimit(2)

                        HStack(spacing: 8) {
                            Text(commit.sha.prefix(7))
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(AppTheme.textSecondary)

                            Text(formatDate(commit.commit.author.date))
                                .font(.caption2)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 64))
                .foregroundColor(AppTheme.textSecondary)

            Text("No Team Member Selected")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Select a team member to view their activity")
                .font(.callout)
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func fileStatus(_ status: String) -> FileStatusType {
        switch status {
        case "added": return .added
        case "removed": return .deleted
        case "modified": return .modified
        case "renamed": return .renamed
        default: return .modified
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return dateString }

        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .abbreviated
        return relative.localizedString(for: date, relativeTo: Date())
    }

    private func formatDate(_ date: Date) -> String {
        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .abbreviated
        return relative.localizedString(for: date, relativeTo: Date())
    }

    private func refreshActivity() async {
        if let repo = appState.currentRepository,
           let remote = repo.remotes.first(where: { $0.isGitHub }),
           let ownerRepo = remote.ownerAndRepo {
            await viewModel.loadTeamActivity(
                owner: ownerRepo.owner,
                repo: ownerRepo.repo,
                localChanges: []
            )
        }
    }
}

// MARK: - View Model

@MainActor
class TeamActivityViewModel: ObservableObject {
    @Published var teamMembers: [TeamMember] = []
    @Published var isLoading = false
    @Published var hasConflicts = false
    @Published var conflictCount = 0
    @Published var conflictMessage = ""

    private let githubService = GitHubService()

    func loadTeamActivity(owner: String, repo: String, localChanges: [StagingFile]) async {
        isLoading = true

        do {
            // Get all open PRs
            let openPRs = try await githubService.listPullRequests(
                owner: owner,
                repo: repo,
                state: .open
            )

            // Group PRs by author
            var memberDict: [String: TeamMember] = [:]
            let localFilePaths = Set(localChanges.map { $0.path })

            for pr in openPRs {
                let userId = pr.user.login

                // Get files for this PR
                let prFiles = try await githubService.getPullRequestFiles(
                    owner: owner,
                    repo: repo,
                    number: pr.number
                )

                // Convert to FileBeingModified with conflict detection
                let filesBeingModified = prFiles.map { file in
                    FileBeingModified(
                        filename: file.filename,
                        status: file.status,
                        additions: file.additions,
                        deletions: file.deletions,
                        source: "PR #\(pr.number)",
                        hasConflict: localFilePaths.contains(file.filename)
                    )
                }

                // Get recent commits for the PR branch
                let recentCommits = try await githubService.getCommitsForBranch(
                    owner: owner,
                    repo: repo,
                    branch: pr.head.ref,
                    since: Calendar.current.date(byAdding: .day, value: -7, to: Date())
                )

                if var member = memberDict[userId] {
                    member.activePRs.append(pr)
                    member.filesBeingModified.append(contentsOf: filesBeingModified)
                    member.recentCommits.append(contentsOf: recentCommits)

                    // Update last active date
                    if let prUpdated = ISO8601DateFormatter().date(from: pr.updatedAt),
                       let currentLast = member.lastActiveDate {
                        member.lastActiveDate = max(currentLast, prUpdated)
                    } else if let prUpdated = ISO8601DateFormatter().date(from: pr.updatedAt) {
                        member.lastActiveDate = prUpdated
                    }

                    memberDict[userId] = member
                } else {
                    let lastActiveDate = ISO8601DateFormatter().date(from: pr.updatedAt)
                    memberDict[userId] = TeamMember(
                        user: pr.user,
                        activePRs: [pr],
                        filesBeingModified: filesBeingModified,
                        recentCommits: recentCommits,
                        lastActiveDate: lastActiveDate
                    )
                }
            }

            teamMembers = Array(memberDict.values).sorted { a, b in
                (a.lastActiveDate ?? .distantPast) > (b.lastActiveDate ?? .distantPast)
            }

            // Calculate conflicts
            let allConflicts = teamMembers.flatMap { $0.filesBeingModified }.filter { $0.hasConflict }
            conflictCount = allConflicts.count
            hasConflicts = conflictCount > 0

            if hasConflicts {
                let uniqueFiles = Set(allConflicts.map { $0.filename })
                conflictMessage = """
                You have local changes to \(uniqueFiles.count) file(s) that are also being modified by your team:

                \(uniqueFiles.sorted().prefix(5).joined(separator: "\n"))
                \(uniqueFiles.count > 5 ? "\n...and \(uniqueFiles.count - 5) more" : "")
                """
            }
        } catch {
            print("Failed to load team activity: \(error)")
        }

        isLoading = false
    }
}

// MARK: - Supporting Views

struct TeamMemberRow: View {
    let member: TeamMember
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: member.user.avatarUrl)) { image in
                image.resizable()
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(AppTheme.textSecondary)
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(member.user.login)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    Label("\(member.activePRs.count)", systemImage: "arrow.triangle.pull")
                        .font(.caption2)
                        .foregroundColor(AppTheme.accent)

                    Label("\(member.filesBeingModified.count)", systemImage: "doc.text")
                        .font(.caption2)
                        .foregroundColor(AppTheme.textSecondary)

                    if member.filesBeingModified.contains(where: { $0.hasConflict }) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundColor(AppTheme.warning)
                    }
                }
            }

            Spacer()
        }
        .padding(12)
        .background(isSelected ? AppTheme.accent.opacity(0.2) : Color.clear)
        .cornerRadius(8)
        .onTapGesture { onSelect() }
    }
}

// MARK: - Models

struct TeamMember: Identifiable {
    var id: String { user.login }
    let user: GitHubUser
    var activePRs: [GitHubPullRequest]
    var filesBeingModified: [FileBeingModified]
    var recentCommits: [GitHubCommit]
    var lastActiveDate: Date?
}

struct FileBeingModified: Identifiable {
    var id: String { filename }
    let filename: String
    let status: String
    let additions: Int
    let deletions: Int
    let source: String?
    let hasConflict: Bool
}

// MARK: - Init Repository Sheet
struct InitRepositorySheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var localPath: String = NSHomeDirectory() + "/Documents"
    @State private var repositoryName: String = ""
    @State private var initialBranch: String = "main"
    @State private var createReadme: Bool = true
    @State private var createGitignore: Bool = true
    @State private var gitignoreTemplate: String = "macOS"
    @State private var isCreating: Bool = false
    @State private var error: String?

    private let gitignoreTemplates = ["None", "macOS", "Swift", "Python", "Node", "Java", "Go"]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(DesignTokens.Typography.iconXL)
                    .foregroundColor(AppTheme.success)
                Text("Initialize Repository")
                    .font(DesignTokens.Typography.headline)
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(DesignTokens.Typography.callout)
                        .foregroundColor(AppTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(DesignTokens.Spacing.lg)

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Text("Repository Name")
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(AppTheme.textSecondary)
                        DSTextField(placeholder: "my-project", text: $repositoryName)
                            .disabled(isCreating)
                    }

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Text("Location")
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(AppTheme.textSecondary)
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            DSTextField(placeholder: "/path/to/parent/directory", text: $localPath)
                                .disabled(isCreating)
                            Button("Browse") { selectLocalPath() }
                                .disabled(isCreating)
                        }
                        if !repositoryName.isEmpty {
                            Text("Will create: \(localPath)/\(repositoryName)")
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(AppTheme.textMuted)
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Text("Initial Branch")
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(AppTheme.textSecondary)
                        DSTextField(placeholder: "main", text: $initialBranch)
                            .disabled(isCreating)
                    }

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Text("Initial Files")
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(AppTheme.textSecondary)
                        Toggle("Create README.md", isOn: $createReadme)
                            .disabled(isCreating)
                        Toggle("Create .gitignore", isOn: $createGitignore)
                            .disabled(isCreating)
                        if createGitignore {
                            Picker("Template", selection: $gitignoreTemplate) {
                                ForEach(gitignoreTemplates, id: \.self) { template in
                                    Text(template).tag(template)
                                }
                            }
                            .pickerStyle(.menu)
                            .disabled(isCreating)
                        }
                    }

                    if let error = error {
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(AppTheme.error)
                            Text(error)
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(AppTheme.error)
                        }
                        .padding(DesignTokens.Spacing.md)
                        .background(AppTheme.error.opacity(0.1))
                        .cornerRadius(DesignTokens.CornerRadius.md)
                    }

                    if isCreating {
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            ProgressView().scaleEffect(0.8)
                            Text("Creating repository...")
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                }
                .padding(DesignTokens.Spacing.lg)
            }

            Divider()

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
                    .disabled(isCreating)
                Spacer()
                Button("Initialize") { initRepository() }
                    .keyboardShortcut(.return)
                    .disabled(repositoryName.isEmpty || localPath.isEmpty || isCreating)
                    .buttonStyle(.borderedProminent)
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .frame(width: 500, height: 550)
        .background(AppTheme.background)
    }

    private func selectLocalPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.message = "Select parent directory"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            localPath = url.path
        }
    }

    private func initRepository() {
        guard !repositoryName.isEmpty else { return }
        isCreating = true
        error = nil
        Task {
            do {
                let repoPath = "\(localPath)/\(repositoryName)"
                try FileManager.default.createDirectory(atPath: repoPath, withIntermediateDirectories: true)
                let initProcess = Process()
                initProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
                initProcess.arguments = ["init", "-b", initialBranch]
                initProcess.currentDirectoryURL = URL(fileURLWithPath: repoPath)
                try initProcess.run()
                initProcess.waitUntilExit()
                if createReadme {
                    try "# \(repositoryName)\n\nA new repository.\n".write(toFile: "\(repoPath)/README.md", atomically: true, encoding: .utf8)
                }
                if createGitignore && gitignoreTemplate != "None" {
                    try getGitignoreContent(for: gitignoreTemplate).write(toFile: "\(repoPath)/.gitignore", atomically: true, encoding: .utf8)
                }
                if createReadme || createGitignore {
                    let addProcess = Process()
                    addProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
                    addProcess.arguments = ["add", "."]
                    addProcess.currentDirectoryURL = URL(fileURLWithPath: repoPath)
                    try addProcess.run()
                    addProcess.waitUntilExit()
                    let commitProcess = Process()
                    commitProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
                    commitProcess.arguments = ["commit", "-m", "Initial commit"]
                    commitProcess.currentDirectoryURL = URL(fileURLWithPath: repoPath)
                    try commitProcess.run()
                    commitProcess.waitUntilExit()
                }
                await appState.openRepository(at: repoPath)
                await MainActor.run { dismiss() }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isCreating = false
                }
            }
        }
    }

    private func getGitignoreContent(for template: String) -> String {
        switch template {
        case "macOS": return ".DS_Store\n.AppleDouble\n.LSOverride\n._*\n"
        case "Swift": return ".DS_Store\n*.xcodeproj\nxcuserdata/\nDerivedData/\n.build/\n"
        case "Python": return "__pycache__/\n*.py[cod]\n.Python\nvenv/\n.env\n"
        case "Node": return "node_modules/\nnpm-debug.log\n.env\ndist/\n"
        case "Java": return "*.class\n*.jar\ntarget/\nbuild/\n"
        case "Go": return "*.exe\n*.test\n*.out\nvendor/\n"
        default: return ""
        }
    }
}

// MARK: - Group Management Sheet
struct GroupManagementSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var groupsService = RepoGroupsService.shared
    @State private var editingGroup: RepoGroupsService.RepoGroup?
    @State private var showCreateGroup = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "folder.badge.gearshape")
                    .font(DesignTokens.Typography.iconXL)
                    .foregroundColor(AppTheme.accent)
                Text("Manage Groups")
                    .font(DesignTokens.Typography.headline)
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(DesignTokens.Typography.callout)
                        .foregroundColor(AppTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(DesignTokens.Spacing.lg)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    if groupsService.groups.isEmpty {
                        VStack(spacing: DesignTokens.Spacing.md) {
                            Image(systemName: "folder.badge.questionmark")
                                .font(DesignTokens.Typography.iconXXXL)
                                .foregroundColor(AppTheme.textSecondary)
                            Text("No groups yet")
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignTokens.Spacing.xxl)
                    } else {
                        ForEach(groupsService.groups.sorted(by: { $0.sortOrder < $1.sortOrder })) { group in
                            GroupManagementRow(group: group, onEdit: {
                                editingGroup = group
                            }, onDelete: {
                                groupsService.deleteGroup(group.id)
                            })
                        }
                    }
                }
                .padding(DesignTokens.Spacing.lg)
            }

            Divider()

            HStack {
                DSButton("Done", variant: .secondary, size: .sm) {
                    dismiss()
                }
                Spacer()
                Button { showCreateGroup = true } label: {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        Image(systemName: "plus.circle.fill")
                        Text("Create Group")
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .frame(width: 500, height: 400)
        .background(AppTheme.background)
        .sheet(isPresented: $showCreateGroup) { CreateGroupSheet() }
        .sheet(item: $editingGroup) { group in EditGroupSheet(group: group) }
    }
}

struct GroupManagementRow: View {
    let group: RepoGroupsService.RepoGroup
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Circle()
                .fill(Color(hex: group.color))
                .frame(width: 12, height: 12)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(group.name)
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(AppTheme.textPrimary)
                Text("\(group.repos.count) repositories")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.textMuted)
            }
            Spacer()
            if isHovered {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Button { onEdit() } label: {
                        Image(systemName: "pencil")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                    Button { onDelete() } label: {
                        Image(systemName: "trash")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(AppTheme.error)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(isHovered ? AppTheme.hover : Color.clear)
        .cornerRadius(DesignTokens.CornerRadius.md)
        .onHover { isHovered = $0 }
    }
}

struct CreateGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var groupsService = RepoGroupsService.shared
    @State private var groupName = ""
    @State private var selectedColor = "007AFF"
    private let availableColors = [
        ("Blue", "007AFF"), ("Purple", "5E5CE6"), ("Pink", "FF2D55"),
        ("Red", "FF3B30"), ("Orange", "FF9500"), ("Yellow", "FFCC00"),
        ("Green", "34C759"), ("Teal", "5AC8FA"), ("Indigo", "5856D6")
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Create Group")
                    .font(DesignTokens.Typography.headline)
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(DesignTokens.Spacing.lg)

            Divider()

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Group Name")
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(AppTheme.textPrimary)
                    DSTextField(placeholder: "Work Projects", text: $groupName)
                }
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Color")
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(AppTheme.textPrimary)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: DesignTokens.Spacing.md) {
                        ForEach(availableColors, id: \.1) { _, hex in
                            ColorPickerButton(
                                color: Color(hex: hex),
                                isSelected: selectedColor == hex
                            ) {
                                selectedColor = hex
                            }
                        }
                    }
                }
            }
            .padding(DesignTokens.Spacing.lg)

            Spacer()
            Divider()

            HStack {
                DSButton("Cancel", variant: .secondary, size: .sm) {
                    dismiss()
                }
                Spacer()
                Button("Create") {
                    _ = groupsService.createGroup(name: groupName, color: selectedColor)
                    dismiss()
                }
                .keyboardShortcut(.return)
                .disabled(groupName.isEmpty)
                .buttonStyle(.borderedProminent)
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .frame(width: 400, height: 300)
        .background(AppTheme.background)
    }
}

struct EditGroupSheet: View {
    let group: RepoGroupsService.RepoGroup
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var groupsService = RepoGroupsService.shared
    @State private var groupName: String
    @State private var selectedColor: String
    private let availableColors = [
        ("Blue", "007AFF"), ("Purple", "5E5CE6"), ("Pink", "FF2D55"),
        ("Red", "FF3B30"), ("Orange", "FF9500"), ("Yellow", "FFCC00"),
        ("Green", "34C759"), ("Teal", "5AC8FA"), ("Indigo", "5856D6")
    ]

    init(group: RepoGroupsService.RepoGroup) {
        self.group = group
        _groupName = State(initialValue: group.name)
        _selectedColor = State(initialValue: group.color)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Edit Group")
                    .font(DesignTokens.Typography.headline)
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(DesignTokens.Spacing.lg)

            Divider()

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Group Name")
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(AppTheme.textPrimary)
                    DSTextField(placeholder: "Work Projects", text: $groupName)
                }
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Color")
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(AppTheme.textPrimary)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: DesignTokens.Spacing.md) {
                        ForEach(availableColors, id: \.1) { _, hex in
                            ColorPickerButton(
                                color: Color(hex: hex),
                                isSelected: selectedColor == hex
                            ) {
                                selectedColor = hex
                            }
                        }
                    }
                }
            }
            .padding(DesignTokens.Spacing.lg)

            Spacer()
            Divider()

            HStack {
                DSButton("Cancel", variant: .secondary, size: .sm) {
                    dismiss()
                }
                Spacer()
                Button("Save") {
                    var updatedGroup = group
                    updatedGroup.name = groupName
                    updatedGroup.color = selectedColor
                    groupsService.updateGroup(updatedGroup)
                    dismiss()
                }
                .keyboardShortcut(.return)
                .disabled(groupName.isEmpty)
                .buttonStyle(.borderedProminent)
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .frame(width: 400, height: 300)
        .background(AppTheme.background)
    }
}

struct ColorPickerButton: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 32, height: 32)
                .overlay(
                    Circle()
                        .strokeBorder(Color.white, lineWidth: isSelected ? 3 : 0)
                )
                .overlay(
                    Circle()
                        .strokeBorder(AppTheme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
