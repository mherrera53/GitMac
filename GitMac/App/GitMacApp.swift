import SwiftUI

@main
struct GitMacApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var recentReposManager = RecentRepositoriesManager.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Preload keychain cache to avoid repeated password prompts
        Task {
            await KeychainManager.shared.preloadCache()
        }

        // Register all integration plugins
        registerPlugins()
    }

    /// Register all integration plugins with the PluginRegistry
    @MainActor
    func registerPlugins() {
        let registry = PluginRegistry.shared

        // Register all integration plugins
        registry.register(NotionPlugin())
        registry.register(LinearPlugin())
        registry.register(JiraPlugin())
        registry.register(TaigaPlugin())
        registry.register(PlannerPlugin())
    }

    func configureWindow() {
        DispatchQueue.main.async {
            // Ensure theme is loaded and applied
            ThemeManager.shared.applyTheme()

            if let window = NSApplication.shared.windows.first {
                window.titlebarAppearsTransparent = true
                window.isMovableByWindowBackground = true
                window.titleVisibility = .hidden  // Hide system title, we use custom toolbar title
                window.title = "" // Explicitly clear title text to prevent duplicates
                // Apply theme appearance
                window.appearance = ThemeManager.shared.appearance
            }

            // Ensure the app icon is properly set
            if NSApp.applicationIconImage == nil {
                NSApp.applicationIconImage = NSImage(named: NSImage.applicationIconName)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(recentReposManager)
                .task {
                    // Restore previous session on launch
                    await appState.restoreSession()
                }
                .onAppear {
                    configureWindow()
                }
                .onReceive(NotificationCenter.default.publisher(for: .themeDidChange)) { _ in
                    // Update window appearance when theme changes
                    configureWindow()
                }
        }
        .commands {
            GitMacCommands()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background || newPhase == .inactive {
                // Save session when app goes to background or becomes inactive
                appState.saveSession()
            }
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

// MARK: - Repository Tab
struct RepositoryTab: Identifiable, Equatable {
    let id = UUID()
    var repository: Repository
    var selectedCommit: Commit?
    var selectedBranch: Branch?
    var selectedStash: Stash?

    static func == (lhs: RepositoryTab, rhs: RepositoryTab) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - App State
@MainActor
class AppState: ObservableObject {
    static let shared = AppState()

    // Multiple repos support (tabs)
    @Published var openTabs: [RepositoryTab] = []
    @Published var activeTabId: UUID?

    // Computed property for backward compatibility
    var currentRepository: Repository? {
        get { activeTab?.repository }
        set {
            if let newValue = newValue {
                if let index = openTabs.firstIndex(where: { $0.id == activeTabId }) {
                    openTabs[index].repository = newValue
                }
            }
        }
    }

    var activeTab: RepositoryTab? {
        openTabs.first { $0.id == activeTabId }
    }

    var activeTabIndex: Int? {
        openTabs.firstIndex { $0.id == activeTabId }
    }

    @Published var isLoading = false
    @Published var errorMessage: String?

    var selectedCommit: Commit? {
        get { activeTab?.selectedCommit }
        set {
            if let index = activeTabIndex {
                openTabs[index].selectedCommit = newValue
            }
        }
    }

    var selectedBranch: Branch? {
        get { activeTab?.selectedBranch }
        set {
            if let index = activeTabIndex {
                openTabs[index].selectedBranch = newValue
            }
        }
    }

    var selectedStash: Stash? {
        get { activeTab?.selectedStash }
        set {
            if let index = activeTabIndex {
                openTabs[index].selectedStash = newValue
            }
        }
    }

    let gitService = GitService()
    let gitHubService = GitHubService()
    let aiService = AIService()

    private let openReposKey = "openRepositoryPaths"
    private let activeRepoKey = "activeRepositoryPath"

    // MARK: - Session Persistence

    /// Save current session (open tabs and active tab)
    func saveSession() {
        let paths = openTabs.map { $0.repository.path }
        UserDefaults.standard.set(paths, forKey: openReposKey)

        if let activePath = activeTab?.repository.path {
            UserDefaults.standard.set(activePath, forKey: activeRepoKey)
        }
    }

    /// Restore previous session
    func restoreSession() async {
        // Check if running in demo mode (UI tests pass this as launch argument)
        // Launch arguments format: ["-demo-mode", "true"] -> check if array contains "-demo-mode"
        let args = CommandLine.arguments
        let isDemoMode = args.contains("-demo-mode")

        if isDemoMode {
            // Open demo repository instead of restoring session
            let demoRepoPath = "/Users/mario/gitmac-demo-repo"
            if FileManager.default.fileExists(atPath: demoRepoPath) {
                do {
                    let repo = try await gitService.openRepository(at: demoRepoPath)
                    let newTab = RepositoryTab(repository: repo)
                    openTabs.append(newTab)
                    activeTabId = newTab.id
                    // Force write to file since NSLog might not show up
                    try? "Demo mode activated".write(toFile: "/tmp/gitmac-demo-mode.txt", atomically: true, encoding: .utf8)
                    return
                } catch {
                    try? "Demo mode failed: \(error)".write(toFile: "/tmp/gitmac-demo-mode.txt", atomically: true, encoding: .utf8)
                }
            } else {
                try? "Demo repo not found".write(toFile: "/tmp/gitmac-demo-mode.txt", atomically: true, encoding: .utf8)
            }
        }

        // Normal session restore
        guard let paths = UserDefaults.standard.stringArray(forKey: openReposKey), !paths.isEmpty else {
            return
        }

        let activePath = UserDefaults.standard.string(forKey: activeRepoKey)

        for path in paths {
            // Verify path exists
            guard FileManager.default.fileExists(atPath: path) else { continue }

            do {
                let repo = try await gitService.openRepository(at: path)
                let newTab = RepositoryTab(repository: repo)
                openTabs.append(newTab)

                // Set active tab if this was the active one
                if path == activePath {
                    activeTabId = newTab.id
                }
            } catch {
                print("Failed to restore repository at \(path): \(error)")
            }
        }

        // If no active tab was set, use the first one
        if activeTabId == nil {
            activeTabId = openTabs.first?.id
        }
    }

    func openRepository(at path: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let repo = try await gitService.openRepository(at: path)

            // Check if already open
            if let existingTab = openTabs.first(where: { $0.repository.path == repo.path }) {
                activeTabId = existingTab.id
            } else {
                // Create new tab
                let newTab = RepositoryTab(repository: repo)
                openTabs.append(newTab)
                activeTabId = newTab.id
            }

            // Save to recent repositories
            RecentRepositoriesManager.shared.addRecent(path: repo.path, name: repo.name)

            // Auto-save session
            saveSession()
        } catch {
            errorMessage = "Error opening repository: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func refresh() async {
        guard let path = currentRepository?.path else { return }
        do {
            let repo = try await gitService.openRepository(at: path)
            // Update the tab with refreshed data
            if let index = openTabs.firstIndex(where: { $0.id == activeTabId }) {
                var updatedTab = openTabs[index]
                updatedTab.repository = repo
                openTabs[index] = updatedTab
            }
        } catch {
            errorMessage = "Error refreshing: \(error.localizedDescription)"
        }
    }

    func cloneRepository(from url: String, to path: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let repo = try await gitService.cloneRepository(from: url, to: path)
            let newTab = RepositoryTab(repository: repo)
            openTabs.append(newTab)
            activeTabId = newTab.id
        } catch {
            errorMessage = "Error cloning repository: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func closeTab(_ tabId: UUID) {
        openTabs.removeAll { $0.id == tabId }

        // If we closed the active tab, activate another one
        if activeTabId == tabId {
            activeTabId = openTabs.last?.id
        }

        // Auto-save after closing tab
        saveSession()
    }

    func selectTab(_ tabId: UUID, fromNavigation: Bool = false) {
        if !fromNavigation, let current = activeTabId, current != tabId {
            backStack.append(current)
            forwardStack.removeAll() // Clear forward stack on new navigation
        }
        
        activeTabId = tabId
        saveSession()
    }
    
    // MARK: - Navigation History
    
    @Published var backStack: [UUID] = []
    @Published var forwardStack: [UUID] = []
    
    var canGoBack: Bool { !backStack.isEmpty }
    var canGoForward: Bool { !forwardStack.isEmpty }
    
    func goBack() {
        guard let current = activeTabId, let previous = backStack.popLast() else { return }
        forwardStack.append(current)
        selectTab(previous, fromNavigation: true)
    }
    
    func goForward() {
        guard let current = activeTabId, let next = forwardStack.popLast() else { return }
        backStack.append(current)
        selectTab(next, fromNavigation: true)
    }
    
    /// Reorder tabs by moving a tab to a new position (before another tab)
    func reorderTab(from sourceId: UUID, to destinationId: UUID) {
        guard let sourceIndex = openTabs.firstIndex(where: { $0.id == sourceId }),
              let destIndex = openTabs.firstIndex(where: { $0.id == destinationId }),
              sourceIndex != destIndex else { return }
        
        let tab = openTabs.remove(at: sourceIndex)
        let newDestIndex = sourceIndex < destIndex ? destIndex - 1 : destIndex
        openTabs.insert(tab, at: newDestIndex)
        
        saveSession()
    }
}

// MARK: - Data Models (Codable for UserDefaults)
struct RecentRepository: Codable, Identifiable, Hashable {
    var id: String { path }
    var path: String
    var name: String
    var lastOpened: Date

    init(path: String, name: String, lastOpened: Date = Date()) {
        self.path = path
        self.name = name
        self.lastOpened = lastOpened
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(path)
    }

    static func == (lhs: RecentRepository, rhs: RecentRepository) -> Bool {
        lhs.path == rhs.path
    }
}

struct FavoriteRepository: Codable, Identifiable {
    var id: String { path }
    var path: String
    var name: String
    var color: String?

    init(path: String, name: String, color: String? = nil) {
        self.path = path
        self.name = name
        self.color = color
    }
}

struct AIConfiguration: Codable, Identifiable {
    var id: String { provider }
    var provider: String // "gemini", "anthropic", "openai"
    var apiKey: String
    var preferredModel: String
    var isDefault: Bool

    init(provider: String, apiKey: String, preferredModel: String, isDefault: Bool = false) {
        self.provider = provider
        self.apiKey = apiKey
        self.preferredModel = preferredModel
        self.isDefault = isDefault
    }
}

// MARK: - Recent Repositories Manager
@MainActor
class RecentRepositoriesManager: ObservableObject {
    static let shared = RecentRepositoriesManager()

    @Published var recentRepos: [RecentRepository] = []
    @Published var favoriteRepos: [FavoriteRepository] = []

    private let recentKey = "recentRepositories"
    private let favoritesKey = "favoriteRepositories"

    private init() {
        loadData()
    }

    func loadData() {
        if let data = UserDefaults.standard.data(forKey: recentKey),
           let repos = try? JSONDecoder().decode([RecentRepository].self, from: data) {
            recentRepos = repos.sorted { $0.lastOpened > $1.lastOpened }
        }

        if let data = UserDefaults.standard.data(forKey: favoritesKey),
           let repos = try? JSONDecoder().decode([FavoriteRepository].self, from: data) {
            favoriteRepos = repos
        }
    }

    func addRecent(path: String, name: String) {
        // Remove if already exists
        recentRepos.removeAll { $0.path == path }

        // Add at beginning
        let repo = RecentRepository(path: path, name: name)
        recentRepos.insert(repo, at: 0)

        // Keep only last 10
        if recentRepos.count > 10 {
            recentRepos = Array(recentRepos.prefix(10))
        }

        saveRecent()
    }

    func addFavorite(path: String, name: String, color: String? = nil) {
        guard !favoriteRepos.contains(where: { $0.path == path }) else { return }
        let repo = FavoriteRepository(path: path, name: name, color: color)
        favoriteRepos.append(repo)
        saveFavorites()
    }

    func removeFavorite(path: String) {
        favoriteRepos.removeAll { $0.path == path }
        saveFavorites()
    }

    func removeRecent(path: String) {
        recentRepos.removeAll { $0.path == path }
        saveRecent()
    }

    private func saveRecent() {
        if let data = try? JSONEncoder().encode(recentRepos) {
            UserDefaults.standard.set(data, forKey: recentKey)
        }
    }

    private func saveFavorites() {
        if let data = try? JSONEncoder().encode(favoriteRepos) {
            UserDefaults.standard.set(data, forKey: favoritesKey)
        }
    }
}

// MARK: - Menu Commands
struct GitMacCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Open Repository...") {
                NotificationCenter.default.post(name: .openRepository, object: nil)
            }
            .keyboardShortcut("o", modifiers: .command)

            Button("Clone Repository...") {
                NotificationCenter.default.post(name: .cloneRepository, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Divider()

            Button("Init Repository...") {
                NotificationCenter.default.post(name: .initRepository, object: nil)
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])
        }

        CommandMenu("Repository") {
            Button("Fetch") {
                NotificationCenter.default.post(name: .fetch, object: nil)
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])

            Button("Pull") {
                NotificationCenter.default.post(name: .pull, object: nil)
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])

            Button("Push") {
                NotificationCenter.default.post(name: .push, object: nil)
            }
            .keyboardShortcut("u", modifiers: [.command, .shift])

            Divider()

            Button("Stash Changes") {
                NotificationCenter.default.post(name: .stash, object: nil)
            }
            .keyboardShortcut("s", modifiers: [.command, .option])

            Button("Pop Stash") {
                NotificationCenter.default.post(name: .popStash, object: nil)
            }
            .keyboardShortcut("s", modifiers: [.command, .option, .shift])
        }

        CommandMenu("Branch") {
            Button("New Branch...") {
                NotificationCenter.default.post(name: .newBranch, object: nil)
            }
            .keyboardShortcut("b", modifiers: [.command, .shift])

            Button("Merge...") {
                NotificationCenter.default.post(name: .merge, object: nil)
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])

            Button("Rebase...") {
                NotificationCenter.default.post(name: .rebase, object: nil)
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let openRepository = Notification.Name("openRepository")
    static let cloneRepository = Notification.Name("cloneRepository")
    static let initRepository = Notification.Name("initRepository")
    static let fetch = Notification.Name("fetch")
    static let pull = Notification.Name("pull")
    static let push = Notification.Name("push")
    static let stash = Notification.Name("stash")
    static let popStash = Notification.Name("popStash")
    static let newBranch = Notification.Name("newBranch")
    static let merge = Notification.Name("merge")
    static let rebase = Notification.Name("rebase")
    static let repositoryDidRefresh = Notification.Name("repositoryDidRefresh")
}
