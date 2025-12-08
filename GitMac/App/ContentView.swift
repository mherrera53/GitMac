import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var recentReposManager: RecentRepositoriesManager
    @StateObject private var themeManager = ThemeManager.shared
    @State private var showCloneSheet = false
    @State private var showOpenPanel = false
    @State private var leftPanelWidth: CGFloat = 220
    @State private var rightPanelWidth: CGFloat = 380

    var body: some View {
        VStack(spacing: 0) {
            // Tab Bar (only show if there are open repos)
            if !appState.openTabs.isEmpty {
                RepositoryTabBar()
            }

            // Main content
            if appState.currentRepository != nil {
                GitKrakenLayout(
                    leftPanelWidth: $leftPanelWidth,
                    rightPanelWidth: $rightPanelWidth
                )
            } else {
                WelcomeView(
                    onOpen: { showOpenPanel = true },
                    onClone: { showCloneSheet = true }
                )
            }
        }
        .background(GitKrakenTheme.background)
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
        .onReceive(NotificationCenter.default.publisher(for: .openRepository)) { _ in
            showOpenPanel = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .cloneRepository)) { _ in
            showCloneSheet = true
        }
        .alert("Error", isPresented: .constant(appState.errorMessage != nil)) {
            Button("OK") {
                appState.errorMessage = nil
            }
        } message: {
            Text(appState.errorMessage ?? "")
        }
    }
}

// MARK: - GitKraken-style 3-Panel Layout
struct GitKrakenLayout: View {
    @EnvironmentObject var appState: AppState
    @Binding var leftPanelWidth: CGFloat
    @Binding var rightPanelWidth: CGFloat
    @State private var selectedFileDiff: FileDiff?
    @State private var showTerminal = false
    @State private var terminalHeight: CGFloat = 200

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Left Panel - Branches/Remotes/Tags
                LeftSidebarPanel()
                    .frame(width: leftPanelWidth)
                    .background(GitKrakenTheme.sidebar)

                // Resizer
                PanelResizer(width: $leftPanelWidth, minWidth: 180, maxWidth: 350)

                // Center Panel - Graph OR Diff
                CenterPanel(selectedFileDiff: $selectedFileDiff, showTerminal: $showTerminal)
                    .frame(maxWidth: .infinity)
                    .background(GitKrakenTheme.background)

                // Resizer
                PanelResizer(width: $rightPanelWidth, minWidth: 300, maxWidth: 500, isRight: true)

                // Right Panel - Staging/Commit
                RightStagingPanel(selectedFileDiff: $selectedFileDiff)
                    .frame(width: rightPanelWidth)
                    .background(GitKrakenTheme.panel)
            }

            // Terminal Panel (togglable)
            if showTerminal {
                TerminalPanel(height: $terminalHeight, onClose: { showTerminal = false })
            }
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
            TerminalResizer(height: $height)

            // Terminal content
            TerminalView()
                .frame(height: height)
        }
        .background(Color(hex: "1E1E1E"))
    }
}

// MARK: - Terminal Resizer
struct TerminalResizer: View {
    @Binding var height: CGFloat
    @State private var isDragging = false

    var body: some View {
        Rectangle()
            .fill(GitKrakenTheme.border)
            .frame(height: 4)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        let newHeight = height - value.translation.height
                        height = min(max(newHeight, 100), 500)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeUpDown.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}

// MARK: - Center Panel (Graph or Diff)
struct CenterPanel: View {
    @EnvironmentObject var appState: AppState
    @Binding var selectedFileDiff: FileDiff?
    @Binding var showTerminal: Bool

    var body: some View {
        VStack(spacing: 0) {
            if let fileDiff = selectedFileDiff {
                // Diff View with close button
                DiffViewWithClose(fileDiff: fileDiff) {
                    selectedFileDiff = nil
                }
            } else {
                // Graph View
                GraphToolbar(showTerminal: $showTerminal)
                if appState.currentRepository != nil {
                    CommitGraphView()
                } else {
                    EmptyStateView()
                }
            }
        }
    }
}

// MARK: - Diff View with Close
struct DiffViewWithClose: View {
    let fileDiff: FileDiff
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Button(action: onClose) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(GitKrakenTheme.textSecondary)
                    .frame(width: 24, height: 24)
                    .background(GitKrakenTheme.backgroundTertiary)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)

                Image(systemName: FileTypeIcon.systemIcon(for: fileDiff.displayPath))
                    .foregroundColor(FileTypeIcon.color(for: fileDiff.displayPath))

                Text(fileDiff.displayPath)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(GitKrakenTheme.textPrimary)

