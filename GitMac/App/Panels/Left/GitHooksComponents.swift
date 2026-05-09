//
//  GitHooksComponents.swift
//  GitMac
//
//  Extracted from ContentView.swift
//  Contains: GitHooksSidebarSection
//

import SwiftUI
import Foundation

// MARK: - Git Hooks Sidebar Section
struct GitHooksSidebarSection: View {
    @Environment(AppState.self) var appState
    @StateObject private var viewModel = GitHooksViewModel()
    @State private var showHooksView = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if viewModel.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Loading...")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textMuted)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            } else {
                Button(action: { showHooksView = true }) {
                    HStack {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textSecondary)
                        Text("\(viewModel.enabledCount) of \(viewModel.hooks.count) enabled")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.textSecondary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9))
                            .foregroundStyle(AppTheme.accent)
                    }
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                }
                .buttonStyle(.plain)
            }
        }
        .task {
            await loadHooks()
        }
        .sheet(isPresented: $showHooksView) {
            GitHooksView()
                .environment(appState)
                .frame(minWidth: DesignTokens.Layout.HooksPanel.minWidth, minHeight: DesignTokens.Layout.HooksPanel.minHeight)
        }
    }

    private func loadHooks() async {
        guard let repoPath = appState.currentRepository?.path else { return }
        await viewModel.loadHooks(at: repoPath)
    }
}
