//
//  TaigaContentView.swift
//  GitMac
//
//  Created on 2025-12-28.
//  Content view for Taiga integration
//

import SwiftUI

/// Content view for Taiga integration
/// Displays tabbed view with user stories, tasks, issues, and epics
struct TaigaContentView: View {
    @ObservedObject var viewModel: TaigaTicketsViewModel
    @State private var selectedTab: TaigaTab = .userStories

    var body: some View {
        VStack(spacing: 0) {
            // Project selector and tabs
            VStack(spacing: DesignTokens.Spacing.sm) {
                if !viewModel.projects.isEmpty {
                    Picker("", selection: $viewModel.selectedProjectId) {
                        Text("Select project...").tag(nil as Int?)
                        ForEach(viewModel.projects) { project in
                            Text(project.name).tag(project.id as Int?)
                        }
                    }
                    .labelsHidden()
                    .padding(.horizontal, DesignTokens.Spacing.md)
                }

                Picker("", selection: $selectedTab) {
                    ForEach(TaigaTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, DesignTokens.Spacing.md)
            }
            .padding(.vertical, DesignTokens.Spacing.sm)

            DSDivider()

            // Tab content
            // Tab content
            if viewModel.isLoading {
                DSLoadingState(message: "Loading project data...")
            } else if let error = viewModel.error {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 24))
                        .foregroundColor(AppTheme.error)
                    Text("Connection Error")
                        .font(.headline)
                        .foregroundColor(AppTheme.textPrimary)
                    Text(error)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button("Retry") {
                        Task { try? await viewModel.refresh() }
                    }
                    .buttonStyle(.plain)
                    .padding(.top, DesignTokens.Spacing.sm)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.selectedProjectId == nil {
                DSEmptyState(
                    icon: "folder",
                    title: "Select a Project",
                    description: "Choose a project from the dropdown above to view its items."
                )
            } else {
                switch selectedTab {
                case .userStories:
                    if viewModel.userStories.isEmpty {
                        DSEmptyState(icon: "doc.text", title: "No Stories", description: "No user stories found for this project.")
                    } else {
                        TaigaUserStoriesView(stories: viewModel.userStories, viewModel: viewModel)
                    }
                case .tasks:
                    if viewModel.tasks.isEmpty {
                        DSEmptyState(icon: "checklist", title: "No Tasks", description: "No tasks found for this project.")
                    } else {
                        TaigaTasksView(tasks: viewModel.tasks)
                    }
                case .issues:
                    if viewModel.issues.isEmpty {
                        DSEmptyState(icon: "exclamationmark.circle", title: "No Issues", description: "No issues found for this project.")
                    } else {
                        TaigaIssuesView(issues: viewModel.issues)
                    }
                case .epics:
                    if viewModel.epics.isEmpty {
                        DSEmptyState(icon: "flag", title: "No Epics", description: "No epics found for this project.")
                    } else {
                        TaigaEpicsView(epics: viewModel.epics)
                    }
                }
            }
        }
        .onChange(of: viewModel.selectedProjectId) { _, newId in
            if let id = newId {
                Task { await viewModel.loadProjectData(projectId: id) }
            }
        }
    }
}