                Spacer()

                HStack(spacing: 12) {
                    Text("+\(fileDiff.additions)")
                        .foregroundColor(GitKrakenTheme.accentGreen)
                    Text("-\(fileDiff.deletions)")
                        .foregroundColor(GitKrakenTheme.accentRed)
                }
                .font(.system(size: 12, weight: .medium, design: .monospaced))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(GitKrakenTheme.toolbar)

            Rectangle().fill(GitKrakenTheme.border).frame(height: 1)

            // Diff content
            GitKrakenDiffContent(fileDiff: fileDiff)
        }
    }
}

// MARK: - GitKraken Diff Content
struct GitKrakenDiffContent: View {
    let fileDiff: FileDiff

    var body: some View {
        if fileDiff.isBinary {
            VStack(spacing: 16) {
                Image(systemName: "doc.fill")
                    .font(.system(size: 48))
                    .foregroundColor(GitKrakenTheme.textMuted)
                Text("Binary file - cannot display diff")
                    .foregroundColor(GitKrakenTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView([.vertical, .horizontal]) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(fileDiff.hunks) { hunk in
                        // Hunk header
                        Text(hunk.header)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(GitKrakenTheme.accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(GitKrakenTheme.accent.opacity(0.1))

                        // Lines
                        ForEach(hunk.lines) { line in
                            DiffLineView(line: line)
                        }
                    }
                }
            }
        }
    }
}

struct DiffLineView: View {
    let line: DiffLine

    var bgColor: Color {
        switch line.type {
        case .addition: return GitKrakenTheme.accentGreen.opacity(0.12)
        case .deletion: return GitKrakenTheme.accentRed.opacity(0.12)
        default: return Color.clear
        }
    }

    var textColor: Color {
        switch line.type {
        case .addition: return GitKrakenTheme.accentGreen
        case .deletion: return GitKrakenTheme.accentRed
        default: return GitKrakenTheme.textPrimary
        }
    }

    var prefix: String {
        switch line.type {
        case .addition: return "+"
        case .deletion: return "-"
        default: return " "
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Line numbers
            Text(line.oldLineNumber.map { String($0) } ?? "")
                .frame(width: 40, alignment: .trailing)
            Text(line.newLineNumber.map { String($0) } ?? "")
                .frame(width: 40, alignment: .trailing)
                .padding(.trailing, 8)

            Text(prefix)
                .frame(width: 14)

            Text(line.content)

            Spacer(minLength: 0)
        }
        .font(.system(size: 12, design: .monospaced))
        .foregroundColor(textColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 1)
        .background(bgColor)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack {
            Spacer()
            Text("No commits")
                .foregroundColor(GitKrakenTheme.textMuted)
            Spacer()
        }
    }
}

// MARK: - Panel Resizer
struct PanelResizer: View {
    @Binding var width: CGFloat
    let minWidth: CGFloat
    let maxWidth: CGFloat
    var isRight: Bool = false

    var body: some View {
        Rectangle()
            .fill(GitKrakenTheme.border)
            .frame(width: 1)
            .contentShape(Rectangle().inset(by: -3))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let delta = isRight ? -value.translation.width : value.translation.width
                        let newWidth = width + delta
                        width = min(max(newWidth, minWidth), maxWidth)
                    }
            )
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}

// MARK: - Left Sidebar Panel (GitKraken style)
struct LeftSidebarPanel: View {
    @EnvironmentObject var appState: AppState
    @State private var expandedSections: Set<String> = ["local", "remote"]

