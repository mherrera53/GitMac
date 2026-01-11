import SwiftUI
import AppKit

/// Staging area view - manage staged and unstaged changes
struct StagingAreaView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = StagingAreaViewModel()
    @State private var commitMessage = ""
    @State private var isAmending = false
    @State private var selectedFile: String?
    @State private var showAICommitSheet = false
    @State private var showCreatePRSheet = false
    @State private var commitSHAForPR: String = ""  // SHA after commit for PR creation
    @State private var showConflictResolver = false
    @State private var conflictFileToResolve: FileStatus?
    @State private var viewMode: FileViewMode = .tree
    @State private var extensionFilter: String? = nil
    @State private var searchText: String = ""
    @Namespace private var animation

    // Section heights for resize functionality
    @State private var unstagedHeight: CGFloat = 200
    @State private var stagedHeight: CGFloat = 200
    @State private var commitHeight: CGFloat = 150

    // Pagination for large file lists
    private let maxVisibleFiles = 500
    @State private var unstagedOffset = 0
    @State private var stagedOffset = 0

    private var repoPath: String {
        appState.currentRepository?.path ?? ""
    }

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

                // Resizer between unstaged and staged
                UniversalResizer(
                    dimension: $unstagedHeight,
                    minDimension: 100,
                    maxDimension: 600,
                    orientation: .vertical
                )

                // Staged changes
                stagedSection

                // Resizer between staged and commit
                UniversalResizer(
                    dimension: $stagedHeight,
                    minDimension: 100,
                    maxDimension: 600,
                    orientation: .vertical
                )

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
                    onCommitPushPR: {
                        Task {
                            await commitPushAndOpenPR()
                        }
                    },
                    onGenerateAI: { showAICommitSheet = true }
                )
                .frame(height: commitHeight)
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
                        .font(DesignTokens.Typography.iconXXXXL)
                        .foregroundColor(AppTheme.textSecondary)
                    Text("Select a file to view changes")
                        .foregroundColor(AppTheme.textSecondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .sheet(isPresented: $showAICommitSheet) {
            AICommitMessageSheet(message: $commitMessage, diff: viewModel.currentDiff)
        }
        .sheet(isPresented: $showCreatePRSheet) {
            CreatePRSheetFromCommit(
                commitSHA: commitSHAForPR,
                onDismiss: { showCreatePRSheet = false }
            )
            .environmentObject(appState)
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
            // Refresh when stash apply/pop, commit, or other operations complete
            if let path = notification.object as? String,
               path == appState.currentRepository?.path {
                Task { @MainActor in
                    // Small delay to ensure git operations are complete
                    try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                    try? await appState.gitService.refresh()
                    if let repo = appState.currentRepository {
                        await viewModel.loadStatus(for: repo)
                    }
                }
            }
        }
    }

    // MARK: - Commit + Push + PR Flow

    /// Commits staged changes, pushes to remote, and opens PR creation sheet
    private func commitPushAndOpenPR() async {
        // Step 1: Commit
        let commitSuccess = await viewModel.commit(message: commitMessage, amend: isAmending)
        guard commitSuccess else {
            return // Commit failed, error already shown
        }

        // Clear commit message after successful commit
        commitMessage = ""
        isAmending = false

        // Step 2: Push
        do {
            let pushSHA = try await appState.gitService.push()
            let shortSHA = String(pushSHA.prefix(7))

            NotificationManager.shared.success(
                "Commit & Push completed",
                detail: "SHA: \(shortSHA)"
            )

            // Step 3: Open PR sheet
            commitSHAForPR = shortSHA
            showCreatePRSheet = true

        } catch {
            NotificationManager.shared.error(
                "Push failed",
                detail: error.localizedDescription
            )
        }
    }

    // MARK: - Toolbar

    private var fileToolbar: some View {
        VStack(spacing: 0) {
            // Main toolbar row
            HStack(spacing: DesignTokens.Spacing.sm) {
                // View mode picker (custom segmented control)
                HStack(spacing: 0) {
                    Button(action: { viewMode = .flat }) {
                        Image(systemName: "list.bullet")
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(viewMode == .flat ? AppTheme.accent : AppTheme.textSecondary)
                            .frame(width: 35, height: 22)
                            .background(viewMode == .flat ? AppTheme.accent.opacity(0.15) : Color.clear)
                    }
                    .buttonStyle(.plain)
                    .help("List view")

                    Button(action: { viewMode = .tree }) {
                        Image(systemName: "folder.fill")
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(viewMode == .tree ? AppTheme.accent : AppTheme.textSecondary)
                            .frame(width: 35, height: 22)
                            .background(viewMode == .tree ? AppTheme.accent.opacity(0.15) : Color.clear)
                    }
                    .buttonStyle(.plain)
                    .help("Tree view")
                }
                .background(AppTheme.backgroundTertiary)
                .cornerRadius(DesignTokens.CornerRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                        .stroke(AppTheme.border, lineWidth: 0.5)
                )

                // Search bar
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textMuted)

                    TextField("Search files...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(DesignTokens.Typography.caption)

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(AppTheme.textMuted)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppTheme.backgroundTertiary)
                .cornerRadius(DesignTokens.CornerRadius.md)
                .frame(maxWidth: 200)

                // Extension filter
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
                                Image(systemName: "doc.fill")
                                Text(".\(ext)")
                                Spacer()
                                Text("\(viewModel.fileCountForExtension(ext))")
                            }
                        }
                    }
                } label: {
                    Image(systemName: extensionFilter != nil ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
                .tint(extensionFilter != nil ? AppTheme.accent : AppTheme.textSecondary)
                .menuStyle(.borderlessButton)

                Spacer()

                // File count with warning for large lists
                if viewModel.totalFileCount > maxVisibleFiles {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.warning)
                        Text("\(viewModel.totalFileCount) files (showing \(maxVisibleFiles))")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(AppTheme.warning)
                    }
                    .help("Use search or filter to narrow down the file list")
                } else {
                    Text("\(viewModel.totalFileCount) files")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
            .background(AppTheme.backgroundSecondary)

            // Active filters indicator
            if extensionFilter != nil || !searchText.isEmpty {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    if let ext = extensionFilter {
                        ActiveFilterTag(label: ".\(ext)") {
                            extensionFilter = nil
                        }
                    }
                    if !searchText.isEmpty {
                        ActiveFilterTag(label: "\"\(searchText)\"") {
                            searchText = ""
                        }
                    }
                    Spacer()
                    Button("Clear all") {
                        extensionFilter = nil
                        searchText = ""
                    }
                    .font(DesignTokens.Typography.caption2)
                    .foregroundColor(AppTheme.accent)
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.xxs)
                .background(AppTheme.accent.opacity(0.08))
            }
        }
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

    private var unstagedSection: some View {
        FileListSection(
            title: "Unstaged Files",
            count: viewModel.unstagedFiles.count + viewModel.untrackedFiles.count,
            icon: "square",
            headerColor: .orange,
            headerActions: {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    DSIconButton(
                        iconName: "plus.circle.fill",
                        variant: .ghost,
                        size: .sm,
                        isDisabled: false,
                        action: {
                            await viewModel.stageAll()
                        }
                    )
                    .help("Stage All")
                    .keyboardShortcut("s", modifiers: [.command, .shift])

                    DSIconButton(
                        iconName: "xmark.circle.fill",
                        variant: .ghost,
                        size: .sm,
                        isDisabled: false,
                        action: {
                            await viewModel.discardAll()
                        }
                    )
                    .help("Discard All")
                }
            },
            content: {
                if viewModel.unstagedFiles.isEmpty && viewModel.untrackedFiles.isEmpty {
                    emptyStateView("No unstaged changes")
                } else {
                    unstagedContent
                }
            },
            maxHeight: unstagedHeight
        )
    }

    @ViewBuilder
    private var unstagedContent: some View {
            if viewMode == .tree {
                FileTreeView(
                    files: filteredUnstagedFiles,
                    untrackedFiles: filteredUntrackedFiles,
                    selectedFile: selectedFile,
                    namespace: animation,
                    onSelect: { path in selectedFile = path },
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
                            onSelect: { selectedFile = file.path },
                            onStage: { await viewModel.stage(file: file.path) },
                            onDiscard: { await viewModel.discardChanges(file: file.path) }
                        )
                    }
                }

                // Added/New files (untracked)
                if !filteredUntrackedFiles.isEmpty {
                    FileStatusSeparator(title: "Added", count: filteredUntrackedFiles.count, color: AppTheme.success)
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
                    FileStatusSeparator(title: "Other Changes", count: otherFiles.count, color: AppTheme.accent)
                    ForEach(otherFiles) { file in
                        FileRow(
                            file: file,
                            isSelected: selectedFile == file.path,
                            onSelect: { selectedFile = file.path },
                            onStage: { await viewModel.stage(file: file.path) },
                            onDiscard: { await viewModel.discardChanges(file: file.path) }
                        )
                    }
                }
            } else {
                // No filter - show paginated files for performance
                ForEach(paginatedUnstagedFiles) { file in
                    FileRow(
                        file: file,
                        isSelected: selectedFile == file.path,
                        onSelect: { selectedFile = file.path },
                        onStage: { await viewModel.stage(file: file.path) },
                        onDiscard: { await viewModel.discardChanges(file: file.path) }
                    )
                }

                ForEach(paginatedUntrackedFiles, id: \.self) { path in
                    UntrackedFileRow(
                        path: path,
                        isSelected: selectedFile == path,
                        namespace: animation,
                        onSelect: { selectedFile = path },
                        onStage: { Task { await viewModel.stage(file: path) } }
                    )
                }

                // Show "more files" indicator
                if hasMoreUnstagedFiles {
                    MoreFilesIndicator(
                        count: (filteredUnstagedFiles.count + filteredUntrackedFiles.count) - maxVisibleFiles,
                        message: "Use search to find specific files"
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
            headerColor: .green,
            headerActions: {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    DSIconButton(
                        iconName: "minus.circle.fill",
                        variant: .ghost,
                        size: .sm,
                        isDisabled: false,
                        action: {
                            await viewModel.unstageAll()
                        }
                    )
                    .help("Unstage All")
                    .keyboardShortcut("u", modifiers: [.command, .shift])

                    DSIconButton(
                        iconName: "xmark.circle.fill",
                        variant: .ghost,
                        size: .sm,
                        isDisabled: false,
                        action: {
                            await viewModel.discardAllStaged()
                        }
                    )
                    .help("Discard All Staged")
                }
            },
            content: {
                if viewModel.stagedFiles.isEmpty {
                    emptyStateView("No staged changes")
                } else {
                    stagedContent
                }
            },
            maxHeight: stagedHeight
        )
    }

    @ViewBuilder
    private var stagedContent: some View {
        if viewMode == .tree {
            FileTreeView(
                files: paginatedStagedFiles,
                untrackedFiles: [],
                selectedFile: selectedFile,
                isStaged: true,
                namespace: animation,
                onSelect: { path in selectedFile = path },
                onUnstage: { path in Task { await viewModel.unstage(file: path) } },
                onUnstageFolder: { folder in Task { await viewModel.unstageFolder(folder) } },
                onDiscardStaged: { path in Task { await viewModel.discardStagedFile(path) } }
            )
        } else {
            ForEach(paginatedStagedFiles) { file in
                FileRow(
                    file: file,
                    isSelected: selectedFile == file.path,
                    onSelect: { selectedFile = file.path },
                    onUnstage: { await viewModel.unstage(file: file.path) },
                    onDiscardStaged: { await viewModel.discardStagedFile(file.path) }
                )
            }
        }

        // Show "more files" indicator for staged
        if hasMoreStagedFiles {
            MoreFilesIndicator(
                count: filteredStagedFiles.count - maxVisibleFiles,
                message: "Use search to find specific files"
            )
        }
    }

    private func emptyStateView(_ text: String) -> some View {

        Text(text)
            .foregroundColor(AppTheme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding()
    }

    // MARK: - Filtered Files (with search and extension filter)

    private func applyFilters(_ files: [FileStatus]) -> [FileStatus] {
        var result = files

        // Apply extension filter
        if let ext = extensionFilter {
            result = result.filter { $0.fileExtension == ext }
        }

        // Apply search filter
        if !searchText.isEmpty {
            let search = searchText.lowercased()
            result = result.filter { $0.path.lowercased().contains(search) }
        }

        return result
    }

    private var filteredUnstagedFiles: [FileStatus] {
        applyFilters(viewModel.unstagedFiles)
    }

    private var filteredUntrackedFiles: [String] {
        var result = viewModel.untrackedFiles

        // Apply extension filter
        if let ext = extensionFilter {
            result = result.filter {
                URL(fileURLWithPath: $0).pathExtension.lowercased() == ext
            }
        }

        // Apply search filter
        if !searchText.isEmpty {
            let search = searchText.lowercased()
            result = result.filter { $0.lowercased().contains(search) }
        }

        return result
    }

    private var filteredStagedFiles: [FileStatus] {
        applyFilters(viewModel.stagedFiles)
    }

    // Paginated versions for display
    private var paginatedUnstagedFiles: [FileStatus] {
        Array(filteredUnstagedFiles.prefix(maxVisibleFiles))
    }

    private var paginatedUntrackedFiles: [String] {
        Array(filteredUntrackedFiles.prefix(maxVisibleFiles))
    }

    private var paginatedStagedFiles: [FileStatus] {
        Array(filteredStagedFiles.prefix(maxVisibleFiles))
    }

    private var hasMoreUnstagedFiles: Bool {
        filteredUnstagedFiles.count + filteredUntrackedFiles.count > maxVisibleFiles
    }

    private var hasMoreStagedFiles: Bool {
        filteredStagedFiles.count > maxVisibleFiles
    }
}

