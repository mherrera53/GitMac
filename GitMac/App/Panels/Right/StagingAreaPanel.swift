import SwiftUI

// MARK: - Staging Area Panel (when no commit selected)
struct StagingAreaPanel: View {
    @ObservedObject var stagingVM: StagingViewModel
    @Binding var selectedFileDiff: FileDiff?
    @Binding var isLoadingDiff: Bool
    @Binding var commitMessage: String
    @Binding var selectedStagingFile: StagingFile?
    @EnvironmentObject var appState: AppState
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var viewMode: StagingViewMode = .tree
    @State private var extensionFilter: String? = nil
    @State private var showCreatePRSheet = false
    @State private var commitSHAForPR: String = ""
    @State private var isAmending = false

    // Confirmation state for destructive actions
    @State private var fileToDiscard: StagingFile?
    @State private var fileToDelete: StagingFile?
    @State private var showDiscardAllConfirm = false
    @State private var showDeleteAllUntrackedConfirm = false
    @State private var folderToDiscard: String?
    @State private var folderToDelete: String?

    // Diff options (persisted)
    @AppStorage("diffIgnoreWhitespace") private var ignoreWhitespace = false
    @AppStorage("diffContextLines") private var contextLines = 3

    // Resizable split ratio for Unstaged/Staged sections (persisted)
    @AppStorage("stagingSplitRatio") private var stagingSplitRatio: Double = 0.5

    // Cached computed values — recomputed only when staging files or filter change, not every body call
    @State private var cachedAvailableExtensions: [String] = []
    @State private var cachedExtensionCounts: [String: Int] = [:]
    @State private var cachedFilteredUnstaged: [StagingFile] = []
    @State private var cachedFilteredStaged: [StagingFile] = []

    private func recomputeCachedValues() {
        let allFiles = stagingVM.unstagedFiles + stagingVM.stagedFiles
        var exts = Set<String>()
        var counts = [String: Int]()
        for file in allFiles {
            let ext = (file.path as NSString).pathExtension.lowercased()
            if !ext.isEmpty {
                exts.insert(ext)
                counts[ext, default: 0] += 1
            }
        }
        cachedAvailableExtensions = exts.sorted()
        cachedExtensionCounts = counts

        if let ext = extensionFilter {
            cachedFilteredUnstaged = stagingVM.unstagedFiles.filter {
                ($0.path as NSString).pathExtension.lowercased() == ext
            }
            cachedFilteredStaged = stagingVM.stagedFiles.filter {
                ($0.path as NSString).pathExtension.lowercased() == ext
            }
        } else {
            cachedFilteredUnstaged = stagingVM.unstagedFiles
            cachedFilteredStaged = stagingVM.stagedFiles
        }
    }

    var body: some View {
        mainContent
            .modifier(fileAlerts)
            .modifier(bulkAlerts)
            .modifier(folderAlerts)
    }

