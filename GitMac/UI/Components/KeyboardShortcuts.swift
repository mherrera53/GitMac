import SwiftUI
import AppKit

// MARK: - Keyboard Shortcuts Manager

struct KeyboardShortcutItem: Identifiable {
    let id = UUID()
    let key: String
    let modifiers: [String]
    let description: String
    let category: ShortcutCategory

    var displayKey: String {
        var parts = modifiers
        parts.append(key)
        return parts.joined(separator: "")
    }

    enum ShortcutCategory: String, CaseIterable {
        case general = "General"
        case staging = "Staging"
        case commit = "Commit"
        case branches = "Branches"
        case navigation = "Navigation"
        case diff = "Diff View"
    }
}

struct KeyboardShortcutsManager {
    static let shortcuts: [KeyboardShortcutItem] = [
        // General
        KeyboardShortcutItem(key: ",", modifiers: ["⌘"], description: "Open Settings", category: .general),
        KeyboardShortcutItem(key: "N", modifiers: ["⌘"], description: "New Repository", category: .general),
        KeyboardShortcutItem(key: "O", modifiers: ["⌘"], description: "Open Repository", category: .general),
        KeyboardShortcutItem(key: "R", modifiers: ["⌘"], description: "Refresh", category: .general),
        KeyboardShortcutItem(key: "T", modifiers: ["⌘"], description: "Toggle Terminal", category: .general),
        KeyboardShortcutItem(key: "?", modifiers: ["⌘", "⇧"], description: "Show Keyboard Shortcuts", category: .general),

        // Staging
        KeyboardShortcutItem(key: "S", modifiers: ["⌘", "⇧"], description: "Stage All Files", category: .staging),
        KeyboardShortcutItem(key: "U", modifiers: ["⌘", "⇧"], description: "Unstage All Files", category: .staging),
        KeyboardShortcutItem(key: "S", modifiers: ["⌘"], description: "Stage Selected File", category: .staging),
        KeyboardShortcutItem(key: "U", modifiers: ["⌘"], description: "Unstage Selected File", category: .staging),
        KeyboardShortcutItem(key: "⌫", modifiers: ["⌘"], description: "Discard Selected Changes", category: .staging),

        // Commit
        KeyboardShortcutItem(key: "⏎", modifiers: ["⌘"], description: "Commit", category: .commit),
        KeyboardShortcutItem(key: "⏎", modifiers: ["⌘", "⇧"], description: "Commit & Push", category: .commit),
        KeyboardShortcutItem(key: "G", modifiers: ["⌘", "⇧"], description: "Generate AI Commit Message", category: .commit),

        // Branches
        KeyboardShortcutItem(key: "B", modifiers: ["⌘"], description: "Show Branches", category: .branches),
        KeyboardShortcutItem(key: "B", modifiers: ["⌘", "⇧"], description: "Create New Branch", category: .branches),
        KeyboardShortcutItem(key: "M", modifiers: ["⌘", "⇧"], description: "Merge Branch", category: .branches),

        // Navigation
        KeyboardShortcutItem(key: "1", modifiers: ["⌘"], description: "Show Graph View", category: .navigation),
        KeyboardShortcutItem(key: "2", modifiers: ["⌘"], description: "Show Staging Area", category: .navigation),
        KeyboardShortcutItem(key: "3", modifiers: ["⌘"], description: "Show History", category: .navigation),
        KeyboardShortcutItem(key: "F", modifiers: ["⌘"], description: "Search Commits", category: .navigation),
        KeyboardShortcutItem(key: "↑", modifiers: ["⌥"], description: "Previous Commit", category: .navigation),
        KeyboardShortcutItem(key: "↓", modifiers: ["⌥"], description: "Next Commit", category: .navigation),

        // Diff
        KeyboardShortcutItem(key: "D", modifiers: ["⌘"], description: "View Diff", category: .diff),
        KeyboardShortcutItem(key: "[", modifiers: ["⌘"], description: "Previous Hunk", category: .diff),
        KeyboardShortcutItem(key: "]", modifiers: ["⌘"], description: "Next Hunk", category: .diff),
        KeyboardShortcutItem(key: "L", modifiers: ["⌘"], description: "Toggle Line Numbers", category: .diff),
        KeyboardShortcutItem(key: "W", modifiers: ["⌘"], description: "Toggle Word Wrap", category: .diff),
    ]

