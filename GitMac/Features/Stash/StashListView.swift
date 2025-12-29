import SwiftUI

/// Stash list and management view
struct StashListView: View {
    @StateObject private var themeManager = ThemeManager.shared

    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = StashListViewModel()
    @State private var selectedStash: Stash?
    @State private var showStashSheet = false
    @State private var showDeleteAlert = false
    @State private var stashToDelete: Stash?

    var body: some View {
        HSplitView {
            // Left: Stash list
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Stashes")
                        .font(.headline)

                    Text("(\(viewModel.stashes.count))")
                        .foregroundColor(AppTheme.textPrimary)

                    Spacer()

                    DSButton(variant: .primary, size: .sm, isDisabled: !viewModel.hasChanges) {
                        showStashSheet = true
                    } label: {
                        Label("Stash", systemImage: "plus")
                    }
                    .help("Stash current changes")
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))

                if let error = viewModel.error {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(AppTheme.error)
                        Text(error)
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(AppTheme.error)
                        Spacer()
                        DSIconButton(iconName: "xmark.circle.fill", variant: .ghost, size: .sm) {
                            viewModel.error = nil
                        }
                    }
                    .padding(DesignTokens.Spacing.sm)
                    .background(AppTheme.error.opacity(0.1))
                    .cornerRadius(DesignTokens.CornerRadius.sm)
                    .padding(.horizontal)
                    .padding(.bottom, DesignTokens.Spacing.sm)
                }

                Divider()

                // List
                if viewModel.stashes.isEmpty {
                    EmptyStashView()
                } else {
                    List(viewModel.stashes, selection: $selectedStash) { stash in
                        StashRow(
                            stash: stash,
                            isSelected: selectedStash?.id == stash.id,
                            files: viewModel.getFiles(for: stash),
                            stats: viewModel.getStats(for: stash),
                            onApply: { Task { await viewModel.applyStash(stash) } },
                            onPop: { Task { await viewModel.popStash(stash) } },
                            onDrop: {
                                stashToDelete = stash
                                showDeleteAlert = true
                            }
                        )
                        .tag(stash)
                    }
                    .listStyle(.plain)
                }
            }
            .frame(minWidth: 280)

            // Right: Stash detail
            if let stash = selectedStash {
                StashDetailView(stash: stash, viewModel: viewModel)
            } else {
                VStack {
                    Spacer()
                    Image(systemName: "archivebox")
                        .font(DesignTokens.Typography.iconXXXXL)
                        .foregroundColor(AppTheme.textPrimary)
                    Text("Select a stash to view details")
                        .foregroundColor(AppTheme.textPrimary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .sheet(isPresented: $showStashSheet) {
            CreateStashSheet(viewModel: viewModel)
        }
        .alert("Drop Stash", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Drop", role: .destructive) {
                if let stash = stashToDelete {
                    Task { await viewModel.dropStash(stash) }
                }
            }
        } message: {
            Text("Are you sure you want to drop '\(stashToDelete?.displayMessage ?? "")'? This cannot be undone.")
        }
        .task {
            viewModel.configure(gitService: appState.gitService)
            if let repo = appState.currentRepository {
                viewModel.loadStashes(from: repo)
            }
        }
    }
}

// MARK: - View Model

@MainActor
class StashListViewModel: ObservableObject {
    @Published var stashes: [Stash] = []
    @Published var hasChanges = false
    @Published var isLoading = false
    @Published var error: String?
    @Published var stashFiles: [String: [StashFile]] = [:] // Cache of files per stash ref
    @Published var stashStats: [String: (additions: Int, deletions: Int)] = [:] // Cache of stats per stash ref

    private var gitService: GitService?
    private let gitEngine = GitEngine()
    private var currentPath: String?

    func configure(gitService: GitService) {
        self.gitService = gitService
    }

    func loadStashes(from repo: Repository) {
        stashes = repo.stashes
        hasChanges = repo.status.hasChanges
        currentPath = repo.path

        // Load file details for each stash
        Task {
            for stash in stashes {
                await loadStashFiles(for: stash)
            }
        }
    }

    func loadStashFiles(for stash: Stash) async {
        guard let path = currentPath else { return }

        do {
            let files = try await gitEngine.getStashFiles(stashRef: stash.reference, at: path)
            let stats = try await gitEngine.getStashStats(stashRef: stash.reference, at: path)
            await MainActor.run {
                stashFiles[stash.reference] = files
                stashStats[stash.reference] = stats
            }
        } catch {
            // Silently fail - file details are optional
        }
    }

