import SwiftUI

// MARK: - Status Icon

/// Displays a git file status badge with customizable size and style
struct StatusIcon: View {
    let status: FileStatusType
    var size: IconSize = .medium
    var style: IconStyle = .badge

    enum IconSize {
        case small      // 11pt - List items
        case medium     // 12pt - Panel headers  
        case large      // 14pt - Prominent indicators
        
        var dimension: CGFloat {
            switch self {
            case .small: return 11
            case .medium: return 12
            case .large: return 14
            }
        }
        
        var fontWeight: Font.Weight {
            .medium  // Consistent GitKraken weight
        }
    }

    enum IconStyle {
        case badge      // Letter with background
        case inline     // Just letter, no background
        case minimal    // Just colored dot
        case circle     // Filled circle with letter
    }

    var body: some View {
        switch style {
        case .badge:
            badgeView
        case .inline:
            inlineView
        case .minimal:
            minimalView
        case .circle:
            circleView
        }
    }

    // MARK: - Style Variants

    private var badgeView: some View {
        Image(systemName: statusIcon)
            .font(.system(size: size.dimension, weight: size.fontWeight))
            .foregroundColor(statusColor)
            .symbolRenderingMode(status == .unmerged ? .multicolor : .hierarchical)
    }

    private var inlineView: some View {
        Image(systemName: statusIcon)
            .font(.system(size: size.dimension, weight: size.fontWeight))
            .foregroundColor(statusColor)
            .symbolRenderingMode(status == .unmerged ? .multicolor : .hierarchical)
    }

    private var minimalView: some View {
        Circle()
            .fill(statusColor)
            .frame(width: size.dimension / 2, height: size.dimension / 2)
    }

    private var circleView: some View {
        Image(systemName: statusIcon)
            .font(.system(size: size.dimension, weight: size.fontWeight))
            .foregroundColor(statusColor)
            .symbolRenderingMode(status == .unmerged ? .multicolor : .hierarchical)
    }

    // MARK: - Icon Mapping (GitKraken style)

    private var statusIcon: String {
        switch status {
        case .added:
            return "plus.circle.fill"
        case .modified:
            return "pencil.circle.fill"
        case .deleted:
            return "minus.circle.fill"
        case .renamed:
            return "arrow.left.arrow.right.circle.fill"
        case .copied:
            return "doc.on.doc.fill"
        case .untracked:
            return "questionmark.circle"
        case .ignored:
            return "eye.slash.circle"
        case .typeChanged:
            return "arrow.triangle.2.circlepath.circle"
        case .unmerged:
            return "exclamationmark.triangle.fill"
        }
    }

    // MARK: - Color Mapping

    private var statusColor: Color {
        switch status {
        case .added:
            return AppTheme.success
        case .modified:
            return AppTheme.warning
        case .deleted:
            return AppTheme.error
        case .renamed:
            return AppTheme.accent
        case .copied:
            return AppTheme.accent
        case .untracked:
            return AppTheme.textMuted
        case .ignored:
            return AppTheme.textMuted.opacity(0.5)
        case .typeChanged:
            return AppTheme.accentPurple
        case .unmerged:
            return AppTheme.error
        }
    }
}

// MARK: - Convenience Initializers

extension StatusIcon {
    /// Creates a StatusIcon from StagingFile.StagingFileStatus
    init(stagingStatus: StagingFile.StagingFileStatus, size: IconSize = .medium, style: IconStyle = .badge) {
        let mappedStatus: FileStatusType
        switch stagingStatus {
        case .added:
            mappedStatus = .added
        case .modified:
            mappedStatus = .modified
        case .deleted:
            mappedStatus = .deleted
        case .renamed:
            mappedStatus = .renamed
        case .untracked:
            mappedStatus = .untracked
        case .conflicted:
            mappedStatus = .unmerged
        }
        self.init(status: mappedStatus, size: size, style: style)
    }
}

// MARK: - Preview

#if DEBUG
struct StatusIcon_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            // Badge style (default)
            HStack(spacing: 8) {
                StatusIcon(status: .added)
                StatusIcon(status: .modified)
                StatusIcon(status: .deleted)
                StatusIcon(status: .renamed)
                StatusIcon(status: .untracked)
            }

            // Sizes
            HStack(spacing: 8) {
                StatusIcon(status: .modified, size: .small)
                StatusIcon(status: .modified, size: .medium)
                StatusIcon(status: .modified, size: .large)
            }

            // Styles
            HStack(spacing: 8) {
                StatusIcon(status: .added, style: .badge)
                StatusIcon(status: .added, style: .inline)
                StatusIcon(status: .added, style: .minimal)
                StatusIcon(status: .added, style: .circle)
            }
        }
        .padding()
    }
}
#endif