    static func shortcuts(for category: KeyboardShortcutItem.ShortcutCategory) -> [KeyboardShortcutItem] {
        shortcuts.filter { $0.category == category }
    }
}

// MARK: - Keyboard Shortcuts Help View

struct KeyboardShortcutsHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Keyboard Shortcuts")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppTheme.textMuted)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(AppTheme.toolbar)

            Divider()

            // Shortcuts list
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(KeyboardShortcutItem.ShortcutCategory.allCases, id: \.rawValue) { category in
                        ShortcutCategorySection(category: category)
                    }
                }
                .padding()
            }
        }
        .frame(width: 500, height: 600)
        .background(AppTheme.background)
    }
}

struct ShortcutCategorySection: View {
    let category: KeyboardShortcutItem.ShortcutCategory

    var shortcuts: [KeyboardShortcutItem] {
        KeyboardShortcutsManager.shortcuts(for: category)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Category header
            HStack(spacing: 8) {
                Image(systemName: categoryIcon)
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.accent)

                Text(category.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
            }
            .padding(.bottom, 4)

            // Shortcuts
            ForEach(shortcuts) { shortcut in
                KeyboardShortcutRow(shortcut: shortcut)
            }
        }
    }

    var categoryIcon: String {
        switch category {
        case .general: return "gearshape"
        case .staging: return "square.stack.3d.up"
        case .commit: return "checkmark.circle"
        case .branches: return "arrow.triangle.branch"
        case .navigation: return "arrow.left.arrow.right"
        case .diff: return "doc.text"
        }
    }
}

struct KeyboardShortcutRow: View {
    let shortcut: KeyboardShortcutItem

    var body: some View {
        HStack {
            Text(shortcut.description)
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textSecondary)

            Spacer()

            // Key combination
            HStack(spacing: 4) {
                ForEach(shortcut.modifiers, id: \.self) { modifier in
                    KeyCap(text: modifier)
                }
                KeyCap(text: shortcut.key)
            }
        }
        .padding(.vertical, 4)
    }
}

struct KeyCap: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundColor(AppTheme.textPrimary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(AppTheme.backgroundSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
    }
}

// MARK: - Quick Actions Palette (Command Palette)

struct QuickActionsPalette: View {
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    let actions: [QuickAction]
    let onAction: (QuickAction) -> Void

    var filteredActions: [QuickAction] {
        if searchText.isEmpty {
            return actions
        }
        return actions.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.category.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppTheme.textMuted)

                TextField("Search actions...", text: $searchText)
                    .font(.system(size: 14))
                    .focused($isSearchFocused)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(AppTheme.backgroundSecondary)

            Divider()

            // Actions list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(filteredActions) { action in
                        QuickActionRow(action: action) {
                            onAction(action)
                            isPresented = false
                        }
                    }
                }
            }
            .frame(maxHeight: 400)
        }
        .frame(width: 400)
        .background(AppTheme.panel)
        .cornerRadius(12)
        .shadow(color: AppTheme.shadow.opacity(0.3), radius: 20)
        .onAppear {
            isSearchFocused = true
        }
    }
}

struct QuickAction: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let category: String
    let shortcut: String?
}

struct QuickActionRow: View {
    let action: QuickAction
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: action.icon)
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.accent)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(action.title)
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.textPrimary)

                    Text(action.category)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textMuted)
                }

                Spacer()

                if let shortcut = action.shortcut {
                    Text(shortcut)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(AppTheme.textMuted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.backgroundSecondary)
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isHovered ? AppTheme.hover : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