    private var isWorkingDirectoryClean: Bool {
        stagingVM.unstagedFiles.isEmpty && stagingVM.stagedFiles.isEmpty
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            if isWorkingDirectoryClean {
                stagingToolbar

                Spacer()
                DSEmptyState(
                    icon: "checkmark.circle",
                    title: "Working Directory Clean",
                    description: "No pending changes. Your working tree is up to date."
                )
                Spacer()
            } else {
                stagingToolbar

                // Resizable split between Unstaged and Staged sections
                GeometryReader { geometry in
                    let availableHeight = geometry.size.height
                    let minSectionHeight: CGFloat = 80
                    let unstagedHeight = max(minSectionHeight, min(availableHeight - minSectionHeight, availableHeight * stagingSplitRatio))

                    VStack(spacing: 0) {
                        // Unstaged Files section
                        StagingSectionWithTree(
                            title: "Unstaged Files",
                            count: cachedFilteredUnstaged.count,
                            totalCount: stagingVM.totalUnstagedCount,
                            actionIcon: "plus.circle.fill",
                            actionColor: AppTheme.success,
                            onAction: { stagingVM.stageAll() },
                            viewMode: viewMode,
                            files: stagingVM.unstagedFiles,
                            isStaged: false,
                            selectedFilePath: selectedFileDiff?.newPath,
                            extensionFilter: extensionFilter,
                            onSelect: loadDiff,
                            onStage: { stagingVM.stage(file: $0) },
                            onStageFolder: { stagingVM.stageFolder($0) },
                            onDiscard: { fileToDiscard = $0 },
                            onDelete: { fileToDelete = $0 },
                            onDiscardFolder: { folderToDiscard = $0 },
                            onDeleteFolder: { folderToDelete = $0 },
                            hasMore: stagingVM.hasMoreUnstaged,
                            onLoadMore: { stagingVM.loadMoreUnstaged() }
                        )
                        .frame(height: unstagedHeight)

                        // Large repo warning
                        if stagingVM.isLargeRepo {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(AppTheme.warning)
                                Text("Large repo: \(stagingVM.totalUnstagedCount + stagingVM.totalStagedCount) files. Consider using .gitignore")
                                    .font(.system(size: 10))
                                    .foregroundStyle(AppTheme.textSecondary)
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AppTheme.warning.opacity(0.1))
                        }

                        // Resizable divider
                        StagingSplitResizer(
                            splitRatio: $stagingSplitRatio,
                            availableHeight: availableHeight,
                            minSectionHeight: minSectionHeight
                        )

                        // Staged Files section
                        StagingSectionWithTree(
                            title: "Staged Files",
                            count: cachedFilteredStaged.count,
                            totalCount: stagingVM.totalStagedCount,
                            actionIcon: "minus.circle.fill",
                            actionColor: AppTheme.error,
                            onAction: { stagingVM.unstageAll() },
                            viewMode: viewMode,
                            files: stagingVM.stagedFiles,
                            isStaged: true,
                            selectedFilePath: selectedFileDiff?.newPath,
                            extensionFilter: extensionFilter,
                            onSelect: loadDiff,
                            onStage: { stagingVM.unstage(file: $0) },
                            onStageFolder: { stagingVM.unstageFolder($0) },
                            hasMore: stagingVM.hasMoreStaged,
                            onLoadMore: { stagingVM.loadMoreStaged() }
                        )
                    }
                }
            }

