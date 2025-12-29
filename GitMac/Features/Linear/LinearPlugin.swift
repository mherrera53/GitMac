//
//  LinearPlugin.swift
//  GitMac
//
//  Created on 2025-12-28.
//  Plugin System - Linear Integration Plugin
//

import SwiftUI

/// Linear integration plugin
/// Provides access to Linear teams and issues
struct LinearPlugin: IntegrationPlugin {
    let id = "linear"
    let name = "Linear"
    let icon = "lineweight"
    let iconColor = Color(hex: "5E6AD2")

    typealias ViewModel = LinearViewModel
    typealias ContentView = LinearContentView

    @MainActor func makeViewModel() -> LinearViewModel {
        LinearViewModel()
    }

    func makeContentView(viewModel: LinearViewModel) -> LinearContentView {
        LinearContentView(viewModel: viewModel)
    }
}
