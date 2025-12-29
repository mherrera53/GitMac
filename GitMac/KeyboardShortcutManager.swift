import SwiftUI
import Carbon

/// Keyboard Shortcut Manager - Customizable keyboard shortcuts
/// Inspired by VSCode's keybindings system
class KeyboardShortcutManager: ObservableObject {
    static let shared = KeyboardShortcutManager()
    
    @Published var shortcuts: [ShortcutAction: KeyboardShortcut] = [:]
    @Published var currentPreset: ShortcutPreset = .default
    
    private let defaults = UserDefaults.standard
    private let shortcutsKey = "keyboardShortcuts"
    private let presetKey = "shortcutPreset"
    
    init() {
        loadShortcuts()
    }
    
    // MARK: - Shortcut Management
    
    func setShortcut(_ shortcut: KeyboardShortcut, for action: ShortcutAction) {
        // Check for conflicts
        if let conflict = findConflict(shortcut, excluding: action) {
            // Handle conflict (can show alert to user)
            print("Conflict with: \(conflict.displayName)")
            return
        }
        
        shortcuts[action] = shortcut
        saveShortcuts()
        
        NotificationCenter.default.post(name: .shortcutsDidChange, object: nil)
    }
    
    func removeShortcut(for action: ShortcutAction) {
        shortcuts.removeValue(forKey: action)
        saveShortcuts()
    }
    
    func resetToDefault() {
        loadPreset(.default)
        saveShortcuts()
    }
    
    func loadPreset(_ preset: ShortcutPreset) {
        currentPreset = preset
        shortcuts = preset.shortcuts
        defaults.set(preset.rawValue, forKey: presetKey)
        saveShortcuts()
        
        NotificationCenter.default.post(name: .shortcutsDidChange, object: nil)
    }
    
    // MARK: - Conflict Detection
    
    func findConflict(_ shortcut: KeyboardShortcut, excluding action: ShortcutAction) -> ShortcutAction? {
        for (existingAction, existingShortcut) in shortcuts {
            if existingAction != action && existingShortcut == shortcut {
                return existingAction
            }
        }
        return nil
    }
    
    func hasConflict(_ shortcut: KeyboardShortcut, excluding action: ShortcutAction) -> Bool {
        return findConflict(shortcut, excluding: action) != nil
    }
    
    // MARK: - Persistence
    
    private func saveShortcuts() {
        let dict = shortcuts.mapValues { $0.toDictionary() }
        defaults.set(dict, forKey: shortcutsKey)
    }
    
    private func loadShortcuts() {
        // Load preset
        if let presetRaw = defaults.string(forKey: presetKey),
           let preset = ShortcutPreset(rawValue: presetRaw) {
            currentPreset = preset
        }
        
        // Load custom shortcuts
        if let dict = defaults.dictionary(forKey: shortcutsKey) as? [String: [String: Any]] {
            for (key, value) in dict {
                if let action = ShortcutAction(rawValue: key),
                   let shortcut = KeyboardShortcut.from(dictionary: value) {
                    shortcuts[action] = shortcut
                }
            }
        } else {
            // First launch - use default preset
            shortcuts = currentPreset.shortcuts
        }
    }
    
    // MARK: - Action Execution
    
    func handle(_ event: NSEvent) -> Bool {
        let shortcut = KeyboardShortcut(from: event)
        
        for (action, actionShortcut) in shortcuts {
            if actionShortcut == shortcut {
                executeAction(action)
                return true
            }
        }
        
        return false
    }
    
    private func executeAction(_ action: ShortcutAction) {
        NotificationCenter.default.post(name: action.notificationName, object: nil)
    }
}

// MARK: - Keyboard Shortcut

struct KeyboardShortcut: Equatable, Codable {
    let key: String
    let modifiers: EventModifiers
    
    init(key: String, modifiers: EventModifiers) {
        self.key = key
        self.modifiers = modifiers
    }
    
    init(from event: NSEvent) {
        self.key = event.charactersIgnoringModifiers ?? ""
        self.modifiers = EventModifiers(from: event.modifierFlags)
    }
    
    var displayString: String {
        var parts: [String] = []
        
        if modifiers.contains(.control) {
            parts.append("⌃")
        }
        if modifiers.contains(.option) {
            parts.append("⌥")
        }
        if modifiers.contains(.shift) {
            parts.append("⇧")
        }
        if modifiers.contains(.command) {
            parts.append("⌘")
        }
        
        parts.append(key.uppercased())
        
        return parts.joined()
    }
    
