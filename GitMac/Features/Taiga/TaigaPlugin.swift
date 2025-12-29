//
//  TaigaPlugin.swift
//  GitMac
//
//  Created on 2025-12-28.
//  Integration Plugin for Taiga
//

import SwiftUI

/// Taiga integration plugin
struct TaigaPlugin: IntegrationPlugin {
    let id = "taiga"
    let name = "Taiga"
    let icon = "ticket.fill"
    let iconColor = Color.green

    typealias ViewModel = TaigaTicketsViewModel
    typealias ContentView = TaigaContentView

    @MainActor func makeViewModel() -> TaigaTicketsViewModel {
        TaigaTicketsViewModel()
    }

    func makeContentView(viewModel: TaigaTicketsViewModel) -> TaigaContentView {
        TaigaContentView(viewModel: viewModel)
    }
}
