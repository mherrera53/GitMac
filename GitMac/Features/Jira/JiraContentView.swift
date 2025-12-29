//
//  JiraContentView.swift
//  GitMac
//
//  Created on 2025-12-28.
//  Content view for Jira integration
//

import SwiftUI

/// Content view for Jira integration
/// Displays issues list with filtering controls
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