// MARK: - More Files Indicator

private struct MoreFilesIndicator: View {
    let count: Int
    let message: String

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "ellipsis.circle")
                .foregroundColor(AppTheme.warning)

            VStack(alignment: .leading, spacing: 2) {
                Text("+\(count) more files not shown")
                    .font(DesignTokens.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.warning)

                Text(message)
                    .font(DesignTokens.Typography.caption2)
                    .foregroundColor(AppTheme.textMuted)
            }

            Spacer()
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(AppTheme.warning.opacity(0.1))
        .cornerRadius(DesignTokens.CornerRadius.sm)
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
    }
}

// MARK: - Active Filter Tag

private struct ActiveFilterTag: View {
    let label: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(DesignTokens.Typography.caption2)
                .foregroundColor(AppTheme.accent)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(AppTheme.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(AppTheme.accent.opacity(0.15))
        .cornerRadius(DesignTokens.CornerRadius.sm)
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

    /// Discard a staged file completely (unstage + discard changes)
    func discardStagedFile(_ path: String) async {
        guard currentPath != nil, let gitService = gitService else { return }
        try? await gitService.discardStagedFile(path: path)
        await reloadStatus()
    }

    /// Discard all staged files completely (unstage + discard changes)
    func discardAllStaged() async {
        guard let gitService = gitService else { return }
        let allStaged = stagedFiles.map { $0.path }
        try? await gitService.discardStagedFiles(paths: allStaged)
        await reloadStatus()
    }

    private func reloadStatus() async {
        // Force refresh from git service first to get latest state
        if let gitService = gitService {
            try? await gitService.refresh()
        }

        // Then reload from appState's current repository
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
            let commit = try await gitService.commit(message: message, amend: amend)
            let shortSHA = String(commit.sha.prefix(7))
            commitError = nil
            showError = false

            // Force refresh the gitService first to update the repository
            try? await gitService.refresh()

            // Then reload our local status
            await reloadStatus()

            // Post notification to update other views (CommitGraph, etc.)
            if let path = currentPath {
                NotificationCenter.default.post(name: .repositoryDidRefresh, object: path)
            }

            // Show success notification with SHA
            let actionName = amend ? "Amend" : "Commit"
            NotificationManager.shared.success(
                "\(actionName) completed",
                detail: "SHA: \(shortSHA)"
            )

            return true
        } catch {
            NotificationManager.shared.error("Commit failed", detail: error.localizedDescription)
            return false
        }
    }

