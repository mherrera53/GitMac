//
//  CreateBranchSheet.swift
//  GitMac
//
//  Sheet for creating a new git branch
//

import SwiftUI

struct CreateBranchSheet: View {
    @EnvironmentObject var appState: AppState
    @Binding var isPresented: Bool

    @State private var branchName = ""
    @State private var baseBranch = "HEAD"
    @State private var checkoutAfterCreate = true
    @State private var isCreating = false
    @State private var errorMessage: String?

    // Branch name suggestions
    @State private var suggestions: [BranchSuggestion] = []
    @State private var isLoadingSuggestions = false
    private let suggestionService = BranchNamingSuggestionService()

    var localBranches: [Branch] {
        appState.currentRepository?.branches ?? []
    }

    var currentBranchName: String {
        appState.currentRepository?.currentBranch?.name ?? "HEAD"
    }

    var repoName: String {
        appState.currentRepository?.name ?? "Unknown"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header (pinned)
            HStack {
                Text("Create New Branch")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
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

            // Repository context info
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.accent)
                    Text(repoName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                }

                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.success)
                    Text(currentBranchName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(AppTheme.backgroundTertiary.opacity(0.5))

            Rectangle().fill(AppTheme.border).frame(height: 1)

            // Scrollable content — grows with suggestions without pushing footer offscreen
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Branch name
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Branch Name")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)

                        DSTextField(placeholder: "feature/my-branch", text: $branchName)
                            .font(.system(size: 13))
                            .padding(8)
                            .background(AppTheme.backgroundSecondary)
                            .clipShape(.rect(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(AppTheme.border, lineWidth: 1)
                            )

                        // Suggestions
                        if isLoadingSuggestions {
                            HStack(spacing: 4) {
                                ProgressView()
                                    .scaleEffect(0.6)
                                Text("Loading suggestions...")
                                    .font(.system(size: 10))
                                    .foregroundStyle(AppTheme.textMuted)
                            }
                        } else if !suggestions.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Suggestions")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(AppTheme.textMuted)

                                FlowLayout(spacing: 6) {
                                    ForEach(suggestions) { suggestion in
                                        Button {
                                            branchName = suggestion.name
                                        } label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: suggestion.icon)
                                                    .font(.system(size: 9))
                                                Text(suggestion.name)
                                                    .font(.system(size: 10))
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(AppTheme.accent.opacity(0.1))
                                            .foregroundStyle(AppTheme.accent)
                                            .clipShape(.rect(cornerRadius: 4))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }

                    // Base branch
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Based On")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)

                        Picker("", selection: $baseBranch) {
                            Text("Current HEAD").tag("HEAD")
                            ForEach(localBranches) { branch in
                                Text(branch.name).tag(branch.name)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }

                    // Checkout toggle
                    Toggle(isOn: $checkoutAfterCreate) {
                        Text("Checkout after creating")
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
            }

            Rectangle().fill(AppTheme.border).frame(height: 1)

            // Footer (pinned at bottom — always visible)
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.textSecondary)

                Spacer()

                Button {
                    createBranch()
                } label: {
                    if isCreating {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 60)
                    } else {
                        Text("Create")
                            .frame(minWidth: 60)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(branchName.isEmpty || isCreating)
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(minWidth: 400, maxWidth: 400, minHeight: 380, maxHeight: 520)
        .background(AppTheme.backgroundSecondary)
        .task {
            await loadSuggestions()
        }
    }

    private func loadSuggestions() async {
        guard let repoPath = appState.currentRepository?.path else { return }

        isLoadingSuggestions = true

        let engine = GitEngine()

        // Get recent commits and modified files for context
        var recentCommits: [Commit] = []
        var modifiedFiles: [String] = []

        do {
            recentCommits = try await engine.getCommits(at: repoPath, limit: 5)
        } catch {
            // Continue without commits
        }

        // Get modified files from status
        let shell = ShellExecutor()
        let statusResult = await shell.execute("git", arguments: ["status", "--porcelain"], workingDirectory: repoPath)
        if statusResult.isSuccess {
            modifiedFiles = statusResult.stdout
                .components(separatedBy: .newlines)
                .filter { !$0.isEmpty }
                .compactMap { line in
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    return String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                }
        }

        let context = BranchContext(
            repoPath: repoPath,
            baseBranch: baseBranch,
            recentCommits: recentCommits,
            modifiedFiles: modifiedFiles,
            currentBranchName: currentBranchName
        )

        let loadedSuggestions = await suggestionService.suggestBranchNames(context: context)

        await MainActor.run {
            suggestions = loadedSuggestions
            isLoadingSuggestions = false
        }
    }

    private func createBranch() {
        guard appState.currentRepository?.path != nil else {
            errorMessage = "No repository selected"
            return
        }

        guard let manager = appState.branchManager else {
            errorMessage = "Branch manager not available"
            return
        }

        isCreating = true
        errorMessage = nil

        Task {
            do {
                try await manager.createBranch(
                    name: branchName,
                    from: baseBranch,
                    checkout: checkoutAfterCreate
                )

                await MainActor.run {
                    isPresented = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isCreating = false
                }
            }
        }
    }
}
