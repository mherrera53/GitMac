//
//  NotionPlugin.swift
//  GitMac
//
//  Created on 2025-12-28.
//  Plugin System - Notion Integration Plugin
//

import SwiftUI

/// Notion integration plugin
/// Provides access to Notion databases and tasks
struct NotionPlugin: IntegrationPlugin {
    let id = "notion"
    let name = "Notion"
    let icon = "doc.text.fill"
    let iconColor = Color.primary

    typealias ViewModel = NotionViewModel
    typealias ContentView = NotionContentView

    @MainActor func makeViewModel() -> NotionViewModel {
        NotionViewModel()
    }

    func makeContentView(viewModel: NotionViewModel) -> NotionContentView {
        NotionContentView(viewModel: viewModel)
    }
}