    func createStash(message: String?, includeUntracked: Bool) async {
        guard let gitService = gitService else {
            self.error = "Git service not configured"
            return
        }
        isLoading = true
        do {
            _ = try await gitService.stash(message: message, includeUntracked: includeUntracked)
        } catch {
            self.self.error = error.localizedDescription
        }
        isLoading = false
    }

    func applyStash(_ stash: Stash) async {
        isLoading = true
        
        if let gitService = gitService {
            do {
                try await gitService.stashApply(index: stash.index)
                // Notify that repository changed so staging area updates
                NotificationCenter.default.post(name: .repositoryDidRefresh, object: gitService.currentRepository?.path)
            } catch {
                self.self.error = error.localizedDescription
            }
        } else if let path = currentPath {
            // Fallback: use GitEngine directly if gitService not configured
            do {
                var options = StashApplyOptions()
                options.stashRef = stash.reference
                try await gitEngine.stashApply(options: options, at: path)
                NotificationCenter.default.post(name: .repositoryDidRefresh, object: path)
            } catch {
                self.self.error = error.localizedDescription
            }
        } else {
            self.error = "Could not apply stash: no repository configured"
        }
        
        isLoading = false
    }

    func popStash(_ stash: Stash) async {
        isLoading = true
        
        if let gitService = gitService {
            do {
                try await gitService.stashPop(index: stash.index)
                NotificationCenter.default.post(name: .repositoryDidRefresh, object: gitService.currentRepository?.path)
            } catch {
                self.self.error = error.localizedDescription
            }
        } else if let path = currentPath {
            do {
                try await gitEngine.stashPop(stashRef: stash.reference, at: path)
                NotificationCenter.default.post(name: .repositoryDidRefresh, object: path)
            } catch {
                self.self.error = error.localizedDescription
            }
        } else {
            self.error = "Could not pop stash: no repository configured"
        }
        
        isLoading = false
    }

    func dropStash(_ stash: Stash) async {
        isLoading = true
        
        if let gitService = gitService {
            do {
                try await gitService.stashDrop(index: stash.index)
            } catch {
                self.self.error = error.localizedDescription
            }
        } else if let path = currentPath {
            do {
                try await gitEngine.stashDrop(stashRef: stash.reference, at: path)
            } catch {
                self.self.error = error.localizedDescription
            }
        } else {
            self.error = "Could not drop stash: no repository configured"
        }
        
        isLoading = false
    }

    func getStashDiff(_ stash: Stash) async -> String {
        // Get stash diff using git stash show -p
        let shell = ShellExecutor()
        let result = await shell.execute(
            "git",
            arguments: ["stash", "show", "-p", stash.reference]
        )
        return result.stdout
    }

    /// Apply a single file from a stash without applying the entire stash
    func applyStashFile(_ stash: Stash, file: StashFile) async {
        guard let path = currentPath else {
            self.error = "No repository configured"
            return
        }
        
        isLoading = true
        
        do {
            // Use git checkout to restore a single file from stash
            // git checkout stash@{N} -- path/to/file
            let shell = ShellExecutor()
            let result = await shell.execute(
                "git",
                arguments: ["checkout", stash.reference, "--", file.path],
                workingDirectory: path
            )
            
            guard result.exitCode == 0 else {
                throw GitError.checkoutFailed(file.path, result.stderr.isEmpty ? "Failed to restore file from stash" : result.stderr)
            }
            
            NotificationCenter.default.post(name: .repositoryDidRefresh, object: path)
        } catch {
            self.self.error = error.localizedDescription
        }
        
        isLoading = false
    }

    func getFiles(for stash: Stash) -> [StashFile] {
        stashFiles[stash.reference] ?? []
    }

    func getStats(for stash: Stash) -> (additions: Int, deletions: Int) {
        stashStats[stash.reference] ?? (0, 0)
    }
}

// MARK: - Subviews

struct StashRow: View {
    @StateObject private var themeManager = ThemeManager.shared
    let stash: Stash
    let isSelected: Bool
    let files: [StashFile]
    let stats: (additions: Int, deletions: Int)
    var onApply: () -> Void = {}
    var onPop: () -> Void = {}
    var onDrop: () -> Void = {}

