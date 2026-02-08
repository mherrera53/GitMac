import SwiftUI
import SwiftData

struct SettingsView: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    @AppStorage("settingsSelectedTab") private var selectedTab: String = "general"

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag("general")
                .accessibilityIdentifier("settings-tab-general")

            AccountsSettingsView()
                .tabItem {
                    Label("Accounts", systemImage: "person.circle")
                }
                .tag("accounts")
                .accessibilityIdentifier("settings-tab-accounts")

            IntegrationsSettingsView()
                .tabItem {
                    Label("Integrations", systemImage: "square.grid.2x2")
                }
                .tag("integrations")
                .accessibilityIdentifier("settings-tab-integrations")

            AISettingsView()
                .tabItem {
                    Label("AI", systemImage: "brain")
                }
                .tag("ai")
                .accessibilityIdentifier("settings-tab-ai")

            GitConfigView()
                .tabItem {
                    Label("Git", systemImage: "arrow.triangle.branch")
                }
                .tag("git")
                .accessibilityIdentifier("settings-tab-git")

            WorkspaceConfigView()
                .tabItem {
                    Label("Workspace", systemImage: "folder.badge.gearshape")
                }
                .tag("workspace")
                .accessibilityIdentifier("settings-tab-workspace")

            KeyboardShortcutsView()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
                .tag("shortcuts")
                .accessibilityIdentifier("settings-tab-shortcuts")

            SubscriptionSettingsView()
                .tabItem {
                    Label("Subscription", systemImage: "star.fill")
                }
                .tag("subscription")
                .accessibilityIdentifier("settings-tab-subscription")
        }
        .accessibilityIdentifier("settings-tabview")
        .frame(width: 850, height: 550)
        .background(AppTheme.background)
        .preferredColorScheme(colorScheme)
        .onAppear {
            configureWindowAppearance()
        }
    }

    private var colorScheme: SwiftUI.ColorScheme? {
        switch themeManager.currentTheme {
        case .light:
            return .light
        case .dark, .custom:
            return .dark
        case .system:
            return nil
        }
    }

    private func configureWindowAppearance() {
        #if os(macOS)
        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first(where: { $0.title.contains("Settings") || $0.title.contains("General") || $0.title.contains("Integrations") }) {
                window.titlebarAppearsTransparent = false
                window.toolbarStyle = .unified

                switch themeManager.currentTheme {
                case .light:
                    window.appearance = NSAppearance(named: .aqua)
                case .dark, .custom:
                    window.appearance = NSAppearance(named: .darkAqua)
                case .system:
                    window.appearance = nil
                }
            }
        }
        #endif
    }
}
