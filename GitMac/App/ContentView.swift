import SwiftUI
import AppKit

struct ContentView: View {
    @Environment(AppState.self) var appState
    @EnvironmentObject var recentReposManager: RecentRepositoriesManager
    @Environment(ThemeManager.self) var themeManager
    var bottomPanelManager: BottomPanelManager
    @StateObject private var gitOperationHandler = GitOperationHandler()
    @State private var showCloneSheet = false
    @State private var showOpenPanel = false
    @State private var showNewBranchSheet = false
    @State private var showMergeSheet = false
    @State private var showSyncWizard = false
    @State private var showRepoStandards = false
    @State private var leftPanelWidth: CGFloat = 260
    @State private var rightPanelWidth: CGFloat = 380
    @State private var showRevertSheet = false
    @State private var revertCommits: [Commit] = []
    @State private var showDetachedHeadAlert = false
    @State private var themeRefreshTrigger = UUID()
    @State private var showBisectSheet = false
    @State private var showReflogSheet = false
    @State private var showGPGSSHSheet = false
    @State private var showInsightsSheet = false
    @State private var showFileBrowserSheet = false
    @State private var showLaunchpadSheet = false
    @State private var showLFSSheet = false
    @AppStorage("toolbarDisplayMode") private var toolbarDisplayMode: ToolbarDisplayMode = .iconAndText

    enum ToolbarDisplayMode: String, CaseIterable {
        case iconOnly = "Icon Only"
        case iconAndText = "Icon and Text"
    }

    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    init() {
        bottomPanelManager = BottomPanelManager.shared
    }

    var body: some View {
        attachGitListeners(to: mainLayout)
            .frame(minWidth: DesignTokens.Layout.Window.minWidth, minHeight: DesignTokens.Layout.Window.minHeight)
            .background(WindowScreenFittingView().allowsHitTesting(false).accessibilityHidden(true))
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
                    .environment(appState)
            }
            .sheet(isPresented: $showRevertSheet) {
                RevertView(targetCommits: revertCommits)
                    .environment(appState)
            }
            .sheet(isPresented: $showMergeSheet) {
                MergeBranchSheet(isPresented: $showMergeSheet)
                    .environment(appState)
            }
            .sheet(isPresented: $showSyncWizard) {
                SyncWizardSheet()
                    .environment(appState)
            }
            .sheet(isPresented: $showRepoStandards) {
                RepoStandardsSheet()
                    .environment(appState)
            }
            .modifier(FeatureSheetsBatch1(
                showBisect: $showBisectSheet,
                showReflog: $showReflogSheet,
                showGPGSSH: $showGPGSSHSheet
            ))
            .modifier(FeatureSheetsBatch2(
                showInsights: $showInsightsSheet,
                showFileBrowser: $showFileBrowserSheet,
                showLaunchpad: $showLaunchpadSheet,
                showLFS: $showLFSSheet
            ))
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
            .alert(
                pushConfirmationTitle,
                isPresented: Binding(
                    get: { gitOperationHandler.pendingPushConfirmation != nil },
                    set: { if !$0 { gitOperationHandler.pendingPushConfirmation = nil } }
                )
            ) {
                if let confirmation = gitOperationHandler.pendingPushConfirmation {
                    Button("Push Anyway", role: .destructive) {
                        Task { await confirmation.onConfirm() }
                    }
                    Button("Cancel", role: .cancel) {
                        confirmation.onCancel()
                    }
                }
            } message: {
                Text(pushConfirmationMessage)
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

    private var pushConfirmationTitle: String {
        guard let confirmation = gitOperationHandler.pendingPushConfirmation else { return "Push Confirmation" }
        if case .requiresConfirmation(_, let severity) = confirmation.result {
            return severity.title
        }
        return "Push Confirmation"
    }

    private var pushConfirmationMessage: String {
        guard let confirmation = gitOperationHandler.pendingPushConfirmation else { return "" }
        if case .requiresConfirmation(let reason, _) = confirmation.result {
            return reason
        }
        return ""
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
            .onReceive(NotificationCenter.default.publisher(for: .showSyncWizard)) { _ in showSyncWizard = true }
            .onReceive(NotificationCenter.default.publisher(for: .showRepoStandards)) { _ in showRepoStandards = true }
            .onReceive(NotificationCenter.default.publisher(for: .showBisect)) { _ in showBisectSheet = true }
            .onReceive(NotificationCenter.default.publisher(for: .showReflog)) { _ in showReflogSheet = true }
            .onReceive(NotificationCenter.default.publisher(for: .showGPGSSH)) { _ in showGPGSSHSheet = true }
            .onReceive(NotificationCenter.default.publisher(for: .showInsights)) { _ in showInsightsSheet = true }
            .onReceive(NotificationCenter.default.publisher(for: .showFileBrowser)) { _ in showFileBrowserSheet = true }
            .onReceive(NotificationCenter.default.publisher(for: .showLaunchpad)) { _ in showLaunchpadSheet = true }
            .onReceive(NotificationCenter.default.publisher(for: .showLFS)) { _ in showLFSSheet = true }
            .modifier(GitOperationListeners())
            .modifier(NavigationListeners(columnVisibility: $columnVisibility))
    }

    struct GitOperationListeners: ViewModifier {
        @Environment(AppState.self) var appState
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
                // Refresh after commit to update push button (ahead/behind counts)
                .onReceive(NotificationCenter.default.publisher(for: .branchDidChange)) { notification in
                    guard let path = notification.object as? String,
                          path == appState.currentRepository?.path else { return }
                    Task {
                        await appState.refresh()
                    }
                }
        }
    }

