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
            // Header
            HStack {
                Text("Create New Branch")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.textMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(AppTheme.backgroundSecondary)

            // Repository context info
            HStack(spacing: 12) {
                // Repository
                HStack(spacing: 4) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.accent)
                    Text(repoName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.textPrimary)
                }

                // Current branch
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.success)
                    Text(currentBranchName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.textPrimary)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(AppTheme.backgroundTertiary.opacity(0.5))

            Rectangle().fill(AppTheme.border).frame(height: 1)

            // Content
            VStack(alignment: .leading, spacing: 16) {
                // Branch name
                VStack(alignment: .leading, spacing: 6) {
                    Text("Branch Name")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)

                    DSTextField(placeholder: "feature/my-branch", text: $branchName)
                        .font(.system(size: 13))
                        .padding(8)
                        .background(AppTheme.backgroundSecondary)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(AppTheme.border, lineWidth: 1)
                        )
                }

                // Base branch
                VStack(alignment: .leading, spacing: 6) {
                    Text("Based On")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)

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
                        .foregroundColor(AppTheme.textSecondary)
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.error)
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
                .foregroundColor(AppTheme.textSecondary)

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
        .frame(width: 380, height: 350)
        .background(AppTheme.backgroundSecondary)
    }

    private func createBranch() {
        guard let repoPath = appState.currentRepository?.path else {
            errorMessage = "No repository selected"
            return
        }

        isCreating = true
        errorMessage = nil

        Task {
            do {
                let engine = GitEngine()
                _ = try await engine.createBranch(
                    named: branchName,
                    from: baseBranch,
                    checkout: checkoutAfterCreate,
                    at: repoPath
                )
                await appState.refresh()

                // Post notifications for UI sync
                if checkoutAfterCreate {
                    NotificationCenter.default.post(name: .branchDidCheckout, object: branchName)
                }
                NotificationCenter.default.post(name: .repositoryDidRefresh, object: repoPath)

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
