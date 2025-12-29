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
            if viewModel.isLoading {
                DSLoadingState(message: "Loading project data...")
            } else if viewModel.selectedProjectId == nil {
                DSEmptyState(
                    icon: "folder",
                    title: "Select a Project",
                    description: "Choose a project from the dropdown above to view its items."
                )
            } else {
                switch selectedTab {
                case .userStories:
                    TaigaUserStoriesView(stories: viewModel.userStories, viewModel: viewModel)
                case .tasks:
                    TaigaTasksView(tasks: viewModel.tasks)
                case .issues:
                    TaigaIssuesView(issues: viewModel.issues)
                case .epics:
                    TaigaEpicsView(epics: viewModel.epics)
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