            CommitSection(
                commitMessage: $commitMessage,
                canCommit: !stagingVM.stagedFiles.isEmpty,
                repositoryPath: appState.currentRepository?.path,
                onCommit: {
                    stagingVM.commit(message: commitMessage, amend: isAmending) {
                        commitMessage = ""
                        isAmending = false
                    }
                },
                onCommitPushPR: {
                    Task {
                        await commitPushAndOpenPR()
                    }
                },
                isAmending: $isAmending
            )
        }
        .onAppear { recomputeCachedValues() }
        .onChange(of: stagingVM.unstagedFiles.count) { recomputeCachedValues() }
        .onChange(of: stagingVM.stagedFiles.count) { recomputeCachedValues() }
        .onChange(of: extensionFilter) { recomputeCachedValues() }
        .sheet(isPresented: $showCreatePRSheet) {
            if let repoPath = appState.currentRepository?.path {
                CreatePRSheetFromCommit(
                    commitSHA: commitSHAForPR,
                    repoPath: repoPath,
                    onDismiss: { showCreatePRSheet = false }
                )
                .environmentObject(appState)
            }
        }
    }

    // MARK: - File-level Alerts

    private var fileAlerts: StagingFileAlerts {
        StagingFileAlerts(
            fileToDiscard: $fileToDiscard,
            fileToDelete: $fileToDelete,
            stagingVM: stagingVM
        )
    }

    // MARK: - Bulk Alerts

    private var bulkAlerts: StagingBulkAlerts {
        StagingBulkAlerts(
            showDiscardAllConfirm: $showDiscardAllConfirm,
            showDeleteAllUntrackedConfirm: $showDeleteAllUntrackedConfirm,
            stagingVM: stagingVM
        )
    }

    // MARK: - Folder Alerts

    private var folderAlerts: StagingFolderAlerts {
        StagingFolderAlerts(
            folderToDiscard: $folderToDiscard,
            folderToDelete: $folderToDelete,
            stagingVM: stagingVM
        )
    }

    // MARK: - Commit + Push + PR Flow

    @MainActor
    private func commitPushAndOpenPR() async {
        // Capture values on MainActor before any async work
        guard let repoPath = appState.currentRepository?.path else {
            NotificationManager.shared.error("No repository", detail: "No repository selected")
            return
        }

        // Capture branch manager and current branch early
        let manager = appState.branchManager
        guard let currentBranch = manager?.currentBranch ?? appState.currentRepository?.currentBranch else {
            NotificationManager.shared.error("Push failed", detail: "No current branch")
            return
        }
        let branchName = currentBranch.name

        // Step 1: Commit
        let commitSuccess = await stagingVM.commitAsync(message: commitMessage)
        guard commitSuccess else {
            return // Commit failed, error already shown
        }

        // Clear commit message (safe - we're on MainActor)
        commitMessage = ""

        // Step 2: Push using branchManager for consistent state
        do {
            let engine = GitEngine()

            // Use branchManager.push() if available for state sync
            if let manager = manager {
                try await manager.push(currentBranch)
            } else {
                // Fallback to direct engine call
                var options = PushOptions()
                options.setUpstream = true
                options.branch = branchName
                try await engine.push(options: options, at: repoPath)
            }

            // Get SHA after push
            let sha = try await engine.getHeadSHA(at: repoPath)
            let shortSHA = String(sha.prefix(7))

            // Step 3: Open PR sheet (safe - we're on MainActor)
            commitSHAForPR = shortSHA
            showCreatePRSheet = true

        } catch {
            NotificationManager.shared.error(
                "Push failed",
                detail: error.localizedDescription
            )
        }
    }

    private var stagingToolbar: some View {
        let theme = Color.Theme(self.themeManager.colors)
        return HStack(spacing: 6) {
            // View mode toggle with custom buttons
            HStack(spacing: 1) {
                Button(action: { viewMode = .flat }) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 11))
                        .foregroundStyle(viewMode == .flat ? theme.accent : theme.text)
                        .frame(width: 24, height: 20)
                        .background(viewMode == .flat ? theme.accent.opacity(0.15) : Color.clear)
                        .clipShape(.rect(cornerRadius: DesignTokens.CornerRadius.sm))
                }
                .buttonStyle(.plain)
                .help("List View")

                Button(action: { viewMode = .tree }) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(viewMode == .tree ? theme.accent : theme.text)
                        .frame(width: 24, height: 20)
                        .background(viewMode == .tree ? theme.accent.opacity(0.15) : Color.clear)
                        .clipShape(.rect(cornerRadius: DesignTokens.CornerRadius.sm))
                }
                .buttonStyle(.plain)
                .help("Tree View")
            }
            .padding(2)
            .background(theme.backgroundTertiary)
            .clipShape(.rect(cornerRadius: DesignTokens.CornerRadius.md))

            // Extension filter
            HStack(spacing: 3) {
                Menu {
                    Button("All Files") { extensionFilter = nil }
                    if !cachedAvailableExtensions.isEmpty {
                        Divider()
                        ForEach(cachedAvailableExtensions, id: \.self) { ext in
                            Button {
                                extensionFilter = ext
                            } label: {
                                HStack {
                                    Text(".\(ext)")
                                    Spacer()
                                    Text("\(cachedExtensionCounts[ext] ?? 0)")
                                        .foregroundStyle(theme.textSecondary)
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 11))
                }
                .tint(extensionFilter != nil ? theme.accent : theme.textSecondary)
                .menuStyle(.borderlessButton)
                .fixedSize()

                Text(extensionFilter.map { ".\($0)" } ?? "All")
                    .font(.system(size: 10))
                    .foregroundStyle(extensionFilter != nil ? theme.accent : theme.text)
                    .lineLimit(1)
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(extensionFilter != nil ? theme.accent.opacity(0.15) : theme.backgroundTertiary)
            .clipShape(.rect(cornerRadius: DesignTokens.CornerRadius.sm))

            Spacer(minLength: 2)

            // Bulk destructive actions
            if stagingVM.unstagedFiles.contains(where: { $0.status == .untracked }) {
                Button {
                    showDeleteAllUntrackedConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textMuted)
                }
                .buttonStyle(.plain)
                .help("Delete All Untracked Files")
            }

            if stagingVM.unstagedFiles.contains(where: { $0.status != .untracked }) {
                Button {
                    showDiscardAllConfirm = true
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textMuted)
                }
                .buttonStyle(.plain)
                .help("Revert All Changes")
            }

            Text("\(stagingVM.unstagedFiles.count + stagingVM.stagedFiles.count)")
                .font(.system(size: 10))
                .foregroundStyle(theme.textMuted)
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(.ultraThinMaterial)
    }

    // availableExtensions, fileCountForExtension, filteredUnstagedFiles, filteredStagedFiles
    // are now cached in @State properties above (cachedAvailableExtensions, etc.)

    private func loadDiff(for file: StagingFile) {
        guard let path = appState.currentRepository?.path else { return }

        // Track the selected staging file for hunk actions
        selectedStagingFile = file

        // Don't clear selectedFileDiff if we're reloading the same file
        // This prevents the need for double-clicking
        if selectedFileDiff?.newPath != file.path {
            isLoadingDiff = true
            selectedFileDiff = nil
        }

        Task {
            if let diff = await stagingVM.getDiff(for: file, at: path, contextLines: contextLines, ignoreWhitespace: ignoreWhitespace) {
                selectedFileDiff = diff
            }
            isLoadingDiff = false
        }
    }
}

