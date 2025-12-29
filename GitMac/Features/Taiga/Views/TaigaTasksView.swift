//
//  TaigaTasksView.swift
//  GitMac
//
//  Created on 2025-12-28.
//  Tasks list view for Taiga integration
//

import SwiftUI

struct TaigaTasksView: View {
    let tasks: [TaigaTask]

    var body: some View {
        if tasks.isEmpty {
            TaigaEmptyView(type: "tasks")
        } else {
            List(tasks) { task in
                TaigaTaskRow(task: task)
            }
            .listStyle(.plain)
        }
    }
}

struct TaigaTaskRow: View {
    let task: TaigaTask

    private var taigaRef: String {
        "TG-\(task.ref)"
    }

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // Leading icon with status color
            HStack(spacing: DesignTokens.Spacing.xs) {
                Circle()
                    .fill(Color(hex: task.statusExtraInfo?.color ?? "888888"))
                    .frame(width: 8, height: 8)

                Button {
                    copyToClipboard(taigaRef)
                } label: {
                    Text(taigaRef)
                        .font(DesignTokens.Typography.caption2)
                        .fontWeight(.bold)
                        .fontDesign(.monospaced)
                        .foregroundColor(AppTheme.textPrimary)
                        .padding(.horizontal, DesignTokens.Spacing.xs)
                        .padding(.vertical, 1)
                        .background(AppTheme.warning)
                        .cornerRadius(DesignTokens.CornerRadius.sm)
                }
                .buttonStyle(.plain)
                .help("Click to copy \(taigaRef)")
            }

            // Task title
            Text(task.subject)
                .font(DesignTokens.Typography.callout)
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(2)

            Spacer()

            // Assignee metadata
            if let assignee = task.assignedToExtraInfo {
                Text(assignee.username)
                    .font(DesignTokens.Typography.caption2)
                    .foregroundColor(AppTheme.textSecondary)
            }

            // Status badge using DSStatusBadge
            if let status = task.statusExtraInfo {
                DSStatusBadge(status.name, variant: .neutral, size: .sm)
            }

            // Insert button
            Button {
                NotificationCenter.default.post(
                    name: .insertTaigaRef,
                    object: nil,
                    userInfo: ["ref": taigaRef, "subject": task.subject]
                )
            } label: {
                Image(systemName: "arrow.right.doc.on.clipboard")
                    .font(DesignTokens.Typography.caption2)
                    .foregroundColor(AppTheme.accent)
            }
            .buttonStyle(.plain)
            .help("Insert into commit message")
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
