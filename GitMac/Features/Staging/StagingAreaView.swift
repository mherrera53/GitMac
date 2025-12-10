import SwiftUI

/// Staging area view - manage staged and unstaged changes
struct StagingAreaView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = StagingAreaViewModel()
    @State private var commitMessage = ""
    @State private var isAmending = false
    @State private var selectedFile: String?
    @State private var showAICommitSheet = false
    @State private var showConflictResolver = false
    @State private var conflictFileToResolve: FileStatus?
    @State private var viewMode: FileViewMode = .tree
    @State private var extensionFilter: String? = nil
    @Namespace private var animation
    
    var body: some View {
        HSplitView {
            // Left: File lists
            VStack(spacing: 0) {
                // View mode and filter toolbar
                fileToolbar

                // Conflicted files (if any)
                if !viewModel.conflictedFiles.isEmpty {
                    conflictsSection
                    Divider()
                }

                // Unstaged changes
                unstagedSection
                Divider()

                // Staged changes
                stagedSection
                Divider()

                // Commit message area
                CommitMessageArea(
                    message: $commitMessage,
                    isAmending: $isAmending,
                    canCommit: viewModel.canCommit(message: commitMessage, amend: isAmending),
                    validationError: viewModel.commitError,
                    hasConflicts: !viewModel.conflictedFiles.isEmpty,
                    onCommit: {
                        Task {
                            let success = await viewModel.commit(message: commitMessage, amend: isAmending)
                            if success {
                                commitMessage = ""
                                isAmending = false
                            }
                        }
                    },
                    onGenerateAI: { showAICommitSheet = true }
                )
            }
            .frame(minWidth: 300)
            .alert("Commit Error", isPresented: $viewModel.showError) {
                Button("OK") { viewModel.showError = false }
            } message: {
                if let error = viewModel.commitError {
                    Text(error.localizedDescription)
                    if let recovery = error.recoverySuggestion {
                        Text(recovery)
                    }
                }
            }

            // Right: Diff viewer
            if let file = selectedFile {
                DiffPreviewView(path: file, staged: viewModel.stagedFiles.contains { $0.path == file })
            } else {
                VStack {
                    Spacer()
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Select a file to view changes")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .sheet(isPresented: $showAICommitSheet) {
            AICommitMessageSheet(message: $commitMessage, diff: viewModel.currentDiff)
        }
        .sheet(isPresented: $showConflictResolver) {
            if let file = conflictFileToResolve, let repoPath = appState.currentRepository?.path {
                InlineConflictResolver(
                    filePath: file.path,
                    repositoryPath: repoPath,
                    onResolved: {
                        if let repo = appState.currentRepository {
                            Task {
                                await viewModel.loadStatus(for: repo)
                                await viewModel.stage(file: file.path)
                            }
                        }
                        showConflictResolver = false
                    }
                )
            }
        }
        .task {
            viewModel.configure(with: appState)
            if let repo = appState.currentRepository {
                await viewModel.loadStatus(for: repo)
            }
        }
        .onChange(of: appState.currentRepository?.status) { _, _ in
            if let repo = appState.currentRepository {
                Task { await viewModel.loadStatus(for: repo) }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .repositoryDidRefresh)) { notification in
            // Refresh when stash apply/pop or other operations complete
            if let path = notification.object as? String,
               path == appState.currentRepository?.path {
                Task {
                    try? await appState.gitService.refresh()
                    if let repo = appState.currentRepository {
                        await viewModel.loadStatus(for: repo)
                    }
                }
            }
        }
    }

    // MARK: - Toolbar

    private var fileToolbar: some View {
        HStack(spacing: 8) {
            // View mode picker
            Picker("View", selection: $viewMode) {
                Image(systemName: "list.bullet").tag(FileViewMode.flat)
                Image(systemName: "folder.fill").tag(FileViewMode.tree)
            }
            .pickerStyle(.segmented)
            .frame(width: 70)
            .help("Toggle flat/tree view")

            Divider().frame(height: 16)

            // Extension filter menu
            Menu {
                Button("All Files") {
                    extensionFilter = nil
                }
                Divider()
                ForEach(viewModel.availableExtensions, id: \.self) { ext in
                    Button {
                        extensionFilter = ext
                    } label: {
                        HStack {
                            Image(systemName: "doc.fill") // FileTypeIcon.systemIcon(for: "file.\(ext)"))
                            Text(".\(ext)")
                            Spacer()
                            Text("\(viewModel.fileCountForExtension(ext))")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                    Text(extensionFilter ?? "All")
                        .lineLimit(1)
                }
            }
            .menuStyle(.borderlessButton)
            .frame(maxWidth: 100)

            Spacer()

            // File count
            Text("\(viewModel.totalFileCount) files")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Sections

    private var conflictsSection: some View {
        FileListSection(
            title: "Conflicts",
            count: viewModel.conflictedFiles.count,
            icon: "exclamationmark.triangle.fill",
            headerColor: .red
        ) {
            EmptyView()
        } content: {
            ForEach(viewModel.conflictedFiles) { file in
                ConflictedFileRow(
                    file: file,
                    isSelected: selectedFile == file.path,
                    onSelect: { selectedFile = file.path },
                    onResolve: {
                        conflictFileToResolve = file
                        showConflictResolver = true
                    }
                )
            }
        }
    }

    @State private var isStagingAll = false
    @State private var isDiscardingAll = false
    @State private var isUnstagingAll = false

    private var unstagedSection: some View {
        FileListSection(
            title: "Unstaged Files",
            count: viewModel.unstagedFiles.count + viewModel.untrackedFiles.count,
            icon: "square",
            headerColor: .orange
        ) {
            HStack(spacing: 8) {
                HeaderActionButton(
                    icon: "plus.circle.fill",
                    color: GitKrakenTheme.accentGreen,
                    isLoading: isStagingAll,
                    tooltip: "Stage All"
                ) {
                    isStagingAll = true
                    await viewModel.stageAll()
                    isStagingAll = false
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])

                HeaderActionButton(
                    icon: "xmark.circle.fill",
                    color: GitKrakenTheme.accentRed,
                    isLoading: isDiscardingAll,
                    tooltip: "Discard All"
                ) {
                    isDiscardingAll = true
                    await viewModel.discardAll()
                    isDiscardingAll = false
                }
            }
        } content: {
            if viewModel.unstagedFiles.isEmpty && viewModel.untrackedFiles.isEmpty {
                emptyStateView("No unstaged changes")
            } else {
                unstagedContent
            }
        }
    }

    @ViewBuilder
    private var unstagedContent: some View {
            if viewMode == .tree {
                FileTreeView(
                    files: filteredUnstagedFiles,
                    untrackedFiles: filteredUntrackedFiles,
                    selectedFile: $selectedFile,
                    namespace: animation,
                    onStage: { path in Task { await viewModel.stage(file: path) } },
                    onDiscard: { path in Task { await viewModel.discardChanges(file: path) } },
                    onStageFolder: { folder in Task { await viewModel.stageFolder(folder) } }
                )
            } else {
            flatUnstagedList
        }
    }

    private var flatUnstagedList: some View {
        Group {
            // When filtering, show grouped by status type
            if extensionFilter != nil {
                // Modified files
                let modifiedFiles = filteredUnstagedFiles.filter { $0.status == .modified }
                if !modifiedFiles.isEmpty {
                    FileStatusSeparator(title: "Modified", count: modifiedFiles.count, color: .orange)
                    ForEach(modifiedFiles) { file in
                        FileRow(
                            file: file,
                            isSelected: selectedFile == file.path,
                            namespace: animation,
                            onSelect: { selectedFile = file.path },
                            onStage: { Task { await viewModel.stage(file: file.path) } },
                            onDiscard: { Task { await viewModel.discardChanges(file: file.path) } }
                        )
                    }
                }

                // Added/New files (untracked)
                if !filteredUntrackedFiles.isEmpty {
                    FileStatusSeparator(title: "Added", count: filteredUntrackedFiles.count, color: .green)
                    ForEach(filteredUntrackedFiles, id: \.self) { path in
                        UntrackedFileRow(
                            path: path,
                            isSelected: selectedFile == path,
                            namespace: animation,
                            onSelect: { selectedFile = path },
                            onStage: { Task { await viewModel.stage(file: path) } }
                        )
                    }
                }

                // Other statuses (deleted, renamed, etc)
                let otherFiles = filteredUnstagedFiles.filter { $0.status != .modified }
                if !otherFiles.isEmpty {
                    FileStatusSeparator(title: "Other Changes", count: otherFiles.count, color: .blue)
                    ForEach(otherFiles) { file in
                        FileRow(
                            file: file,
                            isSelected: selectedFile == file.path,
                            namespace: animation,
                            onSelect: { selectedFile = file.path },
                            onStage: { Task { await viewModel.stage(file: file.path) } },
                            onDiscard: { Task { await viewModel.discardChanges(file: file.path) } }
                        )
                    }
                }
            } else {
                // No filter - show all files together
                ForEach(filteredUnstagedFiles) { file in
                    FileRow(
                        file: file,
                        isSelected: selectedFile == file.path,
                        namespace: animation,
                        onSelect: { selectedFile = file.path },
                        onStage: { Task { await viewModel.stage(file: file.path) } },
                        onDiscard: { Task { await viewModel.discardChanges(file: file.path) } }
                    )
                }

                ForEach(filteredUntrackedFiles, id: \.self) { path in
                    UntrackedFileRow(
                        path: path,
                        isSelected: selectedFile == path,
                        namespace: animation,
                        onSelect: { selectedFile = path },
                        onStage: { Task { await viewModel.stage(file: path) } }
                    )
                }
            }
        }
    }

    private var stagedSection: some View {
        FileListSection(
            title: "Staged Files",
            count: viewModel.stagedFiles.count,
            icon: "checkmark.square.fill",
            headerColor: .green
        ) {
            HeaderActionButton(
                icon: "minus.circle.fill",
                color: GitKrakenTheme.accentOrange,
                isLoading: isUnstagingAll,
                tooltip: "Unstage All"
            ) {
                isUnstagingAll = true
                await viewModel.unstageAll()
                isUnstagingAll = false
            }
            .keyboardShortcut("u", modifiers: [.command, .shift])
        } content: {
            if viewModel.stagedFiles.isEmpty {
                emptyStateView("No staged changes")
            } else {
                stagedContent
            }
        }
    }

    @ViewBuilder
    private var stagedContent: some View {
        if viewMode == .tree {
            FileTreeView(
                files: filteredStagedFiles,
                untrackedFiles: [],
                selectedFile: $selectedFile,
                isStaged: true,
                namespace: animation,
                onUnstage: { path in Task { await viewModel.unstage(file: path) } },
                onUnstageFolder: { folder in Task { await viewModel.unstageFolder(folder) } }
            )
        } else {
            ForEach(filteredStagedFiles) { file in
                FileRow(
                    file: file,
                    isSelected: selectedFile == file.path,
                    namespace: animation,
                    onSelect: { selectedFile = file.path },
                    onUnstage: { Task { await viewModel.unstage(file: file.path) } }
                )
            }
        }
    }

    private func emptyStateView(_ text: String) -> some View {
        Text(text)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding()
    }

    // MARK: - Filtered Files

    private var filteredUnstagedFiles: [FileStatus] {
        guard let ext = extensionFilter else { return viewModel.unstagedFiles }
        return viewModel.unstagedFiles.filter { $0.fileExtension == ext }
    }

    private var filteredUntrackedFiles: [String] {
        guard let ext = extensionFilter else { return viewModel.untrackedFiles }
        return viewModel.untrackedFiles.filter {
            (URL(fileURLWithPath: $0).pathExtension.lowercased()) == ext
        }
    }

    private var filteredStagedFiles: [FileStatus] {
        guard let ext = extensionFilter else { return viewModel.stagedFiles }
        return viewModel.stagedFiles.filter { $0.fileExtension == ext }
    }
}

// MARK: - View Mode
enum FileViewMode {
    case flat
    case tree
}

// MARK: - View Model

// MARK: - Commit Validation Error
enum CommitValidationError: LocalizedError {
    case noStagedFiles
    case emptyMessage
    case messageTooShort
    case noRepository
    case conflictsExist

    var errorDescription: String? {
        switch self {
        case .noStagedFiles:
            return "No files staged for commit"
        case .emptyMessage:
            return "Commit message cannot be empty"
        case .messageTooShort:
            return "Commit message should be at least 3 characters"
        case .noRepository:
            return "No repository selected"
        case .conflictsExist:
            return "Resolve merge conflicts before committing"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .noStagedFiles:
            return "Stage at least one file before committing"
        case .emptyMessage:
            return "Enter a descriptive commit message"
        case .messageTooShort:
            return "Write a more descriptive message"
        case .noRepository:
            return "Open a repository first"
        case .conflictsExist:
            return "Use the conflict resolver to fix merge conflicts"
        }
    }
}

@MainActor
class StagingAreaViewModel: ObservableObject {
    @Published var stagedFiles: [FileStatus] = []
    @Published var unstagedFiles: [FileStatus] = []
    @Published var untrackedFiles: [String] = []
    @Published var conflictedFiles: [FileStatus] = []
    @Published var isLoading = false
    @Published var currentDiff = ""
    @Published var commitError: CommitValidationError?
    @Published var showError = false
    @Published var availableExtensions: [String] = []

    private var currentPath: String?
    private var gitService: GitService?
    private weak var appState: AppState?
    private var extensionCounts: [String: Int] = [:]

    func configure(with appState: AppState) {
        self.appState = appState
        self.gitService = appState.gitService
    }

    // MARK: - Computed Properties

    var totalFileCount: Int {
        stagedFiles.count + unstagedFiles.count + untrackedFiles.count
    }

    func fileCountForExtension(_ ext: String) -> Int {
        extensionCounts[ext] ?? 0
    }

    // MARK: - Extension Cache

    private func updateExtensionCache() {
        var extensions = Set<String>()
        var counts: [String: Int] = [:]

        for file in stagedFiles {
            let ext = file.fileExtension
            if !ext.isEmpty {
                extensions.insert(ext)
                counts[ext, default: 0] += 1
            }
        }
        for file in unstagedFiles {
            let ext = file.fileExtension
            if !ext.isEmpty {
                extensions.insert(ext)
                counts[ext, default: 0] += 1
            }
        }
        for path in untrackedFiles {
            let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
            if !ext.isEmpty {
                extensions.insert(ext)
                counts[ext, default: 0] += 1
            }
        }

        availableExtensions = extensions.sorted()
        extensionCounts = counts
    }

    // MARK: - Load Status

    func loadStatus(for repo: Repository) async {
        currentPath = repo.path
        stagedFiles = repo.status.staged
        unstagedFiles = repo.status.unstaged
        untrackedFiles = repo.status.untracked
        conflictedFiles = repo.status.conflicted

        // Update extension cache once after loading status
        updateExtensionCache()

        // Load diff for all staged files
        if let gitService = gitService {
            currentDiff = (try? await gitService.getDiff(staged: true)) ?? ""
        }

        // Clear any previous error when status updates
        commitError = nil
        showError = false
    }

    // MARK: - Stage/Unstage

    func stage(file: String) async {
        guard currentPath != nil, let gitService = gitService else { return }
        try? await gitService.stage(files: [file])
        await reloadStatus()
    }

    func stageAll() async {
        guard currentPath != nil, let gitService = gitService else { return }
        try? await gitService.stageAll()
        await reloadStatus()
    }

    func stageFolder(_ folder: String) async {
        guard currentPath != nil, let gitService = gitService else { return }
        // Get all files in this folder (unstaged + untracked)
        var filesToStage: [String] = []
        for file in unstagedFiles where file.path.hasPrefix(folder + "/") || file.path.hasPrefix(folder) {
            filesToStage.append(file.path)
        }
        for path in untrackedFiles where path.hasPrefix(folder + "/") || path.hasPrefix(folder) {
            filesToStage.append(path)
        }
        if !filesToStage.isEmpty {
            try? await gitService.stage(files: filesToStage)
            await reloadStatus()
        }
    }

    func unstage(file: String) async {
        guard currentPath != nil, let gitService = gitService else { return }
        try? await gitService.unstage(files: [file])
        await reloadStatus()
    }

    func unstageAll() async {
        guard let gitService = gitService else { return }
        let allStaged = stagedFiles.map { $0.path }
        try? await gitService.unstage(files: allStaged)
        await reloadStatus()
    }

    func unstageFolder(_ folder: String) async {
        guard currentPath != nil, let gitService = gitService else { return }
        var filesToUnstage: [String] = []
        for file in stagedFiles where file.path.hasPrefix(folder + "/") || file.path.hasPrefix(folder) {
            filesToUnstage.append(file.path)
        }
        if !filesToUnstage.isEmpty {
            try? await gitService.unstage(files: filesToUnstage)
            await reloadStatus()
        }
    }

    func discardChanges(file: String) async {
        guard currentPath != nil, let gitService = gitService else { return }
        try? await gitService.discardChanges(files: [file])
        await reloadStatus()
    }

    func discardAll() async {
        guard let gitService = gitService else { return }
        let allUnstaged = unstagedFiles.map { $0.path }
        try? await gitService.discardChanges(files: allUnstaged)
        await reloadStatus()
    }

    private func reloadStatus() async {
        // Reload from appState's current repository
        if let repo = appState?.currentRepository {
            await loadStatus(for: repo)
        }
    }

    // MARK: - Validation

    func validateCommit(message: String, amend: Bool = false) -> CommitValidationError? {
        guard currentPath != nil else { return .noRepository }
        if !conflictedFiles.isEmpty { return .conflictsExist }
        if !amend && stagedFiles.isEmpty { return .noStagedFiles }

        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedMessage.isEmpty { return .emptyMessage }
        if trimmedMessage.count < 3 { return .messageTooShort }

        return nil
    }

    func commit(message: String, amend: Bool = false) async -> Bool {
        if let error = validateCommit(message: message, amend: amend) {
            commitError = error
            showError = true
            return false
        }

        guard currentPath != nil, let gitService = gitService else { return false }

        do {
            _ = try await gitService.commit(message: message, amend: amend)
            commitError = nil
            showError = false
            await reloadStatus()
            return true
        } catch {
            return false
        }
    }

    func canCommit(message: String, amend: Bool = false) -> Bool {
        return validateCommit(message: message, amend: amend) == nil
    }
}

// MARK: - Subviews

struct FileListSection<HeaderActions: View, Content: View>: View {
    let title: String
    let count: Int
    let icon: String
    let headerColor: Color
    @ViewBuilder let headerActions: () -> HeaderActions
    @ViewBuilder let content: () -> Content

    @State private var isExpanded = true

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
                } label: {
                    HStack {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Image(systemName: icon)
                            .foregroundColor(headerColor)

                        Text(title)
                            .fontWeight(.medium)

                        Text("(\(count))")
                            .foregroundColor(.secondary)

                        Spacer()
                    }
                }
                .buttonStyle(.plain)

                headerActions()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))

            // Content - LazyVStack for performance with stable ID to prevent jumping
            if isExpanded {
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: []) {
                        content()
                    }
                    .id(count)  // Stable ID prevents view jumping
                    .animation(.none, value: count)
                }
            }
        }
    }
}

