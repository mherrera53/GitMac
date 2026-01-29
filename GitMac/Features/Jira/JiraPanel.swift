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
                    DSIcon("square.stack.3d.up.fill", size: .md, color: SwiftUI.Color(hex: "0052CC"))

                    Text("Jira")
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(AppTheme.textPrimary)

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

// Note: JiraContentView is defined in JiraContentView.swift

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
                    .foregroundStyle(issueTypeColor(issueType.name))
            }

            // Issue key
            Text(issue.key)
                .font(DesignTokens.Typography.callout)
                .foregroundStyle(AppTheme.textSecondary)

            // Issue summary
            Text(issue.fields.summary)
                .font(DesignTokens.Typography.body)
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(2)

            Spacer()

            // Priority
            if let priority = issue.fields.priority {
                Text(priority.name)
                    .font(DesignTokens.Typography.caption2)
                    .foregroundStyle(priorityColor(priority.name))
            }

            // Status badge
            if let status = issue.fields.status {
                Text(status.name)
                    .font(DesignTokens.Typography.caption2)
                    .foregroundStyle(statusColor(status))
                    .padding(.horizontal, DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
                    .padding(.vertical, DesignTokens.Spacing.xxs)
                    .background(statusColor(status).opacity(0.2))
                    .clipShape(.rect(cornerRadius: DesignTokens.CornerRadius.sm))
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
        .clipShape(.rect(cornerRadius: DesignTokens.CornerRadius.md))
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

// Note: JiraLoginPrompt is defined in JiraLoginPrompt.swift

// MARK: - Settings Sheet

struct JiraSettingsSheet: View {
    @ObservedObject var viewModel: JiraViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Jira Settings")
                    .font(DesignTokens.Typography.headline) // Was: .system(size: 15, weight: .semibold)
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(DesignTokens.Typography.callout) // Was: .system(size: 12, weight: .medium)
                        .foregroundStyle(AppTheme.textMuted)
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
                            .foregroundStyle(AppTheme.success)
                        Text("Connected to Jira")
                            .font(DesignTokens.Typography.body)
                            .foregroundStyle(AppTheme.textPrimary)
                    }

                    Button("Disconnect") {
                        viewModel.logout()
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.error)
                } else {
                    Text("Not connected to Jira")
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(AppTheme.textSecondary)
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