    func canCommit(message: String, amend: Bool = false) -> Bool {
        return validateCommit(message: message, amend: amend) == nil
    }
}

// MARK: - FileListSection moved to UI/Components/Layout/FileListSection.swift

// MARK: - FileRow moved to UI/Components/Rows/FileRow.swift

// MARK: - Subviews

// MARK: - Legacy button wrappers migrated to DS buttons
// These are deprecated - use DSIconButton directly instead

// MARK: - DiffStatsView moved to UI/Components/Diff/DiffStatsView.swift

// MARK: - Conflicted File Row

struct ConflictedFileRow: View {
    let file: FileStatus
    let isSelected: Bool
    var onSelect: () -> Void = {}
    var onResolve: () -> Void = {}

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // Conflict indicator
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(AppTheme.error)
                .frame(width: DesignTokens.Size.iconMD)

            // File icon
            Image(systemName: "doc.fill") // FileTypeIcon.systemIcon(for: file.filename))
                .foregroundColor(AppTheme.accent) // FileTypeIcon.color(for: file.filename))
                .frame(width: DesignTokens.Size.iconMD)

            // File path
            VStack(alignment: .leading, spacing: 0) {
                Text(file.filename)
                    .lineLimit(1)

                if !file.directory.isEmpty && file.directory != "." {
                    Text(file.directory)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(AppTheme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Resolve button
            DSButton(variant: .primary, size: .sm) {
                onResolve()
            } label: {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "wand.and.stars")
                    Text("Resolve")
                }
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
        .background(isSelected ? AppTheme.accent.opacity(0.2) : AppTheme.error.opacity(0.05))
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
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
    var repositoryPath: String = ""
    var onStage: (() -> Void)?
    var onUnstage: (() -> Void)?
    var onDiscard: (() -> Void)?
    var onDiscardStaged: (() -> Void)?
    var onPreview: (() -> Void)?

    var filename: String {
        URL(fileURLWithPath: filePath).lastPathComponent
    }

    var fileExtension: String {
        URL(fileURLWithPath: filePath).pathExtension
    }

    var directory: String {
        URL(fileURLWithPath: filePath).deletingLastPathComponent().path
    }

    var canPreviewFile: Bool {
        FilePreviewHelper.canPreview(filename: filePath)
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

                if let discardStaged = onDiscardStaged {
                    Divider()
                    
                    Button(role: .destructive) {
                        discardStaged()
                    } label: {
                        Label("Unstage & Revert", systemImage: "trash")
                    }
                }
            }

            Divider()

            // Preview and Copy Content (for text files)
            if canPreviewFile {
                Button {
                    onPreview?()
                } label: {
                    Label("Preview File", systemImage: "eye")
                }

                Button {
                    copyFileContent()
                } label: {
                    Label("Copy Content", systemImage: "doc.on.clipboard")
                }

                Divider()
            }

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
                    Label("Revert Changes", systemImage: "arrow.uturn.backward")
                }
            }

            Divider()

            // Ignore submenu (Modern)
            Menu {
                Button {
                    NotificationCenter.default.post(name: .ignoreFile, object: ["type": "file", "path": filePath])
                } label: {
                    Label("Ignore '\(filename)'", systemImage: "doc")
                }

                if !fileExtension.isEmpty {
                    Button {
                        NotificationCenter.default.post(name: .ignoreFile, object: ["type": "extension", "path": filePath, "extension": fileExtension])
                    } label: {
                        Label("Ignore all '.\(fileExtension)' files", systemImage: "doc.badge.ellipsis")
                    }
                }

                if !directory.isEmpty && directory != "." {
                    Button {
                        NotificationCenter.default.post(name: .ignoreFile, object: ["type": "directory", "path": filePath, "directory": directory])
                    } label: {
                        Label("Ignore directory '\(URL(fileURLWithPath: directory).lastPathComponent)/'", systemImage: "folder.badge.minus")
                    }
                }
            } label: {
                Label("Ignore", systemImage: "eye.slash")
            }

            Button {
                NotificationCenter.default.post(name: .assumeUnchanged, object: filePath)
            } label: {
                Label("Assume Unchanged", systemImage: "lock.doc")
            }

            Button {
                NotificationCenter.default.post(name: .stopTrackingFile, object: filePath)
            } label: {
                Label("Stop Tracking", systemImage: "xmark.bin")
            }
        }
    }

    private func copyFileContent() {
        let fullPath: String
        if filePath.hasPrefix("/") {
            fullPath = filePath
        } else if !repositoryPath.isEmpty {
            fullPath = (repositoryPath as NSString).appendingPathComponent(filePath)
        } else {
            fullPath = filePath
        }

        if let content = try? String(contentsOfFile: fullPath, encoding: .utf8) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(content, forType: .string)
        }
    }
}

