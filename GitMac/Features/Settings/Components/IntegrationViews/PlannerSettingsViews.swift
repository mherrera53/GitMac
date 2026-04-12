import SwiftUI

// MARK: - Planner Login View

struct PlannerLoginView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let isLoading: Bool
    let error: String?
    let onLogin: () -> Void

    @State private var clientId = ""
    @State private var hasClientId = false
    @State private var isAuthenticating = false
    @State private var deviceCode: MicrosoftOAuth.DeviceCodeResponse?
    @State private var authError: String?

    private let microsoftOAuth = MicrosoftOAuth.shared

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack {
                Image(systemName: "calendar.badge.checkmark")
                    .foregroundStyle(SwiftUI.Color(hex: "0078D4"))
                Text("Connect to Microsoft Planner")
                    .foregroundStyle(AppTheme.textPrimary)
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(AppTheme.textPrimary)
            }

            Text("Link your Microsoft 365 account to sync Planner tasks and boards.")
                .foregroundStyle(AppTheme.textPrimary)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(AppTheme.textSecondary)

            if let deviceCode = deviceCode {
                // Waiting for user authorization
                MicrosoftOAuthWaitingView(
                    userCode: deviceCode.userCode,
                    verificationUri: deviceCode.verificationUri,
                    onCancel: {
                        Task { await microsoftOAuth.cancelAuthentication() }
                        self.deviceCode = nil
                        isAuthenticating = false
                    }
                )
            } else if !hasClientId {
                // Need to configure Client ID
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Configure Azure AD App")
                        .foregroundStyle(AppTheme.textPrimary)
                        .font(DesignTokens.Typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(AppTheme.textPrimary)

                    Text("Register an app in Azure AD and enter the Client ID.")
                        .foregroundStyle(AppTheme.textPrimary)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(AppTheme.textSecondary)

                    DSTextField(placeholder: "Application (client) ID", text: $clientId)

                    HStack {
                        DSButton("Register App in Azure", variant: .link, size: .sm) {
                            NSWorkspace.shared.open(URL(string: "https://portal.azure.com/#view/Microsoft_AAD_RegisteredApps/ApplicationsListBlade")!)
                        }

                        Spacer()

                        DSButton("Save", variant: .primary, size: .sm, isDisabled: clientId.isEmpty) {
                            await microsoftOAuth.setClientId(clientId)
                            hasClientId = true
                        }
                    }

                    Text("Required: Enable 'Allow public client flows' in Azure AD")
                        .foregroundStyle(AppTheme.textPrimary)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            } else {
                // Ready to authenticate
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppTheme.success)
                        Text("Azure AD configured")
                            .foregroundStyle(AppTheme.textPrimary)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textPrimary)

                        Spacer()

                        DSButton("Change", variant: .link, size: .sm) {
                            hasClientId = false
                            clientId = ""
                        }
                    }

                    DSButton(variant: .primary, size: .md, isDisabled: isAuthenticating) {
                        startOAuth()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.up.forward.app")
                            Text("Sign in with Microsoft")
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }

            if let error = authError ?? error {
                Text(error)
                    .foregroundStyle(AppTheme.error)
                    .font(.caption)
            }

            Text("Required scopes: Tasks.ReadWrite, Group.Read.All, User.Read")
                .foregroundStyle(AppTheme.textPrimary)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .task {
            hasClientId = await microsoftOAuth.hasClientId
        }
    }

    private func startOAuth() {
        isAuthenticating = true
        authError = nil

        Task {
            do {
                let response = try await microsoftOAuth.startAuthentication()
                deviceCode = response

                // Open browser
                microsoftOAuth.openVerificationPage(uri: response.verificationUri)

                // Wait for authorization
                _ = try await microsoftOAuth.waitForAuthentication(deviceCode: response)

                // Success!
                deviceCode = nil
                isAuthenticating = false
                onLogin()
            } catch let error as MicrosoftOAuthError {
                authError = error.localizedDescription
                deviceCode = nil
                isAuthenticating = false
            } catch {
                authError = error.localizedDescription
                deviceCode = nil
                isAuthenticating = false
            }
        }
    }
}

// MARK: - Microsoft OAuth Waiting View

struct MicrosoftOAuthWaitingView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let userCode: String
    let verificationUri: String
    let onCancel: () -> Void

    @State private var copied = false

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "link.circle.fill")
                .font(DesignTokens.Typography.iconXXXL)
                .foregroundStyle(SwiftUI.Color(hex: "0078D4"))

            Text("Enter this code on Microsoft")
                .foregroundStyle(AppTheme.textPrimary)
                .font(DesignTokens.Typography.headline)

            HStack(spacing: DesignTokens.Spacing.md) {
                Text(userCode)
                    .foregroundStyle(AppTheme.textPrimary)
                    .font(DesignTokens.Typography.title2.bold().monospaced())

                DSIconButton(iconName: copied ? "checkmark" : "doc.on.doc", variant: .ghost, size: .sm) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(userCode, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        copied = false
                    }
                }
            }
            .padding()
            .background(AppTheme.textSecondary.opacity(0.1))
            .clipShape(.rect(cornerRadius: DesignTokens.CornerRadius.lg))

            if copied {
                Text("Copied!")
                    .foregroundStyle(AppTheme.textPrimary)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(AppTheme.success)
            }

            ProgressView()
                .scaleEffect(0.8)

            Text("Waiting for authorization...")
                .foregroundStyle(AppTheme.textPrimary)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(AppTheme.textSecondary)

            HStack {
                DSButton("Open Microsoft", variant: .primary, size: .sm) {
                    if let url = URL(string: verificationUri) {
                        NSWorkspace.shared.open(url)
                    }
                }

                DSButton("Cancel", variant: .secondary, size: .sm) {
                    onCancel()
                }
            }
        }
        .padding()
    }
}

// MARK: - Planner Connected View

struct PlannerConnectedView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let selectedRepoPath: String?
    let plans: [PlannerPlan]
    @ObservedObject var workspaceManager: WorkspaceSettingsManager
    let onDisconnect: () -> Void

    @State private var selectedPlanId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppTheme.success)
                Text("Connected to Microsoft Planner")
                    .foregroundStyle(AppTheme.textPrimary)
                    .fontWeight(.medium)
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                DSButton("Disconnect", variant: .danger, size: .sm) {
                    onDisconnect()
                }
            }

            if let repoPath = selectedRepoPath {
                let config = workspaceManager.getConfig(for: repoPath)

                Picker("Plan for this repository", selection: $selectedPlanId) {
                    Text("None").tag(nil as String?)
                        .foregroundStyle(AppTheme.textPrimary)
                    ForEach(plans) { plan in
                        Text(plan.title).tag(Optional(plan.id))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                }
                .onChange(of: selectedPlanId) { _, newValue in
                    let planName = plans.first(where: { $0.id == newValue })?.title
                    workspaceManager.setPlannerPlan(for: repoPath, planId: newValue, planName: planName)
                }
                .onAppear {
                    selectedPlanId = config.plannerPlanId
                }

                if let planName = config.plannerPlanName {
                    HStack {
                        Image(systemName: "checklist")
                            .foregroundStyle(SwiftUI.Color(hex: "0078D4"))
                        Text("Linked to: \(planName)")
                            .foregroundStyle(AppTheme.textPrimary)
                            .font(DesignTokens.Typography.caption)
                    }
                }
            } else {
                Text("Select a repository to assign a plan")
                    .foregroundStyle(AppTheme.textSecondary)
                    .font(DesignTokens.Typography.caption)
            }
        }
    }
}
