//
//  SubmoduleComponents.swift
//  GitMac
//
//  Extracted from ContentView.swift
//  Contains: SubmoduleSidebarSection, SubmoduleSidebarRow
//

import SwiftUI
import Foundation

// MARK: - Submodule Sidebar Section
struct SubmoduleSidebarSection: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = SubmoduleViewViewModel()
    @State private var showSubmoduleView = false

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
            } else if viewModel.submodules.isEmpty {
                Button(action: { showSubmoduleView = true }) {
                    HStack {
                        Image(systemName: "cube.transparent")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textMuted)
                        Text("No submodules")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.textMuted)
                        Spacer()
                        Image(systemName: "plus.circle")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.accent)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            } else {
                ForEach(viewModel.submodules.prefix(3)) { submodule in
                    SubmoduleSidebarRow(submodule: submodule)
                }

                if viewModel.submodules.count > 3 {
                    Button(action: { showSubmoduleView = true }) {
                        HStack {
                            Text("View all \(viewModel.submodules.count) submodules")
                                .font(.system(size: 10))
                                .foregroundStyle(AppTheme.accent)
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
        }
        .task {
            await loadSubmodules()
        }
        .sheet(isPresented: $showSubmoduleView) {
            SubmoduleView()
                .environmentObject(appState)
                .frame(minWidth: DesignTokens.Layout.SubmodulePanel.minWidth, minHeight: DesignTokens.Layout.SubmodulePanel.minHeight)
        }
    }

    private func loadSubmodules() async {
        guard let repoPath = appState.currentRepository?.path else { return }
        await viewModel.loadSubmodules(at: repoPath)
    }
}

// MARK: - Submodule Sidebar Row
struct SubmoduleSidebarRow: View {
    let submodule: GitSubmodule
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: submodule.status == .initialized ? "cube.fill" : "cube.transparent")
                .font(.system(size: 11))
                .foregroundStyle(submodule.status == .initialized ? AppTheme.accent : AppTheme.textMuted)

            Text(submodule.displayName)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(isHovered ? AppTheme.hover : Color.clear)
        .onHover { isHovered = $0 }
    }
}
