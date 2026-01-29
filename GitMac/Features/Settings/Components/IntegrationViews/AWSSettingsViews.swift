import SwiftUI

// MARK: - AWS Connected View

struct AWSConnectedView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    let region: String
    let projects: [String]
    let selectedRepoPath: String?
    @ObservedObject var workspaceManager: WorkspaceSettingsManager
    let onDisconnect: () -> Void
    let onRefresh: () -> Void

    @State private var selectedProject: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppTheme.success)
                Text("Connected")
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text(region)
                    .foregroundStyle(AppTheme.textPrimary)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
                    .padding(.vertical, DesignTokens.Spacing.xxs)
                    .background(AppTheme.warning.opacity(0.2))
                    .clipShape(.rect(cornerRadius: DesignTokens.CornerRadius.sm))
                DSIconButton(iconName: "arrow.clockwise", variant: .ghost, size: .sm, action: onRefresh)
                DSButton("Disconnect", variant: .danger, size: .sm, action: onDisconnect)
            }

            if !projects.isEmpty {
                // Project assignment for current repo
                if let repoPath = selectedRepoPath {
                    Divider()
                        .padding(.vertical, DesignTokens.Spacing.xs)

                    Text("Assign to \(URL(fileURLWithPath: repoPath).lastPathComponent):")
                        .foregroundStyle(AppTheme.textPrimary)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(AppTheme.textSecondary)

                    Picker("CodeBuild Project", selection: $selectedProject) {
                        Text("None").tag("")
                            .foregroundStyle(AppTheme.textPrimary)
                        ForEach(projects, id: \.self) { project in
                            Text(project).tag(project)
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedProject) { _, newValue in
                        workspaceManager.setCodeBuildProject(
                            for: repoPath,
                            projectName: newValue.isEmpty ? nil : newValue
                        )
                    }
                    .onAppear {
                        let config = workspaceManager.getConfig(for: repoPath)
                        selectedProject = config.codeBuildProjectName ?? ""
                    }

                    if !selectedProject.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AppTheme.success)
                                .font(DesignTokens.Typography.caption)
                            Text("Only builds from '\(selectedProject)' will show for this repo")
                                .foregroundStyle(AppTheme.textPrimary)
                                .font(DesignTokens.Typography.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }

                    Divider()
                        .padding(.vertical, DesignTokens.Spacing.xs)
                }

                Text("Available Projects (\(projects.count)):")
                    .foregroundStyle(AppTheme.textPrimary)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(AppTheme.textSecondary)

                ForEach(projects, id: \.self) { project in
                    HStack {
                        Image(systemName: "hammer.fill")
                            .foregroundStyle(AppTheme.warning)
                            .frame(width: 20)
                        Text(project)
                            .foregroundStyle(AppTheme.textPrimary)
                            .font(DesignTokens.Typography.body.monospaced())
                    }
                }
            } else {
                Text("No CodeBuild projects found")
                    .foregroundStyle(AppTheme.textPrimary)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }
}

// MARK: - AWS Login View

struct AWSLoginView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @Binding var accessKeyId: String
    @Binding var secretAccessKey: String
    @Binding var sessionToken: String
    @Binding var region: String
    let isLoading: Bool
    let error: String?
    let onConnect: () -> Void

    let regions = ["us-east-1", "us-east-2", "us-west-1", "us-west-2", "eu-west-1", "eu-central-1", "ap-southeast-1", "ap-northeast-1"]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            DSTextField(placeholder: "Access Key ID", text: $accessKeyId)

            DSSecureField(placeholder: "Secret Access Key", text: $secretAccessKey)

            DSSecureField(placeholder: "Session Token (MFA/2FA)", text: $sessionToken)

            Text("Required if using MFA/2FA authentication")
                .foregroundStyle(AppTheme.textPrimary)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(AppTheme.textSecondary)

            Picker("Region", selection: $region) {
                ForEach(regions, id: \.self) { r in
                    Text(r).tag(r)
                        .foregroundStyle(AppTheme.textPrimary)
                }
            }
            .pickerStyle(.menu)

            if let error = error {
                Text(error)
                    .foregroundStyle(AppTheme.textPrimary)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(AppTheme.error)
            }

            DSButton(variant: .primary, size: .sm, isDisabled: accessKeyId.isEmpty || secretAccessKey.isEmpty || isLoading) {
                onConnect()
            } label: {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Text("Connect")
                        .foregroundStyle(AppTheme.textPrimary)
                }
            }

            Link("Get AWS credentials", destination: URL(string: "https://console.aws.amazon.com/iam/home#/security_credentials")!)
                .font(DesignTokens.Typography.caption)

            Text("For MFA: Run `aws sts get-session-token --serial-number arn:aws:iam::ACCOUNT:mfa/USER --token-code CODE` to get session token")
                .foregroundStyle(AppTheme.textPrimary)
                .font(DesignTokens.Typography.caption2)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }
}
