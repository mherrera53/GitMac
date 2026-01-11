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
        DiffView(fileDiff: fileDiff, repoPath: repoPath, onClose: onClose)
    }
}