    var keyEquivalent: KeyEquivalent {
        KeyEquivalent(Character(key))
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "key": key,
            "modifiers": modifiers.rawValue
        ]
    }
    
    static func from(dictionary: [String: Any]) -> KeyboardShortcut? {
        guard let key = dictionary["key"] as? String,
              let modifiersRaw = dictionary["modifiers"] as? Int else {
            return nil
        }
        
        return KeyboardShortcut(
            key: key,
            modifiers: EventModifiers(rawValue: modifiersRaw)
        )
    }
}

// MARK: - Event Modifiers

struct EventModifiers: OptionSet, Codable {
    let rawValue: Int
    
    static let command = EventModifiers(rawValue: 1 << 0)
    static let shift = EventModifiers(rawValue: 1 << 1)
    static let option = EventModifiers(rawValue: 1 << 2)
    static let control = EventModifiers(rawValue: 1 << 3)
    
    init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    init(from flags: NSEvent.ModifierFlags) {
        var modifiers: EventModifiers = []
        
        if flags.contains(.command) {
            modifiers.insert(.command)
        }
        if flags.contains(.shift) {
            modifiers.insert(.shift)
        }
        if flags.contains(.option) {
            modifiers.insert(.option)
        }
        if flags.contains(.control) {
            modifiers.insert(.control)
        }
        
        self = modifiers
    }
}

// MARK: - Shortcut Actions

enum ShortcutAction: String, CaseIterable, Identifiable {
    // File Operations
    case openRepository = "open_repository"
    case cloneRepository = "clone_repository"
    case closeRepository = "close_repository"
    
    // Navigation
    case showCommandPalette = "show_command_palette"
    case showFileFinder = "show_file_finder"
    case goBack = "go_back"
    case goForward = "go_forward"
    
    // Git Operations
    case stageAll = "stage_all"
    case unstageAll = "unstage_all"
    case commitChanges = "commit_changes"
    case amendCommit = "amend_commit"
    case fetch = "fetch"
    case pull = "pull"
    case push = "push"
    case stash = "stash"
    case popStash = "pop_stash"
    
    // Branch Operations
    case createBranch = "create_branch"
    case deleteBranch = "delete_branch"
    case switchBranch = "switch_branch"
    case mergeBranch = "merge_branch"
    
    // View
    case showGraph = "show_graph"
    case showChanges = "show_changes"
    case showHistory = "show_history"
    case showBranches = "show_branches"
    case showTags = "show_tags"
    case showStashes = "show_stashes"
    case showRemotes = "show_remotes"
    
    // Search
    case searchCommits = "search_commits"
    case searchFiles = "search_files"
    
    // Other
    case refresh = "refresh"
    case showSettings = "show_settings"
    case toggleSidebar = "toggle_sidebar"
    case togglePreviewPanel = "toggle_preview_panel"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .openRepository: return "Open Repository"
        case .cloneRepository: return "Clone Repository"
        case .closeRepository: return "Close Repository"
        case .showCommandPalette: return "Show Command Palette"
        case .showFileFinder: return "Show File Finder"
        case .goBack: return "Go Back"
        case .goForward: return "Go Forward"
        case .stageAll: return "Stage All"
        case .unstageAll: return "Unstage All"
        case .commitChanges: return "Commit Changes"
        case .amendCommit: return "Amend Commit"
        case .fetch: return "Fetch"
        case .pull: return "Pull"
        case .push: return "Push"
        case .stash: return "Stash"
        case .popStash: return "Pop Stash"
        case .createBranch: return "Create Branch"
        case .deleteBranch: return "Delete Branch"
        case .switchBranch: return "Switch Branch"
        case .mergeBranch: return "Merge Branch"
        case .showGraph: return "Show Graph"
        case .showChanges: return "Show Changes"
        case .showHistory: return "Show History"
        case .showBranches: return "Show Branches"
        case .showTags: return "Show Tags"
        case .showStashes: return "Show Stashes"
        case .showRemotes: return "Show Remotes"
        case .searchCommits: return "Search Commits"
        case .searchFiles: return "Search Files"
        case .refresh: return "Refresh"
        case .showSettings: return "Show Settings"
        case .toggleSidebar: return "Toggle Sidebar"
        case .togglePreviewPanel: return "Toggle Preview Panel"
        }
    }
    
    var category: ShortcutCategory {
        switch self {
        case .openRepository, .cloneRepository, .closeRepository:
            return .file
        case .showCommandPalette, .showFileFinder, .goBack, .goForward:
            return .navigation
        case .stageAll, .unstageAll, .commitChanges, .amendCommit, .fetch, .pull, .push, .stash, .popStash:
            return .git
        case .createBranch, .deleteBranch, .switchBranch, .mergeBranch:
            return .branch
        case .showGraph, .showChanges, .showHistory, .showBranches, .showTags, .showStashes, .showRemotes:
            return .view
        case .searchCommits, .searchFiles:
            return .search
        case .refresh, .showSettings, .toggleSidebar, .togglePreviewPanel:
            return .other
        }
    }
    
    var notificationName: Notification.Name {
        Notification.Name(rawValue)
    }
}

