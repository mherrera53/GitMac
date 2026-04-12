import SwiftUI

struct KeyboardShortcutsView: View {
    var body: some View {
        Form {
            SettingsSection(title: "Repository") {
                SimpleShortcutRow(action: "Open Repository", shortcut: "Command+O")
                SimpleShortcutRow(action: "Clone Repository", shortcut: "Shift+Command+N")
                SimpleShortcutRow(action: "Fetch", shortcut: "Shift+Command+F")
                SimpleShortcutRow(action: "Pull", shortcut: "Shift+Command+P")
                SimpleShortcutRow(action: "Push", shortcut: "Shift+Command+U")
            }

            SettingsSection(title: "Staging") {
                SimpleShortcutRow(action: "Stage All", shortcut: "Shift+Command+A")
                SimpleShortcutRow(action: "Commit", shortcut: "Command+Return")
                SimpleShortcutRow(action: "Amend Commit", shortcut: "Option+Command+Return")
            }

            SettingsSection(title: "Branches") {
                SimpleShortcutRow(action: "New Branch", shortcut: "Shift+Command+B")
                SimpleShortcutRow(action: "Merge", shortcut: "Shift+Command+M")
                SimpleShortcutRow(action: "Rebase", shortcut: "Shift+Command+R")
            }

            SettingsSection(title: "Stash") {
                SimpleShortcutRow(action: "Stash Changes", shortcut: "Option+Command+S")
                SimpleShortcutRow(action: "Pop Stash", shortcut: "Shift+Option+Command+S")
            }
        }
        .padding()
        .background(AppTheme.background)
    }
}

struct SimpleShortcutRow: View {
    let action: String
    let shortcut: String

    var body: some View {
        HStack {
            Text(action)
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
            Text(shortcut)
                .foregroundStyle(AppTheme.textPrimary)
                .font(DesignTokens.Typography.body.monospaced())
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.vertical, DesignTokens.Spacing.xxs)
                .background(AppTheme.textSecondary.opacity(0.2))
                .clipShape(.rect(cornerRadius: DesignTokens.CornerRadius.sm))
        }
    }
}
