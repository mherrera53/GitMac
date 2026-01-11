import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var recentReposManager: RecentRepositoriesManager
    @EnvironmentObject var themeManager: ThemeManager
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
    @AppStorage("toolbarDisplayMode") private var toolbarDisplayMode: ToolbarDisplayMode = .iconAndText

    enum ToolbarDisplayMode: String, CaseIterable {
        case iconOnly = "Icon Only"
        case iconAndText = "Icon and Text"
    }

    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var selectedFileDiff: FileDiff? = nil

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
                bottomPanelManager: bottomPanelManager,
                toolbarDisplayMode: $toolbarDisplayMode
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
            .onReceive(NotificationCenter.default.publisher(for: .openRepository)) { _ in showOpenPanel = true }
            .onReceive(NotificationCenter.default.publisher(for: .cloneRepository)) { _ in showCloneSheet = true }
            .onReceive(NotificationCenter.default.publisher(for: .newBranch)) { _ in showNewBranchSheet = true }
            .modifier(GitOperationListeners())
            .modifier(NavigationListeners(columnVisibility: $columnVisibility, selectedFileDiff: $selectedFileDiff))
    }

    struct GitOperationListeners: ViewModifier {
        @EnvironmentObject var appState: AppState
        func body(content: Content) -> some View {
            content
                .onReceive(NotificationCenter.default.publisher(for: .fetch)) { _ in Task { await GitOperationHandler(appState: appState).handleFetch() } }
                .onReceive(NotificationCenter.default.publisher(for: .pull)) { _ in Task { await GitOperationHandler(appState: appState).handlePull() } }
                .onReceive(NotificationCenter.default.publisher(for: .push)) { _ in Task { await GitOperationHandler(appState: appState).handlePush() } }
                .onReceive(NotificationCenter.default.publisher(for: .stash)) { _ in Task { await GitOperationHandler(appState: appState).handleStash() } }
                .onReceive(NotificationCenter.default.publisher(for: .popStash)) { _ in Task { await GitOperationHandler(appState: appState).handlePopStash() } }
                .onReceive(NotificationCenter.default.publisher(for: .applyStash)) { notification in 
                    if let index = notification.object as? Int {
                        Task { await GitOperationHandler(appState: appState).handleApplyStash(index: index) }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .popStashAtIndex)) { notification in 
                    if let index = notification.object as? Int {
                        Task { await GitOperationHandler(appState: appState).handlePopStash(index: index) }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .dropStash)) { notification in
                    if let index = notification.object as? Int {
                        Task { await GitOperationHandler(appState: appState).handleDropStash(index: index) }
                    }
                }
        }
    }

    struct NavigationListeners: ViewModifier {
        @Binding var columnVisibility: NavigationSplitViewVisibility
        @Binding var selectedFileDiff: FileDiff?
        func body(content: Content) -> some View {
            content
                .onReceive(NotificationCenter.default.publisher(for: .showGraph)) { _ in
                    selectedFileDiff = nil
                }
                .onReceive(NotificationCenter.default.publisher(for: .showHistory)) { _ in
                    // Logic to show history if it's a separate view state
                    // For now, history is often part of the graph or a separate tab
                    NotificationCenter.default.post(name: .showHistory, object: nil)
                }
                .onReceive(NotificationCenter.default.publisher(for: .toggleSidebar)) { _ in
                    withAnimation {
                        columnVisibility = columnVisibility == .all ? .detailOnly : .all
                    }
                }
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

    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showInspector: Bool = true
    @Binding var toolbarDisplayMode: ContentView.ToolbarDisplayMode

    /// Toolbar color scheme that follows theme settings properly
    /// - .light theme → light color scheme
    /// - .dark or .custom theme → dark color scheme
    /// - .system theme → nil (follows system appearance)
    private var toolbarColorScheme: SwiftUI.ColorScheme? {
        switch ThemeManager.shared.currentTheme {
        case .light:
            return .light
        case .dark, .custom:
            return .dark
        case .system:
            return nil
        }
    }

    private var toolbarConfigurationMenu: some View {
        Group {
            if #available(macOS 14.0, *) {
                ControlGroup {
                    ForEach(ContentView.ToolbarDisplayMode.allCases, id: \.self) { mode in
                        Button(mode.rawValue) {
                             toolbarDisplayMode = mode // Update binding
                        }
                    }
                } label: {
                    Text("Toolbar Display")
                }
            } else {
                Text("Toolbar Display")
                ForEach(ContentView.ToolbarDisplayMode.allCases, id: \.self) { mode in
                    Button(mode.rawValue) {
                         toolbarDisplayMode = mode
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var centerColumn: some View {
        // Center Area - Graph/Diff + Bottom Panel
        VStack(spacing: 0) {
            // "Defining Space" for Repository Tabs
            if !appState.openTabs.isEmpty {
                RepositoryTabsView()
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, 6)
                    .background(.thinMaterial)
                    .overlay(Divider(), alignment: .bottom)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            // Center Panel - Graph OR Diff
            CenterPanel(selectedFileDiff: $selectedFileDiff, isLoadingDiff: $isLoadingDiff)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Bottom Panel (Terminal/Logs) - Resizable
            if bottomPanelManager.isPanelVisible {
                 UnifiedBottomPanel(panelManager: bottomPanelManager)
                     .frame(height: bottomPanelManager.panelHeight)
                     .transition(.move(edge: .bottom))
                     // Force recreation of the panel when repository changes to ensure
                     // correct context (Terminal sessions, Integration tabs, etc.)
                     .id(appState.currentRepository?.id.uuidString ?? "no-repo")
            }
        }
        .contextMenu { toolbarConfigurationMenu }
        .onReceive(NotificationCenter.default.publisher(for: .showGraph)) { _ in
            selectedFileDiff = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: .showHistory)) { _ in
            selectedFileDiff = nil
        }
    }

    // Simplified Toolbar Sections
    private var toolbarGitActions: some View {
        Group {
            if appState.currentRepository != nil {
                HStack(spacing: 0) {
                    // Separator
                    Rectangle()
                        .fill(AppTheme.border)
                        .frame(width: 1, height: 24)
                        .padding(.horizontal, 8)
                    
                    // Toolbar Actions - Using XcodeToolbarButton for proper rendering
                    HStack(spacing: 4) {
                        XcodeToolbarButton(icon: "arrow.down.to.line", color: Color(nsColor: .systemBlue)) {
                            NotificationCenter.default.post(name: .pull, object: nil)
                        }
                        .help("Pull")

                        XcodeToolbarButton(icon: "arrow.counterclockwise", color: Color(nsColor: .systemBlue)) {
                            NotificationCenter.default.post(name: .fetch, object: nil)
                        }
                        .help("Fetch")

                        XcodeToolbarButton(icon: "arrow.up.to.line", color: Color(nsColor: .systemGreen)) {
                            NotificationCenter.default.post(name: .push, object: nil)
                        }
                        .help("Push")

                        XcodeToolbarButton(icon: "arrow.triangle.branch", color: Color(nsColor: .systemBlue)) {
                            NotificationCenter.default.post(name: .newBranch, object: nil)
                        }
                        .help("New Branch")

                        XcodeToolbarButton(icon: "tray.and.arrow.down", color: Color(nsColor: .systemOrange)) {
                            NotificationCenter.default.post(name: .stash, object: nil)
                        }
                        .help("Stash")

                        XcodeToolbarButton(icon: "tray.and.arrow.up", color: Color(nsColor: .systemOrange)) {
                            NotificationCenter.default.post(name: .popStash, object: nil)
                        }
                        .help("Pop Stash")

                        XcodeToolbarButton(icon: "terminal", color: Color(nsColor: .labelColor)) {
                            bottomPanelManager.openTab(type: .terminal)
                        }
                        .help("Terminal")
                    }
                }
            }
        }
    }
    
    // Right side toolbar buttons (Settings + Sidebar toggles)
    private var toolbarRightActions: some View {
        Group {
            // Settings Button
            if #available(macOS 14.0, *) {
                SettingsLink {
                    Image(systemName: "gearshape.fill")
                        .renderingMode(.template)
                        .font(.system(size: DesignTokens.Toolbar.iconSize, weight: .regular))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(
                            width: DesignTokens.Toolbar.iconOnlyButtonSize.width,
                            height: DesignTokens.Toolbar.iconOnlyButtonSize.height
                        )
                }
                .buttonStyle(.plain)
                .help("Settings (⌘,)")
            } else {
                XcodeToolbarButton(icon: "gearshape.fill", color: AppTheme.textSecondary) {
                    NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                }
                .help("Settings (⌘,)")
            }

            // Inspector Toggle (Right Panel)
            XcodeToolbarButton(icon: "sidebar.trailing", color: showInspector ? AppTheme.accent : AppTheme.textSecondary) {
                withAnimation {
                    showInspector.toggle()
                }
            }
            .help("Toggle Inspector")
        }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Left Panel - Branches/Remotes/Tags
            LeftSidebarPanel()
                .navigationSplitViewColumnWidth(min: DesignTokens.Layout.Sidebar.minWidth, ideal: DesignTokens.Layout.Sidebar.idealWidth, max: DesignTokens.Layout.Sidebar.maxWidth)
                .background(AppTheme.sidebar)
        } detail: {
            // Center content - expands when inspector is hidden
            centerColumn
        }
        .navigationSplitViewStyle(.prominentDetail)
        .inspector(isPresented: $showInspector) {
            // Right Panel - Staging/Commit (proper inspector behavior)
            RightStagingPanel(selectedFileDiff: $selectedFileDiff, isLoadingDiff: $isLoadingDiff)
                .inspectorColumnWidth(min: DesignTokens.Layout.StagingPanel.minWidth, ideal: DesignTokens.Layout.StagingPanel.idealWidth, max: DesignTokens.Layout.StagingPanel.maxWidth)
                .background(AppTheme.background)
        }
        // .windowTitleHidden() // Hide system title to prevent duplicates with custom title
        .navigationTitle("") // Hide system title
        .toolbar {
            // All actions centered
            ToolbarItem(placement: .principal) {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    // Git Actions
                    if appState.currentRepository != nil {
                        XcodeToolbarButton(icon: "arrow.down.to.line", color: AppTheme.info) {
                            NotificationCenter.default.post(name: .pull, object: nil)
                        }
                        .help("Pull")

                        XcodeToolbarButton(icon: "arrow.counterclockwise", color: AppTheme.info) {
                            NotificationCenter.default.post(name: .fetch, object: nil)
                        }
                        .help("Fetch")

                        XcodeToolbarButton(icon: "arrow.up.to.line", color: AppTheme.success) {
                            NotificationCenter.default.post(name: .push, object: nil)
                        }
                        .help("Push")

                        // CI/CD Status Badge
                        CICDToolbarBadge(repoPath: appState.currentRepository?.path)

                        XcodeToolbarButton(icon: "arrow.triangle.branch", color: AppTheme.info) {
                            NotificationCenter.default.post(name: .newBranch, object: nil)
                        }
                        .help("New Branch")

                        XcodeToolbarButton(icon: "tray.and.arrow.down", color: AppTheme.warning) {
                            NotificationCenter.default.post(name: .stash, object: nil)
                        }
                        .help("Stash")

                        XcodeToolbarButton(icon: "tray.and.arrow.up", color: AppTheme.warning) {
                            NotificationCenter.default.post(name: .popStash, object: nil)
                        }
                        .help("Pop Stash")

                        XcodeToolbarButton(icon: "terminal", color: AppTheme.textSecondary) {
                            bottomPanelManager.openTab(type: .terminal)
                        }
                        .help("Terminal")

                        Divider().frame(height: 20)
                    }

                    // Integrations
                    XcodeToolbarButton(icon: "person.2.fill", color: AppTheme.accentPurple) {
                        bottomPanelManager.openTab(type: .teamActivity)
                    }
                    .help("Team Activity")

                    XcodeToolbarButton(icon: "tag.fill", color: AppTheme.success) {
                        bottomPanelManager.openTab(type: .taiga)
                    }
                    .help("Taiga")

                    XcodeToolbarButton(icon: "square.stack.3d.up", color: AppTheme.info) {
                        bottomPanelManager.openTab(type: .jira)
                    }
                    .help("Jira")

                    XcodeToolbarButton(icon: "lineweight", color: AppTheme.accentIndigo) {
                        bottomPanelManager.openTab(type: .linear)
                    }
                    .help("Linear")
                }
            }

            // Right side - only Settings and Inspector toggle
            ToolbarItemGroup(placement: .primaryAction) {
                if #available(macOS 14.0, *) {
                    SettingsLink {
                        Image(systemName: "gearshape.fill")
                            .renderingMode(.template)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .help("Settings")
                } else {
                    XcodeToolbarButton(icon: "gearshape.fill", color: AppTheme.textSecondary) {
                        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                    }
                    .help("Settings")
                }

                XcodeToolbarButton(icon: "sidebar.trailing", color: showInspector ? AppTheme.accent : AppTheme.textSecondary) {
                    withAnimation {
                        showInspector.toggle()
                    }
                }
                .help("Toggle Inspector")
            }
        }
        .toolbarBackground(AppTheme.background, for: .windowToolbar)
        .toolbarColorScheme(toolbarColorScheme, for: .windowToolbar)
        .preferredColorScheme(toolbarColorScheme)
        .id(themeRefreshTrigger)
        .onChange(of: appState.activeTabId) { _, _ in
            // Clear diff when switching repositories
            selectedFileDiff = nil
        }
    }
}
