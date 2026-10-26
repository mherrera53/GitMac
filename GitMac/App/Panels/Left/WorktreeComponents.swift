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
    @Environment(AppState.self) var appState
    @StateObject private var manager = WorktreeManager.shared
    @State private var showAddSheet = false
    @State private var showManager = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Worktrees").font(.caption.weight(.semibold))
                Spacer()
                GitHelpButton(topicID: "worktrees")
            }.padding(.horizontal, 8)
            if manager.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.6)
                    Spacer()
                }
                .padding(.vertical, 8)
            } else {
                ForEach(manager.worktrees, id: \.path) { worktree in
                    WorktreeSidebarRow(worktree: worktree)
                }

                if manager.worktrees.isEmpty {
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
            Button("Manage Worktrees…", systemImage: "slider.horizontal.3") { showManager = true }
                .buttonStyle(.borderless).padding(8)
                .help("Open folders, protect worktrees and review removal safely")
        }
        .task(id: appState.currentRepository?.path) {
            await manager.refresh(at: appState.currentRepository?.path)
        }
        .sheet(isPresented: $showAddSheet) {
            AddWorktreeSheet()
        }
        .sheet(isPresented: $showManager) {
            WorktreeListView()
                .frame(minWidth: 480, idealWidth: 680, maxWidth: 900, minHeight: 340, idealHeight: 520, maxHeight: 700)
        }
    }
}

// MARK: - Worktree Sidebar Row
struct WorktreeSidebarRow: View {
    let worktree: Worktree
    @Environment(AppState.self) var appState
    @State private var isHovered = false

    var body: some View {
        Button {
            Task { await appState.openRepository(at: worktree.path) }
        } label: {
          HStack(spacing: 8) {
            Image(systemName: worktree.isMain ? "house.fill" : "folder.fill")
                .font(.system(size: 11))
                .foregroundStyle(worktree.isMain ? AppTheme.accent : AppTheme.accent)

            VStack(alignment: .leading, spacing: 2) {
              Text(worktree.name)
                .font(.system(size: 11))
                .foregroundStyle(worktree.isMain ? AppTheme.textPrimary : AppTheme.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
              Text(worktree.branch ?? (worktree.isBare ? "Bare repository" : "Detached \(worktree.shortSHA)"))
                  .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }

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
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(worktree.isPrunable || worktree.isBare)
        .help("Open worktree folder: \(worktree.path)")
        .accessibilityLabel("Open \(worktree.name), \(worktree.branch ?? "detached revision")")
        .onHover { isHovered = $0 }
    }
}
