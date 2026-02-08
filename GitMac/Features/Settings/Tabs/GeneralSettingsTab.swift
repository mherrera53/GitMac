import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @AppStorage("showInMenuBar") private var showInMenuBar = false
    @AppStorage("openAtLogin") private var openAtLogin = false
    @AppStorage("defaultClonePath") private var defaultClonePath = "~/Developer"
    @AppStorage("confirmBeforePush") private var confirmBeforePush = true
    @AppStorage("confirmBeforeForce") private var confirmBeforeForce = true
    @AppStorage("notificationSounds") private var notificationSounds = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            SettingsSection(title: "Appearance") {
                // Theme selector with icons
                HStack(spacing: DesignTokens.Spacing.md) {
                    ForEach(Theme.allCases.filter { $0 != .custom }) { theme in
                        ThemeButton(
                            theme: theme,
                            isSelected: themeManager.currentTheme == theme
                        ) {
                            themeManager.setTheme(theme)
                        }
                    }
                }
                .padding(.vertical, DesignTokens.Spacing.sm)

                // Custom theme button
                DSButton(variant: .secondary) {
                    ThemeEditorWindowController.shared.showWindow()
                } label: {
                    HStack {
                        Image(systemName: "paintbrush.fill")
                        Text("Customize Colors...")
                            .foregroundColor(AppTheme.textPrimary)
                        Spacer()
                        if themeManager.currentTheme == .custom {
                            Image(systemName: "checkmark")
                                .foregroundColor(AppTheme.success)
                        }
                    }
                }
            }

            SettingsSection(title: "Startup") {
                DSToggle("Open at login", isOn: $openAtLogin)
                DSToggle("Show in menu bar", isOn: $showInMenuBar)
            }

            SettingsSection(title: "Repositories") {
                HStack {
                    DSTextField(placeholder: "Default clone path", text: $defaultClonePath)

                    DSButton("Browse...", variant: .secondary, size: .sm) {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = false
                        panel.canChooseDirectories = true

                        panel.begin { response in
                            if response == .OK {
                                Task { @MainActor in
                                    defaultClonePath = panel.url?.path ?? defaultClonePath
                                }
                            }
                        }
                    }
                }
            }

            SettingsSection(title: "Confirmations") {
                DSToggle("Confirm before pushing", isOn: $confirmBeforePush)
                DSToggle("Confirm before force operations", isOn: $confirmBeforeForce)
            }

            SettingsSection(title: "Notifications") {
                DSToggle("Play sounds for notifications", isOn: $notificationSounds)
            }
            }
        }
        .padding()
        .background(AppTheme.background)
    }
}