struct UntrackedFileRow: View {
    let path: String
    let isSelected: Bool
    var namespace: Namespace.ID? = nil
    var onSelect: () -> Void = {}
    var onStage: (() -> Void)? = nil

    @State private var showDeleteConfirmation = false

    var filename: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    var directory: String {
        URL(fileURLWithPath: path).deletingLastPathComponent().path
    }

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            StatusIcon(status: .untracked)

            Image(systemName: "doc.fill")
                .foregroundColor(AppTheme.accent)
                .frame(width: DesignTokens.Size.iconMD)

            VStack(alignment: .leading, spacing: 0) {
                Text(filename)
                    .lineLimit(1)

                if !directory.isEmpty && directory != "." {
                    Text(directory)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(AppTheme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
        .background(isSelected ? AppTheme.accent.opacity(0.2) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
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
                showDeleteConfirmation = true
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
        .confirmationDialog(
            "Delete '\(filename)'?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                try? FileManager.default.removeItem(atPath: path)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This file will be permanently deleted. This action cannot be undone.")
        }
    }
}

// MARK: - StatusIcon moved to UI/Components/Icons/StatusIcon.swift

// MARK: - File Status Separator

struct FileStatusSeparator: View {
    let title: String
    let count: Int
    let color: Color


    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Rectangle()
                .fill(color)
                .frame(width: 3, height: DesignTokens.Size.iconSM)
                .cornerRadius(DesignTokens.CornerRadius.sm)

            Text(title)
                .font(DesignTokens.Typography.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)

            Text("(\(count))")
                .font(DesignTokens.Typography.caption2)
                .foregroundColor(AppTheme.textSecondary)

            Rectangle()
                .fill(color.opacity(0.3))
                .frame(height: 1)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
        .background(color.opacity(0.05))
    }
}

// MARK: - CommitMessageArea moved to UI/Components/Commit/CommitMessageArea.swift

struct DiffPreviewView: View {
    let path: String
    let staged: Bool
    var gitService: GitService?


    @State private var diff = ""
    @State private var hunks: [DiffHunk] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var scrollOffset: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "doc.fill") // FileTypeIcon.systemIcon(for: path))
                    .foregroundColor(AppTheme.accent) // FileTypeIcon.color(for: path))
                Text(path)
                    .fontWeight(.medium)
                Spacer()

                if staged {
                    Text("Staged")
                        .font(DesignTokens.Typography.caption)
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .padding(.vertical, DesignTokens.Spacing.xxs)
                        .background(AppTheme.success.opacity(0.2))
                        .foregroundColor(AppTheme.success)
                        .cornerRadius(DesignTokens.CornerRadius.sm)
                }
            }
            .padding()
            .background(AppTheme.backgroundSecondary)

            Divider()

            // Diff content
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                Text(error)
                    .foregroundColor(AppTheme.error)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if hunks.isEmpty {
                Text("No changes to display")
                    .foregroundColor(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Interactive hunk view
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
                    },
                    scrollOffset: $scrollOffset,
                    viewportHeight: $viewportHeight,
                    viewId: "StagingDiff"
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
        hunks = []
        let service = gitService ?? GitService()
        
        do {
            let diffString = try await service.getDiff(for: path, staged: staged)
            let diffs = await DiffParser.parseAsync(diffString)
            if let first = diffs.first {
                self.hunks = first.hunks
            }
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
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
    @State private var selectedStyle: CommitStyle? = .conventional

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Text("Generate Commit Message")
                .font(DesignTokens.Typography.title2)
                .fontWeight(.semibold)

            DSPicker(
                items: CommitStyle.allCases,
                selection: $selectedStyle
            ) { style in
                Text(style.description)
            }

            if isGenerating {
                ProgressView("Generating...")
                    .frame(maxHeight: .infinity)
            } else if !generatedMessage.isEmpty {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Generated Message:")
                        .font(DesignTokens.Typography.headline)

                    DSTextEditor(placeholder: "Generated commit message", text: $generatedMessage, minHeight: 100)
                }
            } else if let error = error {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: DesignTokens.Size.iconXL))
                        .foregroundColor(AppTheme.warning)
                    Text(error)
                        .foregroundColor(AppTheme.textSecondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                VStack {
                    Image(systemName: "sparkles")
                        .font(.system(size: DesignTokens.Size.iconXL))
                        .foregroundColor(AppTheme.accent)
                    Text("Click Generate to create a commit message")
                        .foregroundColor(AppTheme.textSecondary)
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
            generatedMessage = try await AIService.shared.generateCommitMessage(
                diff: diff,
                style: selectedStyle ?? .conventional
            )
        } catch {
            self.error = error.localizedDescription
        }

        isGenerating = false
    }
}

// MARK: - Flat Tree Item (for virtualized rendering)

struct FlatTreeItem: Identifiable {
    let id: String
    let name: String
    let path: String
    let isFolder: Bool
    let depth: Int  // Indentation level
    let fileCount: Int  // For folders
    let file: FileStatus?
    let isUntracked: Bool
    let hasChildren: Bool
}

// MARK: - File Tree View (Flattened for performance)

struct FileTreeView: View {
    let files: [FileStatus]
    let untrackedFiles: [String]
    let selectedFile: String?
    var isStaged: Bool = false
    var namespace: Namespace.ID? = nil

    // Selection callback
    var onSelect: ((String) -> Void)? = nil

    // Callbacks for unstaged files
    var onStage: ((String) -> Void)? = nil
    var onDiscard: ((String) -> Void)? = nil
    var onStageFolder: ((String) -> Void)? = nil

    // Callbacks for staged files
    var onUnstage: ((String) -> Void)? = nil
    var onUnstageFolder: ((String) -> Void)? = nil
    var onDiscardStaged: ((String) -> Void)? = nil

    // Section identifier for expansion state
    private var section: String {
        isStaged ? "staged" : "unstaged"
    }

    // Flattened tree for virtualized rendering
    @State private var flatItems: [FlatTreeItem] = []
    @State private var lastFileCount: Int = -1
    @State private var lastUntrackedCount: Int = -1
    @State private var expandedPaths: Set<String> = []
    @State private var refreshTrigger: Int = 0

    var body: some View {
        // Use ForEach with explicit id for stable identity during scroll
        ForEach(flatItems, id: \.id) { item in
            FlatTreeRowView(
                item: item,
                isSelected: selectedFile == item.path,
                isExpanded: expandedPaths.contains(item.path),
                isStaged: isStaged,
                onToggle: { toggleExpansion(item.path) },
                onSelect: { onSelect?(item.path) },
                onStage: onStage,
                onDiscard: onDiscard,
                onStageFolder: onStageFolder,
                onUnstage: onUnstage,
                onUnstageFolder: onUnstageFolder,
                onDiscardStaged: onDiscardStaged
            )
            .id(item.id)  // Stable identity for virtualization
        }
        .onAppear {
            loadExpandedState()
            rebuildFlatListIfNeeded()
        }
        .onChange(of: files.count) { _, _ in
            rebuildFlatListIfNeeded()
        }
        .onChange(of: untrackedFiles.count) { _, _ in
            rebuildFlatListIfNeeded()
        }
    }

