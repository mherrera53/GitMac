import SwiftUI

/// Stash list and management view
struct StashListView: View {
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
                        .foregroundColor(.secondary)

                    Spacer()

                    Button {
                        showStashSheet = true
                    } label: {
                        Label("Stash", systemImage: "plus")
                    }
                    .buttonStyle(.borderless)
                    .disabled(!viewModel.hasChanges)
                    .help("Stash current changes")
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))

                if let error = viewModel.error {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                        Spacer()
                        Button {
                            viewModel.error = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(4)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
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
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Select a stash to view details")
                        .foregroundColor(.secondary)
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
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func applyStash(_ stash: Stash) async {
        guard let gitService = gitService else { return }
        isLoading = true
        do {
            try await gitService.stashApply(index: stash.index)
            // Notify that repository changed so staging area updates
            NotificationCenter.default.post(name: .repositoryDidRefresh, object: gitService.currentRepository?.path)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func popStash(_ stash: Stash) async {
        guard let gitService = gitService else { return }
        isLoading = true
        do {
            try await gitService.stashPop(index: stash.index)
            // Notify that repository changed so staging area updates
            NotificationCenter.default.post(name: .repositoryDidRefresh, object: gitService.currentRepository?.path)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func dropStash(_ stash: Stash) async {
        guard let gitService = gitService else { return }
        isLoading = true
        do {
            try await gitService.stashDrop(index: stash.index)
        } catch {
            self.error = error.localizedDescription
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

    func getFiles(for stash: Stash) -> [StashFile] {
        stashFiles[stash.reference] ?? []
    }

    func getStats(for stash: Stash) -> (additions: Int, deletions: Int) {
        stashStats[stash.reference] ?? (0, 0)
    }
}

// MARK: - Subviews

struct StashRow: View {
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
            HStack(spacing: 6) {
                // Expand/collapse chevron
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .frame(width: 12)
                }
                .buttonStyle(.plain)

                Image(systemName: "archivebox.fill")
                    .foregroundColor(.orange)

                Text(stash.reference)
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)

                Spacer()

                // File count badge
                if !files.isEmpty {
                    HStack(spacing: 2) {
                        Image(systemName: "doc")
                            .font(.system(size: 9))
                        Text("\(files.count)")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(4)
                }

                // Stats badges
                if stats.additions > 0 {
                    HStack(spacing: 1) {
                        Text("+\(stats.additions)")
                    }
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.green)
                }

                if stats.deletions > 0 {
                    HStack(spacing: 1) {
                        Text("-\(stats.deletions)")
                    }
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.red)
                }

                if isHovered {
                    HStack(spacing: 4) {
                        Button { onApply() } label: {
                            Image(systemName: "arrow.uturn.backward")
                        }
                        .buttonStyle(.borderless)
                        .help("Apply")

                        Button { onPop() } label: {
                            Image(systemName: "arrow.uturn.backward.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("Pop")

                        Button { onDrop() } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.borderless)
                        .help("Drop")
                    }
                }
            }

            // Message and metadata
            VStack(alignment: .leading, spacing: 2) {
                Text(stash.displayMessage)
                    .lineLimit(2)
                    .padding(.leading, 18)

                HStack {
                    if let branch = stash.branchName {
                        Text("on \(branch)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text(stash.relativeDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 18)
            }
            .padding(.top, 4)

            // Expanded file list as tree
            if isExpanded && !files.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    StashFileTreeView(files: files)
                }
                .padding(.leading, 16)
                .padding(.top, 6)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(isSelected ? Color.accentColor.opacity(0.1) : (isHovered ? Color.secondary.opacity(0.05) : Color.clear))
        .cornerRadius(4)
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
    let file: StashFile

    var directory: String {
        let url = URL(fileURLWithPath: file.path)
        let dir = url.deletingLastPathComponent().path
        return dir == "." || dir.isEmpty ? "" : dir
    }

    var body: some View {
        HStack(spacing: 8) {
            // Status indicator
            Text(file.statusLetter)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(file.statusColor)
                .frame(width: 16, height: 16)
                .background(file.statusColor.opacity(0.2))
                .cornerRadius(3)

            // File icon
            Image(systemName: "doc.fill")
                .foregroundColor(.secondary)
                .frame(width: 16)

            // File path
            VStack(alignment: .leading, spacing: 0) {
                Text(file.filename)
                    .lineLimit(1)

                if !directory.isEmpty {
                    Text(directory)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

// MARK: - Stash File Tree

struct StashFileTreeView: View {
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
            HStack(spacing: 6) {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .frame(width: 12)
                }
                .buttonStyle(.plain)

                Image(systemName: isExpanded ? "folder.fill" : "folder")
                    .foregroundColor(.yellow)
                    .frame(width: 16)

                Text(node.name)
                    .lineLimit(1)

                Text("(\(node.fileCount))")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
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
        HStack(spacing: 6) {
            Color.clear.frame(width: 12)

            Text(file.statusLetter)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(file.statusColor)
                .frame(width: 16, height: 16)
                .background(file.statusColor.opacity(0.2))
                .cornerRadius(3)

            Image(systemName: "doc.fill")
                .foregroundColor(.secondary)
                .frame(width: 16)

            Text(file.filename)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
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
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(stash.reference)
                            .font(.headline)

                        if !files.isEmpty {
                            HStack(spacing: 2) {
                                Image(systemName: "doc")
                                    .font(.system(size: 10))
                                Text("\(files.count)")
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15))
                            .cornerRadius(4)
                        }
                    }

                    Text(stash.message)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Stats
                if stats.additions > 0 || stats.deletions > 0 {
                    HStack(spacing: 8) {
                        if stats.additions > 0 {
                            Text("+\(stats.additions)")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(.green)
                        }
                        if stats.deletions > 0 {
                            Text("-\(stats.deletions)")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal, 8)
                }

                HStack(spacing: 8) {
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
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Image(systemName: "doc.on.doc.fill")
                                    .foregroundColor(.orange)

                                Text("Changed Files")
                                    .fontWeight(.medium)

                                Text("(\(files.count))")
                                    .foregroundColor(.secondary)

                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(nsColor: .controlBackgroundColor))

                    // File tree
                    if showDiff {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                StashFileTreeView(files: files)
                            }
                            .padding(.vertical, 4)
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
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "archivebox")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No stashes")
                .font(.headline)

            Text("Stash your changes to save them temporarily")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Text("Use ⌥⌘S to stash changes")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CreateStashSheet: View {
    @ObservedObject var viewModel: StashListViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var message = ""
    @State private var includeUntracked = true
    @State private var keepIndex = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Stash Changes")
                .font(.title2)
                .fontWeight(.semibold)

            Form {
                TextField("Message (optional)", text: $message)
                    .textFieldStyle(.roundedBorder)

                Toggle("Include untracked files", isOn: $includeUntracked)
                Toggle("Keep staged changes", isOn: $keepIndex)
            }

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
