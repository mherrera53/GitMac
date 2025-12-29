import SwiftUI

/// Command Palette - Fast access to all Git operations (Cmd+Shift+P)
struct CommandPalette: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var selectedIndex = 0
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: "command.circle.fill")
                    .font(DesignTokens.Typography.title3)
                    .foregroundColor(AppTheme.accent)

                TextField("Type a command...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(DesignTokens.Typography.headline)
                    .focused($isSearchFocused)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppTheme.textPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Results
            if filteredCommands.isEmpty {
                emptyState
            } else {
                commandList
            }
            
            Divider()
            
            // Footer with shortcuts
            footerView
        }
        .frame(width: 600, height: 500)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            isSearchFocused = true
        }
    }
    
    private var commandList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(Array(filteredCommands.enumerated()), id: \.element.id) { index, command in
                        CommandRow(
                            command: command,
                            isSelected: index == selectedIndex,
                            searchText: searchText
                        )
                        .id(index)
                        .onTapGesture {
                            executeCommand(command)
                        }
                    }
                }
            }
            .onChange(of: selectedIndex) { _, newValue in
                withAnimation {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.textPrimary)
            
            Text("No commands found")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)
            
            Text("Try a different search term")
                .font(.caption)
                .foregroundColor(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var footerView: some View {
        HStack {
            KeyboardShortcutHint(symbol: "↑↓", label: "Navigate")
            KeyboardShortcutHint(symbol: "↵", label: "Execute")
            KeyboardShortcutHint(symbol: "Esc", label: "Close")
            
            Spacer()
            
            Text("\(filteredCommands.count) commands")
                .font(.caption)
                .foregroundColor(AppTheme.textPrimary)
        }
        .padding(.horizontal)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }
    
    // MARK: - Keyboard Navigation
    
    private var keyboardHandler: some View {
        Color.clear
            .onKeyPress(.downArrow) {
                selectedIndex = min(selectedIndex + 1, filteredCommands.count - 1)
                return .handled
            }
            .onKeyPress(.upArrow) {
                selectedIndex = max(selectedIndex - 1, 0)
                return .handled
            }
            .onKeyPress(.return) {
                if !filteredCommands.isEmpty {
                    executeCommand(filteredCommands[selectedIndex])
                }
                return .handled
            }
            .onKeyPress(.escape) {
                dismiss()
                return .handled
            }
    }
    
    // MARK: - Helpers
    
    private var filteredCommands: [GitCommand] {
        let commands = availableCommands
        
        if searchText.isEmpty {
            return commands
        }
        
        return commands.filter { command in
            command.title.localizedCaseInsensitiveContains(searchText) ||
            command.description.localizedCaseInsensitiveContains(searchText) ||
            command.keywords.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    private var availableCommands: [GitCommand] {
        var commands: [GitCommand] = [
            // Repository
            .init(
                id: "repo.open",
                category: .repository,
                title: "Open Repository",
                description: "Open an existing Git repository",
                icon: "folder.badge.plus",
                keywords: ["open", "folder"],
                action: { NotificationCenter.default.post(name: .openRepository, object: nil) }
            ),
            .init(
                id: "repo.clone",
                category: .repository,
                title: "Clone Repository",
                description: "Clone a repository from URL",
                icon: "arrow.down.doc",
                keywords: ["clone", "download"],
                action: { NotificationCenter.default.post(name: .cloneRepository, object: nil) }
            ),
            .init(
                id: "repo.init",
                category: .repository,
                title: "Initialize Repository",
                description: "Create a new Git repository",
                icon: "plus.circle",
                keywords: ["init", "new", "create"],
                action: { /* TODO */ }
            ),
            
            // Branches
            .init(
                id: "branch.create",
                category: .branch,
                title: "Create Branch",
                description: "Create a new branch",
                icon: "arrow.branch",
                keywords: ["branch", "new", "create"],
                shortcut: "Cmd+B",
                action: { NotificationCenter.default.post(name: .newBranch, object: nil) }
            ),
            .init(
                id: "branch.checkout",
                category: .branch,
                title: "Checkout Branch",
                description: "Switch to a different branch",
                icon: "arrow.right.circle",
                keywords: ["checkout", "switch"],
                action: { /* TODO: Show branch picker */ }
            ),
            .init(
                id: "branch.delete",
                category: .branch,
                title: "Delete Branch",
                description: "Delete a local branch",
                icon: "trash",
                keywords: ["delete", "remove"],
                action: { /* TODO */ }
            ),
            
            // Commits
            .init(
                id: "commit.create",
                category: .commit,
                title: "Commit Changes",
                description: "Create a new commit with staged changes",
                icon: "checkmark.circle",
                keywords: ["commit", "save"],
                shortcut: "Cmd+Return",
                action: { /* Focus commit message */ }
            ),
            .init(
                id: "commit.amend",
                category: .commit,
                title: "Amend Last Commit",
                description: "Modify the most recent commit",
                icon: "pencil.circle",
                keywords: ["amend", "edit", "modify"],
                action: { /* TODO */ }
            ),
            .init(
                id: "commit.revert",
                category: .commit,
                title: "Revert Commit",
                description: "Create inverse commit",
                icon: "arrow.uturn.backward.circle",
                keywords: ["revert", "undo"],
                action: { /* TODO */ }
            ),
            
            // Staging
            .init(
                id: "stage.all",
                category: .staging,
                title: "Stage All Changes",
                description: "Stage all modified files",
                icon: "plus.circle",
                keywords: ["stage", "add", "all"],
                shortcut: "Cmd+Shift+S",
                action: { NotificationCenter.default.post(name: .stageAll, object: nil) }
            ),
            .init(
                id: "unstage.all",
                category: .staging,
                title: "Unstage All Changes",
                description: "Unstage all staged files",
                icon: "minus.circle",
                keywords: ["unstage", "remove"],
                shortcut: "Cmd+Shift+U",
                action: { NotificationCenter.default.post(name: .unstageAll, object: nil) }
            ),
            .init(
                id: "discard.all",
                category: .staging,
                title: "Discard All Changes",
                description: "⚠️ Permanently discard all unstaged changes",
                icon: "xmark.circle",
                keywords: ["discard", "reset", "delete"],
                action: { /* TODO: Confirmation dialog */ }
            ),
            
            // Remote
            .init(
                id: "remote.fetch",
                category: .remote,
                title: "Fetch",
                description: "Fetch changes from remote",
                icon: "arrow.down.circle",
                keywords: ["fetch", "download"],
                shortcut: "Cmd+Shift+F",
                action: { NotificationCenter.default.post(name: .fetch, object: nil) }
            ),
            .init(
                id: "remote.pull",
                category: .remote,
                title: "Pull",
                description: "Fetch and merge changes from remote",
                icon: "arrow.down.to.line.circle",
                keywords: ["pull", "download", "merge"],
                shortcut: "Cmd+Shift+L",
                action: { NotificationCenter.default.post(name: .pull, object: nil) }
            ),
            .init(
                id: "remote.push",
                category: .remote,
                title: "Push",
                description: "Push commits to remote",
                icon: "arrow.up.circle",
                keywords: ["push", "upload"],
                shortcut: "Cmd+Shift+P",
                action: { NotificationCenter.default.post(name: .push, object: nil) }
            ),
            
            // Stash
            .init(
                id: "stash.save",
                category: .stash,
                title: "Stash Changes",
                description: "Save changes for later",
                icon: "archivebox",
                keywords: ["stash", "save", "store"],
                action: { NotificationCenter.default.post(name: .stash, object: nil) }
            ),
            .init(
                id: "stash.pop",
                category: .stash,
                title: "Pop Stash",
                description: "Apply and remove most recent stash",
                icon: "tray.and.arrow.up",
                keywords: ["pop", "apply"],
                action: { NotificationCenter.default.post(name: .popStash, object: nil) }
            ),
            
            // Merge & Rebase
            .init(
                id: "merge.branch",
                category: .merge,
                title: "Merge Branch",
                description: "Merge another branch into current",
                icon: "arrow.triangle.merge",
                keywords: ["merge", "combine"],
                action: { NotificationCenter.default.post(name: .merge, object: nil) }
            ),
            .init(
                id: "rebase.interactive",
                category: .merge,
                title: "Interactive Rebase",
                description: "Reorder, squash, or edit commits",
                icon: "arrow.up.arrow.down.circle",
                keywords: ["rebase", "interactive", "squash"],
                action: { /* TODO */ }
            ),
            
            // Reset
            .init(
                id: "reset.soft",
                category: .reset,
                title: "Reset (Soft)",
                description: "Keep changes staged",
                icon: "arrow.uturn.backward",
                keywords: ["reset", "soft"],
                action: { /* TODO */ }
            ),
            .init(
                id: "reset.mixed",
                category: .reset,
                title: "Reset (Mixed)",
                description: "Keep changes unstaged",
                icon: "arrow.uturn.backward",
                keywords: ["reset", "mixed"],
                action: { /* TODO */ }
            ),
            .init(
                id: "reset.hard",
                category: .reset,
                title: "Reset (Hard)",
                description: "⚠️ Discard all changes",
                icon: "arrow.uturn.backward",
                keywords: ["reset", "hard", "discard"],
                action: { /* TODO */ }
            ),
            
            // View
            .init(
                id: "view.reflog",
                category: .view,
                title: "Show Reflog",
                description: "View Git's operation history",
                icon: "clock.arrow.circlepath",
                keywords: ["reflog", "history"],
                action: { /* TODO */ }
            ),
            .init(
                id: "view.graph",
                category: .view,
                title: "Show Commit Graph",
                description: "View commit history graph",
                icon: "chart.xyaxis.line",
                keywords: ["graph", "history", "log"],
                action: { /* TODO */ }
            ),
        ]
        
        // Sort by relevance (exact match first, then alphabetical)
        if !searchText.isEmpty {
            commands.sort { a, b in
                let aExact = a.title.localizedCaseInsensitiveCompare(searchText) == .orderedSame
                let bExact = b.title.localizedCaseInsensitiveCompare(searchText) == .orderedSame
                
                if aExact != bExact {
                    return aExact
                }
                
                return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            }
        }
        
        return commands
    }
    
    private func executeCommand(_ command: GitCommand) {
        dismiss()
        
        // Small delay to let sheet dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            command.action()
        }
    }
}

// MARK: - Command Row

struct CommandRow: View {
    let command: GitCommand
    let isSelected: Bool
    let searchText: String
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: command.icon)
                .font(.system(size: 20))
                .foregroundColor(command.category.color)
                .frame(width: 32, height: 32)
                .background(command.category.color.opacity(0.15))
                .cornerRadius(8)
            
            // Title & Description
            VStack(alignment: .leading, spacing: 2) {
                Text(highlightedText(command.title, matching: searchText))
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(command.description)
                    .font(.caption)
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Shortcut badge
            if let shortcut = command.shortcut {
                Text(shortcut)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(AppTheme.textPrimary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(AppTheme.textSecondary.opacity(0.1))
                    .cornerRadius(4)
            }
            
            // Category badge
            Text(command.category.displayName)
                .font(.system(size: 9))
                .foregroundColor(command.category.color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(command.category.color.opacity(0.1))
                .cornerRadius(4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? AppTheme.accent.opacity(0.2) : Color.clear)
        .contentShape(Rectangle())
    }
    
    private func highlightedText(_ text: String, matching search: String) -> AttributedString {
        var attributed = AttributedString(text)
        
        if !search.isEmpty, let range = text.range(of: search, options: .caseInsensitive) {
            let nsRange = NSRange(range, in: text)
            if let attrRange = Range<AttributedString.Index>(nsRange, in: attributed) {
                attributed[attrRange].foregroundColor = .accentColor
                attributed[attrRange].font = .body.bold()
            }
        }
        
        return attributed
    }
}

// MARK: - Supporting Views

struct KeyboardShortcutHint: View {
    let symbol: String
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Text(symbol)
                .font(.system(size: 11, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(AppTheme.textSecondary.opacity(0.15))
                .cornerRadius(4)
            
            Text(label)
                .font(.caption)
                .foregroundColor(AppTheme.textPrimary)
        }
    }
}

// MARK: - Models

struct GitCommand: Identifiable {
    let id: String
    let category: CommandCategory
    let title: String
    let description: String
    let icon: String
    let keywords: [String]
    var shortcut: String? = nil
    let action: () -> Void
}

enum CommandCategory {
    case repository
    case branch
    case commit
    case staging
    case remote
    case stash
    case merge
    case reset
    case view
    case tools
    
    var displayName: String {
        switch self {
        case .repository: return "Repo"
        case .branch: return "Branch"
        case .commit: return "Commit"
        case .staging: return "Stage"
        case .remote: return "Remote"
        case .stash: return "Stash"
        case .merge: return "Merge"
        case .reset: return "Reset"
        case .view: return "View"
        case .tools: return "Tools"
        }
    }
    
    var color: Color {
        switch self {
        case .repository: return .blue
        case .branch: return .green
        case .commit: return .orange
        case .staging: return .purple
        case .remote: return .cyan
        case .stash: return .indigo
        case .merge: return .pink
        case .reset: return .red
        case .view: return .teal
        case .tools: return .gray
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let stageAll = Notification.Name("stageAll")
    static let unstageAll = Notification.Name("unstageAll")
    static let showNotification = Notification.Name("showNotification")
}

struct NotificationMessage {
    enum NotificationType {
        case success
        case error
        case warning
        case info
    }
    
    let type: NotificationType
    let message: String
    let detail: String?
    
    init(type: NotificationType, message: String, detail: String? = nil) {
        self.type = type
        self.message = message
        self.detail = detail
    }
}
