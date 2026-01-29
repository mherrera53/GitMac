//
//  WorktreeComponents.swift
//  GitMac
//
//  Extracted from ContentView.swift
//  Contains: WorktreeSidebarSection, WorktreeSidebarRow
//

import SwiftUI
import Foundation

// MARK: - Worktree Sidebar Section
struct WorktreeSidebarSection: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = WorktreeListViewModel()
    @State private var showAddSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.6)
                    Spacer()
                }
                .padding(.vertical, 8)
            } else {
                ForEach(viewModel.worktrees) { worktree in
                    WorktreeSidebarRow(worktree: worktree)
                }

                if viewModel.worktrees.isEmpty {
                    Text("No worktrees")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textMuted)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                }

                // Add worktree button
                Button {
                    showAddSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10))
                        Text("Add Worktree")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(AppTheme.textMuted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .task {
            await viewModel.refresh(at: appState.currentRepository?.path)
        }
        .onChange(of: appState.currentRepository?.path) { _, newPath in
            Task { await viewModel.refresh(at: newPath) }
        }
        .sheet(isPresented: $showAddSheet) {
            AddWorktreeSheet(viewModel: viewModel)
        }
    }
}

// MARK: - Worktree Sidebar Row
struct WorktreeSidebarRow: View {
    let worktree: Worktree
    @EnvironmentObject var appState: AppState
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: worktree.isMain ? "house.fill" : "folder.fill")
                .font(.system(size: 11))
                .foregroundStyle(worktree.isMain ? AppTheme.accent : AppTheme.accent)

            Text(worktree.name)
                .font(.system(size: 11))
                .foregroundStyle(worktree.isMain ? AppTheme.textPrimary : AppTheme.textSecondary)
                .lineLimit(1)

            if worktree.isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(AppTheme.warning)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(isHovered ? AppTheme.hover : Color.clear)
        .onHover { isHovered = $0 }
        .onTapGesture(count: 2) {
            // Open worktree in new tab
            Task {
                await appState.openRepository(at: worktree.path)
            }
        }
    }
}
