//
//  TerminalPanel.swift
//  GitMac
//
//  Extracted from ContentView.swift
//

import SwiftUI

// MARK: - Terminal Panel
struct TerminalPanel: View {
    @Binding var height: CGFloat
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Resizer handle
            UniversalResizer(
                dimension: $height,
                minDimension: DesignTokens.Layout.BottomPanel.minHeight,
                maxDimension: DesignTokens.Layout.BottomPanel.maxHeight,
                orientation: .vertical
            )

            // Terminal content - Ghostty Native
            #if GHOSTTY_AVAILABLE
            GhosttyNativeView()
                .frame(height: height)
            #else
            TerminalView()
                .frame(height: height)
            #endif
        }
        .background(AppTheme.background)
    }
}
