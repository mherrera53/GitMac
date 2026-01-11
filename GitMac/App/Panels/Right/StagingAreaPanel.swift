import SwiftUI

// MARK: - Staging Area Panel (when no commit selected)
struct StagingAreaPanel: View {
    @ObservedObject var stagingVM: StagingViewModel
    @Binding var selectedFileDiff: FileDiff?
    @Binding var isLoadingDiff: Bool
    @Binding var commitMessage: String
    @EnvironmentObject var appState: AppState
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var viewMode: StagingViewMode = .tree
    @State private var extensionFilter: String? = nil
    @State private var showCreatePRSheet = false
    @State private var commitSHAForPR: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar with view mode and filter
            stagingToolbar

            // Unstaged Files
            StagingSectionWithTree(
                title: "Unstaged Files",
                count: filteredUnstagedFiles.count,
                actionIcon: "plus.circle.fill",
                actionColor: AppTheme.success,
                onAction: { stagingVM.stageAll() },
                viewMode: viewMode,
                files: stagingVM.unstagedFiles,  // Pass ALL files
                isStaged: false,
                selectedFilePath: selectedFileDiff?.newPath,
                extensionFilter: extensionFilter,  // Pass filter separately
                onSelect: loadDiff,
                onStage: { stagingVM.stage(file: $0) },
                onStageFolder: { stagingVM.stageFolder($0) },
                onDiscard: { stagingVM.discard(file: $0) },
                onDelete: { stagingVM.deleteFile($0) }
            )

            Rectangle().fill(AppTheme.border).frame(height: 1)

            // Staged Files
            StagingSectionWithTree(
                title: "Staged Files",
                count: filteredStagedFiles.count,
                actionIcon: "minus.circle.fill",
                actionColor: AppTheme.error,
                onAction: { stagingVM.unstageAll() },
                viewMode: viewMode,
                files: stagingVM.stagedFiles,  // Pass ALL files
                isStaged: true,
                selectedFilePath: selectedFileDiff?.newPath,
                extensionFilter: extensionFilter,  // Pass filter separately
                onSelect: loadDiff,
                onStage: { stagingVM.unstage(file: $0) },
                onStageFolder: { stagingVM.unstageFolder($0) }
            )

            Spacer()

            // Commit Section
            CommitSection(
                commitMessage: $commitMessage,
                canCommit: !stagingVM.stagedFiles.isEmpty,
                repositoryPath: appState.currentRepository?.path,
                onCommit: { stagingVM.commit(message: commitMessage) { commitMessage = "" } },
                onCommitPushPR: {
                    Task {
                        await commitPushAndOpenPR()
                    }
                }
            )
        }
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

    // MARK: - Commit + Push + PR Flow

    private func commitPushAndOpenPR() async {
        // Step 1: Commit
        let commitSuccess = await stagingVM.commitAsync(message: commitMessage)
        guard commitSuccess else {
            return // Commit failed, error already shown
        }

        // Clear commit message
        commitMessage = ""

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

    private var stagingToolbar: some View {
        let theme = Color.Theme(self.themeManager.colors)
        return HStack(spacing: 8) {
            // View mode toggle with custom buttons
            HStack(spacing: 2) {
                Button(action: { viewMode = .flat }) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 12))
                        .foregroundColor(viewMode == .flat ? theme.accent : theme.text)
                        .frame(width: 28, height: 22)
                        .background(viewMode == .flat ? theme.accent.opacity(0.15) : Color.clear)
                        .cornerRadius(DesignTokens.CornerRadius.sm)
                }
                .buttonStyle(.plain)
                .help("List View")

                Button(action: { viewMode = .tree }) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 12))
                        .foregroundColor(viewMode == .tree ? theme.accent : theme.text)
                        .frame(width: 28, height: 22)
                        .background(viewMode == .tree ? theme.accent.opacity(0.15) : Color.clear)
                        .cornerRadius(DesignTokens.CornerRadius.sm)
                }
                .buttonStyle(.plain)
                .help("Tree View")
            }
            .padding(2)
            .background(theme.backgroundTertiary)
            .cornerRadius(DesignTokens.CornerRadius.md)

            // Extension filter - Separado: Menu (icono) + Text
            HStack(spacing: 4) {
                Menu {
                    Button("All Files") { extensionFilter = nil }
                    if !availableExtensions.isEmpty {
                        Divider()
                        ForEach(availableExtensions, id: \.self) { ext in
                            Button {
                                extensionFilter = ext
                            } label: {
                                HStack {
                                    Text(".\(ext)")
                                    Spacer()
                                    Text("\(fileCountForExtension(ext))")
                                        .foregroundColor(theme.textSecondary)
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
                .tint(extensionFilter != nil ? theme.accent : theme.textSecondary)
                .menuStyle(.borderlessButton)

                Text(extensionFilter.map { ".\($0)" } ?? "All")
                    .font(.system(size: 10))
                    .foregroundColor(extensionFilter != nil ? theme.accent : theme.text)
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(extensionFilter != nil ? theme.accent.opacity(0.15) : theme.backgroundTertiary)
            .cornerRadius(DesignTokens.CornerRadius.sm)

            Spacer()

            Text("\(stagingVM.unstagedFiles.count + stagingVM.stagedFiles.count)")
                .font(.system(size: 10))
                .foregroundColor(theme.textMuted)
        }

        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(.ultraThinMaterial)
    }

    private var availableExtensions: [String] {
        var exts = Set<String>()
        for file in stagingVM.unstagedFiles + stagingVM.stagedFiles {
            let ext = (file.path as NSString).pathExtension.lowercased()
            if !ext.isEmpty { exts.insert(ext) }
        }
        return exts.sorted()
    }

    private func fileCountForExtension(_ ext: String) -> Int {
        (stagingVM.unstagedFiles + stagingVM.stagedFiles).filter {
            ($0.path as NSString).pathExtension.lowercased() == ext
        }.count
    }

    private var filteredUnstagedFiles: [StagingFile] {
        guard let ext = extensionFilter else { return stagingVM.unstagedFiles }
        return stagingVM.unstagedFiles.filter {
            ($0.path as NSString).pathExtension.lowercased() == ext
        }
    }

    private var filteredStagedFiles: [StagingFile] {
        guard let ext = extensionFilter else { return stagingVM.stagedFiles }
        return stagingVM.stagedFiles.filter {
            ($0.path as NSString).pathExtension.lowercased() == ext
        }
    }

    private func loadDiff(for file: StagingFile) {
        guard let path = appState.currentRepository?.path else { return }

        // Don't clear selectedFileDiff if we're reloading the same file
        // This prevents the need for double-clicking
        if selectedFileDiff?.newPath != file.path {
            isLoadingDiff = true
            selectedFileDiff = nil
        }

        Task {
            if let diff = await stagingVM.getDiff(for: file, at: path) {
                selectedFileDiff = diff
            }
            isLoadingDiff = false
        }
    }
}

// MARK: - Staging View Mode
enum StagingViewMode {
    case flat
    case tree
}
