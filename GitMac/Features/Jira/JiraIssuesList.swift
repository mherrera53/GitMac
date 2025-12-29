//
//  JiraIssuesList.swift
//  GitMac
//
//  Created on 2025-12-29.
//  Issues list components for Jira integration
//

import SwiftUI

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

// MARK: - Issue Row

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

    // MARK: - Helper Methods

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

// MARK: - Notification

extension Notification.Name {
    static let insertJiraRef = Notification.Name("insertJiraRef")
}
