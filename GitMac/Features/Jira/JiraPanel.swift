//
//  JiraPanel.swift
//  GitMac
//
//  Created on 2025-12-28.
//  Main panel for Jira integration
//

import SwiftUI

// MARK: - Jira Panel (Bottom Panel)

struct JiraPanel: View {
    @Binding var height: CGFloat
    let onClose: () -> Void
    @StateObject private var viewModel = JiraViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Resizer handle
            UniversalResizer(
                dimension: $height,
                minDimension: 150,
                maxDimension: 500,
                orientation: .vertical
            )

            // Panel content
            VStack(spacing: 0) {
                // Header
                HStack(spacing: DesignTokens.Spacing.md) {
                    DSIcon("square.stack.3d.up.fill", size: .md, color: Color(hex: "0052CC"))

                    Text("Jira")
                        .font(DesignTokens.Typography.headline)
                        .foregroundColor(AppTheme.textPrimary)

                    Spacer()

                    // Refresh button
                    DSIconButton(
                        iconName: "arrow.clockwise",
                        variant: .ghost,
                        size: .sm
                    ) {
                        try? await viewModel.refresh()
                    }
                    .disabled(viewModel.isLoading)

                    // Settings button
                    DSIconButton(
                        iconName: "gear",
                        variant: .ghost,
                        size: .sm
                    ) {
                        viewModel.showSettings = true
                    }

                    // Close button
                    DSCloseButton {
                        onClose()
                    }
                }
                .padding(DesignTokens.Spacing.md)
                .background(AppTheme.backgroundSecondary)

                DSDivider()

                // Content
                if viewModel.isLoading && !viewModel.isAuthenticated {
                    DSLoadingState(message: "Loading...")
                } else if let error = viewModel.error {
                    DSErrorState(
                        message: error,
                        onRetry: {
                            try? await viewModel.refresh()
                        }
                    )
                } else if !viewModel.isAuthenticated {
                    JiraLoginPrompt(viewModel: viewModel)
                } else {
                    JiraContentView(viewModel: viewModel)
                }
            }
            .background(AppTheme.background)
        }
        .frame(height: height)
        .sheet(isPresented: $viewModel.showSettings) {
            JiraSettingsSheet(viewModel: viewModel)
        }
    }
}

// MARK: - Content View

struct JiraContentView: View {
    @ObservedObject var viewModel: JiraViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Filter controls
            VStack(spacing: DesignTokens.Spacing.sm) {
                if !viewModel.projects.isEmpty {
                    Picker("", selection: $viewModel.selectedProjectKey) {
                        Text("All projects").tag(nil as String?)
                        ForEach(viewModel.projects) { project in
                            Text("\(project.key) - \(project.name)").tag(project.key as String?)
                        }
                    }
                    .labelsHidden()
                    .padding(.horizontal, DesignTokens.Spacing.md)
                }

                Picker("", selection: $viewModel.filterMode) {
                    Text("My Issues").tag(JiraFilterMode.myIssues)
                    Text("Project").tag(JiraFilterMode.project)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, DesignTokens.Spacing.md)
            }
            .padding(.vertical, DesignTokens.Spacing.sm)

            DSDivider()

            // Issues list
            if viewModel.isLoading {
                DSLoadingState(message: "Loading issues...")
            } else if viewModel.issues.isEmpty {
                DSEmptyState(
                    icon: "tray",
                    title: "No Issues Found",
                    description: "No issues match your current filter criteria."
                )
            } else {
                JiraIssuesListView(issues: viewModel.issues)
            }
        }
        .onChange(of: viewModel.selectedProjectKey) { _, _ in
            Task { try? await viewModel.refresh() }
        }
        .onChange(of: viewModel.filterMode) { _, _ in
            Task { try? await viewModel.refresh() }
        }
    }
}

// MARK: - Issues List

struct JiraIssuesListView: View {
    let issues: [JiraIssue]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: DesignTokens.Spacing.xs) {
                ForEach(issues) { issue in
                    JiraIssueRow(issue: issue)
                }
            }
            .padding(DesignTokens.Spacing.sm)
        }
    }
}

struct JiraIssueRow: View {
    let issue: JiraIssue
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // Issue type icon
            if let issueType = issue.fields.issuetype {
                Image(systemName: issueTypeIcon(issueType.name))
                    .font(DesignTokens.Typography.callout)
                    .foregroundColor(issueTypeColor(issueType.name))
            }

