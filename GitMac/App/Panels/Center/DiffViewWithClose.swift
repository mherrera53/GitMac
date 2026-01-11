//
//  DiffViewWithClose.swift
//  GitMac
//
//  Extracted from ContentView.swift
//

import SwiftUI

// MARK: - Diff View with Close
struct DiffViewWithClose: View {
    let fileDiff: FileDiff
    var repoPath: String? = nil
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Close button overlay
            HStack {
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppTheme.textMuted)
                }
                .buttonStyle(.plain)
                .padding(8)
            }
            .background(AppTheme.backgroundSecondary.opacity(0.8))

            // Use standard diff viewer
            DiffView(fileDiff: fileDiff, repoPath: repoPath)
        }
    }
}
