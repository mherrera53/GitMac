//
//  NotionContentView.swift
//  GitMac
//
//  Created on 2025-12-28.
//  Notion Integration - Content View for DSIntegrationPanel
//

import SwiftUI

/// Content view for Notion integration
/// Displays database selector and tasks list
struct NotionContentView: View {
    @ObservedObject var viewModel: NotionViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Database selector
            if !viewModel.databases.isEmpty {
                HStack(spacing: DesignTokens.Spacing.md) {
                    DSIcon("folder.fill", size: .sm, color: AppTheme.textSecondary)

                    Picker("", selection: $viewModel.selectedDatabaseId) {
                        Text("Select database...").tag(nil as String?)
                        ForEach(viewModel.databases) { db in
                            Text(db.displayTitle).tag(db.id as String?)
                        }
                    }
                    .labelsHidden()
                }
                .padding(DesignTokens.Spacing.md)
                .background(AppTheme.backgroundSecondary)

                DSDivider()
            }

            // Content
            if viewModel.isLoading {
                DSLoadingState(message: "Loading tasks...")
            } else if viewModel.selectedDatabaseId == nil {
                DSEmptyState(
                    icon: "tray",
                    title: "No Database Selected",
                    description: "Select a database to view tasks"
                )
            } else if viewModel.tasks.isEmpty {
                DSEmptyState(
                    icon: "checkmark.circle",
                    title: "No Tasks",
                    description: "This database has no tasks"
                )
            } else {
                NotionTasksListView(tasks: viewModel.tasks)
            }
        }
        .onChange(of: viewModel.selectedDatabaseId) { _, newId in
            if let id = newId {
                UserDefaults.standard.set(id, forKey: "notion_selected_database_id")
                Task { await viewModel.loadTasks(databaseId: id) }
            }
        }
    }
}

// MARK: - Tasks List

struct NotionTasksListView: View {
    let tasks: [NotionTask]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: DesignTokens.Spacing.xs) {
                ForEach(tasks) { task in
                    NotionTaskRow(task: task)
                }
            }
            .padding(DesignTokens.Spacing.sm)
        }
    }
}

struct NotionTaskRow: View {
    let task: NotionTask

    var body: some View {
        let isDone = task.status?.lowercased() == "done"

        PanelIssueRow(
            identifier: nil,
            title: task.title,
            leadingIcon: {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(DesignTokens.Typography.callout)
                    .foregroundColor(isDone ? AppTheme.success : AppTheme.textSecondary)
            },
            statusBadge: {
                if let status = task.status {
                    StatusBadge(text: status, color: statusColor(task.statusColor))
                }
            },
            metadata: {
                if let url = task.url {
                    Link(destination: URL(string: url)!) {
                        Image(systemName: "arrow.up.right.square")
                            .font(DesignTokens.Typography.caption2)
                            .foregroundColor(AppTheme.textMuted)
                    }
                    .help("Open in Notion")
                }
            },
            onInsert: {
                NotificationCenter.default.post(
                    name: .insertNotionRef,
                    object: nil,
                    userInfo: ["title": task.title, "id": task.id]
                )
            }
        )
    }

    private func statusColor(_ color: String?) -> Color {
        guard let color = color else { return AppTheme.textSecondary }
        switch color {
        case "gray": return AppTheme.textSecondary
        case "brown": return Color(hex: "8B4513")  // Notion API color, do not change
        case "orange": return AppTheme.warning
        case "yellow": return AppTheme.warning
        case "green": return AppTheme.success
        case "blue": return AppTheme.accent
        case "purple": return AppTheme.accentPurple
        case "pink": return Color(hex: "FF69B4")  // Notion API color, do not change
        case "red": return AppTheme.error
        default: return AppTheme.textSecondary
        }
    }
}