    private func loadExpandedState() {
        // Load expansion state from TreeExpansionState
        expandedPaths = TreeExpansionState.shared.expandedPaths(for: section)
    }

    private func toggleExpansion(_ path: String) {
        if expandedPaths.contains(path) {
            expandedPaths.remove(path)
        } else {
            expandedPaths.insert(path)
        }
        TreeExpansionState.shared.setExpanded(path, section: section, expanded: expandedPaths.contains(path))
        rebuildFlatList()
    }

    private func rebuildFlatListIfNeeded() {
        let fileCount = files.count
        let untrackedCount = untrackedFiles.count

        guard fileCount != lastFileCount || untrackedCount != lastUntrackedCount else { return }

        lastFileCount = fileCount
        lastUntrackedCount = untrackedCount
        rebuildFlatList()
    }

    private func rebuildFlatList() {
        let root = FileTreeBuilder.buildTree(
            files: files,
            untrackedFiles: untrackedFiles,
            section: section
        )
        flatItems = flattenTree(root.children, depth: 0)
    }

    private func flattenTree(_ nodes: [FileTreeNode], depth: Int) -> [FlatTreeItem] {
        var result: [FlatTreeItem] = []
        for node in nodes {
            let item = FlatTreeItem(
                id: node.id,
                name: node.name,
                path: node.path,
                isFolder: node.isFolder,
                depth: depth,
                fileCount: node.cachedFileCount,
                file: node.file,
                isUntracked: node.isUntracked,
                hasChildren: !node.children.isEmpty
            )
            result.append(item)

            // Only add children if folder is expanded
            if node.isFolder && expandedPaths.contains(node.path) {
                result.append(contentsOf: flattenTree(node.children, depth: depth + 1))
            }
        }
        return result
    }
}

// MARK: - Flat Tree Row View (single row, no nesting)

struct FlatTreeRowView: View {
    let item: FlatTreeItem
    let isSelected: Bool
    let isExpanded: Bool
    let isStaged: Bool
    let onToggle: () -> Void
    let onSelect: () -> Void
    var onStage: ((String) -> Void)?
    var onDiscard: ((String) -> Void)?
    var onStageFolder: ((String) -> Void)?
    var onUnstage: ((String) -> Void)?
    var onUnstageFolder: ((String) -> Void)?
    var onDiscardStaged: ((String) -> Void)?

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            // Indentation
            if item.depth > 0 {
                Color.clear.frame(width: CGFloat(item.depth) * 16)
            }

            if item.isFolder {
                folderContent
            } else {
                fileContent
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(isSelected && !item.isFolder ? AppTheme.accent.opacity(0.2) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            if item.isFolder {
                onToggle()
            } else {
                onSelect()
            }
        }
        .contextMenu { contextMenuContent }
    }

    @ViewBuilder
    private var folderContent: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(DesignTokens.Typography.callout)
                .fontWeight(.bold)
                .foregroundColor(AppTheme.textSecondary.opacity(0.6))
                .frame(width: DesignTokens.Size.iconLG)

            Image(systemName: isExpanded ? "folder.fill" : "folder")
                .foregroundColor(AppTheme.warning)
                .frame(width: DesignTokens.Size.iconMD)

            Text(item.name)
                .lineLimit(1)

            Text("(\(item.fileCount))")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(AppTheme.textSecondary)

            Spacer()
        }
    }

    @ViewBuilder
    private var fileContent: some View {
        // Indent space for alignment with folder chevron
        Color.clear.frame(width: DesignTokens.Size.iconLG)

        // Status icon
        if let file = item.file {
            StatusIcon(status: file.status)
        } else if item.isUntracked {
            StatusIcon(status: .untracked)
        }

        // File icon
        Image(systemName: "doc.fill")
            .foregroundColor(AppTheme.accent)
            .frame(width: DesignTokens.Size.iconMD)

        // Filename
        Text(item.name)
            .lineLimit(1)

        Spacer()

        // Line change counters (don't show for deleted files)
        if let file = item.file, file.hasChanges, file.status != .deleted {
            DiffStatsView(additions: file.additions, deletions: file.deletions)
        }
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        if item.isFolder {
            if isStaged {
                Button { onUnstageFolder?(item.path) } label: {
                    Label("Unstage Folder", systemImage: "minus.circle")
                }
            } else {
                Button { onStageFolder?(item.path) } label: {
                    Label("Stage Folder", systemImage: "plus.circle")
                }
            }
        } else {
            if isStaged {
                Button { onUnstage?(item.path) } label: {
                    Label("Unstage File", systemImage: "minus.circle")
                }
                if onDiscardStaged != nil {
                    Divider()
                    Button(role: .destructive) { onDiscardStaged?(item.path) } label: {
                        Label("Unstage & Revert", systemImage: "trash")
                    }
                }
            } else {
                Button { onStage?(item.path) } label: {
                    Label("Stage File", systemImage: "plus.circle")
                }
                if !item.isUntracked, let discard = onDiscard {
                    Divider()
                    Button(role: .destructive) { discard(item.path) } label: {
                        Label("Revert Changes", systemImage: "arrow.uturn.backward")
                    }
                }
            }
        }

        Divider()

        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(item.path, forType: .string)
        } label: {
            Label("Copy Path", systemImage: "doc.on.doc")
        }
    }
}

// MARK: - Tree Builder (static for caching)

enum FileTreeBuilder {
    static func buildTree(files: [FileStatus], untrackedFiles: [String], section: String) -> FileTreeNode {
        var root = FileTreeNode(name: "", path: "", isFolder: true, section: section)

        // Add FileStatus files
        for file in files {
            addToTree(root: &root, path: file.path, file: file, isUntracked: false, section: section)
        }

        // Add untracked files
        for path in untrackedFiles {
            addToTree(root: &root, path: path, file: nil, isUntracked: true, section: section)
        }

        // Post-process: compute file counts and sort children (once, not during render)
        finalizeNode(&root)

        return root
    }

    /// Post-process to compute file counts and sort children
    private static func finalizeNode(_ node: inout FileTreeNode) {
        if node.isFolder {
            // First finalize all children
            for i in node.children.indices {
                finalizeNode(&node.children[i])
            }
            // Sort children: folders first, then alphabetically
            node.children.sort { a, b in
                if a.isFolder && !b.isFolder { return true }
                if !a.isFolder && b.isFolder { return false }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
            // Compute file count from children
            node.cachedFileCount = node.children.reduce(0) { $0 + $1.cachedFileCount }
        } else {
            node.cachedFileCount = 1
        }
    }

    private static func addToTree(root: inout FileTreeNode, path: String, file: FileStatus?, isUntracked: Bool, section: String) {
        let components = path.split(separator: "/").map(String.init)
        addToNode(node: &root, components: components, index: 0, file: file, isUntracked: isUntracked, section: section)
    }

    private static func addToNode(node: inout FileTreeNode, components: [String], index: Int, file: FileStatus?, isUntracked: Bool, section: String) {
        guard index < components.count else { return }

        let component = components[index]
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
            node.children.append(fileNode)
        } else {
            // This is a folder - find or create
            if let existingIndex = node.children.firstIndex(where: { $0.name == component && $0.isFolder }) {
                addToNode(node: &node.children[existingIndex], components: components, index: index + 1, file: file, isUntracked: isUntracked, section: section)
            } else {
                var folderNode = FileTreeNode(name: component, path: currentPath, isFolder: true, section: section)
                addToNode(node: &folderNode, components: components, index: index + 1, file: file, isUntracked: isUntracked, section: section)
                node.children.append(folderNode)
            }
        }
    }
}

