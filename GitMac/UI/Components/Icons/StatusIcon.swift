import SwiftUI

// MARK: - Status Icon

/// Displays a git file status badge with customizable size and style
struct StatusIcon: View {
    let status: FileStatusType
    var size: IconSize = .medium
    var style: IconStyle = .badge

    enum IconSize {
        case small
        case medium
        case large

        var dimension: CGFloat {
            switch self {
            case .small: return 12
            case .medium: return 16
            case .large: return 20
            }
        }

        var fontSize: CGFloat {
            switch self {
            case .small: return 8
            case .medium: return 10
            case .large: return 12
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .small: return 2
            case .medium: return 3
            case .large: return 4
            }
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
        Text(status.rawValue)
            .font(.system(size: size.fontSize, weight: .bold, design: .monospaced))
            .foregroundColor(statusColor)
            .frame(width: size.dimension, height: size.dimension)
            .background(statusColor.opacity(0.2))
            .cornerRadius(size.cornerRadius)
    }

    private var inlineView: some View {
        Text(status.rawValue)
            .font(.system(size: size.fontSize, weight: .bold, design: .monospaced))
            .foregroundColor(statusColor)
            .frame(width: size.dimension, height: size.dimension)
    }

    private var minimalView: some View {
        Circle()
            .fill(statusColor)
            .frame(width: size.dimension / 2, height: size.dimension / 2)
    }

    private var circleView: some View {
        ZStack {
            Circle()
                .fill(statusColor)

            Text(status.rawValue)
                .font(.system(size: size.fontSize, weight: .bold, design: .monospaced))
                .foregroundColor(AppTheme.background)
        }
        .frame(width: size.dimension, height: size.dimension)
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
