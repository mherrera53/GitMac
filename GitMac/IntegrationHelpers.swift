import SwiftUI

/// Extension para agregar todas las funcionalidades nuevas a ContentView
/// Este archivo debe integrarse en ContentView.swift existente

// MARK: - Notification Names Extension
extension Notification.Name {
    static let showCommandPalette = Notification.Name("showCommandPalette")
    static let showFileFinder = Notification.Name("showFileFinder")
    static let openRepository = Notification.Name("openRepository")
    static let cloneRepository = Notification.Name("cloneRepository")
    static let toggleTerminal = Notification.Name("toggleTerminal")
    static let stageAll = Notification.Name("stageAll")
    static let unstageAll = Notification.Name("unstageAll")
    static let fetch = Notification.Name("fetch")
    static let pull = Notification.Name("pull")
    static let push = Notification.Name("push")
    static let newBranch = Notification.Name("newBranch")
    static let merge = Notification.Name("merge")
    static let stash = Notification.Name("stash")
    static let popStash = Notification.Name("popStash")
}

// MARK: - ContentView Integration Example
/*
 Para integrar en tu ContentView.swift existente:

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var recentReposManager: RecentRepositoriesManager
    @StateObject private var themeManager = ThemeManager.shared
    
    // 👇 AGREGAR ESTOS ESTADOS
    @State private var showCommandPalette = false
    @State private var showFileFinder = false
    @State private var showCloneSheet = false
    @State private var showOpenPanel = false
    @State private var showNewBranchSheet = false
    @State private var showMergeSheet = false
    @State private var showTerminal = false
    @State private var terminalHeight: CGFloat = 200
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab Bar (only show if there are open repos)
            if !appState.openTabs.isEmpty {
                RepositoryTabBar()
            }

            // Main content
            if appState.currentRepository != nil {
                mainContentWithTerminal // 👈 CAMBIAR A ESTO
            } else {
                WelcomeView(
                    onOpen: { showOpenPanel = true },
                    onClone: { showCloneSheet = true }
                )
            }
        }
        .background(GitKrakenTheme.background)
        .withToastNotifications() // 👈 AGREGAR ESTO
        // 👇 AGREGAR TODOS ESTOS SHEETS
        .sheet(isPresented: $showCloneSheet) {
            CloneRepositorySheet()
        }
        .sheet(isPresented: $showCommandPalette) {
            CommandPalette()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showFileFinder) {
            FuzzyFileFinder()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showNewBranchSheet) {
            CreateBranchSheet(isPresented: $showNewBranchSheet)
                .environmentObject(appState)
        }
        .sheet(isPresented: $showMergeSheet) {
            MergeBranchSheet(isPresented: $showMergeSheet)
                .environmentObject(appState)
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
        // 👇 AGREGAR TODOS ESTOS RECEIVERS
        .onReceive(NotificationCenter.default.publisher(for: .showCommandPalette)) { _ in
            showCommandPalette = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .showFileFinder)) { _ in
            showFileFinder = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .openRepository)) { _ in
            showOpenPanel = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .cloneRepository)) { _ in
            showCloneSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleTerminal)) { _ in
            withAnimation {
                showTerminal.toggle()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .fetch)) { _ in
            handleFetch()
        }
        .onReceive(NotificationCenter.default.publisher(for: .pull)) { _ in
            handlePull()
        }
        .onReceive(NotificationCenter.default.publisher(for: .push)) { _ in
            handlePush()
        }
        .onReceive(NotificationCenter.default.publisher(for: .stash)) { _ in
            handleStash()
        }
        .onReceive(NotificationCenter.default.publisher(for: .popStash)) { _ in
            handlePopStash()
        }
        .onReceive(NotificationCenter.default.publisher(for: .newBranch)) { _ in
            showNewBranchSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .merge)) { _ in
            showMergeSheet = true
        }
    }
    
    // 👇 AGREGAR ESTA VISTA
    @ViewBuilder
    private var mainContentWithTerminal: some View {
        VStack(spacing: 0) {
            // Contenido principal existente
            GitKrakenLayout(
                leftPanelWidth: .constant(220),
                rightPanelWidth: .constant(380)
            )
            
            // Terminal panel (opcional)
            if showTerminal {
                Divider()
                
                TerminalView()
                    .frame(height: terminalHeight)
                    .environmentObject(appState)
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    withAnimation {
                        showTerminal.toggle()
                    }
                } label: {
                    Image(systemName: "terminal")
                }
                .help("Toggle Terminal (⌘`)")
            }
        }
    }
    
    // Métodos existentes se mantienen igual...
}
*/