// MARK: - TreeExpansionState moved to UI/Components/FileTree/TreeExpansionState.swift

// MARK: - Tree Node Model (struct for performance)

struct FileTreeNode: Identifiable {
    let id: String
    let name: String
    let path: String
    let isFolder: Bool
    let section: String
    var file: FileStatus?
    var isUntracked: Bool
    var children: [FileTreeNode] = []
    var cachedFileCount: Int = 0  // Pre-computed to avoid recursive calls during render

    init(name: String, path: String, isFolder: Bool, file: FileStatus? = nil, isUntracked: Bool = false, section: String = "") {
        self.name = name
        self.path = path
        self.isFolder = isFolder
        self.section = section
        self.file = file
        self.isUntracked = isUntracked
        self.id = section.isEmpty ? (path.isEmpty ? "root" : path) : "\(section):\(path.isEmpty ? "root" : path)"
        self.cachedFileCount = isFolder ? 0 : 1
    }
}

extension Notification.Name {
    static let ignoreFile = Notification.Name("ignoreFile")
    static let assumeUnchanged = Notification.Name("assumeUnchanged")
    static let stopTrackingFile = Notification.Name("stopTrackingFile")
}

// MARK: - File Preview View

struct FilePreviewView: View {
    let filePath: String
    let repositoryPath: String
    @State private var content: String = ""
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isLoading = true
    @State private var error: String?
    @State private var isBinary = false
    @State private var fileSize: Int64 = 0
    @State private var copyFeedback = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        VStack(spacing: 0) {
            // Header
            previewHeader(theme)

            Divider()

            // Content
            if isLoading {
                ProgressView("Loading file...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = error {
                previewErrorView(error)
            } else if isBinary {
                binaryFileView(theme)
            } else {
                textContentView
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .task {
            await loadFile()
        }
    }

    // MARK: - Header

    @ViewBuilder
    private func previewHeader(_ theme: Color.Theme) -> some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // File icon
            PreviewFileTypeIcon(filename: previewFilename)
                .frame(width: DesignTokens.Size.iconXL, height: DesignTokens.Size.iconXL)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(previewFilename)
                    .font(DesignTokens.Typography.subheadline)
                    .fontWeight(.semibold)

                Text(previewDirectory)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            // File info badges
            HStack(spacing: DesignTokens.Spacing.sm) {
                if fileSize > 0 {
                    Text(formatFileSize(fileSize))
                        .font(DesignTokens.Typography.caption2)
                        .padding(.horizontal, DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
                        .padding(.vertical, DesignTokens.Spacing.xxs)
                        .background(AppTheme.textSecondary.opacity(0.1))
                        .cornerRadius(DesignTokens.CornerRadius.sm)
                }

                Text(previewFileExtension.uppercased())
                    .font(DesignTokens.Typography.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
                    .padding(.vertical, DesignTokens.Spacing.xxs)
                    .background(languageColor.opacity(0.2))
                    .foregroundColor(languageColor)
                    .cornerRadius(DesignTokens.CornerRadius.sm)
            }

            // Actions
            HStack(spacing: DesignTokens.Spacing.xs) {
                // Copy button
                DSButton(variant: .outline, size: .sm, isDisabled: isBinary || content.isEmpty) {
                    copyPreviewContent()
                } label: {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        Image(systemName: copyFeedback ? "checkmark" : "doc.on.doc")
                        Text(copyFeedback ? "Copied!" : "Copy")
                    }
                }

                // Open in default app
                DSButton(variant: .outline, size: .sm) {
                    NSWorkspace.shared.open(URL(fileURLWithPath: fullPath))
                } label: {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        Image(systemName: "arrow.up.forward.app")
                        Text("Open")
                    }
                }

                // Reveal in Finder
                DSIconButton(iconName: "folder", variant: .outline, size: .sm) {
                    NSWorkspace.shared.selectFile(fullPath, inFileViewerRootedAtPath: "")
                }
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(AppTheme.backgroundSecondary)
    }

    // MARK: - Content Views

    private var textContentView: some View {
        ScrollView([.horizontal, .vertical]) {
            Text(content)
                .font(DesignTokens.Typography.callout)
                .monospaced()
                .textSelection(.enabled)
                .padding(DesignTokens.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(AppTheme.background)
    }

    @ViewBuilder
    private func binaryFileView(_ theme: Color.Theme) -> some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "doc.fill")
                .font(.system(size: DesignTokens.Size.iconXL))
                .foregroundColor(theme.textSecondary)

            Text("Binary File")
                .font(DesignTokens.Typography.headline)
                .fontWeight(.semibold)

            Text("This file cannot be previewed as text")
                .font(DesignTokens.Typography.body)
                .foregroundColor(theme.textSecondary)

            Button {
                NSWorkspace.shared.open(URL(fileURLWithPath: fullPath))
            } label: {
                Label("Open with Default App", systemImage: "arrow.up.forward.app")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func previewErrorView(_ message: String) -> some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: DesignTokens.Size.iconXL))
                .foregroundColor(AppTheme.warning)

            Text("Unable to load file")
                .font(DesignTokens.Typography.subheadline)
                .fontWeight(.medium)

            Text(message)
                .font(DesignTokens.Typography.callout)
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Computed Properties

    private var fullPath: String {
        if filePath.hasPrefix("/") {
            return filePath
        }
        return (repositoryPath as NSString).appendingPathComponent(filePath)
    }

    private var previewFilename: String {
        URL(fileURLWithPath: filePath).lastPathComponent
    }

    private var previewDirectory: String {
        URL(fileURLWithPath: filePath).deletingLastPathComponent().path
    }

    private var previewFileExtension: String {
        URL(fileURLWithPath: filePath).pathExtension.lowercased()
    }

    private var languageColor: Color {
        switch previewFileExtension {
        case "swift": return .orange
        case "sql": return .blue
        case "json": return .green
        case "xml", "html": return .purple
        case "css", "scss": return .pink
        case "js", "ts", "tsx", "jsx": return .yellow
        case "py": return .blue
        case "rb": return .red
        case "go": return .cyan
        case "rs": return .orange
        case "md", "txt": return .gray
        case "yml", "yaml": return .red
        case "sh", "bash", "zsh": return .green
        default: return .secondary
        }
    }

    // MARK: - Actions

    private func loadFile() async {
        isLoading = true

        let url = URL(fileURLWithPath: fullPath)

        // Check file size
        if let attrs = try? FileManager.default.attributesOfItem(atPath: fullPath),
           let size = attrs[.size] as? Int64 {
            fileSize = size

            // Limit preview to 5MB
            if size > 5_000_000 {
                error = "File is too large to preview (\(formatFileSize(size)))"
                isLoading = false
                return
            }
        }

        // Check if binary
        if FilePreviewHelper.isBinaryFile(at: fullPath) {
            isBinary = true
            isLoading = false
            return
        }

        // Load content
        do {
            content = try String(contentsOf: url, encoding: .utf8)
        } catch {
            // Try other encodings
            if let data = FileManager.default.contents(atPath: fullPath) {
                if let str = String(data: data, encoding: .isoLatin1) {
                    content = str
                } else if let str = String(data: data, encoding: .ascii) {
                    content = str
                } else {
                    self.error = "Unable to read file: unsupported encoding"
                }
            } else {
                self.self.error = error.localizedDescription
            }
        }

        isLoading = false
    }

    private func copyPreviewContent() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)

        withAnimation {
            copyFeedback = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                copyFeedback = false
            }
        }
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Preview File Type Icon

struct PreviewFileTypeIcon: View {
    let filename: String

