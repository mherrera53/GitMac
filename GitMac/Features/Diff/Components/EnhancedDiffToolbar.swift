import SwiftUI

// MARK: - Enhanced Diff Toolbar

/// Simplified toolbar with single button for each feature
struct EnhancedDiffToolbar: View {
    let filename: String
    let additions: Int
    let deletions: Int
    @Binding var showHistory: Bool
    @Binding var showBlame: Bool
    @Binding var showMinimap: Bool
    let onDiscardLines: ([DiffLine]) -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            // File info
            VStack(alignment: .leading, spacing: 2) {
                Text(filename)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(AppTheme.textPrimary)

                HStack(spacing: 12) {
                    Label("\(additions)", systemImage: "plus")
                        .foregroundColor(AppTheme.gitAdded)
                    Label("\(deletions)", systemImage: "minus")
                        .foregroundColor(AppTheme.gitDeleted)
                }
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Action buttons
            HStack(spacing: 8) {
                // History button
                Button(action: { showHistory.toggle() }) {
                    Image(systemName: "clock")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(showHistory ? AppTheme.accent : AppTheme.textSecondary)
                }
                .buttonStyle(ToolbarButtonStyle(isActive: showHistory))

                // Blame button
                Button(action: { showBlame.toggle() }) {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(showBlame ? AppTheme.accent : AppTheme.textSecondary)
                }
                .buttonStyle(ToolbarButtonStyle(isActive: showBlame))

                // Minimap toggle
                Button(action: { showMinimap.toggle() }) {
                    Image(systemName: "map")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(showMinimap ? AppTheme.accent : AppTheme.textSecondary)
                }
                .buttonStyle(ToolbarButtonStyle(isActive: showMinimap))

                // Discard selected
                Button(action: { onDiscardLines([]) }) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                }
                .buttonStyle(ToolbarButtonStyle(isActive: false))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(AppTheme.backgroundSecondary)
        .overlay(
            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
}

// MARK: - Toolbar Button Style

struct ToolbarButtonStyle: ButtonStyle {
    let isActive: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isActive ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isActive ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