struct FileRow: View {
    let file: FileStatus
    let isSelected: Bool
    var namespace: Namespace.ID? = nil
    var onSelect: () -> Void = {}
    var onStage: (() async -> Void)? = nil
    var onUnstage: (() async -> Void)? = nil
    var onDiscard: (() async -> Void)? = nil

    @State private var isHovered = false
    @State private var isStaging = false
    @State private var isUnstaging = false
    @State private var isDiscarding = false

    var body: some View {
        HStack(spacing: 8) {
            // Status indicator
            StatusIcon(status: file.status)

            // File icon
            Image(systemName: "doc.fill") // FileTypeIcon.systemIcon(for: file.filename))
                .foregroundColor(.blue) // FileTypeIcon.color(for: file.filename))
                .frame(width: 16)

            // File path
            VStack(alignment: .leading, spacing: 0) {
                Text(file.filename)
                    .lineLimit(1)

                if !file.directory.isEmpty && file.directory != "." {
                    Text(file.directory)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Line change counters
            if file.hasChanges {
                DiffStatsView(additions: file.additions, deletions: file.deletions)
            }

            // Actions (shown on hover)
            if isHovered {
                HStack(spacing: 4) {
                    if let stage = onStage {
                        FileActionButton(
                            icon: "plus.circle",
                            color: GitKrakenTheme.accentGreen,
                            isLoading: isStaging,
                            tooltip: "Stage"
                        ) {
                            isStaging = true
                            await stage()
                            isStaging = false
                        }
                    }

                    if let unstage = onUnstage {
                        FileActionButton(
                            icon: "minus.circle",
                            color: GitKrakenTheme.accentOrange,
                            isLoading: isUnstaging,
                            tooltip: "Unstage"
                        ) {
                            isUnstaging = true
                            await unstage()
                            isUnstaging = false
                        }
                    }

                    if let discard = onDiscard {
                        FileActionButton(
                            icon: "xmark.circle",
                            color: GitKrakenTheme.accentRed,
                            isLoading: isDiscarding,
                            tooltip: "Discard changes"
                        ) {
                            isDiscarding = true
                            await discard()
                            isDiscarding = false
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.2) : (isHovered ? Color.secondary.opacity(0.1) : Color.clear))
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onHover { isHovered = $0 }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
        .matchedGeometryEffect(id: file.path, in: namespace ?? Namespace().wrappedValue, isSource: true)
        .contextMenu {
            FileContextMenu(
                filePath: file.path,
                isStaged: onUnstage != nil,
                onStage: onStage != nil ? { Task { await onStage?() } } : nil,
                onUnstage: onUnstage != nil ? { Task { await onUnstage?() } } : nil,
                onDiscard: onDiscard != nil ? { Task { await onDiscard?() } } : nil
            )
        }
    }
}

// MARK: - Header Action Button (with loading state)

struct HeaderActionButton: View {
    let icon: String
    let color: Color
    let isLoading: Bool
    let tooltip: String
    let action: () async -> Void

    @State private var isHovered = false

    var body: some View {
        Button {
            guard !isLoading else { return }
            Task { await action() }
        } label: {
            Group {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: icon)
                        .foregroundColor(color)
                }
            }
            .frame(width: 24, height: 24)
            .background(isHovered ? color.opacity(0.15) : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .help(tooltip)
        .onHover { isHovered = $0 }
    }
}

// MARK: - File Action Button (with loading state)

struct FileActionButton: View {
    let icon: String
    let color: Color
    let isLoading: Bool
    let tooltip: String
    let action: () async -> Void

    @State private var isHovered = false

    var body: some View {
        Button {
            guard !isLoading else { return }
            Task { await action() }
        } label: {
            Group {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 14, height: 14)
                } else {
                    Image(systemName: icon)
                        .foregroundColor(isHovered ? color : color.opacity(0.8))
                }
            }
            .frame(width: 20, height: 20)
            .background(isHovered ? color.opacity(0.15) : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .help(tooltip)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Diff Stats View

struct DiffStatsView: View {
    let additions: Int
    let deletions: Int

    var body: some View {
        HStack(spacing: 4) {
            if additions > 0 {
                HStack(spacing: 1) {
                    Text("+")
                        .foregroundColor(.green)
                    Text("\(additions)")
                        .foregroundColor(.green)
                }
                .font(.system(size: 10, weight: .medium, design: .monospaced))
            }

            if deletions > 0 {
                HStack(spacing: 1) {
                    Text("−")
                        .foregroundColor(.red)
                    Text("\(deletions)")
                        .foregroundColor(.red)
                }
                .font(.system(size: 10, weight: .medium, design: .monospaced))
            }
        }
    }
}

// MARK: - Conflicted File Row

struct ConflictedFileRow: View {
    let file: FileStatus
    let isSelected: Bool
    var onSelect: () -> Void = {}
    var onResolve: () -> Void = {}

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            // Conflict indicator
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .frame(width: 16)

            // File icon
            Image(systemName: "doc.fill") // FileTypeIcon.systemIcon(for: file.filename))
                .foregroundColor(.blue) // FileTypeIcon.color(for: file.filename))
                .frame(width: 16)

            // File path
            VStack(alignment: .leading, spacing: 0) {
                Text(file.filename)
                    .lineLimit(1)

                if !file.directory.isEmpty && file.directory != "." {
                    Text(file.directory)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Resolve button
            Button {
                onResolve()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "wand.and.stars")
                    Text("Resolve")
                }
                .font(.caption)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.red.opacity(0.05))
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onHover { isHovered = $0 }
        .contextMenu {
            Button {
                onResolve()
            } label: {
                Label("Resolve Conflict...", systemImage: "wand.and.stars")
            }

            Divider()

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(file.path, forType: .string)
            } label: {
                Label("Copy Path", systemImage: "doc.on.doc")
            }
        }
    }
}

// MARK: - File Context Menu
struct FileContextMenu: View {
    let filePath: String
    let isStaged: Bool
    var onStage: (() -> Void)?
    var onUnstage: (() -> Void)?
    var onDiscard: (() -> Void)?

    var filename: String {
        URL(fileURLWithPath: filePath).lastPathComponent
    }

    var body: some View {
        Group {
            // Stage/Unstage
            if !isStaged, let stage = onStage {
                Button {
                    stage()
                } label: {
                    Label("Stage File", systemImage: "plus.circle")
                }
            }

            if isStaged, let unstage = onUnstage {
                Button {
                    unstage()
                } label: {
                    Label("Unstage File", systemImage: "minus.circle")
                }
            }

            Divider()

            // File operations
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(filePath, forType: .string)
            } label: {
                Label("Copy Path", systemImage: "doc.on.doc")
            }

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(filename, forType: .string)
            } label: {
                Label("Copy Filename", systemImage: "doc.text")
            }

            Divider()

            Button {
                NSWorkspace.shared.selectFile(filePath, inFileViewerRootedAtPath: "")
            } label: {
                Label("Reveal in Finder", systemImage: "folder")
            }

            Button {
                NSWorkspace.shared.open(URL(fileURLWithPath: filePath))
            } label: {
                Label("Open with Default App", systemImage: "arrow.up.forward.app")
            }

            if !isStaged, let discard = onDiscard {
                Divider()

                Button(role: .destructive) {
                    discard()
                } label: {
                    Label("Discard Changes", systemImage: "xmark.circle")
                }
            }

            Divider()

            Button {
                NotificationCenter.default.post(name: .ignoreFile, object: filePath)
            } label: {
                Label("Ignore", systemImage: "eye.slash")
            }

            Button {
                NotificationCenter.default.post(name: .assumeUnchanged, object: filePath)
            } label: {
                Label("Assume Unchanged", systemImage: "lock.doc")
            }
        }
    }
}

struct UntrackedFileRow: View {
    let path: String
    let isSelected: Bool
    var namespace: Namespace.ID? = nil
    var onSelect: () -> Void = {}
    var onStage: (() -> Void)? = nil

    @State private var isHovered = false

    var filename: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    var directory: String {
        URL(fileURLWithPath: path).deletingLastPathComponent().path
    }

    var body: some View {
        HStack(spacing: 8) {
            StatusIcon(status: .untracked)

            Image(systemName: "doc.fill") // FileTypeIcon.systemIcon(for: filename))
                .foregroundColor(.blue) // FileTypeIcon.color(for: filename))
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 0) {
                Text(filename)
                    .lineLimit(1)

                if !directory.isEmpty && directory != "." {
                    Text(directory)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if isHovered, let stage = onStage {
                Button {
                    stage()
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.borderless)
                .help("Stage")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.2) : (isHovered ? Color.secondary.opacity(0.1) : Color.clear))
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onHover { isHovered = $0 }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
        .matchedGeometryEffect(id: path, in: namespace ?? Namespace().wrappedValue, isSource: true)
        .contextMenu {
            if let stage = onStage {
                Button {
                    stage()
                } label: {
                    Label("Stage File", systemImage: "plus.circle")
                }
            }

            Divider()

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(path, forType: .string)
            } label: {
                Label("Copy Path", systemImage: "doc.on.doc")
            }

            Button {
                NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
            } label: {
                Label("Reveal in Finder", systemImage: "folder")
            }

            Divider()

            Button(role: .destructive) {
                try? FileManager.default.removeItem(atPath: path)
            } label: {
                Label("Delete File", systemImage: "trash")
            }

            Divider()

            Button {
                NotificationCenter.default.post(name: .ignoreFile, object: path)
            } label: {
                Label("Ignore", systemImage: "eye.slash")
            }
        }
    }
}

struct StatusIcon: View {
    let status: FileStatusType

    var body: some View {
        Text(status.rawValue)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundColor(statusColor)
            .frame(width: 16, height: 16)
            .background(statusColor.opacity(0.2))
            .cornerRadius(3)
    }

    var statusColor: Color {
        switch status {
        case .added: return .green
        case .modified: return .orange
        case .deleted: return .red
        case .renamed: return .blue
        case .copied: return .blue
        case .untracked: return .gray
        case .ignored: return .gray
        case .typeChanged: return .purple
        case .unmerged: return .red
        }
    }
}

// MARK: - File Status Separator

struct FileStatusSeparator: View {
    let title: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(color)
                .frame(width: 3, height: 14)
                .cornerRadius(1.5)

            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(color)

            Text("(\(count))")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            Rectangle()
                .fill(color.opacity(0.3))
                .frame(height: 1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.05))
    }
}

struct CommitMessageArea: View {
    @Binding var message: String
    @Binding var isAmending: Bool
    let canCommit: Bool
    var validationError: CommitValidationError? = nil
    var hasConflicts: Bool = false
    let onCommit: () -> Void
    let onGenerateAI: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Commit Message")
                    .font(.headline)

