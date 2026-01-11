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
        .onReceive(Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()) { _ in
            // Auto-refresh WIP changes every 2 seconds
            if let path = appState.currentRepository?.path {
                Task {
                    await stagingVM.loadStatus(at: path)
                }
            }
        }
        .onChange(of: appState.selectedCommit) { _, newCommit in
            if let commit = newCommit, let path = appState.currentRepository?.path {
                let requestedSHA = commit.sha
                Task {
                    await commitDetailVM.loadCommitFiles(sha: requestedSHA, at: path)

                    let firstFile = await MainActor.run { commitDetailVM.changedFiles.first }
                    guard let firstFile else { return }

                    let stillSelectedBefore = await MainActor.run { appState.selectedCommit?.sha == requestedSHA }
                    guard stillSelectedBefore else { return }

                    await MainActor.run {
                        isLoadingDiff = true
                        selectedFileDiff = nil
                    }

                    let diff = await commitDetailVM.getDiff(for: firstFile, commit: commit, at: path)

                    let stillSelectedAfter = await MainActor.run { appState.selectedCommit?.sha == requestedSHA }
                    guard stillSelectedAfter else { return }

                    await MainActor.run {
                        if let diff {
                            selectedFileDiff = diff
                        }
                        isLoadingDiff = false
                    }
                }
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
