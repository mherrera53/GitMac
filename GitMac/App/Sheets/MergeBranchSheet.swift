//
//  MergeBranchSheet.swift
//  GitMac
//
//  Sheet for merging branches
//

import SwiftUI

struct MergeBranchSheet: View {
    @Environment(AppState.self) var appState
    @Binding var isPresented: Bool

    @State private var selectedBranch: String = ""
    @State private var noFastForward = false
    @State private var isMerging = false
    @State private var errorMessage: String?
    @State private var isLoadingBranches = false
    @State private var availableBranches: [Branch] = []

    var currentBranchName: String {
        appState.currentRepository?.currentBranch?.name ?? "current branch"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Merge Branch")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()

                if isLoadingBranches {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 20, height: 20)
                }

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.textMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(AppTheme.backgroundSecondary)

            Rectangle().fill(AppTheme.border).frame(height: 1)

            // Content
            VStack(alignment: .leading, spacing: 16) {
                // Source branch
                VStack(alignment: .leading, spacing: 6) {
                    Text("Merge Branch")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)

                    Picker("", selection: $selectedBranch) {
                        Text("Select a branch...").tag("")
                        ForEach(availableBranches) { branch in
                            Text(branch.name).tag(branch.name)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .disabled(isLoadingBranches)
                }

                // Info
                if !selectedBranch.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.merge")
                            .foregroundStyle(AppTheme.accent)
                        Text("Merge '\(selectedBranch)' into '\(currentBranchName)'")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(10)
                    .background(AppTheme.backgroundSecondary)
                    .clipShape(.rect(cornerRadius: 6))
                }

                // Options
                Toggle(isOn: $noFastForward) {
                    Text("Create merge commit (no fast-forward)")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.error)
                }
            }
            .padding(16)

            Spacer()

            Rectangle().fill(AppTheme.border).frame(height: 1)

            // Footer
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.textSecondary)

                Spacer()

                Button {
                    mergeBranch()
                } label: {
                    if isMerging {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 60)
                    } else {
                        Text("Merge")
                            .frame(minWidth: 60)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedBranch.isEmpty || isMerging)
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 400, height: 300)
        .background(AppTheme.backgroundSecondary)
        .task {
            await loadBranches()
        }
    }

    private func loadBranches() async {
        isLoadingBranches = true
        do {
            // Force refresh to get latest branches after pull
            try await appState.gitService.refresh()
            let branches = try await appState.gitService.getBranches()
            await MainActor.run {
                // Filter out current branch (can't merge into itself)
                availableBranches = branches.filter { !$0.isHead && !$0.isCurrent }
                isLoadingBranches = false
            }
        } catch {
            await MainActor.run {
                // Fallback to cached branches
                availableBranches = appState.currentRepository?.branches.filter { !$0.isHead } ?? []
                isLoadingBranches = false
            }
        }
    }

    private func mergeBranch() {
        guard !selectedBranch.isEmpty else { return }
        let currentBranch = appState.currentRepository?.currentBranch?.name ?? "HEAD"
        isMerging = true
        errorMessage = nil

        Task {
            do {
                try await appState.gitService.merge(branch: selectedBranch, noFastForward: noFastForward)
                await appState.refresh()

                // Track successful merge
                RemoteOperationTracker.shared.recordMerge(
                    success: true,
                    sourceBranch: selectedBranch,
                    targetBranch: currentBranch
                )

                await MainActor.run {
                    isPresented = false
                }
            } catch {
                // Track failed merge
                RemoteOperationTracker.shared.recordMerge(
                    success: false,
                    sourceBranch: selectedBranch,
                    targetBranch: currentBranch,
                    error: error.localizedDescription
                )

                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isMerging = false
                }
            }
        }
    }
}