// MARK: - Shortcut Categories

enum ShortcutCategory: String, CaseIterable {
    case file = "File"
    case navigation = "Navigation"
    case git = "Git Operations"
    case branch = "Branches"
    case view = "View"
    case search = "Search"
    case other = "Other"
}

// MARK: - Shortcut Presets

enum ShortcutPreset: String, CaseIterable, Identifiable {
    case `default` = "default"
    case vscode = "vscode"
    case xcode = "xcode"
    case sublime = "sublime"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .default: return "Default"
        case .vscode: return "VS Code"
        case .xcode: return "Xcode"
        case .sublime: return "Sublime"
        }
    }
    
    var shortcuts: [ShortcutAction: KeyboardShortcut] {
        switch self {
        case .default:
            return defaultShortcuts
        case .vscode:
            return vscodeShortcuts
        case .xcode:
            return xcodeShortcuts
        case .sublime:
            return sublimeShortcuts
        }
    }
}

// MARK: - Default Shortcuts

private let defaultShortcuts: [ShortcutAction: KeyboardShortcut] = [
    .openRepository: KeyboardShortcut(key: "o", modifiers: [.command]),
    .cloneRepository: KeyboardShortcut(key: "n", modifiers: [.command, .shift]),
    .showCommandPalette: KeyboardShortcut(key: "p", modifiers: [.command, .shift]),
    .showFileFinder: KeyboardShortcut(key: "p", modifiers: [.command]),
    .stageAll: KeyboardShortcut(key: "s", modifiers: [.command, .shift]),
    .unstageAll: KeyboardShortcut(key: "u", modifiers: [.command, .shift]),
    .commitChanges: KeyboardShortcut(key: "\r", modifiers: [.command]),
    .fetch: KeyboardShortcut(key: "f", modifiers: [.command, .shift]),
    .pull: KeyboardShortcut(key: "l", modifiers: [.command, .shift]),
    .push: KeyboardShortcut(key: "p", modifiers: [.command, .option]),
    .createBranch: KeyboardShortcut(key: "b", modifiers: [.command]),
    .refresh: KeyboardShortcut(key: "r", modifiers: [.command]),
    .showSettings: KeyboardShortcut(key: ",", modifiers: [.command]),
]

private let vscodeShortcuts: [ShortcutAction: KeyboardShortcut] = [
    .openRepository: KeyboardShortcut(key: "o", modifiers: [.command]),
    .showCommandPalette: KeyboardShortcut(key: "p", modifiers: [.command, .shift]),
    .showFileFinder: KeyboardShortcut(key: "p", modifiers: [.command]),
    .stageAll: KeyboardShortcut(key: "s", modifiers: [.command, .shift]),
    .commitChanges: KeyboardShortcut(key: "\r", modifiers: [.command]),
    .refresh: KeyboardShortcut(key: "r", modifiers: [.command]),
]

private let xcodeShortcuts: [ShortcutAction: KeyboardShortcut] = [
    .openRepository: KeyboardShortcut(key: "o", modifiers: [.command]),
    .showCommandPalette: KeyboardShortcut(key: "k", modifiers: [.command, .shift]),
    .commitChanges: KeyboardShortcut(key: "c", modifiers: [.command, .option]),
    .refresh: KeyboardShortcut(key: "r", modifiers: [.command]),
]

