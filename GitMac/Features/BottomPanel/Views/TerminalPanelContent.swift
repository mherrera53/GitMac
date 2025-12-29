//
//  TerminalPanelContent.swift
//  GitMac
//
//  Created by GitMac on 2025-12-28.
//

import SwiftUI

struct TerminalPanelContent: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        // The existing TerminalView has its own internal tab system (TerminalTabManager)
        // It will display its own tabs within this panel
        TerminalView()
            .environmentObject(appState)
    }
}
