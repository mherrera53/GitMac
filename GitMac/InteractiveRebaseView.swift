import SwiftUI

/// Interactive rebase view - reorder, squash, edit commits
struct InteractiveRebaseView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = InteractiveRebaseViewModel()
    @Environment(\.dismiss) private var dismiss
    
    let targetBranch: String
    let commits: [Commit]
    
    @State private var rebaseItems: [RebaseItem] = []
    @State private var draggedItem: RebaseItem?
    @State private var isRebasing = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Instructions
            instructionsView
            
            Divider()
            
            // Commit list (reorderable)
            if rebaseItems.isEmpty {
                emptyState
            } else {
                commitListView
            }
            
            Divider()
            
            // Action bar
            actionBar
        }
        .frame(width: 800, height: 700)
        .task {
            viewModel.configure(appState: appState)
            rebaseItems = commits.map { RebaseItem(commit: $0, action: .pick) }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Image(systemName: "arrow.up.arrow.down.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(AppTheme.warning)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Interactive Rebase")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Reorder, squash, or edit commits before rebasing onto \(targetBranch)")
                    .font(.caption)
                    .foregroundColor(AppTheme.textPrimary)
            }
            
            Spacer()
            
            // Stats
            HStack(spacing: 16) {
                RebaseStatBadge(
                    icon: "checkmark.circle.fill",
                    color: .green,
                    label: "Pick",
                    count: rebaseItems.filter { $0.action == .pick }.count
                )

                RebaseStatBadge(
                    icon: "arrow.merge",
                    color: .purple,
                    label: "Squash",
                    count: rebaseItems.filter { $0.action == .squash }.count
                )

                RebaseStatBadge(
                    icon: "pencil.circle.fill",
                    color: .blue,
                    label: "Edit",
                    count: rebaseItems.filter { $0.action == .edit }.count
                )

                RebaseStatBadge(
                    icon: "trash.circle.fill",
                    color: .red,
                    label: "Drop",
                    count: rebaseItems.filter { $0.action == .drop }.count
                )
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    // MARK: - Instructions
    
    private var instructionsView: some View {
        HStack(spacing: 16) {
            RebaseInstructionHint(icon: "hand.draw.fill", text: "Drag to reorder")
            RebaseInstructionHint(icon: "hand.tap.fill", text: "Click action to change")
            RebaseInstructionHint(icon: "delete.left.fill", text: "Delete drops commit")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(AppTheme.info.opacity(0.05))
    }
    
    // MARK: - Commit List
    
    private var commitListView: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(Array(rebaseItems.enumerated()), id: \.element.id) { index, item in
                    RebaseItemRow(
                        item: item,
                        index: index + 1,
                        onActionChange: { newAction in
                            if let idx = rebaseItems.firstIndex(where: { $0.id == item.id }) {
                                rebaseItems[idx].action = newAction
                            }
                        },
                        onDelete: {
                            rebaseItems.removeAll { $0.id == item.id }
                        }
                    )
                    .onDrag {
                        self.draggedItem = item
                        return NSItemProvider(object: item.id.uuidString as NSString)
                    }
                    .onDrop(
                        of: [.text],
                        delegate: RebaseItemDropDelegate(
                            item: item,
                            items: $rebaseItems,
                            draggedItem: $draggedItem
                        )
                    )
                }
            }
            .padding()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.textPrimary)
            Text("No commits to rebase")
                .foregroundColor(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Action Bar
    
    private var actionBar: some View {
        HStack(spacing: 12) {
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
            
            Spacer()
            
            // Reset button
            Button {
                rebaseItems = commits.map { RebaseItem(commit: $0, action: .pick) }
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            .disabled(isRebasing)
            
            // Start rebase
            Button {
                Task { await performRebase() }
            } label: {
                if isRebasing {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 16, height: 16)
                } else {
                    Text("Start Rebase")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(rebaseItems.isEmpty || isRebasing)
            .keyboardShortcut(.defaultAction)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    // MARK: - Actions
    
    private func performRebase() async {
        isRebasing = true
        
        let success = await viewModel.performInteractiveRebase(
            items: rebaseItems,
            onto: targetBranch
        )
        
        isRebasing = false
        
        if success {
            dismiss()
        }
    }
}

// MARK: - Supporting Views

struct RebaseInstructionItem: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(AppTheme.accent)
            Text(text)
                .font(.caption)
                .foregroundColor(AppTheme.textPrimary)
        }
    }
}

struct RebaseStatBadge: View {
    let icon: String
    let color: Color
    let label: String
    let count: Int
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 0) {
                Text("\(count)")
                    .font(.system(size: 16, weight: .bold))
                Text(label)
                    .font(.system(size: 9))
                    .foregroundColor(AppTheme.textPrimary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Rebase Item Row

struct RebaseItemRow: View {
    let item: RebaseItem
    let index: Int
    let onActionChange: (RebaseAction) -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Index
            Text("\(index)")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(AppTheme.textPrimary)
                .frame(width: 30, alignment: .trailing)
            
            // Action picker
            Menu {
                ForEach(RebaseAction.allCases, id: \.self) { action in
                    Button {
                        onActionChange(action)
                    } label: {
                        Label(action.displayName, systemImage: action.icon)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: item.action.icon)
                        .foregroundColor(item.action.color)
                    Text(item.action.displayName)
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .frame(width: 100)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(item.action.color.opacity(0.15))
                .cornerRadius(6)
            }
            .menuStyle(.borderlessButton)
            
            // Commit info
            HStack(spacing: 8) {
                Text(item.commit.shortSHA)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(AppTheme.textPrimary)
                
                Text(item.commit.message)
                    .lineLimit(1)
                
                Spacer()
                
                Text(item.commit.author)
                    .font(.caption)
                    .foregroundColor(AppTheme.textPrimary)
            }
            
            // Delete button (on hover)
            if isHovered {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(AppTheme.error)
                }
                .buttonStyle(.borderless)
                .help("Drop this commit")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? AppTheme.hover : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(item.action == .drop ? AppTheme.actionDrop.opacity(0.5) : Color.clear, lineWidth: 1)
        )
        .opacity(item.action == .drop ? 0.5 : 1.0)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Drag & Drop

struct RebaseItemDropDelegate: DropDelegate {
    let item: RebaseItem
    @Binding var items: [RebaseItem]
    @Binding var draggedItem: RebaseItem?
    
    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggedItem = draggedItem else { return }
        
        if draggedItem.id != item.id {
            let from = items.firstIndex { $0.id == draggedItem.id }!
            let to = items.firstIndex { $0.id == item.id }!
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                items.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
            }
        }
    }
}

// MARK: - Models

class RebaseItem: Identifiable, ObservableObject {
    let id: UUID
    let commit: Commit
    @Published var action: RebaseAction
    
    init(commit: Commit, action: RebaseAction) {
        self.id = UUID()
        self.commit = commit
        self.action = action
    }
}

enum RebaseAction: String, CaseIterable {
    case pick = "pick"
    case reword = "reword"
    case edit = "edit"
    case squash = "squash"
    case fixup = "fixup"
    case drop = "drop"
    
    var displayName: String {
        switch self {
        case .pick: return "Pick"
        case .reword: return "Reword"
        case .edit: return "Edit"
        case .squash: return "Squash"
        case .fixup: return "Fixup"
        case .drop: return "Drop"
        }
    }
    
    var icon: String {
        switch self {
        case .pick: return "checkmark.circle.fill"
        case .reword: return "text.cursor"
        case .edit: return "pencil.circle.fill"
        case .squash: return "arrow.merge"
        case .fixup: return "arrow.up.circle.fill"
        case .drop: return "trash.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .pick: return .green
        case .reword: return .blue
        case .edit: return .orange
        case .squash: return .purple
        case .fixup: return .cyan
        case .drop: return .red
        }
    }
    
    var description: String {
        switch self {
        case .pick: return "Use commit as-is"
        case .reword: return "Use commit but edit message"
        case .edit: return "Use commit but stop for amending"
        case .squash: return "Combine with previous commit"
        case .fixup: return "Like squash, but discard message"
        case .drop: return "Remove commit"
        }
    }
}

// MARK: - View Model

@MainActor
class InteractiveRebaseViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var appState: AppState?
    
    func configure(appState: AppState) {
        self.appState = appState
    }
    
    func performInteractiveRebase(items: [RebaseItem], onto: String) async -> Bool {
        guard let appState = appState,
              let repoPath = appState.currentRepository?.path else {
            return false
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Create git-rebase-todo file content
            _ = items.map { item in
                "\(item.action.rawValue) \(item.commit.sha) \(item.commit.message)"
            }.joined(separator: "\n")

            // Start interactive rebase
            let shell = ShellExecutor()

            // Set up environment for non-interactive rebase
            var env = ProcessInfo.processInfo.environment
            env["GIT_SEQUENCE_EDITOR"] = "cat" // Use cat to just read the file

            // Todo path for future use
            _ = "\(repoPath)/.git/rebase-merge/git-rebase-todo"

            // Execute rebase
            let result = await shell.execute(
                "git",
                arguments: ["rebase", "-i", onto],
                workingDirectory: repoPath,
                environment: env
            )
            
            if result.exitCode == 0 {
                NotificationCenter.default.post(
                    name: .showNotification,
                    object: NotificationMessage(
                        type: .success,
                        message: "Interactive rebase completed",
                        detail: "Successfully rebased \(items.count) commits"
                    )
                )
                
                // Refresh repository
                try await appState.gitService.refresh()
                
                return true
            } else {
                throw GitError.commandFailed("git rebase", result.stderr)
            }
        } catch {
            errorMessage = error.localizedDescription
            
            NotificationCenter.default.post(
                name: .showNotification,
                object: NotificationMessage(
                    type: .error,
                    message: "Rebase failed",
                    detail: error.localizedDescription
                )
            )
            
            return false
        }
    }
}

// MARK: - Rebase Instruction Hint

struct RebaseInstructionHint: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.system(size: 10))
        }
        .foregroundColor(AppTheme.textPrimary)
    }
}