            // Issue key
            Text(issue.key)
                .font(DesignTokens.Typography.callout)
                .foregroundColor(AppTheme.textSecondary)

            // Issue summary
            Text(issue.fields.summary)
                .font(DesignTokens.Typography.body)
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(2)

            Spacer()

            // Priority
            if let priority = issue.fields.priority {
                Text(priority.name)
                    .font(DesignTokens.Typography.caption2)
                    .foregroundColor(priorityColor(priority.name))
            }

            // Status badge
            if let status = issue.fields.status {
                Text(status.name)
                    .font(DesignTokens.Typography.caption2)
                    .foregroundColor(statusColor(status))
                    .padding(.horizontal, DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
                    .padding(.vertical, DesignTokens.Spacing.xxs)
                    .background(statusColor(status).opacity(0.2))
                    .cornerRadius(DesignTokens.CornerRadius.sm)
            }

            // Insert button (shown on hover)
            if isHovered {
                DSIconButton(
                    iconName: "arrow.right.doc.on.clipboard",
                    variant: .ghost,
                    size: .sm
                ) {
                    NotificationCenter.default.post(
                        name: .insertJiraRef,
                        object: nil,
                        userInfo: ["key": issue.key, "summary": issue.fields.summary]
                    )
                }
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(isHovered ? AppTheme.backgroundSecondary : Color.clear)
        .cornerRadius(DesignTokens.CornerRadius.md)
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.fastEasing) {
                isHovered = hovering
            }
        }
    }

    private func issueTypeIcon(_ type: String) -> String {
        switch type.lowercased() {
        case "bug": return "ladybug.fill"
        case "story", "user story": return "book.fill"
        case "task": return "checkmark.square"
        case "epic": return "bolt.fill"
        case "subtask", "sub-task": return "arrow.turn.down.right"
        default: return "circle.fill"
        }
    }

    private func issueTypeColor(_ type: String) -> Color {
        switch type.lowercased() {
        case "bug": return AppTheme.error
        case "story", "user story": return AppTheme.success
        case "task": return AppTheme.accent
        case "epic": return AppTheme.accentPurple
        default: return AppTheme.textSecondary
        }
    }

    private func priorityColor(_ priority: String) -> Color {
        switch priority.lowercased() {
        case "highest", "blocker": return AppTheme.error
        case "high", "critical": return AppTheme.warning
        case "medium": return AppTheme.warning
        case "low": return AppTheme.accent
        case "lowest": return AppTheme.textSecondary
        default: return AppTheme.textSecondary
        }
    }

    private func statusColor(_ status: JiraStatus) -> Color {
        if let category = status.statusCategory {
            switch category.key {
            case "new", "undefined": return AppTheme.textSecondary
            case "indeterminate": return AppTheme.accent
            case "done": return AppTheme.success
            default: return AppTheme.textSecondary
            }
        }
        return AppTheme.textSecondary
    }
}

// MARK: - Login Prompt

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
                .font(DesignTokens.Typography.headline) // Was: .system(size: 15, weight: .semibold)
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

// MARK: - Settings Sheet

struct JiraSettingsSheet: View {
    @ObservedObject var viewModel: JiraViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Jira Settings")
                    .font(DesignTokens.Typography.headline) // Was: .system(size: 15, weight: .semibold)
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(DesignTokens.Typography.callout) // Was: .system(size: 12, weight: .medium)
                        .foregroundColor(AppTheme.textMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(DesignTokens.Spacing.lg)
            .background(AppTheme.toolbar)

            Rectangle().fill(AppTheme.border).frame(height: 1)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                if viewModel.isAuthenticated {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppTheme.success)
                        Text("Connected to Jira")
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(AppTheme.textPrimary)
                    }

                    Button("Disconnect") {
                        viewModel.logout()
                        dismiss()
                    }
                    .foregroundColor(AppTheme.error)
                } else {
                    Text("Not connected to Jira")
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            .padding(DesignTokens.Spacing.lg)

            Spacer()
        }
        .frame(width: 350, height: 200)
        .background(AppTheme.panel)
    }
}

// MARK: - Notification

extension Notification.Name {
    static let insertJiraRef = Notification.Name("insertJiraRef")
}
