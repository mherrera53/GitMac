//
//  WelcomeView.swift
//  GitMac
//
//  Welcome screen shown when no repository is open
//

import SwiftUI

struct WelcomeView: View {
    let onOpen: () -> Void
    let onClone: () -> Void
    @EnvironmentObject var recentReposManager: RecentRepositoriesManager
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 0) {
            // Left side - Actions
            VStack(spacing: 24) {
                Spacer()

                // App Icon
                if let appIcon = NSImage(named: NSImage.applicationIconName) {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                } else {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppTheme.accent, AppTheme.info],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                Text("GitMac")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)

                Text("A Git client for Mac")
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.textSecondary)

                HStack(spacing: 16) {
                    WelcomeButton(icon: "folder", title: "Open", color: AppTheme.accent, action: onOpen)
                    WelcomeButton(icon: "arrow.down.circle", title: "Clone", color: AppTheme.success, action: onClone)
                    WelcomeButton(icon: "plus.circle", title: "Init", color: AppTheme.accent) {
                        NotificationCenter.default.post(name: .initRepository, object: nil)
                    }
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(AppTheme.background)

            // Right side - Recent repos
            VStack(alignment: .leading, spacing: 0) {
                Text("RECENT REPOSITORIES")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.textMuted)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                ScrollView {
                    VStack(spacing: 0) {
                        if recentReposManager.recentRepos.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "clock")
                                    .font(.system(size: 32))
                                    .foregroundColor(AppTheme.textMuted)
                                Text("No recent repositories")
                                    .foregroundColor(AppTheme.textMuted)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                        } else {
                            ForEach(recentReposManager.recentRepos) { repo in
                                RecentRepoRow(repo: repo)
                            }
                        }
                    }
                }
            }
            .frame(width: 320)
            .background(AppTheme.backgroundSecondary)
        }
    }
}

// MARK: - Welcome Button

struct WelcomeButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(isHovered ? .white : color)
            .frame(width: 80, height: 80)
            .background(isHovered ? color : color.opacity(0.15))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Recent Repo Row

struct RecentRepoRow: View {
    let repo: RecentRepository
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var recentReposManager: RecentRepositoriesManager
    @State private var isHovered = false

    var body: some View {
        Button {
            Task {
                await appState.openRepository(at: repo.path)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 20))
                    .foregroundColor(AppTheme.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(repo.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.textPrimary)
                    Text(repo.path)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textMuted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(isHovered ? AppTheme.hover : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