                Spacer()

                Button {
                    onGenerateAI()
                } label: {
                    Label("Generate with AI", systemImage: "sparkles")
                }
                .buttonStyle(.borderless)
            }

            // Conflict warning
            if hasConflicts {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Resolve merge conflicts before committing")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Spacer()
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(4)
            }

            TextEditor(text: $message)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 80, maxHeight: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(borderColor, lineWidth: 1)
                )

            // Validation hint
            if !canCommit && !message.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                    Text(validationHint)
                        .font(.caption)
                    Spacer()
                }
                .foregroundColor(.secondary)
            }

            // Character count
            HStack {
                Text("\(message.count) characters")
                    .font(.caption2)
                    .foregroundColor(message.count < 3 ? .orange : .secondary)

                Spacer()
            }

            HStack {
                Toggle("Amend last commit", isOn: $isAmending)
                    .toggleStyle(.checkbox)

                Spacer()

                Button("Commit") {
                    onCommit()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canCommit)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }

    var borderColor: Color {
        if hasConflicts {
            return .orange
        }
        if !canCommit && !message.isEmpty {
            return .orange.opacity(0.5)
        }
        return Color.secondary.opacity(0.3)
    }

    var validationHint: String {
        if message.trimmingCharacters(in: .whitespacesAndNewlines).count < 3 {
            return "Message should be at least 3 characters"
        }
        if let error = validationError {
            return error.errorDescription ?? "Cannot commit"
        }
        return "Ready to commit"
    }
}