    @State private var isHovered = false
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            HStack(spacing: DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs) {
                // Expand/collapse chevron
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(DesignTokens.Typography.caption2)
                        .foregroundColor(AppTheme.textPrimary)
                        .frame(width: 12)
                }
                .buttonStyle(.plain)

                Image(systemName: "archivebox.fill")
                    .foregroundColor(AppTheme.warning)

                Text(stash.reference)
                    .font(DesignTokens.Typography.caption.monospacedDigit())
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()

                // File count badge
                if !files.isEmpty {
                    HStack(spacing: DesignTokens.Spacing.xxs) {
                        Image(systemName: "doc")
                            .font(DesignTokens.Typography.caption2)
                        Text("\(files.count)")
                            .font(DesignTokens.Typography.caption2)
                    }
                    .foregroundColor(AppTheme.textPrimary)
                    .padding(.horizontal, DesignTokens.Spacing.xs)
                    .padding(.vertical, DesignTokens.Spacing.xxs)
                    .background(AppTheme.textSecondary.opacity(0.15))
                    .cornerRadius(DesignTokens.CornerRadius.sm)
                }

                // Stats badges
                if stats.additions > 0 {
                    HStack(spacing: DesignTokens.Spacing.xxs / 2) {
                        Text("+\(stats.additions)")
                    }
                    .font(DesignTokens.Typography.caption2.weight(.medium).monospacedDigit())
                    .foregroundColor(AppTheme.success)
                }

                if stats.deletions > 0 {
                    HStack(spacing: DesignTokens.Spacing.xxs / 2) {
                        Text("-\(stats.deletions)")
                    }
                    .font(DesignTokens.Typography.caption2.weight(.medium).monospacedDigit())
                    .foregroundColor(AppTheme.error)
                }

                if isHovered {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        DSIconButton(iconName: "arrow.uturn.backward", variant: .ghost, size: .sm) {
                            onApply()
                        }
                        .help("Apply")

                        DSIconButton(iconName: "arrow.uturn.backward.circle", variant: .ghost, size: .sm) {
                            onPop()
                        }
                        .help("Pop")

                        DSIconButton(iconName: "trash", variant: .ghost, size: .sm) {
                            onDrop()
                        }
                        .help("Drop")
                    }
                }
            }

            // Message and metadata
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(stash.displayMessage)
                    .lineLimit(2)
                    .padding(.leading, 18)

                HStack {
                    if let branch = stash.branchName {
                        Text("on \(branch)")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(AppTheme.textPrimary)
                    }

                    Spacer()

                    Text(stash.relativeDate)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(AppTheme.textPrimary)
                }
                .padding(.leading, 18)
            }
            .padding(.top, DesignTokens.Spacing.xs)

            // Expanded file list as tree
            if isExpanded && !files.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    StashFileTreeView(files: files)
                }
                .padding(.leading, 16)
                .padding(.top, DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
            }
        }
        .padding(.vertical, DesignTokens.Spacing.sm)
        .padding(.horizontal, DesignTokens.Spacing.xs)
        .background(isSelected ? AppTheme.accent.opacity(0.1) : (isHovered ? AppTheme.textSecondary.opacity(0.05) : Color.clear))
        .cornerRadius(DesignTokens.CornerRadius.sm)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Apply") { onApply() }
            Button("Pop") { onPop() }
            Divider()
            Button("Create Branch from Stash...") { }
            Divider()
            Button("Drop", role: .destructive) { onDrop() }
        }
    }
}

struct StashFileRow: View {
    @StateObject private var themeManager = ThemeManager.shared
    let file: StashFile

    var directory: String {
        let url = URL(fileURLWithPath: file.path)
        let dir = url.deletingLastPathComponent().path
        return dir == "." || dir.isEmpty ? "" : dir
    }

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // Status indicator
            Text(file.statusLetter)
                .font(DesignTokens.Typography.caption2.weight(.bold).monospacedDigit())
                .foregroundColor(file.statusColor)
                .frame(width: 16, height: 16)
                .background(file.statusColor.opacity(0.2))
                .cornerRadius(DesignTokens.CornerRadius.sm)

            // File icon
            Image(systemName: "doc.fill")
                .foregroundColor(AppTheme.textPrimary)
                .frame(width: 16)

            // File path
            VStack(alignment: .leading, spacing: 0) {
                Text(file.filename)
                    .lineLimit(1)

                if !directory.isEmpty {
                    Text(directory)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
    }
}

// MARK: - Stash File Tree

struct StashFileTreeView: View {
    @StateObject private var themeManager = ThemeManager.shared
    let files: [StashFile]