// MARK: - GitMacApp Integration Example
/*
 Para integrar en tu GitMacApp.swift:

@main
struct GitMacApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var recentReposManager = RecentRepositoriesManager()
    @StateObject private var themeManager = ThemeManager.shared // 👈 AGREGAR
    @StateObject private var shortcutManager = KeyboardShortcutManager.shared // 👈 AGREGAR
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(recentReposManager)
                .environmentObject(themeManager) // 👈 AGREGAR
        }
        .commands {
            // File menu
            CommandGroup(replacing: .newItem) {
                Button("Open Repository...") {
                    NotificationCenter.default.post(name: .openRepository, object: nil)
                }
                .keyboardShortcut("o", modifiers: [.command])
                
                Button("Clone Repository...") {
                    NotificationCenter.default.post(name: .cloneRepository, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }
            
            // View menu
            CommandMenu("View") {
                Button("Command Palette") {
                    NotificationCenter.default.post(name: .showCommandPalette, object: nil)
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                
                Button("Go to File") {
                    NotificationCenter.default.post(name: .showFileFinder, object: nil)
                }
                .keyboardShortcut("p", modifiers: [.command])
                
                Divider()
                
                Button("Toggle Terminal") {
                    NotificationCenter.default.post(name: .toggleTerminal, object: nil)
                }
                .keyboardShortcut("`", modifiers: [.command])
            }
            
            // Git menu
            CommandMenu("Git") {
                Button("Commit") {
                    // Focus commit message
                }
                .keyboardShortcut(.return, modifiers: [.command])
                
                Button("Stage All") {
                    NotificationCenter.default.post(name: .stageAll, object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                
                Button("Unstage All") {
                    NotificationCenter.default.post(name: .unstageAll, object: nil)
                }
                .keyboardShortcut("u", modifiers: [.command, .shift])
                
                Divider()
                
                Button("Fetch") {
                    NotificationCenter.default.post(name: .fetch, object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                
                Button("Pull") {
                    NotificationCenter.default.post(name: .pull, object: nil)
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
                
                Button("Push") {
                    NotificationCenter.default.post(name: .push, object: nil)
                }
                .keyboardShortcut("p", modifiers: [.command, .option])
                
                Divider()
                
                Button("New Branch...") {
                    NotificationCenter.default.post(name: .newBranch, object: nil)
                }
                .keyboardShortcut("b", modifiers: [.command])
                
                Button("Merge...") {
                    NotificationCenter.default.post(name: .merge, object: nil)
                }
                
                Divider()
                
                Button("Stash Changes") {
                    NotificationCenter.default.post(name: .stash, object: nil)
                }
                
                Button("Pop Stash") {
                    NotificationCenter.default.post(name: .popStash, object: nil)
                }
            }
        }
        
        // Settings window
        Settings {
            SettingsView()
                .environmentObject(appState)
                .environmentObject(themeManager)
        }
    }
}
*/

// MARK: - SettingsView Integration Example
/*
 Para integrar en tu SettingsView.swift:

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        TabView {
            // Tabs existentes...
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            // 👇 AGREGAR ESTOS TABS
            ThemeSettingsView()
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }
            
            ShortcutSettingsView()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
            
            ExternalToolsSettingsView()
                .tabItem {
                    Label("External Tools", systemImage: "wrench.and.screwdriver")
                }
            
            // Opcional: GitHub
            GitHubIntegrationView()
                .tabItem {
                    Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                }
        }
        .frame(width: 600, height: 500)
    }
}
*/

// MARK: - Helper para usar NotificationManager
extension View {
    func showSuccessNotification(_ message: String, detail: String? = nil) {
        NotificationManager.shared.success(message, detail: detail)
    }
    
    func showErrorNotification(_ message: String, detail: String? = nil) {
        NotificationManager.shared.error(message, detail: detail)
    }
    
    func showWarningNotification(_ message: String, detail: String? = nil) {
        NotificationManager.shared.warning(message, detail: detail)
    }
    
    func showInfoNotification(_ message: String, detail: String? = nil) {
        NotificationManager.shared.info(message, detail: detail)
    }
}

// MARK: - Ejemplo de uso en operaciones Git
/*
extension AppState {
    func handleGitOperation() async {
        do {
            try await gitService.someOperation()
            NotificationManager.shared.success("Operation completed")
        } catch {
            NotificationManager.shared.error(
                "Operation failed",
                detail: error.localizedDescription
            )
        }
    }
}
*/