// MARK: - Alert ViewModifiers (broken out for type-checker)

struct StagingFileAlerts: ViewModifier {
    @Binding var fileToDiscard: StagingFile?
    @Binding var fileToDelete: StagingFile?
    let stagingVM: StagingViewModel

    func body(content: Content) -> some View {
        content
            .alert("Revert Changes?",
                   isPresented: Binding(get: { fileToDiscard != nil }, set: { if !$0 { fileToDiscard = nil } })) {
                Button("Revert", role: .destructive) {
                    if let file = fileToDiscard { stagingVM.discard(file: file) }
                    fileToDiscard = nil
                }
                Button("Cancel", role: .cancel) { fileToDiscard = nil }
            } message: {
                Text("This will permanently discard changes to \"\(fileToDiscard?.path ?? "")\".")
            }
            .alert("Delete File?",
                   isPresented: Binding(get: { fileToDelete != nil }, set: { if !$0 { fileToDelete = nil } })) {
                Button("Delete", role: .destructive) {
                    if let file = fileToDelete { stagingVM.deleteFile(file) }
                    fileToDelete = nil
                }
                Button("Cancel", role: .cancel) { fileToDelete = nil }
            } message: {
                Text("This will permanently delete \"\(fileToDelete?.path ?? "")\" from disk.")
            }
    }
}

struct StagingBulkAlerts: ViewModifier {
    @Binding var showDiscardAllConfirm: Bool
    @Binding var showDeleteAllUntrackedConfirm: Bool
    let stagingVM: StagingViewModel

