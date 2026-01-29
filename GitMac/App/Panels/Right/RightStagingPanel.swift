import SwiftUI

// MARK: - Right Staging Panel
struct RightStagingPanel: View {
    @EnvironmentObject var appState: AppState
    @Binding var selectedFileDiff: FileDiff?
    @Binding var isLoadingDiff: Bool
    @State private var commitMessage = ""
    @StateObject private var stagingVM = StagingViewModel()
    @StateObject private var commitDetailVM = CommitDetailViewModel()
    @StateObject private var stashDetailVM = StashDetailViewModel()
    @ObservedObject private var themeManager = ThemeManager.shared

    /// Whether the panel is showing the WIP staging area (no commit or stash selected)
    private var isShowingWIP: Bool {
        appState.selectedCommit == nil && appState.selectedStash == nil
    }

    var body: some View {
        VStack(spacing: 0) {
            if let selectedCommit = appState.selectedCommit {
                // Show commit details when a commit is selected
                RightCommitDetailPanel(
                    commit: selectedCommit,
                    viewModel: commitDetailVM,
                    selectedFileDiff: $selectedFileDiff,
                    onClose: { appState.selectedCommit = nil }
                )
            } else if let selectedStash = appState.selectedStash {
                // Show stash details when a stash is selected
                StashDetailPanel(
                    stash: selectedStash,
                    viewModel: stashDetailVM,
                    selectedFileDiff: $selectedFileDiff,
                    onClose: { appState.selectedStash = nil }
                )
            } else {
                // Show staging area when no commit/stash is selected (WIP mode)
                StagingAreaPanel(
                    stagingVM: stagingVM,
                    selectedFileDiff: $selectedFileDiff,
                    isLoadingDiff: $isLoadingDiff,
                    commitMessage: $commitMessage
                )
            }
        }
        .task(id: isShowingWIP) {
            // Fires immediately when switching to WIP mode
            if isShowingWIP, let path = appState.currentRepository?.path {
                await stagingVM.loadStatus(at: path)
            }
        }
        .onChange(of: appState.currentRepository?.path) { _, newPath in
            if let path = newPath {
                Task { await stagingVM.loadStatus(at: path) }
            }
        }
        // FileWatcher-driven refresh: fires within ~0.5s of any file/index change
        .onChange(of: appState.statusChangeCounter) { _, _ in
            guard isShowingWIP, let path = appState.currentRepository?.path else { return }
            Task { await stagingVM.loadStatus(at: path) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .fileSavedInEditor)) { _ in
            // Refresh staging when a file is saved in the editor
            if let path = appState.currentRepository?.path {
                Task {
                    await stagingVM.loadStatus(at: path)
                    // If we have a selected diff, reload it
                    if let currentDiff = selectedFileDiff {
                        let file = StagingFile(path: currentDiff.newPath, status: .modified, isStaged: false)
                        if let diff = await stagingVM.getDiff(for: file, at: path) {
                            selectedFileDiff = diff
                        }
                    }
                }
            }
        }
        .onChange(of: appState.selectedCommit) { _, _ in
            // Clear diff when commit selection changes
            selectedFileDiff = nil
            // Reset view model so new commit loads fresh
            commitDetailVM.reset()
        }
        .onReceive(NotificationCenter.default.publisher(for: .loadFirstFileDiff)) { _ in
            // Double-click: load diff for first file
            guard let commit = appState.selectedCommit,
                  let path = appState.currentRepository?.path,
                  let firstFile = commitDetailVM.changedFiles.first else { return }

            Task {
                isLoadingDiff = true
                if let diff = await commitDetailVM.getDiff(for: firstFile, commit: commit, at: path) {
                    selectedFileDiff = diff
                }
                isLoadingDiff = false
            }
        }
        .onChange(of: appState.selectedStash) { _, newStash in
            if let stash = newStash, let path = appState.currentRepository?.path {
                Task { await stashDetailVM.loadStashFiles(stashRef: stash.reference, at: path) }
            }
        }
        .task(id: appState.selectedStash?.sha) {
            // Load stash files when stash is selected (initial load)
            if let stash = appState.selectedStash, let path = appState.currentRepository?.path {
                await stashDetailVM.loadStashFiles(stashRef: stash.reference, at: path)
            }
        }
    }
}
