//
//  WelcomeView.swift
//  GitMac
//
//  Welcome screen shown when no repository is open
//

import SwiftUI

// MARK: - App Icon View

/// Displays the official GitMac app icon from the bundle
struct AppIconView: View {
    let size: CGFloat
    @State private var appIcon: NSImage?
    @State private var retryCount = 0

    var body: some View {
        Group {
            if let icon = appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
            } else {
                // Fallback with gradient while loading
                RoundedRectangle(cornerRadius: size * 0.2)
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.accent, AppTheme.info],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                    .overlay(
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: size * 0.5))
                            .foregroundColor(.white)
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
            }
        }
        .task {
            await loadIconAsync()
        }
    }

    @MainActor
    private func loadIconAsync() async {
        // Try multiple times with delay (icon might not be ready immediately in Xcode)
        for attempt in 0..<3 {
            if let icon = getAppIcon() {
                appIcon = icon
                return
            }

            // Wait a bit before retrying
            if attempt < 2 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
        }
    }

    private func getAppIcon() -> NSImage? {
        // Method 1: Get from NSApp (most reliable for running app)
        if let icon = NSApp.applicationIconImage {
            // Check if it's a real icon (not the generic app icon)
            if icon.size.width >= 32 {
                return icon
            }
        }

        // Method 2: NSWorkspace icon (always returns something)
        let workspaceIcon = NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
        if workspaceIcon.size.width >= 32 {
            return workspaceIcon
        }

        // Method 3: NSImage.applicationIconName
        if let icon = NSImage(named: NSImage.applicationIconName) {
            if icon.size.width >= 32 {
                return icon
            }
        }

        // Method 4: Load from asset catalog
        if let icon = NSImage(named: "AppIcon") {
            return icon
        }

        // Method 5: Try loading from bundle resources
        if let resourcePath = Bundle.main.resourcePath {
            // Try different possible names
            for filename in ["AppIcon.icns", "AppIcon.png", "Icon.icns"] {
                let path = (resourcePath as NSString).appendingPathComponent(filename)
                if let icon = NSImage(contentsOfFile: path) {
                    return icon
                }
            }
        }

        // Method 6: Try bundle URL with different extensions
        for ext in ["icns", "png", "pdf"] {
            if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: ext),
               let icon = NSImage(contentsOf: iconURL) {
                return icon
            }
        }

        return nil
    }
}

// MARK: - Welcome View

struct WelcomeView: View {
    let onOpen: () -> Void
    let onClone: () -> Void
    @EnvironmentObject var recentReposManager: RecentRepositoriesManager
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @State private var refreshTrigger = UUID()

    var body: some View {
        HStack(spacing: 0) {
            // Left side - Actions
            VStack(spacing: 24) {
                Spacer()

                // App Icon - Load from bundle
                AppIconView(size: 120)

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
        // Force re-render when theme changes via multiple triggers
        .id("\(themeManager.currentTheme.rawValue)-\(refreshTrigger)")
        .onReceive(NotificationCenter.default.publisher(for: .themeDidChange)) { _ in
            // Force view refresh when theme changes
            refreshTrigger = UUID()
        }
        .preferredColorScheme(themeManager.currentTheme == .light ? .light :
                              themeManager.currentTheme == .dark ? .dark : nil)
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
