//
//  SyncButton.swift
//  GitMac
//
//  One-click sync button for pull + push operations
//

import SwiftUI

struct SyncButton: View {
    @EnvironmentObject var appState: AppState
    let currentBranch: Branch?

    @State private var isSyncing = false
    @State private var showError = false
    @State private var errorMessage = ""

    private var aheadCount: Int {
        currentBranch?.upstream?.ahead ?? 0
    }

    private var behindCount: Int {
        currentBranch?.upstream?.behind ?? 0
    }

    private var totalChanges: Int {
        aheadCount + behindCount
    }

    private var syncIcon: String {
        if isSyncing {
            return "arrow.triangle.2.circlepath"
        } else if aheadCount > 0 && behindCount > 0 {
            return "arrow.triangle.2.circlepath"
        } else if aheadCount > 0 {
            return "arrow.up.circle"
        } else if behindCount > 0 {
            return "arrow.down.circle"
        }
        return "arrow.triangle.2.circlepath"
    }

    private var buttonLabel: String {
        if isSyncing {
            return "Syncing..."
        } else if totalChanges > 0 {
            return "Sync (\(totalChanges))"
        }
        return "Sync"
    }

    private var isDisabled: Bool {
        isSyncing || currentBranch == nil || totalChanges == 0
    }

    var body: some View {
        Button {
            performSync()
        } label: {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: syncIcon)
                    .font(.system(size: DesignTokens.Size.iconSM))
                    .rotationEffect(isSyncing ? .degrees(360) : .degrees(0))
                    .animation(isSyncing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isSyncing)

                Text(buttonLabel)
                    .font(DesignTokens.Typography.callout)
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
        }
        .buttonStyle(.bordered)
        .disabled(isDisabled)
        .help(syncTooltip)
        .keyboardShortcut("s", modifiers: [.command, .shift])
        .alert("Sync Failed", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private var syncTooltip: String {
        if currentBranch == nil {
            return "No branch selected"
        } else if totalChanges == 0 {
            return "Already up to date"
        } else if aheadCount > 0 && behindCount > 0 {
            return "Pull \(behindCount) and push \(aheadCount) commits (⌘⇧S)"
        } else if behindCount > 0 {
            return "Pull \(behindCount) commits (⌘⇧S)"
        } else if aheadCount > 0 {
            return "Push \(aheadCount) commits (⌘⇧S)"
        }
        return "Sync with remote (⌘⇧S)"
    }

    private func performSync() {
        guard let repoPath = appState.currentRepository?.path,
              let branch = currentBranch else {
            return
        }

        isSyncing = true

        Task {
            do {
                let tracker = GitProgressTracker.shared
                let operationId = tracker.startOperation(type: .sync, repositoryPath: repoPath)

                // Step 1: Fetch to update refs
                tracker.updateProgress(
                    operationId: operationId,
                    phase: .starting,
                    current: 0,
                    total: 3,
                    message: "Fetching updates..."
                )

                try await appState.gitService.fetch(prune: true)

                // Step 2: Pull if behind
                if behindCount > 0 {
                    tracker.updateProgress(
                        operationId: operationId,
                        phase: .receiving,
                        current: 1,
                        total: 3,
                        message: "Pulling \(behindCount) commits..."
                    )

                    try await appState.gitService.pull(rebase: false)
                }

                // Step 3: Push if ahead
                if aheadCount > 0 {
                    tracker.updateProgress(
                        operationId: operationId,
                        phase: .writing,
                        current: 2,
                        total: 3,
                        message: "Pushing \(aheadCount) commits..."
                    )

                    try await appState.gitService.push()
                }

                // Complete
                tracker.updateProgress(
                    operationId: operationId,
                    phase: .complete,
                    current: 3,
                    total: 3,
                    message: "Sync complete"
                )

                tracker.completeOperation(operationId: operationId, success: true)

                // Refresh repository
                await appState.refresh()

                // Show success notification
                await MainActor.run {
                    let pulledText = behindCount > 0 ? "\(behindCount) pulled" : nil
                    let pushedText = aheadCount > 0 ? "\(aheadCount) pushed" : nil
                    let details = [pulledText, pushedText].compactMap { $0 }.joined(separator: ", ")
                    let message = "Sync Complete: \(details)"

                    NotificationManager.shared.show(message, type: .success)
                }

            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }

                // Mark operation as failed
                if let operation = GitProgressTracker.shared.activeOperations.first(where: { $0.repositoryPath == repoPath }) {
                    GitProgressTracker.shared.completeOperation(operationId: operation.id, success: false, error: error)
                }
            }

            await MainActor.run {
                isSyncing = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SyncButton(currentBranch: Branch(
        name: "main",
        fullName: "refs/heads/main",
        isRemote: false,
        isHead: true,
        targetSHA: "abc123def456",
        upstream: UpstreamInfo(
            name: "origin/main",
            ahead: 2,
            behind: 1
        )
    ))
    .environmentObject(AppState())
    .padding()
}
