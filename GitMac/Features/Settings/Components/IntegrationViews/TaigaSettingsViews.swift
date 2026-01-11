import SwiftUI

// MARK: - Taiga Login View

struct TaigaLoginView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @Binding var username: String
    @Binding var password: String
    let isLoading: Bool
    let error: String?
    let onLogin: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack {
                Image(systemName: "ticket.fill")
                    .foregroundColor(Color(hex: "4DC8A8"))
                Text("Connect to Taiga")
                    .foregroundColor(AppTheme.textPrimary)
                    .font(DesignTokens.Typography.headline)
                    .foregroundColor(AppTheme.textPrimary)
            }

            Text("Link your Taiga account to sync user stories, tasks, and issues.")
                .foregroundColor(AppTheme.textPrimary)
                .font(DesignTokens.Typography.caption)
                .foregroundColor(AppTheme.textSecondary)

            DSTextField(placeholder: "Username or Email", text: $username)

            DSSecureField(placeholder: "Password", text: $password)

            HStack {
                DSButton("Create Account", variant: .link, size: .sm) {
                    NSWorkspace.shared.open(URL(string: "https://tree.taiga.io/register")!)
                }

                Spacer()

                DSButton("Sign In", variant: .primary, size: .sm, isDisabled: username.isEmpty || password.isEmpty || isLoading) {
                    onLogin()
                }
            }

            if let error = error {
                Text(error)
                    .foregroundColor(AppTheme.error)
                    .font(DesignTokens.Typography.caption)
            }
        }
    }
}

// MARK: - Taiga Connected View

struct TaigaConnectedView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    let selectedRepoPath: String?
    let projects: [TaigaProject]
    @ObservedObject var workspaceManager: WorkspaceSettingsManager
    let onDisconnect: () -> Void

    @State private var selectedProjectId: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppTheme.success)
                Text("Connected to Taiga")
                    .foregroundColor(AppTheme.textPrimary)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                DSButton("Disconnect", variant: .danger, size: .sm) {
                    onDisconnect()
                }
            }

            if let repoPath = selectedRepoPath {
                let config = workspaceManager.getConfig(for: repoPath)

                Picker("Project for this repository", selection: $selectedProjectId) {
                    Text("None").tag(nil as Int?)
                        .foregroundColor(AppTheme.textPrimary)
                    ForEach(projects) { project in
                        Text(project.name).tag(Optional(project.id))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                }
                .onChange(of: selectedProjectId) { _, newValue in
                    let projectName = projects.first(where: { $0.id == newValue })?.name
                    workspaceManager.setTaigaProject(for: repoPath, projectId: newValue, projectName: projectName)
                }
                .onAppear {
                    selectedProjectId = config.taigaProjectId
                }

                if let projectName = config.taigaProjectName {
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundColor(Color(hex: "4DC8A8"))
                        Text("Linked to: \(projectName)")
                            .foregroundColor(AppTheme.textPrimary)
                            .font(DesignTokens.Typography.caption)
                    }
                }
            } else {
                Text("Select a repository to assign a project")
                    .foregroundColor(AppTheme.textSecondary)
                    .font(DesignTokens.Typography.caption)
            }
        }
    }
}