    var body: some View {
        let tree = buildTree()
        ForEach(tree.children.sorted(by: { $0.name < $1.name })) { node in
            StashTreeNodeView(node: node)
        }
    }

    private func buildTree() -> StashTreeNode {
        let root = StashTreeNode(name: "", path: "", isFolder: true)

        for file in files {
            addToTree(root: root, file: file)
        }

        return root
    }

    private func addToTree(root: StashTreeNode, file: StashFile) {
        let components = file.path.split(separator: "/").map(String.init)
        var current = root

        for (index, component) in components.enumerated() {
            let isLast = index == components.count - 1
            let currentPath = components[0...index].joined(separator: "/")

            if isLast {
                let fileNode = StashTreeNode(
                    name: component,
                    path: currentPath,
                    isFolder: false,
                    file: file
                )
                current.children.append(fileNode)
            } else {
                if let existing = current.children.first(where: { $0.name == component && $0.isFolder }) {
                    current = existing
                } else {
                    let folderNode = StashTreeNode(name: component, path: currentPath, isFolder: true)
                    current.children.append(folderNode)
                    current = folderNode
                }
            }
        }
    }
}

class StashTreeNode: Identifiable, ObservableObject {
    var id: String { path.isEmpty ? UUID().uuidString : path }
    let name: String
    let path: String
    let isFolder: Bool
    var file: StashFile?
    var children: [StashTreeNode] = []

    init(name: String, path: String, isFolder: Bool, file: StashFile? = nil) {
        self.name = name
        self.path = path
        self.isFolder = isFolder
        self.file = file
    }

    var fileCount: Int {
        if isFolder {
            return children.reduce(0) { $0 + $1.fileCount }
        }
        return 1
    }
}

struct StashTreeNodeView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @ObservedObject var node: StashTreeNode
    @State private var isExpanded = true

    var body: some View {
        if node.isFolder {
            folderView
        } else if let file = node.file {
            fileView(file: file)
        }
    }

    private var folderView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs) {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(DesignTokens.Typography.caption2)
                        .foregroundColor(AppTheme.textPrimary)
                        .frame(width: 12)
                }
                .buttonStyle(.plain)

                Image(systemName: isExpanded ? "folder.fill" : "folder")
                    .foregroundColor(AppTheme.warning)
                    .frame(width: 16)

                Text(node.name)
                    .lineLimit(1)

                Text("(\(node.fileCount))")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .contentShape(Rectangle())
            .contextMenu {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(node.path, forType: .string)
                } label: {
                    Label("Copy Path", systemImage: "doc.on.doc")
                }

                Button {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: node.path)
                } label: {
                    Label("Reveal in Finder", systemImage: "folder")
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(node.children.sorted(by: sortNodes)) { child in
                        StashTreeNodeView(node: child)
                            .padding(.leading, 16)
                    }
                }
            }
        }
    }

    private func fileView(file: StashFile) -> some View {
        HStack(spacing: DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs) {
            Color.clear.frame(width: 12)

            Text(file.statusLetter)
                .font(DesignTokens.Typography.caption2.weight(.bold).monospacedDigit())
                .foregroundColor(file.statusColor)
                .frame(width: 16, height: 16)
                .background(file.statusColor.opacity(0.2))
                .cornerRadius(DesignTokens.CornerRadius.sm)

            Image(systemName: "doc.fill")
                .foregroundColor(AppTheme.textPrimary)
                .frame(width: 16)

            Text(file.filename)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(file.path, forType: .string)
            } label: {
                Label("Copy Path", systemImage: "doc.on.doc")
            }

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(file.filename, forType: .string)
            } label: {
                Label("Copy Filename", systemImage: "doc.text")
            }

            Divider()

            Button {
                NSWorkspace.shared.selectFile(file.path, inFileViewerRootedAtPath: "")
            } label: {
                Label("Reveal in Finder", systemImage: "folder")
            }
        }
    }

    private func sortNodes(_ a: StashTreeNode, _ b: StashTreeNode) -> Bool {
        if a.isFolder && !b.isFolder { return true }
        if !a.isFolder && b.isFolder { return false }
        return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
    }
}

struct StashDetailView: View {
    @StateObject private var themeManager = ThemeManager.shared
    let stash: Stash
    @ObservedObject var viewModel: StashListViewModel
    @State private var diff = ""
    @State private var isLoading = true
    @State private var showDiff = true

