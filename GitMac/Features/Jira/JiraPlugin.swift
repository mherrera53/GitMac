//
//  JiraPlugin.swift
//  GitMac
//
//  Created on 2025-12-28.
//  Integration Plugin for Jira
//

import SwiftUI

/// Jira integration plugin
struct JiraPlugin: IntegrationPlugin {
    let id = "jira"
    let name = "Jira"
    let icon = "square.stack.3d.up.fill"
    let iconColor = Color(hex: "0052CC")

    @MainActor func makeViewModel() -> JiraViewModel {
        JiraViewModel()
    }

    func makeContentView(viewModel: JiraViewModel) -> some View {
        JiraContentView(viewModel: viewModel)
    }
}