    var body: some View {
        VStack(spacing: 0) {
            // Repository Header
            if let repo = appState.currentRepository {
                HStack(spacing: 8) {
                    Image(systemName: "folder.fill")
                        .foregroundColor(GitKrakenTheme.accent)
                    Text(repo.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(GitKrakenTheme.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(GitKrakenTheme.backgroundSecondary)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    // LOCAL Section - Show master/main + 3 most recent branches
                    SidebarSection(title: "LOCAL", isExpanded: expandedSections.contains("local")) {
                        expandedSections.toggle("local")
                    } content: {
                        if let repo = appState.currentRepository {
                            let localBranches = repo.branches.filter { !$0.isRemote }

                            // Find master or main branch
                            let mainBranch = localBranches.first { $0.name == "master" || $0.name == "main" }

                            // Get current branch if it's not master/main
                            let currentBranch = localBranches.first { $0.isCurrent && $0.name != "master" && $0.name != "main" }

                            // Get other branches (excluding master/main and current)
                            let otherBranches = localBranches
                                .filter { !$0.isCurrent && $0.name != "master" && $0.name != "main" }
                                .prefix(3)

                            // Display in order: main/master first, then current, then recent
                            if let main = mainBranch {
                                SidebarBranchRow(branch: main)
                            }

                            if let current = currentBranch {
                                SidebarBranchRow(branch: current)
                            }

                            ForEach(Array(otherBranches)) { branch in
                                SidebarBranchRow(branch: branch)
                            }

                            // Show count of hidden branches
                            let totalLocal = localBranches.count
                            let shownCount = (mainBranch != nil ? 1 : 0) + (currentBranch != nil ? 1 : 0) + otherBranches.count
                            if totalLocal > shownCount {
                                HStack {
                                    Text("+ \(totalLocal - shownCount) more")
                                        .font(.system(size: 10))
                                        .foregroundColor(GitKrakenTheme.textMuted)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    // REMOTE Section
                    SidebarSection(title: "REMOTE", isExpanded: expandedSections.contains("remote")) {
                        expandedSections.toggle("remote")
                    } content: {
                        if let repo = appState.currentRepository {
                            ForEach(repo.remotes) { remote in
                                RemoteSidebarRow(remote: remote)
                            }
                        }
                    }

                    // STASHES Section
                    SidebarSection(title: "STASHES", isExpanded: expandedSections.contains("stashes")) {
                        expandedSections.toggle("stashes")
                    } content: {
                        if let repo = appState.currentRepository {
                            ForEach(repo.stashes) { stash in
                                StashSidebarRow(stash: stash)
                            }
                        }
                    }

                    // TAGS Section
                    SidebarSection(title: "TAGS", isExpanded: expandedSections.contains("tags")) {
                        expandedSections.toggle("tags")
                    } content: {
                        if let repo = appState.currentRepository {
                            ForEach(repo.tags) { tag in
                                TagSidebarRow(tag: tag)
                            }
                        }
                    }

                    // WORKTREES Section
                    SidebarSection(title: "WORKTREES", isExpanded: expandedSections.contains("worktrees")) {
                        expandedSections.toggle("worktrees")
                    } content: {
                        WorktreeSidebarSection()
                    }
                }
                .padding(.top, 8)
            }
        }
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
                        .foregroundColor(GitKrakenTheme.textMuted)
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
                    .foregroundColor(GitKrakenTheme.textMuted)
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
                .foregroundColor(worktree.isMain ? GitKrakenTheme.accent : GitKrakenTheme.accentPurple)

            Text(worktree.name)
                .font(.system(size: 11))
                .foregroundColor(worktree.isMain ? GitKrakenTheme.textPrimary : GitKrakenTheme.textSecondary)
                .lineLimit(1)

            if worktree.isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9))
                    .foregroundColor(GitKrakenTheme.accentOrange)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(isHovered ? GitKrakenTheme.hover : Color.clear)
        .onHover { isHovered = $0 }
        .onTapGesture(count: 2) {
            // Open worktree in new tab
            Task {
                await appState.openRepository(at: worktree.path)
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
                        .foregroundColor(GitKrakenTheme.textMuted)
                        .frame(width: 12)
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(GitKrakenTheme.textMuted)
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

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(branch.isCurrent ? GitKrakenTheme.accentGreen : GitKrakenTheme.textMuted)
                .frame(width: 8, height: 8)

            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 12))
                .foregroundColor(branch.isCurrent ? GitKrakenTheme.accentGreen : GitKrakenTheme.textSecondary)

            Text(branch.name)
                .font(.system(size: 12))
                .foregroundColor(branch.isCurrent ? GitKrakenTheme.textPrimary : GitKrakenTheme.textSecondary)
                .lineLimit(1)

            Spacer()

            if branch.isCurrent {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(GitKrakenTheme.accentGreen)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(isHovered ? GitKrakenTheme.hover : Color.clear)
        .onHover { isHovered = $0 }
        .onTapGesture {
            appState.selectedBranch = branch
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
                    .foregroundColor(GitKrakenTheme.textMuted)
                    .frame(width: 12)

                Image(systemName: "network")
                    .font(.system(size: 12))
                    .foregroundColor(GitKrakenTheme.textSecondary)

                Text(remote.name)
                    .font(.system(size: 12))
                    .foregroundColor(GitKrakenTheme.textSecondary)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(isHovered ? GitKrakenTheme.hover : Color.clear)
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
                .foregroundColor(GitKrakenTheme.accentPurple)

            Text(stash.message)
                .font(.system(size: 12))
                .foregroundColor(GitKrakenTheme.textSecondary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(isHovered ? GitKrakenTheme.hover : Color.clear)
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
                .foregroundColor(GitKrakenTheme.accentOrange)

            Text(tag.name)
                .font(.system(size: 12))
                .foregroundColor(GitKrakenTheme.textSecondary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(isHovered ? GitKrakenTheme.hover : Color.clear)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Graph Toolbar
struct GraphToolbar: View {
    @EnvironmentObject var appState: AppState
    @Binding var showTerminal: Bool
    @State private var searchText = ""

    var body: some View {
        HStack(spacing: 12) {
            // Undo/Redo buttons
            HStack(spacing: 2) {
                ToolbarIconButton(icon: "arrow.uturn.backward", tooltip: "Undo") {
                    // Undo action - will implement git reflog based undo
                }
                ToolbarIconButton(icon: "arrow.uturn.forward", tooltip: "Redo") {
                    // Redo action
                }
            }

            ToolbarDivider()

            // Fetch/Pull/Push buttons
            HStack(spacing: 4) {
                ToolbarButton(icon: "arrow.down", label: "Fetch") {
                    NotificationCenter.default.post(name: .fetch, object: nil)
                }
                ToolbarButton(icon: "arrow.down.circle.fill", label: "Pull") {
                    NotificationCenter.default.post(name: .pull, object: nil)
                }
                ToolbarButton(icon: "arrow.up.circle.fill", label: "Push") {
                    NotificationCenter.default.post(name: .push, object: nil)
                }
            }

            ToolbarDivider()

            // Branch button
            ToolbarButton(icon: "arrow.triangle.branch", label: "Branch") {
                NotificationCenter.default.post(name: .newBranch, object: nil)
            }

            ToolbarDivider()

            // Stash/Pop buttons
            HStack(spacing: 4) {
                ToolbarButton(icon: "archivebox", label: "Stash") {
                    NotificationCenter.default.post(name: .stash, object: nil)
                }
                ToolbarButton(icon: "archivebox.fill", label: "Pop") {
                    NotificationCenter.default.post(name: .popStash, object: nil)
                }
            }

            ToolbarDivider()

            // Terminal button
            ToolbarIconButton(
                icon: showTerminal ? "terminal.fill" : "terminal",
                tooltip: showTerminal ? "Hide Terminal" : "Show Terminal",
                isActive: showTerminal
            ) {
                showTerminal.toggle()
            }

            Spacer()

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(GitKrakenTheme.textMuted)
                TextField("Search commits...", text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundColor(GitKrakenTheme.textPrimary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(GitKrakenTheme.backgroundTertiary)
            .cornerRadius(6)
            .frame(width: 200)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(GitKrakenTheme.toolbar)
    }
}

// MARK: - Toolbar Divider
struct ToolbarDivider: View {
    var body: some View {
        Rectangle()
            .fill(GitKrakenTheme.border)
            .frame(width: 1, height: 28)
            .padding(.horizontal, 4)
    }
}

// MARK: - Toolbar Icon Button (compact)
struct ToolbarIconButton: View {
    let icon: String
    let tooltip: String
    var isActive: Bool = false
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(isActive ? GitKrakenTheme.accent : (isHovered ? GitKrakenTheme.textPrimary : GitKrakenTheme.textSecondary))
                .frame(width: 28, height: 28)
                .background(isActive ? GitKrakenTheme.accent.opacity(0.15) : (isHovered ? GitKrakenTheme.hover : Color.clear))
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(tooltip)
    }
}

// MARK: - Toolbar Button
struct ToolbarButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(label)
                    .font(.system(size: 10))
            }
            .foregroundColor(isHovered ? GitKrakenTheme.textPrimary : GitKrakenTheme.textSecondary)
            .frame(width: 50, height: 40)
            .background(isHovered ? GitKrakenTheme.hover : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Right Staging Panel
struct RightStagingPanel: View {
    @EnvironmentObject var appState: AppState
    @Binding var selectedFileDiff: FileDiff?
    @State private var commitMessage = ""
    @StateObject private var stagingVM = StagingViewModel()
    @StateObject private var commitDetailVM = CommitDetailViewModel()

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
            } else {
                // Show staging area when no commit is selected (WIP mode)
                StagingAreaPanel(
                    stagingVM: stagingVM,
                    selectedFileDiff: $selectedFileDiff,
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
        .onChange(of: appState.selectedCommit) { _, newCommit in
            if let commit = newCommit, let path = appState.currentRepository?.path {
                Task { await commitDetailVM.loadCommitFiles(sha: commit.sha, at: path) }
            }
        }
    }
}

// MARK: - Staging Area Panel (when no commit selected)
struct StagingAreaPanel: View {
    @ObservedObject var stagingVM: StagingViewModel
    @Binding var selectedFileDiff: FileDiff?
    @Binding var commitMessage: String
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Unstaged Files
            StagingSection(
                title: "Unstaged Files",
                count: stagingVM.unstagedFiles.count,
                actionIcon: "plus.circle",
                actionColor: GitKrakenTheme.accentGreen,
                onAction: { stagingVM.stageAll() }
            ) {
                ForEach(stagingVM.unstagedFiles) { file in
                    ClickableFileRow(
                        file: file,
                        isStaged: false,
                        onSelect: { loadDiff(for: file) },
                        onStage: { stagingVM.stage(file: file) }
                    )
                }
                if stagingVM.unstagedFiles.isEmpty {
                    Text("No unstaged changes")
                        .font(.system(size: 11))
                        .foregroundColor(GitKrakenTheme.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
            }

            Rectangle().fill(GitKrakenTheme.border).frame(height: 1)

            // Staged Files
            StagingSection(
                title: "Staged Files",
                count: stagingVM.stagedFiles.count,
                actionIcon: "minus.circle",
                actionColor: GitKrakenTheme.accentRed,
                onAction: { stagingVM.unstageAll() }
            ) {
                ForEach(stagingVM.stagedFiles) { file in
                    ClickableFileRow(
                        file: file,
                        isStaged: true,
                        onSelect: { loadDiff(for: file) },
                        onStage: { stagingVM.unstage(file: file) }
                    )
                }
                if stagingVM.stagedFiles.isEmpty {
                    Text("No staged changes")
                        .font(.system(size: 11))
                        .foregroundColor(GitKrakenTheme.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
            }

            Spacer()

            // Commit Section
            CommitSection(
                commitMessage: $commitMessage,
                canCommit: !stagingVM.stagedFiles.isEmpty,
                onCommit: { stagingVM.commit(message: commitMessage) { commitMessage = "" } }
            )
        }
    }

    private func loadDiff(for file: StagingFile) {
        guard let path = appState.currentRepository?.path else { return }
        Task {
            if let diff = await stagingVM.getDiff(for: file, at: path) {
                selectedFileDiff = diff
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
                        .foregroundColor(GitKrakenTheme.textMuted)
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(GitKrakenTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                }

                // Commit message
                Text(commit.message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(GitKrakenTheme.textPrimary)
                    .lineLimit(3)

                // Author and date
                HStack(spacing: 8) {
                    AuthorAvatar(name: commit.author, size: 20)
                    Text(commit.author)
                        .font(.system(size: 12))
                        .foregroundColor(GitKrakenTheme.textSecondary)
                    Spacer()
                    Text(commit.relativeDate)
                        .font(.system(size: 11))
                        .foregroundColor(GitKrakenTheme.textMuted)
                }

                // SHA
                HStack {
                    Text(String(commit.sha.prefix(8)))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(GitKrakenTheme.accent)
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(commit.sha, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                            .foregroundColor(GitKrakenTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
            }
            .padding(12)
            .background(GitKrakenTheme.backgroundSecondary)

            Rectangle().fill(GitKrakenTheme.border).frame(height: 1)

            // Changed files
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Changed Files")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(GitKrakenTheme.textMuted)
                    Spacer()
                    Text("\(viewModel.changedFiles.count)")
                        .font(.system(size: 11))
                        .foregroundColor(GitKrakenTheme.textMuted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(GitKrakenTheme.backgroundTertiary)
                        .cornerRadius(4)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(GitKrakenTheme.backgroundSecondary)

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
                                    onSelect: { loadCommitFileDiff(file) }
                                )
                            }
                            if viewModel.changedFiles.isEmpty {
                                Text("No files changed")
                                    .font(.system(size: 11))
                                    .foregroundColor(GitKrakenTheme.textMuted)
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
        do {
            let diffString = try await engine.getCommitFileDiff(sha: commit.sha, filePath: file.path, at: path)
            let diffs = DiffParser.parse(diffString)
            return diffs.first
        } catch {
            print("Error getting diff: \(error)")
            return nil
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
        case added, modified, deleted, renamed

        var color: Color {
            switch self {
            case .added: return GitKrakenTheme.accentGreen
            case .modified: return GitKrakenTheme.accentOrange
            case .deleted: return GitKrakenTheme.accentRed
            case .renamed: return GitKrakenTheme.accent
            }
        }

        var icon: String {
            switch self {
            case .added: return "plus"
            case .modified: return "pencil"
            case .deleted: return "minus"
            case .renamed: return "arrow.right"
            }
        }
    }
}

// MARK: - Commit File Row
struct CommitFileRow: View {
    let file: CommitFile
    let onSelect: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            // Status icon
            Image(systemName: file.status.icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(file.status.color)
                .frame(width: 16)

            // File icon
            Image(systemName: FileTypeIcon.systemIcon(for: file.path))
                .font(.system(size: 12))
                .foregroundColor(FileTypeIcon.color(for: file.path))

            // Filename
            Text((file.path as NSString).lastPathComponent)
                .font(.system(size: 12))
                .foregroundColor(GitKrakenTheme.textPrimary)
                .lineLimit(1)

            Spacer()

            // Additions/Deletions
            if file.additions > 0 {
                Text("+\(file.additions)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(GitKrakenTheme.accentGreen)
            }
            if file.deletions > 0 {
                Text("-\(file.deletions)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(GitKrakenTheme.accentRed)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isHovered ? GitKrakenTheme.hover : Color.clear)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture { onSelect() }
    }
}

// MARK: - Author Avatar
struct AuthorAvatar: View {
    let name: String
    let size: CGFloat

    var color: Color {
        let colors = GitKrakenTheme.laneColors
        let hash = abs(name.hashValue)
        return colors[hash % colors.count]
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
            Text(String(name.prefix(1)).uppercased())
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundColor(.white)
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
        do {
            let diffString = try await engine.getDiff(for: file.path, staged: file.isStaged, at: path)
            let diffs = DiffParser.parse(diffString)
            return diffs.first
        } catch {
            print("Error getting diff: \(error)")
            return nil
        }
    }
}

// MARK: - Staging File Model
struct StagingFile: Identifiable {
    let id = UUID()
    let path: String
    let status: StagingFileStatus
    var isStaged: Bool = false

    enum StagingFileStatus {
        case added, modified, deleted, renamed, untracked

        var color: Color {
            switch self {
            case .added: return GitKrakenTheme.accentGreen
            case .modified: return GitKrakenTheme.accentOrange
            case .deleted: return GitKrakenTheme.accentRed
            case .renamed: return GitKrakenTheme.accent
            case .untracked: return GitKrakenTheme.textMuted
            }
        }

        var icon: String {
            switch self {
            case .added: return "plus"
            case .modified: return "pencil"
            case .deleted: return "minus"
            case .renamed: return "arrow.right"
            case .untracked: return "questionmark"
            }
        }
    }

    init(path: String, status: StagingFileStatus, isStaged: Bool = false) {
        self.path = path
        self.status = status
        self.isStaged = isStaged
    }

    init(from fileStatus: FileStatus, staged: Bool = false) {
        self.path = fileStatus.path
        self.isStaged = staged
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
                    .foregroundColor(GitKrakenTheme.textMuted)
                Spacer()
                Text("\(count)")
                    .font(.system(size: 11))
                    .foregroundColor(GitKrakenTheme.textMuted)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(GitKrakenTheme.backgroundTertiary)
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
            .background(GitKrakenTheme.backgroundSecondary)

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
    let onSelect: () -> Void
    let onStage: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            // Status icon
            Image(systemName: file.status.icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(file.status.color)
                .frame(width: 16)

            // File icon
            Image(systemName: FileTypeIcon.systemIcon(for: file.path))
                .font(.system(size: 12))
                .foregroundColor(FileTypeIcon.color(for: file.path))

            // Filename
            Text((file.path as NSString).lastPathComponent)
                .font(.system(size: 12))
                .foregroundColor(GitKrakenTheme.textPrimary)
                .lineLimit(1)

            Spacer()

            // Stage/Unstage button (on hover)
            if isHovered {
                Button(action: onStage) {
                    Image(systemName: isStaged ? "minus.circle.fill" : "plus.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(isStaged ? GitKrakenTheme.accentRed : GitKrakenTheme.accentGreen)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isHovered ? GitKrakenTheme.hover : Color.clear)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture { onSelect() }
    }
}

// MARK: - Commit Section
struct CommitSection: View {
    @Binding var commitMessage: String
    let canCommit: Bool
    let onCommit: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topLeading) {
                if commitMessage.isEmpty {
                    Text("Commit message...")
                        .foregroundColor(GitKrakenTheme.textMuted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 10)
                }
                TextEditor(text: $commitMessage)
                    .font(.system(size: 12))
                    .foregroundColor(GitKrakenTheme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(minHeight: 60, maxHeight: 100)
            }
            .padding(4)
            .background(GitKrakenTheme.backgroundTertiary)
            .cornerRadius(6)

            Button(action: onCommit) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Commit")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(canCommit && !commitMessage.isEmpty ? GitKrakenTheme.accentGreen : GitKrakenTheme.backgroundTertiary)
                .foregroundColor(canCommit && !commitMessage.isEmpty ? .white : GitKrakenTheme.textMuted)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(!canCommit || commitMessage.isEmpty)
        }
        .padding(12)
        .background(GitKrakenTheme.backgroundSecondary)
    }
}

// MARK: - Tab Button
struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? GitKrakenTheme.textPrimary : GitKrakenTheme.textMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? GitKrakenTheme.panel : Color.clear)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Staging View (GitKraken style)
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
                        .foregroundColor(GitKrakenTheme.textMuted)
                    Spacer()
                    Text("\(unstagedFiles.count)")
                        .font(.system(size: 11))
                        .foregroundColor(GitKrakenTheme.textMuted)
                    Button {
                        // Stage all
                    } label: {
                        Image(systemName: "plus.circle")
                            .foregroundColor(GitKrakenTheme.accentGreen)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(GitKrakenTheme.backgroundSecondary)

                FileListView(files: unstagedFiles, isStaged: false)
                    .frame(minHeight: 100)
            }

            Divider()
                .background(GitKrakenTheme.border)

            // Staged Files
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Staged Files")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(GitKrakenTheme.textMuted)
                    Spacer()
                    Text("\(stagedFiles.count)")
                        .font(.system(size: 11))
                        .foregroundColor(GitKrakenTheme.textMuted)
                    Button {
                        // Unstage all
                    } label: {
                        Image(systemName: "minus.circle")
                            .foregroundColor(GitKrakenTheme.accentRed)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(GitKrakenTheme.backgroundSecondary)

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
                            .foregroundColor(GitKrakenTheme.textMuted)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 10)
                    }
                    TextEditor(text: $commitMessage)
                        .font(.system(size: 12))
                        .foregroundColor(GitKrakenTheme.textPrimary)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .frame(minHeight: 60, maxHeight: 100)
                }
                .padding(4)
                .background(GitKrakenTheme.backgroundTertiary)
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
                    .background(stagedFiles.isEmpty ? GitKrakenTheme.backgroundTertiary : GitKrakenTheme.accentGreen)
                    .foregroundColor(stagedFiles.isEmpty ? GitKrakenTheme.textMuted : .white)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(stagedFiles.isEmpty || commitMessage.isEmpty)
            }
            .padding(12)
            .background(GitKrakenTheme.backgroundSecondary)
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
                        .foregroundColor(GitKrakenTheme.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                }
            }
        }
        .background(GitKrakenTheme.panel)
    }
}

// MARK: - Staging File Row
struct StagingFileRow: View {
    let file: FileChange
    let isStaged: Bool
    @State private var isHovered = false

    var statusColor: Color {
        switch file.status {
        case .added: return GitKrakenTheme.accentGreen
        case .modified: return GitKrakenTheme.accentOrange
        case .deleted: return GitKrakenTheme.accentRed
        case .renamed: return GitKrakenTheme.accent
        case .untracked: return GitKrakenTheme.textMuted
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

            Image(systemName: FileTypeIcon.systemIcon(for: file.path))
                .font(.system(size: 12))
                .foregroundColor(FileTypeIcon.color(for: file.path))

            Text((file.path as NSString).lastPathComponent)
                .font(.system(size: 12))
                .foregroundColor(GitKrakenTheme.textPrimary)
                .lineLimit(1)

            Spacer()

            if isHovered {
                Button {
                    // Stage/Unstage file
                } label: {
                    Image(systemName: isStaged ? "minus.circle" : "plus.circle")
                        .foregroundColor(isStaged ? GitKrakenTheme.accentRed : GitKrakenTheme.accentGreen)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isHovered ? GitKrakenTheme.hover : Color.clear)
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
                            .foregroundColor(GitKrakenTheme.textPrimary)

                        HStack {
                            Text(commit.author)
                                .foregroundColor(GitKrakenTheme.textSecondary)
                            Text("•")
                                .foregroundColor(GitKrakenTheme.textMuted)
                            Text(commit.date, style: .relative)
                                .foregroundColor(GitKrakenTheme.textMuted)
                        }
                        .font(.system(size: 12))

                        Text(commit.sha)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(GitKrakenTheme.textMuted)

                        Divider()
                            .background(GitKrakenTheme.border)

                        Text("Changes will appear here...")
                            .foregroundColor(GitKrakenTheme.textMuted)
                    }
                    .padding()
                }
            } else {
                VStack {
                    Spacer()
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(GitKrakenTheme.textMuted)
                    Text("Select a commit to view diff")
                        .foregroundColor(GitKrakenTheme.textMuted)
                    Spacer()
                }
            }
        }
        .background(GitKrakenTheme.panel)
    }
}

// MARK: - Welcome View (GitKraken style)
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

                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [GitKrakenTheme.accent, GitKrakenTheme.accentCyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("GitMac")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(GitKrakenTheme.textPrimary)

                Text("A Git client for Mac")
                    .font(.system(size: 16))
                    .foregroundColor(GitKrakenTheme.textSecondary)

                HStack(spacing: 16) {
                    WelcomeButton(icon: "folder", title: "Open", color: GitKrakenTheme.accent, action: onOpen)
                    WelcomeButton(icon: "arrow.down.circle", title: "Clone", color: GitKrakenTheme.accentGreen, action: onClone)
                    WelcomeButton(icon: "plus.circle", title: "Init", color: GitKrakenTheme.accentPurple) {
                        NotificationCenter.default.post(name: .initRepository, object: nil)
                    }
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(GitKrakenTheme.background)

            // Right side - Recent repos
            VStack(alignment: .leading, spacing: 0) {
                Text("RECENT REPOSITORIES")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(GitKrakenTheme.textMuted)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                ScrollView {
                    VStack(spacing: 0) {
                        if recentReposManager.recentRepos.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "clock")
                                    .font(.system(size: 32))
                                    .foregroundColor(GitKrakenTheme.textMuted)
                                Text("No recent repositories")
                                    .foregroundColor(GitKrakenTheme.textMuted)
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
            .background(GitKrakenTheme.sidebar)
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
                    .foregroundColor(GitKrakenTheme.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(repo.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(GitKrakenTheme.textPrimary)
                    Text(repo.path)
                        .font(.system(size: 11))
                        .foregroundColor(GitKrakenTheme.textMuted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(isHovered ? GitKrakenTheme.hover : Color.clear)
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
                .foregroundColor(GitKrakenTheme.textPrimary)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Repository URL")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(GitKrakenTheme.textMuted)
                    TextField("https://github.com/user/repo.git", text: $repoURL)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(GitKrakenTheme.backgroundTertiary)
                        .cornerRadius(6)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Destination")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(GitKrakenTheme.textMuted)
                    HStack {
                        TextField("Select destination folder", text: $destinationPath)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(GitKrakenTheme.backgroundTertiary)
                            .cornerRadius(6)

                        Button("Browse") {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = false
                            panel.canChooseDirectories = true
                            if panel.runModal() == .OK {
                                destinationPath = panel.url?.path ?? ""
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
        .background(GitKrakenTheme.panel)
    }
}

// MARK: - Repository Tab Bar (GitKraken style)
struct RepositoryTabBar: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var recentReposManager: RecentRepositoriesManager

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

            Spacer()

            // Add new tab button
            Button {
                openNewRepository()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(GitKrakenTheme.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(GitKrakenTheme.hover)
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
        }
        .frame(height: 36)
        .background(GitKrakenTheme.toolbar)
        .overlay(
            Rectangle()
                .fill(GitKrakenTheme.border)
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

        if panel.runModal() == .OK, let url = panel.url {
            Task {
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
    @State private var isHovered = false

    var isActive: Bool {
        appState.activeTabId == tab.id
    }

    var body: some View {
        HStack(spacing: 8) {
            // Branch indicator dot
            Circle()
                .fill(GitKrakenTheme.accentGreen)
                .frame(width: 8, height: 8)

            // Repo name
            Text(tab.repository.name)
                .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                .foregroundColor(isActive ? GitKrakenTheme.textPrimary : GitKrakenTheme.textSecondary)
                .lineLimit(1)

            // Close button (show on hover or if active)
            if isHovered || isActive {
                Button {
                    appState.closeTab(tab.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(GitKrakenTheme.textMuted)
                        .frame(width: 16, height: 16)
                        .background(isHovered ? GitKrakenTheme.backgroundTertiary : Color.clear)
                        .cornerRadius(3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isActive ? GitKrakenTheme.background : (isHovered ? GitKrakenTheme.backgroundSecondary : GitKrakenTheme.toolbar))
        .overlay(
            Rectangle()
                .fill(isActive ? GitKrakenTheme.accent : Color.clear)
                .frame(height: 2),
            alignment: .bottom
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
