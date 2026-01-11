import SwiftUI

struct WorkspaceConfigView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @StateObject private var workspaceManager = WorkspaceSettingsManager.shared
    @EnvironmentObject var appState: AppState

    @State private var mainBranchName: String = ""
    @State private var saveStatus: String?

    var body: some View {
        Form {
            if let repoPath = appState.currentRepository?.path {
                SettingsSection(title: "Current Repository") {
                    Text(repoPath)
                        .foregroundColor(AppTheme.textPrimary)
                        .font(DesignTokens.Typography.caption.monospaced())
                        .foregroundColor(AppTheme.textSecondary)
                }

                SettingsSection(title: "Main Branch Configuration") {
                    DSTextField(placeholder: "Main branch name (e.g., main, master, develop)", text: $mainBranchName)
                        .onChange(of: mainBranchName) { _, newValue in
                            guard !newValue.isEmpty else { return }
                            workspaceManager.setMainBranch(for: repoPath, branchName: newValue)
                            saveStatus = "Saved"

                            // Clear status after 2 seconds
                            Task {
                                try? await Task.sleep(nanoseconds: 2_000_000_000)
                                saveStatus = nil
                            }
                        }

                    Text("This sets which branch is considered the 'main' branch for this repository. Used for comparisons, badges, and workflows.")
                        .foregroundColor(AppTheme.textPrimary)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(AppTheme.textSecondary)

                    if let status = saveStatus {
                        Text(status)
                            .foregroundColor(AppTheme.textPrimary)
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(AppTheme.success)
                    }
                }

                SettingsSection(title: "Integration Settings") {
                    Text("Additional per-repository settings (Taiga, Planner, etc.) will appear here")
                        .foregroundColor(AppTheme.textPrimary)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }
            } else {
                Section {
                    VStack(spacing: DesignTokens.Spacing.md) {
                        Image(systemName: "folder.badge.questionmark")
                            .font(DesignTokens.Typography.iconXXXL)
                            .foregroundColor(AppTheme.textSecondary)

                        Text("No Repository Open")
                            .foregroundColor(AppTheme.textPrimary)
                            .font(DesignTokens.Typography.headline)
                            .foregroundColor(AppTheme.textPrimary)

                        Text("Open a repository to configure workspace settings")
                            .foregroundColor(AppTheme.textPrimary)
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            }
        }
        .padding()
        .background(AppTheme.background)
        .task {
            loadConfig()
        }
        .onChange(of: appState.currentRepository?.path) { _, _ in
            loadConfig()
        }
    }

    private func loadConfig() {
        guard let repoPath = appState.currentRepository?.path else {
            mainBranchName = ""
            return
        }

        // Load main branch from workspace settings
        mainBranchName = workspaceManager.getMainBranch(for: repoPath)
    }
}
