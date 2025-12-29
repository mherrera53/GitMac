//
//  JiraLoginPrompt.swift
//  GitMac
//
//  Created on 2025-12-29.
//  Login prompt view for Jira integration
//

import SwiftUI

/// Custom login prompt for Jira
/// Handles Jira-specific authentication with site URL, email, and API token
struct JiraLoginPrompt: View {
    @ObservedObject var viewModel: JiraViewModel
    @State private var email = ""
    @State private var apiToken = ""
    @State private var siteUrl = ""
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(DesignTokens.Typography.iconXXXL)
                .foregroundColor(Color(hex: "0052CC"))

            Text("Connect to Jira")
                .font(DesignTokens.Typography.headline)
                .foregroundColor(AppTheme.textPrimary)

            Text("Enter your Jira Cloud credentials")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)

            VStack(spacing: DesignTokens.Spacing.sm) {
                DSTextField(placeholder: "Site URL (e.g., yourcompany.atlassian.net)", text: $siteUrl)
                    .frame(maxWidth: 350)

                DSTextField(placeholder: "Email", text: $email)
                    .frame(maxWidth: 350)

                DSSecureField(placeholder: "API Token", text: $apiToken)
                    .frame(maxWidth: 350)
            }

            if let error = error {
                Text(error)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.error)
            }

            Button {
                login()
            } label: {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text("Connect")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(email.isEmpty || apiToken.isEmpty || siteUrl.isEmpty || isLoading)

            Link("Get API token from Atlassian",
                 destination: URL(string: "https://id.atlassian.com/manage-profile/security/api-tokens")!)
                .font(DesignTokens.Typography.caption)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func login() {
        isLoading = true
        error = nil

        Task {
            do {
                // Create Basic auth token
                let credentials = "\(email):\(apiToken)"
                let encodedCredentials = Data(credentials.utf8).base64EncodedString()
                let basicToken = "Basic \(encodedCredentials)"

                // For Jira Server/Data Center, we use Basic auth
                // For Jira Cloud with API token, we also use Basic auth
                // Extract cloud ID from site URL
                var cleanSiteUrl = siteUrl.trimmingCharacters(in: .whitespaces)
                if !cleanSiteUrl.hasPrefix("https://") {
                    cleanSiteUrl = "https://\(cleanSiteUrl)"
                }

                // For cloud, we need to get the cloud ID
                // Using the REST API directly with Basic auth
                let cloudId = cleanSiteUrl
                    .replacingOccurrences(of: "https://", with: "")
                    .replacingOccurrences(of: ".atlassian.net", with: "")
                    .replacingOccurrences(of: "/", with: "")

                // Save credentials
                try await KeychainManager.shared.saveJiraToken(basicToken)
                try await KeychainManager.shared.saveJiraCloudId(cloudId)
                try await KeychainManager.shared.saveJiraSiteUrl(cleanSiteUrl)

                // Configure service for direct REST API access
                await JiraService.shared.setAccessToken(basicToken, cloudId: cloudId, siteUrl: cleanSiteUrl)

                await MainActor.run {
                    viewModel.isAuthenticated = true
                    isLoading = false
                }

                await viewModel.loadProjects()
                try? await viewModel.refresh()
            } catch {
                await MainActor.run {
                    self.error = "Failed to connect: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}