    struct NavigationListeners: ViewModifier {
        @Binding var columnVisibility: NavigationSplitViewVisibility
        func body(content: Content) -> some View {
            content
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
    @Environment(AppState.self) var appState
    @Binding var leftPanelWidth: CGFloat
    @Binding var rightPanelWidth: CGFloat
    let themeRefreshTrigger: UUID
    var bottomPanelManager: BottomPanelManager
    @State private var selectedFileDiff: FileDiff?
    @State private var isLoadingDiff = false
    @State private var searchText = ""
    @StateObject private var stagingVM = StagingViewModel()
    @State private var selectedStagingFile: StagingFile?

    // Helper function for group colors
    private func getGroupColor(for repoPath: String) -> Color? {
        let groups = RepoGroupsService.shared.getGroupsForRepo(repoPath)
        return groups.first.map { SwiftUI.Color(hex: $0.color) }
    }

    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showInspector: Bool = true
    @State private var availableSize: CGSize = .zero
    @State private var inspectorCollapsedForSpace = false
    @State private var sidebarCollapsedForSpace = false
    @Binding var toolbarDisplayMode: ContentView.ToolbarDisplayMode

    /// Toolbar color scheme that follows theme settings properly
    /// - .light theme → light color scheme
    /// - .dark theme → dark; custom follows its background
    /// - .system theme → nil (follows system appearance)
    private var toolbarColorScheme: SwiftUI.ColorScheme? {
        switch ThemeManager.shared.currentTheme {
        case .light:
            return .light
        case .dark:
            return .dark
        case .custom:
            return ThemeManager.shared.colors.background.isLight ? .light : .dark
        case .system:
            return nil
        }
    }

    private var toolbarConfigurationMenu: some View {
        // The deployment target is macOS 14: no legacy availability branch is
        // needed, and avoiding it keeps ContentBuilder compatible with that OS.
        ControlGroup {
            ForEach(ContentView.ToolbarDisplayMode.allCases, id: \.self) { mode in
                Button(mode.rawValue) {
                    toolbarDisplayMode = mode
                }
            }
        } label: {
            Text("Toolbar Display")
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
                    .liquidGlassTabBar()
                    .overlay(Divider(), alignment: .bottom)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            // Center Panel - Graph OR Diff
            CenterPanel(
                selectedFileDiff: $selectedFileDiff,
                isLoadingDiff: $isLoadingDiff,
                onStageHunk: selectedStagingFile != nil && !(selectedStagingFile?.isStaged ?? false)
                    ? { index in await stagingVM.stageHunk(file: selectedStagingFile!.path, hunkIndex: index) }
                    : nil,
                onDiscardHunk: selectedStagingFile != nil && !(selectedStagingFile?.isStaged ?? false)
                    ? { index in await stagingVM.discardHunk(file: selectedStagingFile!.path, hunkIndex: index) }
                    : nil,
                onUnstageHunk: selectedStagingFile != nil && (selectedStagingFile?.isStaged ?? false)
                    ? { index in await stagingVM.unstageHunk(file: selectedStagingFile!.path, hunkIndex: index) }
                    : nil
            )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Bottom Panel (Terminal/Logs) - Resizable
            // Always show UnifiedBottomPanel - it handles both collapsed (28px tab bar) and expanded states
            // When fully hidden (no tabs), show minimal CollapsedBottomPanelBar
            if bottomPanelManager.openTabs.isEmpty && !bottomPanelManager.isPanelVisible {
                // No tabs open and panel hidden - show minimal bar to open terminal
                CollapsedBottomPanelBar(panelManager: bottomPanelManager)
            } else {
                // Has tabs or panel is visible - show full UnifiedBottomPanel
                // UnifiedBottomPanel handles its own height (28px collapsed, panelHeight expanded)
                UnifiedBottomPanel(panelManager: bottomPanelManager,
                    maximumHeight: DesignTokens.Layout.Responsive.bottomPanelLimit(availableHeight: availableSize.height))
                    .transition(.move(edge: .bottom))
            }
        }
        .contextMenu { toolbarConfigurationMenu }
        .onReceive(NotificationCenter.default.publisher(for: .showGraph)) { _ in
            selectedFileDiff = nil
            selectedStagingFile = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: .showHistory)) { _ in
            selectedFileDiff = nil
            selectedStagingFile = nil
        }
    }

