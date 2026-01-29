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
                            .foregroundStyle(.white)
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
        // Method 1: Load from dedicated WelcomeIcon asset (most reliable)
        if let icon = NSImage(named: "WelcomeIcon") {
            return icon
        }

        // Method 2: Get from NSApp (reliable for running app)
        if let icon = NSApp.applicationIconImage {
            if icon.size.width >= 32 {
                return icon
            }
        }

        // Method 3: NSWorkspace icon (always returns something)
        let workspaceIcon = NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
        if workspaceIcon.size.width >= 32 {
            return workspaceIcon
        }

        // Method 4: NSImage.applicationIconName
        if let icon = NSImage(named: NSImage.applicationIconName) {
            if icon.size.width >= 32 {
                return icon
            }
        }

        // Method 5: Load from asset catalog
        if let icon = NSImage(named: "AppIcon") {
            return icon
        }

        // Method 6: Try loading from bundle resources
        if let resourcePath = Bundle.main.resourcePath {
            for filename in ["AppIcon.icns", "AppIcon.png", "Icon.icns"] {
                let path = (resourcePath as NSString).appendingPathComponent(filename)
                if let icon = NSImage(contentsOfFile: path) {
                    return icon
                }
            }
        }

        // Method 7: Try bundle URL with different extensions
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
    @Environment(\.colorScheme) private var colorScheme
    @State private var refreshTrigger = UUID()

    // Computed colors that respond to theme changes
    private var backgroundColor: SwiftUI.Color {
        colorScheme == .dark ? SwiftUI.Color(hex: "#1E1E1E") : SwiftUI.Color(hex: "#FFFFFF")
    }

    private var backgroundSecondaryColor: SwiftUI.Color {
        colorScheme == .dark ? SwiftUI.Color(hex: "#252526") : SwiftUI.Color(hex: "#F5F5F7")
    }

    private var textPrimaryColor: SwiftUI.Color {
        colorScheme == .dark ? SwiftUI.Color.white : SwiftUI.Color(hex: "#1D1D1F")
    }

    private var textSecondaryColor: SwiftUI.Color {
        colorScheme == .dark ? SwiftUI.Color(hex: "#CCCCCC") : SwiftUI.Color(hex: "#48484A")
    }

    private var textMutedColor: SwiftUI.Color {
        colorScheme == .dark ? SwiftUI.Color(hex: "#999999") : SwiftUI.Color(hex: "#6E6E73")
    }

    private var accentColor: Color {
        Color.accentColor
    }

    private var successColor: Color {
        Color(nsColor: .systemGreen)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left side - Actions
            VStack(spacing: 24) {
                Spacer()

                // App Icon - Load from bundle
                AppIconView(size: 120)

                Text("GitMac")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(textPrimaryColor)

                Text("A Git client for Mac")
                    .font(.system(size: 16))
                    .foregroundStyle(textSecondaryColor)

                HStack(spacing: 16) {
                    WelcomeButton(icon: "folder", title: "Open", color: accentColor, action: onOpen)
                    WelcomeButton(icon: "arrow.down.circle", title: "Clone", color: successColor, action: onClone)
                    WelcomeButton(icon: "plus.circle", title: "Init", color: accentColor) {
                        NotificationCenter.default.post(name: .initRepository, object: nil)
                    }
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(backgroundColor)

            // Right side - Recent repos
            RecentReposSidebar(
                recentRepos: recentReposManager.recentRepos,
                backgroundColor: backgroundSecondaryColor,
                textMutedColor: textMutedColor
            )
        }
        // Force re-render when theme changes
        .id("\(themeManager.currentTheme.rawValue)-\(colorScheme)-\(refreshTrigger)")
        .onReceive(NotificationCenter.default.publisher(for: .themeDidChange)) { _ in
            refreshTrigger = UUID()
        }
        .preferredColorScheme(themeManager.currentTheme == .light ? .light :
                              themeManager.currentTheme == .dark ? .dark : nil)
        .onAppear {
            // Ensure window appearance matches theme on appear
            if let window = NSApplication.shared.windows.first(where: { $0.isKeyWindow }) {
                window.appearance = themeManager.appearance
            }
        }
    }
}

// MARK: - Recent Repos Sidebar

struct RecentReposSidebar: View {
    let recentRepos: [RecentRepository]
    let backgroundColor: Color
    let textMutedColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("RECENT REPOSITORIES")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(textMutedColor)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)

            ScrollView {
                VStack(spacing: 0) {
                    if recentRepos.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "clock")
                                .font(.system(size: 32))
                                .foregroundStyle(textMutedColor)
                            Text("No recent repositories")
                                .foregroundStyle(textMutedColor)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else {
                        ForEach(recentRepos) { repo in
                            RecentRepoRow(repo: repo)
                        }
                    }
                }
            }
        }
        .frame(width: 320)
        .background(backgroundColor)
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
            .foregroundStyle(isHovered ? .white : color)
            .frame(width: 80, height: 80)
            .background(isHovered ? color : color.opacity(0.15))
            .clipShape(.rect(cornerRadius: 12))
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
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    private var textPrimaryColor: SwiftUI.Color {
        colorScheme == .dark ? SwiftUI.Color.white : SwiftUI.Color(hex: "#1D1D1F")
    }

    private var textMutedColor: SwiftUI.Color {
        colorScheme == .dark ? SwiftUI.Color(hex: "#999999") : SwiftUI.Color(hex: "#6E6E73")
    }

    private var hoverColor: Color {
        Color.accentColor.opacity(0.1)
    }

    var body: some View {
        Button {
            Task {
                await appState.openRepository(at: repo.path)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(repo.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(textPrimaryColor)
                    Text(repo.path)
                        .font(.system(size: 11))
                        .foregroundStyle(textMutedColor)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(isHovered ? hoverColor : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