    func body(content: Content) -> some View {
        content
            .alert("Revert All Changes?", isPresented: $showDiscardAllConfirm) {
                Button("Revert All", role: .destructive) { stagingVM.discardAll() }
                Button("Cancel", role: .cancel) {}
            } message: {
                let count = stagingVM.unstagedFiles.filter { $0.status != .untracked }.count
                Text("This will permanently discard changes to \(count) tracked file(s).")
            }
            .alert("Delete All Untracked Files?", isPresented: $showDeleteAllUntrackedConfirm) {
                Button("Delete All", role: .destructive) { stagingVM.deleteAllUntracked() }
                Button("Cancel", role: .cancel) {}
            } message: {
                let count = stagingVM.unstagedFiles.filter { $0.status == .untracked }.count
                Text("This will permanently delete \(count) untracked file(s) from disk.")
            }
    }
}

struct StagingFolderAlerts: ViewModifier {
    @Binding var folderToDiscard: String?
    @Binding var folderToDelete: String?
    let stagingVM: StagingViewModel

    func body(content: Content) -> some View {
        content
            .alert("Revert Folder Changes?",
                   isPresented: Binding(get: { folderToDiscard != nil }, set: { if !$0 { folderToDiscard = nil } })) {
                Button("Revert", role: .destructive) {
                    if let folder = folderToDiscard { stagingVM.discardFolder(folder) }
                    folderToDiscard = nil
                }
                Button("Cancel", role: .cancel) { folderToDiscard = nil }
            } message: {
                let folder = folderToDiscard ?? ""
                let count = stagingVM.unstagedFiles.filter {
                    $0.status != .untracked && ($0.path.hasPrefix(folder + "/") || $0.path == folder)
                }.count
                Text("This will permanently discard changes to \(count) file(s) in \"\(folder)\".")
            }
            .alert("Delete Untracked in Folder?",
                   isPresented: Binding(get: { folderToDelete != nil }, set: { if !$0 { folderToDelete = nil } })) {
                Button("Delete", role: .destructive) {
                    if let folder = folderToDelete { stagingVM.deleteUntrackedInFolder(folder) }
                    folderToDelete = nil
                }
                Button("Cancel", role: .cancel) { folderToDelete = nil }
            } message: {
                let folder = folderToDelete ?? ""
                let count = stagingVM.unstagedFiles.filter {
                    $0.status == .untracked && ($0.path.hasPrefix(folder + "/") || $0.path == folder)
                }.count
                Text("This will permanently delete \(count) untracked file(s) in \"\(folder)\" from disk.")
            }
    }
}

// MARK: - Staging Split Resizer

/// Draggable divider between Unstaged and Staged sections
struct StagingSplitResizer: View {
    @Binding var splitRatio: Double
    let availableHeight: CGFloat
    let minSectionHeight: CGFloat

    @State private var isHovering = false
    @State private var isDragging = false
    @State private var dragStartRatio: Double = 0

    var body: some View {
        ZStack {
            // Hit area for dragging
            Rectangle()
                .fill(Color.clear)
                .frame(height: 8)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if !isDragging {
                                // Store initial ratio at drag start
                                dragStartRatio = splitRatio
                                isDragging = true
                            }
                            // Calculate new ratio from start position + translation
                            let deltaRatio = value.translation.height / availableHeight
                            let newRatio = dragStartRatio + deltaRatio

                            // Clamp to ensure min heights
                            let minRatio = minSectionHeight / availableHeight
                            let maxRatio = 1.0 - minRatio
                            splitRatio = min(maxRatio, max(minRatio, newRatio))
                        }
                        .onEnded { _ in
                            isDragging = false
                            updateCursor()
                        }
                )
                .onHover { hovering in
                    isHovering = hovering
                    updateCursor()
                }

            // Visual divider line
            Rectangle()
                .fill(visualColor)
                .frame(height: 1)
                .allowsHitTesting(false)
        }
        .frame(height: 8)
    }

    private func updateCursor() {
        if isHovering || isDragging {
            NSCursor.resizeUpDown.set()
        } else {
            NSCursor.arrow.set()
        }
    }

    private var visualColor: Color {
        if isDragging {
            return AppTheme.accent
        } else if isHovering {
            return AppTheme.border.opacity(0.8)
        } else {
            return AppTheme.border
        }
    }
}