    var body: some View {
        GeometryReader { geometry in
            splitLayout
                .onChange(of: geometry.size, initial: true) { _, size in
                    let previousWidth = availableSize.width
                    availableSize = size
                    // Changing only the terminal/window height must not undo a
                    // user's explicit choice to reopen a compact-width panel.
                    guard previousWidth != size.width else { return }
                    let panels = DesignTokens.Layout.Responsive.Panels(
                        sidebarVisible: columnVisibility != .detailOnly,
                        inspectorVisible: showInspector,
                        sidebarCollapsedForSpace: sidebarCollapsedForSpace,
                        inspectorCollapsedForSpace: inspectorCollapsedForSpace).fitting(width: size.width)
                    showInspector = panels.inspectorVisible
                    columnVisibility = panels.sidebarVisible ? .all : .detailOnly
                    sidebarCollapsedForSpace = panels.sidebarCollapsedForSpace
                    inspectorCollapsedForSpace = panels.inspectorCollapsedForSpace
                }
        }
    }

    private var splitLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Left Panel - Branches/Remotes/Tags
            GeometryReader { geometry in
                LeftSidebarPanel()
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
                .navigationSplitViewColumnWidth(min: DesignTokens.Layout.Sidebar.minWidth, ideal: DesignTokens.Layout.Sidebar.idealWidth, max: DesignTokens.Layout.Sidebar.maxWidth)
                .background(AppTheme.sidebar)
        } detail: {
            // Center content - expands when inspector is hidden
            // The whole column must keep a stable native minimum when the
            // graph/loading/file viewer branches replace one another.
            GeometryReader { geometry in
                centerColumn
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .navigationSplitViewStyle(.prominentDetail)
        .inspector(isPresented: $showInspector) {
            // Right Panel - Staging/Commit (proper inspector behavior)
            // Bound all inspector modes, not only the stash child. Switching
            // staging/commit/stash must not change SplitViewChildController's
            // minimum-size contract during an AppKit constraint update.
            GeometryReader { geometry in
                RightStagingPanel(
                    selectedFileDiff: $selectedFileDiff,
                    isLoadingDiff: $isLoadingDiff,
                    stagingVM: stagingVM,
                    selectedStagingFile: $selectedStagingFile
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
                .inspectorColumnWidth(min: DesignTokens.Layout.StagingPanel.minWidth, ideal: DesignTokens.Layout.StagingPanel.idealWidth, max: DesignTokens.Layout.StagingPanel.maxWidth)
                .background(AppTheme.background)
        }
        // .windowTitleHidden() // Hide system title to prevent duplicates with custom title
        .navigationTitle("") // Hide system title
        .toolbar {
            // All actions centered
            ToolbarItem(placement: .principal) {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    // Git Actions - State-aware buttons that show ahead/behind counts
                    if appState.currentRepository != nil {
                        PullToolbarButton()
                        FetchToolbarButton()
                        PushToolbarButton()
                    }

                    if availableSize.width >= DesignTokens.Layout.Responsive.compactToolbarWidth {
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
                    } else {
                        compactActionsMenu
                    }
                }
            }

            // Right side - only Settings and Inspector toggle
            ToolbarItemGroup(placement: .primaryAction) {
                GitHelpButton(topicID: "basics")
                if #available(macOS 14.0, *) {
                    SettingsLink {
                        Image(systemName: "gearshape")
                            .renderingMode(.template)
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(minWidth: 28, minHeight: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .help("Application Settings (⌘,)")
                    .accessibilityLabel("Open application settings")
                    .accessibilityIdentifier("application-settings")
                } else {
                    XcodeToolbarButton(icon: "gearshape.fill", color: AppTheme.textSecondary) {
                        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                    }
                    .help("Settings")
                }

                XcodeToolbarButton(icon: "sidebar.trailing", color: showInspector ? AppTheme.accent : AppTheme.textSecondary) {
                    withAnimation {
                        inspectorCollapsedForSpace = false
                        if !showInspector && availableSize.width < DesignTokens.Layout.Responsive.inspectorWidth {
                            sidebarCollapsedForSpace = false
                            columnVisibility = .detailOnly
                        }
                        showInspector.toggle()
                    }
                }
                .help("Toggle Inspector")
                .accessibilityLabel("Toggle Inspector")
                .accessibilityIdentifier("inspector-toggle")
            }
        }
        .toolbarBackground(AppTheme.background, for: .windowToolbar)
        .toolbarColorScheme(toolbarColorScheme, for: .windowToolbar)
        .preferredColorScheme(toolbarColorScheme)
        .id(themeRefreshTrigger)
        .onReceive(NotificationCenter.default.publisher(for: .toggleSidebar)) { _ in
            sidebarCollapsedForSpace = false
            if columnVisibility == .all { columnVisibility = .detailOnly }
            else {
                if availableSize.width < DesignTokens.Layout.Responsive.inspectorWidth { showInspector = false }
                columnVisibility = .all
            }
        }
        .onChange(of: appState.activeTabId) { _, _ in
            // Clear diff when switching repositories
            selectedFileDiff = nil
            selectedStagingFile = nil
        }
    }

    private var compactActionsMenu: some View {
        Menu {
            Button("New Branch", systemImage: "arrow.triangle.branch") { NotificationCenter.default.post(name: .newBranch, object: nil) }
            Button("Stash", systemImage: "tray.and.arrow.down") { NotificationCenter.default.post(name: .stash, object: nil) }
            Button("Pop Stash", systemImage: "tray.and.arrow.up") { NotificationCenter.default.post(name: .popStash, object: nil) }
            Button("Terminal", systemImage: "terminal") { bottomPanelManager.openTab(type: .terminal) }
            Divider()
            Button("CI/CD") { NotificationCenter.default.post(name: .showCICD, object: nil) }
            Button("Team Activity") { bottomPanelManager.openTab(type: .teamActivity) }
            Button("Taiga") { bottomPanelManager.openTab(type: .taiga) }
            Button("Jira") { bottomPanelManager.openTab(type: .jira) }
            Button("Linear") { bottomPanelManager.openTab(type: .linear) }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .help("More repository actions")
        .accessibilityLabel("More repository actions")
    }
}

/// Fits only the containing window; never the first global application window.
private struct WindowScreenFittingView: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowScreenFittingNSView { WindowScreenFittingNSView() }
    func updateNSView(_ nsView: WindowScreenFittingNSView, context: Context) {}
}

private final class WindowScreenFittingNSView: NSView {
    private var isFitting = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self)
        guard let window else { return }
        for name in [NSWindow.didChangeScreenNotification, NSWindow.didChangeBackingPropertiesNotification,
                     NSWindow.didEndLiveResizeNotification] {
            NotificationCenter.default.addObserver(self, selector: #selector(fitWindow), name: name, object: window)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(fitWindow),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        DispatchQueue.main.async { [weak self] in self?.fitWindow() }
    }

    @objc private func fitWindow() {
        guard !isFitting, let window, !window.inLiveResize,
              !window.styleMask.contains(.fullScreen), let screen = window.screen ?? NSScreen.screens.first else { return }
        let fitted = DesignTokens.Layout.Responsive.windowFrame(window.frame, fitting: screen.visibleFrame)
        guard fitted != window.frame else { return }
        isFitting = true
        window.setFrame(fitted, display: true)
        isFitting = false
    }

    deinit { NotificationCenter.default.removeObserver(self) }
}

// MARK: - Collapsed Bottom Panel Bar
/// Minimal bar shown when bottom panel is hidden - click to expand
struct CollapsedBottomPanelBar: View {
    var panelManager: BottomPanelManager
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            // Drag handle indicator
            Image(systemName: "chevron.up")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(AppTheme.textMuted)

            // Show open tabs icons
            if !panelManager.openTabs.isEmpty {
                ForEach(panelManager.openTabs.prefix(4)) { tab in
                    Image(systemName: tab.type.icon)
                        .font(.system(size: 9))
                        .foregroundStyle(panelManager.activeTabId == tab.id ? AppTheme.accent : AppTheme.textMuted)
                }
                if panelManager.openTabs.count > 4 {
                    Text("+\(panelManager.openTabs.count - 4)")
                        .font(.system(size: 9))
                        .foregroundStyle(AppTheme.textMuted)
                }
            } else {
                Text("Terminal")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textMuted)
            }

            Spacer()

            // Quick action buttons
            Button {
                panelManager.openTab(type: .terminal)
            } label: {
                Image(systemName: "terminal")
                    .font(.system(size: 9))
                    .foregroundStyle(AppTheme.textMuted)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open terminal")
            .accessibilityIdentifier("open-terminal")
        }
        .padding(.horizontal, 12)
        .frame(height: 22)
        .background(isHovered ? AppTheme.hover : AppTheme.backgroundSecondary)
        .overlay(
            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1),
            alignment: .top
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.3)) {
                if panelManager.openTabs.isEmpty {
                    panelManager.openTab(type: .terminal)
                } else {
                    panelManager.isPanelVisible = true
                }
            }
        }
        .onHover { isHovered = $0 }
    }
}

