import SwiftUI

// MARK: - Empty State View

/// Displays empty state with icon, title, message, and optional action
/// Used when lists, views, or sections have no content
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String?
    var action: EmptyStateAction?
    var style: EmptyStyle = .default

    struct EmptyStateAction {
        let title: String
        let icon: String?
        let action: () -> Void

        init(title: String, icon: String? = nil, action: @escaping () -> Void) {
            self.title = title
            self.icon = icon
            self.action = action
        }
    }

    enum EmptyStyle {
        case `default`      // Standard size and spacing
        case compact        // Smaller, less padding
        case prominent      // Larger, more visible
    }

    var body: some View {
        VStack(spacing: style.spacing) {
            Image(systemName: icon)
                .font(style.iconFont)
                .foregroundColor(style.iconColor)

            Text(title)
                .font(style.titleFont)
                .fontWeight(style.titleWeight)
                .foregroundColor(AppTheme.textPrimary)

            if let message = message {
                Text(message)
                    .font(style.messageFont)
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, style.messagePadding)
            }

            if let action = action {
                Button {
                    action.action()
                } label: {
                    HStack(spacing: 6) {
                        if let icon = action.icon {
                            Image(systemName: icon)
                                .font(style.buttonFont)
                        }
                        Text(action.title)
                            .font(style.buttonFont)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, style.buttonHorizontalPadding)
                    .padding(.vertical, style.buttonVerticalPadding)
                    .background(AppTheme.accent)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .padding(.top, style.buttonTopPadding)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(style.containerPadding)
    }
}

// MARK: - Empty Style Extension

extension EmptyStateView.EmptyStyle {
    var spacing: CGFloat {
        switch self {
        case .default: return 12
        case .compact: return 8
        case .prominent: return 16
        }
    }

    var iconFont: Font {
        switch self {
        case .default: return .system(size: 48)
        case .compact: return .system(size: 32)
        case .prominent: return .system(size: 64)
        }
    }

    var iconColor: Color {
        AppTheme.textSecondary.opacity(0.6)
    }

    var titleFont: Font {
        switch self {
        case .default: return .title3
        case .compact: return .body
        case .prominent: return .title
        }
    }

    var titleWeight: Font.Weight {
        switch self {
        case .default: return .semibold
        case .compact: return .medium
        case .prominent: return .bold
        }
    }

    var messageFont: Font {
        switch self {
        case .default: return .body
        case .compact: return .caption
        case .prominent: return .title3
        }
    }

    var messagePadding: CGFloat {
        switch self {
        case .default: return 40
        case .compact: return 20
        case .prominent: return 60
        }
    }

    var buttonFont: Font {
        switch self {
        case .default: return .body
        case .compact: return .caption
        case .prominent: return .title3
        }
    }

    var buttonHorizontalPadding: CGFloat {
        switch self {
        case .default: return 16
        case .compact: return 12
        case .prominent: return 20
        }
    }

    var buttonVerticalPadding: CGFloat {
        switch self {
        case .default: return 8
        case .compact: return 6
        case .prominent: return 10
        }
    }

    var buttonTopPadding: CGFloat {
        switch self {
        case .default: return 8
        case .compact: return 4
        case .prominent: return 12
        }
    }

    var containerPadding: CGFloat {
        switch self {
        case .default: return 40
        case .compact: return 20
        case .prominent: return 60
        }
    }
}

// MARK: - Convenience Initializers

extension EmptyStateView {
    /// Creates an empty state without action button
    static func message(
        icon: String,
        title: String,
        message: String? = nil,
        style: EmptyStyle = .default
    ) -> EmptyStateView {
        EmptyStateView(icon: icon, title: title, message: message, action: nil, style: style)
    }

    /// Creates an empty state with action button
    static func withAction(
        icon: String,
        title: String,
        message: String? = nil,
        actionTitle: String,
        actionIcon: String? = nil,
        style: EmptyStyle = .default,
        action: @escaping () -> Void
    ) -> EmptyStateView {
        EmptyStateView(
            icon: icon,
            title: title,
            message: message,
            action: EmptyStateAction(title: actionTitle, icon: actionIcon, action: action),
            style: style
        )
    }
}

// MARK: - Common Empty States

extension EmptyStateView {
    /// Empty state for no files
    static func noFiles(action: (() -> Void)? = nil) -> EmptyStateView {
        if let action = action {
            return .withAction(
                icon: "doc.badge.ellipsis",
                title: "No Files",
                message: "No modified files in the working directory",
                actionTitle: "Refresh",
                actionIcon: "arrow.clockwise",
                action: action
            )
        } else {
            return .message(
                icon: "doc.badge.ellipsis",
                title: "No Files",
                message: "No modified files in the working directory"
            )
        }
    }

    /// Empty state for no commits
    static func noCommits(action: (() -> Void)? = nil) -> EmptyStateView {
        if let action = action {
            return .withAction(
                icon: "clock",
                title: "No Commits",
                message: "No commits in this branch yet",
                actionTitle: "Create First Commit",
                actionIcon: "plus.circle",
                action: action
            )
        } else {
            return .message(
                icon: "clock",
                title: "No Commits",
                message: "No commits in this branch yet"
            )
        }
    }

    /// Empty state for no branches
    static func noBranches(action: (() -> Void)? = nil) -> EmptyStateView {
        if let action = action {
            return .withAction(
                icon: "arrow.branch",
                title: "No Branches",
                message: "No branches found in this repository",
                actionTitle: "Create Branch",
                actionIcon: "plus",
                action: action
            )
        } else {
            return .message(
                icon: "arrow.branch",
                title: "No Branches",
                message: "No branches found in this repository"
            )
        }
    }

    /// Empty state for no stashes
    static func noStashes(action: (() -> Void)? = nil) -> EmptyStateView {
        if let action = action {
            return .withAction(
                icon: "tray.fill",
                title: "No Stashes",
                message: "You haven't stashed any changes yet",
                actionTitle: "Stash Changes",
                actionIcon: "tray.and.arrow.down",
                action: action
            )
        } else {
            return .message(
                icon: "tray.fill",
                title: "No Stashes",
                message: "You haven't stashed any changes yet"
            )
        }
    }

    /// Empty state for no search results
    static func noSearchResults(query: String) -> EmptyStateView {
        .message(
            icon: "magnifyingglass",
            title: "No Results",
            message: "No results found for \"\(query)\""
        )
    }

    /// Empty state for no repository
    static func noRepository(action: @escaping () -> Void) -> EmptyStateView {
        .withAction(
            icon: "folder.badge.questionmark",
            title: "No Repository",
            message: "Please select a Git repository to get started",
            actionTitle: "Open Repository",
            actionIcon: "folder",
            action: action
        )
    }
}

// MARK: - Preview

#if DEBUG
struct EmptyStateView_Previews: PreviewProvider {
    static var previews: some View {
        TabView {
            // Default style
            EmptyStateView.noFiles(action: { print("Refresh") })
                .tabItem { Label("No Files", systemImage: "doc") }

            // Compact style
            EmptyStateView.message(
                icon: "star",
                title: "No Favorites",
                message: "You haven't favorited any items yet",
                style: .compact
            )
            .tabItem { Label("Compact", systemImage: "star") }

            // Prominent style
            EmptyStateView.noRepository { print("Open repository") }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.background)
                .tabItem { Label("Prominent", systemImage: "folder") }

            // No action
            EmptyStateView.noCommits()
                .tabItem { Label("No Action", systemImage: "clock") }

            // Search results
            EmptyStateView.noSearchResults(query: "test.swift")
                .tabItem { Label("Search", systemImage: "magnifyingglass") }

            // Stashes
            EmptyStateView.noStashes(action: { print("Stash changes") })
                .tabItem { Label("Stashes", systemImage: "tray") }
        }
        .frame(width: 600, height: 500)
    }
}
#endif
