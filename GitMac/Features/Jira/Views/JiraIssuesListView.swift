//
//  JiraIssuesListView.swift
//  GitMac
//
//  Created on 2025-12-28.
//  Issues list view for Jira integration
//

import SwiftUI

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

    var body: some View {
        PanelIssueRow(
            identifier: issue.key,
            title: issue.fields.summary,
            leadingIcon: {
                if let issueType = issue.fields.issuetype {
                    Image(systemName: issueTypeIcon(issueType.name))
                        .font(DesignTokens.Typography.callout)
                        .foregroundColor(issueTypeColor(issueType.name))
                }
            },
            statusBadge: {
                if let status = issue.fields.status {
                    StatusBadge(text: status.name, color: statusColor(status))
                }
            },
            metadata: {
                if let priority = issue.fields.priority {
                    Text(priority.name)
                        .font(DesignTokens.Typography.caption2)
                        .foregroundColor(priorityColor(priority.name))
                }
            },
            onInsert: {
                NotificationCenter.default.post(
                    name: .insertJiraRef,
                    object: nil,
                    userInfo: ["key": issue.key, "summary": issue.fields.summary]
                )
            }
        )
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

// MARK: - Notification

extension Notification.Name {
    static let insertJiraRef = Notification.Name("insertJiraRef")
}