struct DiffPreviewView: View {
    let path: String
    let staged: Bool
    var gitService: GitService?

    @State private var diff = ""
    @State private var hunks: [DiffHunk] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "doc.fill") // FileTypeIcon.systemIcon(for: path))
                    .foregroundColor(.blue) // FileTypeIcon.color(for: path))
                Text(path)
                    .fontWeight(.medium)
                Spacer()

                if staged {
                    Text("Staged")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(4)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Diff content
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if hunks.isEmpty {
                Text("No changes to display")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Interactive hunk view
                HunkDiffView(
                    hunks: hunks,
                    showLineNumbers: true,
                    filePath: path,
                    isStaged: staged,
                    onStageHunk: staged ? nil : { hunkIndex in
                        Task { await stageHunk(at: hunkIndex) }
                    },
                    onUnstageHunk: staged ? { hunkIndex in
                        Task { await unstageHunk(at: hunkIndex) }
                    } : nil,
                    onDiscardHunk: staged ? nil : { hunkIndex in
                        Task { await discardHunk(at: hunkIndex) }
                    }
                )
            }
        }
        .task(id: path) {
            await loadDiff()
        }
    }

    private func loadDiff() async {
        isLoading = true
        errorMessage = nil
        let service = gitService ?? GitService()
        diff = (try? await service.getDiff(for: path, staged: staged)) ?? ""
        // Use the shared DiffParser that returns FileDiffs, then take hunks
        let files = DiffParser.parse(diff)
        if let first = files.first {
            hunks = first.hunks
        } else {
            hunks = []
        }
        isLoading = false
    }

    private func stageHunk(at index: Int) async {
        guard index < hunks.count else { return }
        let service = gitService ?? GitService()
        do {
            try await service.stageHunk(filePath: path, hunk: hunks[index])
            await loadDiff()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func unstageHunk(at index: Int) async {
        guard index < hunks.count else { return }
        let service = gitService ?? GitService()
        do {
            try await service.unstageHunk(filePath: path, hunk: hunks[index])
            await loadDiff()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func discardHunk(at index: Int) async {
        guard index < hunks.count else { return }
        let service = gitService ?? GitService()
        do {
            try await service.discardHunk(filePath: path, hunk: hunks[index])
            await loadDiff()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// Removed duplicate DiffParser here to avoid redeclaration and use the shared one in DiffView.swift

// MARK: - AI Commit Message Sheet

struct AICommitMessageSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var message: String
    let diff: String

    @State private var generatedMessage = ""
    @State private var isGenerating = false
    @State private var error: String?
    @State private var selectedStyle: CommitStyle = .conventional

    private let aiService = AIService()

    var body: some View {
        VStack(spacing: 16) {
            Text("Generate Commit Message")
                .font(.title2)
                .fontWeight(.semibold)

            Picker("Style", selection: $selectedStyle) {
                ForEach(CommitStyle.allCases, id: \.self) { style in
                    Text(style.description).tag(style)
                }
            }
            .pickerStyle(.segmented)

            if isGenerating {
                ProgressView("Generating...")
                    .frame(maxHeight: .infinity)
            } else if !generatedMessage.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Generated Message:")
                        .font(.headline)

                    TextEditor(text: $generatedMessage)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                }
            } else if let error = error {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundColor(.orange)
                    Text(error)
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                VStack {
                    Image(systemName: "sparkles")
                        .font(.system(size: 32))
                        .foregroundColor(.accentColor)
                    Text("Click Generate to create a commit message")
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                if generatedMessage.isEmpty || isGenerating {
                    Button("Generate") {
                        Task { await generate() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isGenerating || diff.isEmpty)
                } else {
                    Button("Regenerate") {
                        Task { await generate() }
                    }

                    Button("Use This") {
                        message = generatedMessage
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
        .frame(width: 500, height: 350)
    }

    private func generate() async {
        isGenerating = true
        error = nil

        do {
            generatedMessage = try await aiService.generateCommitMessage(
                diff: diff,
                style: selectedStyle
            )
        } catch {
            self.error = error.localizedDescription
        }

        isGenerating = false
    }
}

// MARK: - File Tree View

struct FileTreeView: View {
    let files: [FileStatus]
    let untrackedFiles: [String]
    @Binding var selectedFile: String?
    var isStaged: Bool = false
    var namespace: Namespace.ID? = nil

    // Callbacks for unstaged files
    var onStage: ((String) -> Void)? = nil
    var onDiscard: ((String) -> Void)? = nil
    var onStageFolder: ((String) -> Void)? = nil

    // Callbacks for staged files
    var onUnstage: ((String) -> Void)? = nil
    var onUnstageFolder: ((String) -> Void)? = nil

    // Section identifier for expansion state (prevents conflicts between staged/unstaged)
    private var section: String {
        isStaged ? "staged" : "unstaged"
    }

    var body: some View {
        let tree = buildTree()
        ForEach(tree.children.sorted(by: { $0.name < $1.name })) { node in
            TreeNodeView(
                node: node,
                selectedFile: $selectedFile,
                isStaged: isStaged,
                section: section,
                namespace: namespace,
                onStage: onStage,
                onDiscard: onDiscard,
                onStageFolder: onStageFolder,
                onUnstage: onUnstage,
                onUnstageFolder: onUnstageFolder
            )
        }
    }

    private func buildTree() -> FileTreeNode {
        let root = FileTreeNode(name: "", path: "", isFolder: true, section: section)

        // Add FileStatus files
        for file in files {
            addToTree(root: root, path: file.path, file: file, isUntracked: false)
        }

        // Add untracked files
        for path in untrackedFiles {
            addToTree(root: root, path: path, file: nil, isUntracked: true)
        }

        return root
    }

    private func addToTree(root: FileTreeNode, path: String, file: FileStatus?, isUntracked: Bool) {
        let components = path.split(separator: "/").map(String.init)
        var current = root

        for (index, component) in components.enumerated() {
            let isLast = index == components.count - 1
            let currentPath = components[0...index].joined(separator: "/")

            if isLast {
                // This is a file
                let fileNode = FileTreeNode(
                    name: component,
                    path: currentPath,
                    isFolder: false,
                    file: file,
                    isUntracked: isUntracked,
                    section: section
                )
                current.children.append(fileNode)
            } else {
                // This is a folder - find or create
                if let existing = current.children.first(where: { $0.name == component && $0.isFolder }) {
                    current = existing
                } else {
                    let folderNode = FileTreeNode(name: component, path: currentPath, isFolder: true, section: section)
                    current.children.append(folderNode)
                    current = folderNode
                }
            }
        }
    }
}

// MARK: - Tree Expansion State (shared across all tree views)

class TreeExpansionState: ObservableObject {
    static let shared = TreeExpansionState()

    @Published var expandedPaths: Set<String> = []

    // Track explicitly collapsed paths to distinguish from "never seen"
    private var collapsedPaths: Set<String> = []

    func isExpanded(_ path: String, section: String = "") -> Bool {
        let key = section.isEmpty ? path : "\(section):\(path)"
        // Default to expanded for new paths
        if !expandedPaths.contains(key) && !collapsedPaths.contains(key) {
            expandedPaths.insert(key)
            return true
        }
        return expandedPaths.contains(key)
    }

    func toggle(_ path: String, section: String = "") {
        let key = section.isEmpty ? path : "\(section):\(path)"
        if expandedPaths.contains(key) {
            expandedPaths.remove(key)
            collapsedPaths.insert(key)
        } else {
            expandedPaths.insert(key)
            collapsedPaths.remove(key)
        }
    }
}

// MARK: - Tree Node Model

class FileTreeNode: Identifiable, ObservableObject {
    let id: String
    let name: String
    let path: String
    let isFolder: Bool
    let section: String
    var file: FileStatus?
    var isUntracked: Bool
    var children: [FileTreeNode] = []

    init(name: String, path: String, isFolder: Bool, file: FileStatus? = nil, isUntracked: Bool = false, section: String = "") {
        self.name = name
        self.path = path
        self.isFolder = isFolder
        self.section = section
        self.file = file
        self.isUntracked = isUntracked
        // Create stable ID using section and path
        self.id = section.isEmpty ? (path.isEmpty ? "root" : path) : "\(section):\(path.isEmpty ? "root" : path)"
    }

    var fileCount: Int {
        if isFolder {
            return children.reduce(0) { $0 + $1.fileCount }
        }
        return 1
    }
}

// MARK: - Tree Node View

struct TreeNodeView: View {
    @ObservedObject var node: FileTreeNode
    @Binding var selectedFile: String?
    var isStaged: Bool
    var section: String = ""
    var namespace: Namespace.ID? = nil
    var onStage: ((String) -> Void)?
    var onDiscard: ((String) -> Void)?
    var onStageFolder: ((String) -> Void)?
    var onUnstage: ((String) -> Void)?
    var onUnstageFolder: ((String) -> Void)?

    @ObservedObject private var expansionState = TreeExpansionState.shared
    @State private var isHovered = false

    private var isExpanded: Bool {
        expansionState.isExpanded(node.path, section: section)
    }

    var body: some View {
        if node.isFolder {
            folderView
        } else {
            fileView
        }
    }

    private var folderView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Folder header
            HStack(spacing: 6) {
                // Clickable folder name area
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .frame(width: 12)

                    Image(systemName: isExpanded ? "folder.fill" : "folder")
                        .foregroundColor(.yellow)
                        .frame(width: 16)

                    Text(node.name)
                        .lineLimit(1)

                    Text("(\(node.fileCount))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        expansionState.toggle(node.path, section: section)
                    }
                }

                Spacer()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            expansionState.toggle(node.path, section: section)
                        }
                    }

                // Folder actions on hover
                if isHovered {
                    if isStaged {
                        if let unstageFolder = onUnstageFolder {
                            Button {
                                unstageFolder(node.path)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                            .help("Unstage Folder")
                        }
                    } else {
                        if let stageFolder = onStageFolder {
                            Button {
                                stageFolder(node.path)
                            } label: {
                                Image(systemName: "plus.circle")
                            }
                            .buttonStyle(.borderless)
                            .help("Stage Folder")
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
            .background(isHovered ? Color.secondary.opacity(0.1) : Color.clear)
            .onHover { isHovered = $0 }
            .contextMenu {
                if isStaged {
                    Button {
                        onUnstageFolder?(node.path)
                    } label: {
                        Label("Unstage Folder", systemImage: "minus.circle")
                    }
                } else {
                    Button {
                        onStageFolder?(node.path)
                    } label: {
                        Label("Stage Folder", systemImage: "plus.circle")
                    }
                }

                Divider()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(node.path, forType: .string)
                } label: {
                    Label("Copy Path", systemImage: "doc.on.doc")
                }
            }

            // Children
            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(node.children.sorted(by: sortNodes)) { child in
                        TreeNodeView(
                            node: child,
                            selectedFile: $selectedFile,
                            isStaged: isStaged,
                            section: section,
                            namespace: namespace,
                            onStage: onStage,
                            onDiscard: onDiscard,
                            onStageFolder: onStageFolder,
                            onUnstage: onUnstage,
                            onUnstageFolder: onUnstageFolder
                        )
                        .padding(.leading, 16)
                    }
                }
            }
        }
    }

    private var fileView: some View {
        HStack(spacing: 6) {
            // Indent space for alignment
            Color.clear.frame(width: 12)

            // Status icon
            if let file = node.file {
                StatusIcon(status: file.status)
            } else if node.isUntracked {
                StatusIcon(status: .untracked)
            }

            // File icon
            Image(systemName: "doc.fill") // FileTypeIcon.systemIcon(for: node.name))
                .foregroundColor(.blue) // FileTypeIcon.color(for: node.name))
                .frame(width: 16)

            // Filename
            Text(node.name)
                .lineLimit(1)

            Spacer()

            // Line change counters
            if let file = node.file, file.hasChanges {
                DiffStatsView(additions: file.additions, deletions: file.deletions)
            }

            // Actions on hover
            if isHovered {
                if isStaged {
                    if let unstage = onUnstage {
                        Button {
                            unstage(node.path)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("Unstage")
                    }
                } else {
                    if let stage = onStage {
                        Button {
                            stage(node.path)
                        } label: {
                            Image(systemName: "plus.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("Stage")
                    }

                    if let discard = onDiscard, !node.isUntracked {
                        Button {
                            discard(node.path)
                        } label: {
                            Image(systemName: "xmark.circle")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.borderless)
                        .help("Discard")
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(selectedFile == node.path ? Color.accentColor.opacity(0.2) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedFile = node.path
        }
        .onHover { isHovered = $0 }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
        .matchedGeometryEffect(id: node.path, in: namespace ?? Namespace().wrappedValue, isSource: true)
        .contextMenu {
            if isStaged {
                Button {
                    onUnstage?(node.path)
                } label: {
                    Label("Unstage File", systemImage: "minus.circle")
                }
            } else {
                Button {
                    onStage?(node.path)
                } label: {
                    Label("Stage File", systemImage: "plus.circle")
                }

                if !node.isUntracked {
                    Button(role: .destructive) {
                        onDiscard?(node.path)
                    } label: {
                        Label("Discard Changes", systemImage: "xmark.circle")
                    }
                }
            }

            Divider()

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(node.path, forType: .string)
            } label: {
                Label("Copy Path", systemImage: "doc.on.doc")
            }

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(node.name, forType: .string)
            } label: {
                Label("Copy Filename", systemImage: "doc.text")
            }

            Divider()

            Button {
                NSWorkspace.shared.selectFile(node.path, inFileViewerRootedAtPath: "")
            } label: {
                Label("Reveal in Finder", systemImage: "folder")
            }
        }
    }

    // Sort: folders first, then files alphabetically
    private func sortNodes(_ a: FileTreeNode, _ b: FileTreeNode) -> Bool {
        if a.isFolder && !b.isFolder { return true }
        if !a.isFolder && b.isFolder { return false }
        return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
    }
}

extension Notification.Name {
    static let ignoreFile = Notification.Name("ignoreFile")
    static let assumeUnchanged = Notification.Name("assumeUnchanged")
}