    var body: some View {
        Image(systemName: iconName)
            .foregroundColor(iconColor)
    }

    private var previewFileExtension: String {
        URL(fileURLWithPath: filename).pathExtension.lowercased()
    }

    private var iconName: String {
        switch previewFileExtension {
        case "swift": return "swift"
        case "sql": return "cylinder.split.1x2"
        case "json": return "curlybraces"
        case "xml", "html": return "chevron.left.forwardslash.chevron.right"
        case "css", "scss": return "paintbrush"
        case "js", "ts", "tsx", "jsx": return "j.square"
        case "py": return "p.square"
        case "rb": return "r.square"
        case "go": return "g.square"
        case "md": return "doc.text"
        case "txt": return "doc.plaintext"
        case "yml", "yaml": return "list.bullet.indent"
        case "sh", "bash", "zsh": return "terminal"
        case "png", "jpg", "jpeg", "gif", "svg", "webp": return "photo"
        case "pdf": return "doc.richtext"
        case "zip", "tar", "gz", "rar": return "archivebox"
        case "mp3", "wav", "m4a": return "waveform"
        case "mp4", "mov", "avi": return "film"
        default: return "doc.fill"
        }
    }

    private var iconColor: Color {
        switch previewFileExtension {
        case "swift": return .orange
        case "sql": return .blue
        case "json": return .green
        case "xml", "html": return .purple
        case "css", "scss": return .pink
        case "js", "ts", "tsx", "jsx": return .yellow
        case "py": return .blue
        case "rb": return .red
        case "go": return .cyan
        case "md", "txt": return .gray
        case "yml", "yaml": return .red
        case "sh", "bash", "zsh": return .green
        case "png", "jpg", "jpeg", "gif", "svg", "webp": return .purple
        case "pdf": return .red
        default: return .blue
        }
    }
}

// MARK: - File Preview Helper

// MARK: - Create PR Sheet from Commit

/// Sheet to create a PR after commit + push flow
struct CreatePRSheetFromCommit: View {
    let commitSHA: String
    let onDismiss: () -> Void

    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = PRListViewModel()
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared

    @State private var title = ""
    @State private var prBody = ""
    @State private var baseBranch = ""  // Will be set from WorkspaceSettings
    @State private var isDraft = false
    @State private var isCreating = false
    @State private var isGenerating = false
    @State private var selectedReviewers: Set<String> = []
    @State private var selectedLabels: Set<String> = []
    @State private var availableReviewers: [GitHubUser] = []
    @State private var availableLabels: [GitHubLabel] = []

    private var headBranch: String {
        appState.currentRepository?.currentBranch?.name ?? ""
    }

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        return VStack(spacing: DesignTokens.Spacing.lg) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Create Pull Request")
                        .font(.title2)
                        .fontWeight(.semibold)

                    if !commitSHA.isEmpty {
                        Text("Commit: \(commitSHA)")
                            .font(.caption)
                            .foregroundColor(theme.textSecondary)
                    }
                }

                Spacer()