    private var files: [StashFile] {
        viewModel.getFiles(for: stash)
    }

    private var stats: (additions: Int, deletions: Int) {
        viewModel.getStats(for: stash)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    HStack {
                        Text(stash.reference)
                            .font(.headline)

                        if !files.isEmpty {
                            HStack(spacing: DesignTokens.Spacing.xxs) {
                                Image(systemName: "doc")
                                    .font(DesignTokens.Typography.caption2)
                                Text("\(files.count)")
                                    .font(DesignTokens.Typography.caption)
                            }
                            .foregroundColor(AppTheme.textPrimary)
                            .padding(.horizontal, DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
                            .padding(.vertical, DesignTokens.Spacing.xxs)
                            .background(AppTheme.textSecondary.opacity(0.15))
                            .cornerRadius(DesignTokens.CornerRadius.sm)
                        }
                    }

                    Text(stash.message)
                        .foregroundColor(AppTheme.textPrimary)
                }

                Spacer()

                // Stats
                if stats.additions > 0 || stats.deletions > 0 {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        if stats.additions > 0 {
                            Text("+\(stats.additions)")
                                .font(DesignTokens.Typography.callout.weight(.medium).monospacedDigit())
                                .foregroundColor(AppTheme.success)
                        }
                        if stats.deletions > 0 {
                            Text("-\(stats.deletions)")
                                .font(DesignTokens.Typography.callout.weight(.medium).monospacedDigit())
                                .foregroundColor(AppTheme.error)
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                }

                HStack(spacing: DesignTokens.Spacing.sm) {
                    Button {
                        Task { await viewModel.applyStash(stash) }
                    } label: {
                        Label("Apply", systemImage: "arrow.uturn.backward")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        Task { await viewModel.popStash(stash) }
                    } label: {
                        Label("Pop", systemImage: "arrow.uturn.backward.circle")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // File list section (collapsible)
            if !files.isEmpty {
                VStack(spacing: 0) {
                    // Section header
                    HStack {
                        Button {
                            withAnimation { showDiff.toggle() }
                        } label: {
                            HStack {
                                Image(systemName: showDiff ? "chevron.down" : "chevron.right")
                                    .font(DesignTokens.Typography.caption)
                                    .foregroundColor(AppTheme.textPrimary)

                                Image(systemName: "doc.on.doc.fill")
                                    .foregroundColor(AppTheme.warning)

                                Text("Changed Files")
                                    .fontWeight(.medium)

                                Text("(\(files.count))")
                                    .foregroundColor(AppTheme.textPrimary)

                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .background(Color(nsColor: .controlBackgroundColor))

                    // File tree
                    if showDiff {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                StashFileTreeView(files: files)
                            }
                            .padding(.vertical, DesignTokens.Spacing.xs)
                        }
                        .frame(maxHeight: 200)
                        .background(Color(nsColor: .textBackgroundColor))
                    }

                    Divider()
                }
            }

            // Diff content
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView([.vertical, .horizontal]) {
                    Text(diff)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .task(id: stash.id) {
            isLoading = true
            diff = await viewModel.getStashDiff(stash)
            isLoading = false
        }
    }
}

struct EmptyStashView: View {
    @StateObject private var themeManager = ThemeManager.shared
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "archivebox")
                .font(DesignTokens.Typography.iconXXXXL)
                .foregroundColor(AppTheme.textPrimary)

            Text("No stashes")
                .font(.headline)

            Text("Stash your changes to save them temporarily")
                .foregroundColor(AppTheme.textPrimary)
                .multilineTextAlignment(.center)

            Text("Use ⌥⌘S to stash changes")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CreateStashSheet: View {
    @StateObject private var themeManager = ThemeManager.shared
    @ObservedObject var viewModel: StashListViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var message = ""
    @State private var includeUntracked = true
    @State private var keepIndex = false

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Text("Stash Changes")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                DSTextField(placeholder: "Message (optional)", text: $message)

                DSToggle("Include untracked files", isOn: $includeUntracked, style: .checkbox)
                DSToggle("Keep staged changes", isOn: $keepIndex, style: .checkbox)
            }
            .padding()

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Stash") {
                    Task {
                        await viewModel.createStash(
                            message: message.isEmpty ? nil : message,
                            includeUntracked: includeUntracked
                        )
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 400)
    }
}

// #Preview {
//     StashListView()
//         .environmentObject(AppState())
//         .frame(width: 700, height: 500)
// }