// MARK: - Orphan Feature Sheets

private struct FeatureSheetsBatch1: ViewModifier {
    @Environment(AppState.self) var appState
    @Environment(ThemeManager.self) var themeManager
    @Binding var showBisect: Bool
    @Binding var showReflog: Bool
    @Binding var showGPGSSH: Bool

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showBisect) {
                BisectView()
                    .environment(appState)
                    .environment(themeManager)
                    .frame(minWidth: 720, minHeight: 520)
            }
            .sheet(isPresented: $showReflog) {
                ReflogView()
                    .environment(appState)
                    .frame(minWidth: 720, minHeight: 520)
            }
            .sheet(isPresented: $showGPGSSH) {
                GPGSSHManagementView()
                    .frame(minWidth: 720, minHeight: 520)
            }
    }
}

private struct FeatureSheetsBatch2: ViewModifier {
    @Environment(AppState.self) var appState
    @Binding var showInsights: Bool
    @Binding var showFileBrowser: Bool
    @Binding var showLaunchpad: Bool
    @Binding var showLFS: Bool

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showInsights) {
                InsightsView()
                    .environment(appState)
                    .frame(minWidth: 720, minHeight: 520)
            }
            .sheet(isPresented: $showFileBrowser) {
                if let path = appState.currentRepository?.path {
                    FileBrowserView(repoPath: path)
                        .environment(appState)
                        .frame(minWidth: 720, minHeight: 520)
                }
            }
            .sheet(isPresented: $showLaunchpad) {
                LaunchpadView()
                    .environment(appState)
                    .frame(minWidth: 720, minHeight: 520)
            }
            .sheet(isPresented: $showLFS) {
                LFSManagerView()
                    .environment(appState)
                    .frame(minWidth: 720, minHeight: 520)
            }
    }
}
