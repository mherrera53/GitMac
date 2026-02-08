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
    var onFileSaved: (() -> Void)? = nil
    var onStageHunk: ((Int) async -> Bool)? = nil
    var onDiscardHunk: ((Int) async -> Bool)? = nil
    var onUnstageHunk: ((Int) async -> Bool)? = nil

    var body: some View {
        DiffView(
            fileDiff: fileDiff,
            repoPath: repoPath,
            onClose: onClose,
            onFileSaved: onFileSaved,
            onStageHunk: onStageHunk,
            onDiscardHunk: onDiscardHunk,
            onUnstageHunk: onUnstageHunk
        )
    }
}
