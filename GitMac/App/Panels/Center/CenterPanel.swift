//
//  CenterPanel.swift
//  GitMac
//
//  Extracted from ContentView.swift
//

import SwiftUI

// MARK: - Center Panel (Graph or Diff)
struct CenterPanel: View {
    @Environment(AppState.self) var appState
    @Binding var selectedFileDiff: FileDiff?
    @Binding var isLoadingDiff: Bool
    var onStageHunk: ((Int) async -> Bool)? = nil
    var onDiscardHunk: ((Int) async -> Bool)? = nil
    var onUnstageHunk: ((Int) async -> Bool)? = nil

    var body: some View {
        VStack(spacing: 0) {
            if isLoadingDiff {
                // Loading indicator
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading preview...")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.background)
            } else if let fileDiff = selectedFileDiff {
                // Diff View with close button
                DiffViewWithClose(
                    fileDiff: fileDiff,
                    repoPath: appState.currentRepository?.path,
                    onClose: { selectedFileDiff = nil },
                    onStageHunk: onStageHunk,
                    onDiscardHunk: onDiscardHunk,
                    onUnstageHunk: onUnstageHunk
                )
            } else {
                // Graph View
                if appState.currentRepository != nil {
                    CommitGraphView()
                } else {
                    DSEmptyState(
                        icon: "folder.badge.questionmark",
                        title: "No Repository",
                        description: "Open a repository to get started"
                    )
                }
            }
        }
    }
}
