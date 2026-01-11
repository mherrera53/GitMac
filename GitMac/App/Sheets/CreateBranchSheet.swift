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
        .frame(width: 380, height: 320)
        .background(AppTheme.backgroundSecondary)
    }

    private func createBranch() {
        isCreating = true
        errorMessage = nil

        Task {
            do {
                _ = try await appState.gitService.createBranch(
                    named: branchName,
                    from: baseBranch,
                    checkout: checkoutAfterCreate
                )
                await appState.refresh()
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
