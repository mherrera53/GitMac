import SwiftUI

// MARK: - Compact Repo Tab (for toolbar)
struct CompactRepoTab: View {
    let tab: RepositoryTab
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovered = false
    @StateObject private var groupsService = RepoGroupsService.shared

    var groupColor: Color? {
        let groups = groupsService.getGroupsForRepo(tab.repository.path)
        guard let firstGroup = groups.first else { return nil }
        return SwiftUI.Color(hex: firstGroup.color)
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 4) {
                // Group color indicator
                if let color = groupColor {
                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                }

                // Repo name
                Text(tab.repository.name)
                    .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? AppTheme.textPrimary : AppTheme.textSecondary)
                    .lineLimit(1)

                // Close button (on hover)
                if isHovered {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(AppTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isActive ? AppTheme.backgroundSecondary : (isHovered ? AppTheme.hover : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