                // AI Generate Button
                Button {
                    Task { await generateTitleAndDescription() }
                } label: {
                    HStack(spacing: DesignTokens.Spacing.sm - 2) {
                        if isGenerating {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Generating...")
                        } else {
                            Image(systemName: "sparkles")
                                .foregroundColor(theme.accent)
                            Text("Generate with AI")
                        }
                    }
                    .font(.subheadline)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isGenerating || headBranch.isEmpty)
            }

            ScrollView {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    // Branch info (read-only)
                    HStack {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text("From").font(.caption).foregroundColor(theme.textSecondary)
                            Text(headBranch)
                                .padding(.horizontal, DesignTokens.Spacing.sm)
                                .padding(.vertical, DesignTokens.Spacing.xs)
                                .background(AppTheme.accent.opacity(0.15))
                                .cornerRadius(DesignTokens.CornerRadius.sm)
                        }

                        Image(systemName: "arrow.right")
                            .foregroundColor(theme.textSecondary)
                            .padding(.horizontal, DesignTokens.Spacing.sm)

                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text("To").font(.caption).foregroundColor(theme.textSecondary)
                            Text(baseBranch.isEmpty ? "Loading..." : baseBranch)
                                .padding(.horizontal, DesignTokens.Spacing.sm)
                                .padding(.vertical, DesignTokens.Spacing.xs)
                                .background(theme.success.opacity(0.15))
                                .cornerRadius(DesignTokens.CornerRadius.sm)
                        }
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(DesignTokens.CornerRadius.lg)

                    // Title
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("Title").font(.caption).foregroundColor(theme.textSecondary)
                        DSTextField(placeholder: "Enter PR title", text: $title)
                    }

                    // Description
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("Description").font(.caption).foregroundColor(theme.textSecondary)
                        DSTextEditor(
                            placeholder: "Enter PR description...",
                            text: $prBody,
                            minHeight: 120
                        )
                    }

                    // Reviewers
                    if !availableReviewers.isEmpty {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text("Reviewers (optional)").font(.caption).foregroundColor(theme.textSecondary)
                            FlowLayout(spacing: DesignTokens.Spacing.sm - 2) {
                                ForEach(availableReviewers.prefix(10), id: \.id) { user in
                                    Button {
                                        toggleSelection(user.login, in: &selectedReviewers)
                                    } label: {
                                        HStack(spacing: DesignTokens.Spacing.xs) {
                                            AsyncImage(url: URL(string: user.avatarUrl)) { image in
                                                image.resizable()
                                            } placeholder: {
                                                Image(systemName: "person.circle.fill")
                                                    .foregroundColor(theme.textSecondary)
                                            }
                                            .frame(width: DesignTokens.Size.avatarXS, height: DesignTokens.Size.avatarXS)
                                            .clipShape(Circle())

                                            Text(user.login)
                                                .font(.caption)
                                        }
                                        .padding(.horizontal, DesignTokens.Spacing.sm)
                                        .padding(.vertical, DesignTokens.Spacing.xs)
                                        .background(selectedReviewers.contains(user.login) ? AppTheme.accent : theme.textMuted.opacity(0.2))
                                        .foregroundColor(selectedReviewers.contains(user.login) ? .white : .primary)
                                        .cornerRadius(DesignTokens.CornerRadius.xl)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Labels
                    if !availableLabels.isEmpty {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text("Labels (optional)").font(.caption).foregroundColor(theme.textSecondary)
                            FlowLayout(spacing: DesignTokens.Spacing.sm - 2) {
                                ForEach(availableLabels.prefix(15), id: \.id) { label in
                                    Button {
                                        toggleSelection(label.name, in: &selectedLabels)
                                    } label: {
                                        Text(label.name)
                                            .font(.caption)
                                            .padding(.horizontal, DesignTokens.Spacing.sm)
                                            .padding(.vertical, DesignTokens.Spacing.xs)
                                            .background(selectedLabels.contains(label.name) ? theme.info : theme.textMuted.opacity(0.2))
                                            .foregroundColor(selectedLabels.contains(label.name) ? .white : .primary)
                                            .cornerRadius(DesignTokens.CornerRadius.xl)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Options
                    Toggle("Create as draft", isOn: $isDraft)
                        .padding(.vertical, DesignTokens.Spacing.sm)
                }
                .padding(.horizontal)
            }

            // Actions
            HStack {
                Button("Cancel") {
                    onDismiss()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    Task {
                        await createPullRequest()
                    }
                } label: {
                    if isCreating {
                        HStack(spacing: DesignTokens.Spacing.xs) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Creating...")
                        }
                    } else {
                        Text("Create Pull Request")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.isEmpty || headBranch.isEmpty || isCreating || isGenerating)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 650, height: 600)
        .task {
            await loadMetadata()
        }
    }

    // MARK: - Actions

    private func generateTitleAndDescription() async {
        isGenerating = true
        do {
            // Use origin/baseBranch to compare against remote (works even if local branch doesn't exist)
            let remoteBase = "origin/\(baseBranch)"
            let diff = try await appState.gitService.getDiff(from: remoteBase, to: headBranch)
            let commits = try await appState.gitService.getCommits(branch: headBranch, limit: 20)

            // Generate both in parallel
            async let generatedTitle = AIService.shared.generatePRTitle(commits: commits, diff: diff)
            async let generatedDescription = AIService.shared.generatePRDescription(diff: diff, commits: commits, template: nil)

            title = try await generatedTitle
            prBody = try await generatedDescription
        } catch {
            print("Failed to generate PR content: \(error)")
            NotificationManager.shared.error("AI Generation Failed", detail: error.localizedDescription)
        }
        isGenerating = false
    }

    private func createPullRequest() async {
        isCreating = true

        await viewModel.createPRWithMetadata(
            title: title,
            body: prBody,
            head: headBranch,
            base: baseBranch,
            draft: isDraft,
            reviewers: Array(selectedReviewers),
            assignees: [],
            labels: Array(selectedLabels)
        )

        isCreating = false
        onDismiss()
        dismiss()
    }

    private func loadMetadata() async {
        guard let repo = appState.currentRepository,
              let remote = repo.remotes.first(where: { $0.isGitHub }),
              let ownerRepo = remote.ownerAndRepo else { return }

        // Set base branch from WorkspaceSettings
        baseBranch = WorkspaceSettingsManager.shared.getMainBranch(for: repo.path)

        // Configure viewModel
        viewModel.owner = ownerRepo.owner
        viewModel.repo = ownerRepo.repo

        // Load collaborators
        do {
            let githubService = GitHubService()
            availableReviewers = try await githubService.getCollaborators(
                owner: ownerRepo.owner,
                repo: ownerRepo.repo
            )
        } catch {
            print("Failed to load collaborators: \(error)")
        }

        // Load labels
        do {
            let githubService = GitHubService()
            availableLabels = try await githubService.getLabels(
                owner: ownerRepo.owner,
                repo: ownerRepo.repo
            )
        } catch {
            print("Failed to load labels: \(error)")
        }
    }

    private func toggleSelection(_ item: String, in set: inout Set<String>) {
        if set.contains(item) {
            set.remove(item)
        } else {
            set.insert(item)
        }
    }
}

// MARK: - File Preview Helper

enum FilePreviewHelper {
    // Common text file extensions
    static let textExtensions: Set<String> = [
        "txt", "md", "markdown", "rst", "rtf",
        "sql", "json", "xml", "html", "htm", "css", "scss", "sass", "less",
        "js", "jsx", "ts", "tsx", "mjs", "cjs",
        "py", "pyw", "pyi", "rb", "rake", "gemspec",
        "swift", "m", "mm", "h", "c", "cpp", "cc", "cxx", "hpp",
        "java", "kt", "kts", "scala", "groovy",
        "go", "rs", "zig", "nim",
        "php", "phtml", "twig", "blade",
        "sh", "bash", "zsh", "fish", "ps1", "bat", "cmd",
        "yml", "yaml", "toml", "ini", "cfg", "conf", "config",
        "env", "envrc", "editorconfig", "gitignore", "gitattributes",
        "dockerfile", "makefile", "cmake", "gradle",
        "csv", "tsv", "log", "diff", "patch", "vue"
    ]

    // Binary file extensions
    static let binaryExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "bmp", "ico", "icns", "webp", "tiff", "tif", "svg",
        "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx",
        "zip", "tar", "gz", "bz2", "xz", "7z", "rar",
        "exe", "dll", "so", "dylib", "a", "o", "obj",
        "mp3", "wav", "m4a", "flac", "aac", "ogg",
        "mp4", "mov", "avi", "mkv", "webm",
        "ttf", "otf", "woff", "woff2", "eot",
        "sqlite", "db", "mdb",
        "class", "jar", "war",
        "pyc", "pyo", "beam",
        "wasm"
    ]

    static func isBinaryFile(at path: String) -> Bool {
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()

        // Check known extensions first
        if textExtensions.contains(ext) {
            return false
        }
        if binaryExtensions.contains(ext) {
            return true
        }

        // Check file content for binary bytes
        guard let fileHandle = FileHandle(forReadingAtPath: path) else {
            return false
        }
        defer { try? fileHandle.close() }

        // Read first 8KB to check for binary content
        let data = fileHandle.readData(ofLength: 8192)

        // Check for null bytes (common indicator of binary files)
        if data.contains(0x00) {
            return true
        }

        // Check for high ratio of non-printable characters
        let nonPrintableCount = data.filter { byte in
            // Allow common text bytes: tab, newline, carriage return, and printable ASCII
            byte != 0x09 && byte != 0x0A && byte != 0x0D && (byte < 0x20 || byte > 0x7E)
        }.count

        let ratio = Double(nonPrintableCount) / Double(max(data.count, 1))
        return ratio > 0.3
    }

    static func canPreview(filename: String) -> Bool {
        let ext = URL(fileURLWithPath: filename).pathExtension.lowercased()
        return textExtensions.contains(ext)
    }
}