private let sublimeShortcuts: [ShortcutAction: KeyboardShortcut] = [
    .openRepository: KeyboardShortcut(key: "o", modifiers: [.command]),
    .showCommandPalette: KeyboardShortcut(key: "p", modifiers: [.command, .shift]),
    .showFileFinder: KeyboardShortcut(key: "p", modifiers: [.command]),
    .refresh: KeyboardShortcut(key: "r", modifiers: [.command]),
]

// MARK: - Shortcut Settings View

struct ShortcutSettingsView: View {
    @StateObject private var manager = KeyboardShortcutManager.shared
    @State private var selectedCategory: ShortcutCategory = .navigation
    @State private var searchText = ""
    @State private var editingAction: ShortcutAction?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Keyboard Shortcuts")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Preset selector
                Menu {
                    ForEach(ShortcutPreset.allCases) { preset in
                        Button {
                            manager.loadPreset(preset)
                        } label: {
                            HStack {
                                Text(preset.displayName)
                                if manager.currentPreset == preset {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(AppTheme.accent)
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text("Preset: \(manager.currentPreset.displayName)")
                        Image(systemName: "chevron.down")
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
                .menuStyle(.borderlessButton)
                
                Button("Reset to Default") {
                    manager.resetToDefault()
                }
            }
            .padding()
            
            Divider()
            
            HSplitView {
                // Categories
                List(ShortcutCategory.allCases, id: \.self, selection: $selectedCategory) { category in
                    Text(category.rawValue)
                        .tag(category)
                }
                .frame(minWidth: 150, maxWidth: 200)
                
                // Shortcuts list
                shortcutsList
            }
        }
    }
    
    private var shortcutsList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(filteredActions) { action in
                    ShortcutRow(
                        action: action,
                        shortcut: manager.shortcuts[action],
                        isEditing: editingAction == action,
                        onEdit: { editingAction = action },
                        onSave: { newShortcut in
                            manager.setShortcut(newShortcut, for: action)
                            editingAction = nil
                        },
                        onRemove: {
                            manager.removeShortcut(for: action)
                        }
                    )
                }
            }
        }
    }
    
    private var filteredActions: [ShortcutAction] {
        ShortcutAction.allCases.filter { $0.category == selectedCategory }
    }
}

// MARK: - Shortcut Row

struct ShortcutRow: View {
    let action: ShortcutAction
    let shortcut: KeyboardShortcut?
    let isEditing: Bool
    let onEdit: () -> Void
    let onSave: (KeyboardShortcut) -> Void
    let onRemove: () -> Void
    
    @State private var isHovered = false
    @State private var recordingShortcut: KeyboardShortcut?
    
    var body: some View {
        HStack {
            Text(action.displayName)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            
            if isEditing {
                ShortcutRecorder(shortcut: $recordingShortcut)
                    .frame(width: 150)
                
                Button("Save") {
                    if let newShortcut = recordingShortcut {
                        onSave(newShortcut)
                    }
                }
                .buttonStyle(.borderedProminent)
            } else {
                if let shortcut = shortcut {
                    Text(shortcut.displayString)
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.textSecondary.opacity(0.2))
                        .cornerRadius(6)
                } else {
                    Text("Not set")
                        .foregroundColor(AppTheme.textPrimary)
                }
                
                if isHovered {
                    Button {
                        onEdit()
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .buttonStyle(.borderless)
                    
                    if shortcut != nil {
                        Button {
                            onRemove()
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHovered ? AppTheme.textSecondary.opacity(0.05) : Color.clear)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Shortcut Recorder

struct ShortcutRecorder: View {
    @Binding var shortcut: KeyboardShortcut?
    @State private var isRecording = false
    
    var body: some View {
        Button {
            isRecording = true
        } label: {
            if isRecording {
                Text("Press keys...")
                    .foregroundColor(AppTheme.textPrimary)
            } else if let shortcut = shortcut {
                Text(shortcut.displayString)
                    .font(.system(.body, design: .monospaced))
            } else {
                Text("Click to record")
                    .foregroundColor(AppTheme.textPrimary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(AppTheme.textSecondary.opacity(0.1))
        .cornerRadius(6)
        // TODO: Implement actual key recording with NSEvent monitor
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let shortcutsDidChange = Notification.Name("shortcutsDidChange")
}
