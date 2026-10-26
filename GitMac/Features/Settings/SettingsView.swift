import SwiftUI

enum SettingsWindowMetrics {
    static let minimum = CGSize(width: 660, height: 400)
    static let preferred = CGSize(width: 900, height: 620)
}

enum SettingsCategory: String, CaseIterable, Identifiable {
    case general, accounts, integrations, ai, git, workflows, workspace, shortcuts, subscription

    var id: String { rawValue }
    var title: String {
        switch self {
        case .general: return "General"
        case .accounts: return "Accounts"
        case .integrations: return "Integrations"
        case .ai: return "AI"
        case .git: return "Git"
        case .workflows: return "Workflows"
        case .workspace: return "Workspace"
        case .shortcuts: return "Shortcuts"
        case .subscription: return "Subscription"
        }
    }
    var symbol: String {
        switch self {
        case .general: return "gear"
        case .accounts: return "person.circle"
        case .integrations: return "square.grid.2x2"
        case .ai: return "brain"
        case .git: return "arrow.triangle.branch"
        case .workflows: return "bolt.circle"
        case .workspace: return "folder.badge.gearshape"
        case .shortcuts: return "keyboard"
        case .subscription: return "star.fill"
        }
    }
}

struct SettingsView: View {
    @Environment(ThemeManager.self) private var themeManager

    @AppStorage("settingsSelectedTab") private var selectedTab: String = "general"

    private var category: SettingsCategory { SettingsCategory(rawValue: selectedTab) ?? .general }

    var body: some View {
        HStack(spacing: 0) {
            List(selection: Binding<String?>(
                get: { category.rawValue },
                set: { if let value = $0, SettingsCategory(rawValue: value) != nil { selectedTab = value } }
            )) {
                ForEach(SettingsCategory.allCases) { item in
                    Label(item.title, systemImage: item.symbol)
                        .symbolRenderingMode(.hierarchical)
                        .tag(item.rawValue)
                        .accessibilityIdentifier("settings-tab-\(item.rawValue)")
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(AppTheme.backgroundSecondary)
            .tint(AppTheme.accent)
            .foregroundStyle(AppTheme.textPrimary)
            .accessibilityLabel("Settings categories")
            .frame(width: 180)
            Divider()
            VStack(alignment: .leading, spacing: 0) {
                Text(category.title)
                    .font(.title2.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding()
                    .accessibilityAddTraits(.isHeader)
                Divider()
                // A stable proposal prevents each pane's ideal size from
                // changing the native window constraints during selection.
                GeometryReader { geometry in
                    selectedContent
                        .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("settings-content-\(category.rawValue)")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings-tabview")
        .frame(minWidth: SettingsWindowMetrics.minimum.width, idealWidth: SettingsWindowMetrics.preferred.width, maxWidth: .infinity,
               minHeight: SettingsWindowMetrics.minimum.height, idealHeight: SettingsWindowMetrics.preferred.height, maxHeight: .infinity)
        .background(AppTheme.background)
        .preferredColorScheme(colorScheme)
        .onAppear {
            if SettingsCategory(rawValue: selectedTab) == nil { selectedTab = SettingsCategory.general.rawValue }
        }
    }

    @ViewBuilder private var selectedContent: some View {
        switch category {
        case .general: GeneralSettingsView()
        case .accounts: AccountsSettingsView()
        case .integrations: IntegrationsSettingsView()
        case .ai: AISettingsView()
        case .git: GitConfigView()
        case .workflows: WorkflowSettingsView()
        case .workspace: WorkspaceConfigView()
        case .shortcuts: KeyboardShortcutsView()
        case .subscription: SubscriptionSettingsView()
        }
    }

    private var colorScheme: SwiftUI.ColorScheme? {
        switch themeManager.currentTheme {
        case .light:
            return .light
        case .dark:
            return .dark
        case .custom:
            return themeManager.colors.background.isLight ? .light : .dark
        case .system:
            return nil
        }
    }
}
