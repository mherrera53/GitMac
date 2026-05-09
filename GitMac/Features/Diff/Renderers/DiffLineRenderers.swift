import SwiftUI

// MARK: - Diff Line Renderers

struct DiffLineRow: View {
    @Environment(ThemeManager.self) private var themeManager

    let line: DiffLine
    let side: DiffSide
    let showLineNumber: Bool
    let filename: String

    var lineNumber: Int? {
        switch side {
        case .left: return line.oldLineNumber
        case .right: return line.newLineNumber
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            if showLineNumber {
                Text(lineNumber.map { String($0) } ?? "")
                    .font(DesignTokens.Typography.commitHash)
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: 40, alignment: .trailing)
                    .padding(.trailing, DesignTokens.Spacing.sm)
            }

            Text(line.content)
                .font(DesignTokens.Typography.diffLine)
                .foregroundStyle(textColor)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 1)
        .padding(.horizontal, DesignTokens.Spacing.xs)
        .background(backgroundColor)
        .diffLineContextMenu(line: line)
    }

    var backgroundColor: SwiftUI.Color {
        switch line.type {
        case .addition: return AppTheme.success.opacity(0.15)
        case .deletion: return AppTheme.error.opacity(0.15)
        case .context, .hunkHeader: return SwiftUI.Color.clear
        }
    }

    var textColor: SwiftUI.Color {
        switch line.type {
        case .addition: return AppTheme.success
        case .deletion: return AppTheme.error
        case .context, .hunkHeader: return AppTheme.textPrimary
        }
    }
}

struct InlineDiffLineRow: View {
    @Environment(ThemeManager.self) private var themeManager

    let line: DiffLine
    let showLineNumbers: Bool
    let filename: String

    var body: some View {
        HStack(spacing: 0) {
            // Line numbers
            if showLineNumbers {
                HStack(spacing: 0) {
                    Text(line.oldLineNumber.map { String($0) } ?? "")
                        .frame(width: 40, alignment: .trailing)

                    Text(line.newLineNumber.map { String($0) } ?? "")
                        .frame(width: 40, alignment: .trailing)
                }
                .font(DesignTokens.Typography.commitHash)
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.trailing, DesignTokens.Spacing.sm)
            }

            // Indicator
            Text(lineIndicator)
                .font(DesignTokens.Typography.diffLine)
                .foregroundStyle(indicatorColor)
                .frame(width: 16)

            Text(line.content)
                .font(DesignTokens.Typography.diffLine)
                .foregroundStyle(textColor)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .textSelection(.enabled)
        }
        .padding(.vertical, 1)
        .padding(.horizontal, DesignTokens.Spacing.xs)
        .background(backgroundColor)
        .frame(maxWidth: .infinity, alignment: .leading)
        .diffLineContextMenu(line: line)
    }

    var lineIndicator: String {
        switch line.type {
        case .addition: return "+"
        case .deletion: return "-"
        case .context: return " "
        case .hunkHeader: return "@"
        }
    }

    var indicatorColor: SwiftUI.Color {
        switch line.type {
        case .addition: return AppTheme.diffAddition
        case .deletion: return AppTheme.diffDeletion
        case .context: return AppTheme.textSecondary
        case .hunkHeader: return AppTheme.accent
        }
    }

    var backgroundColor: SwiftUI.Color {
        switch line.type {
        case .addition: return AppTheme.diffAdditionBg
        case .deletion: return AppTheme.diffDeletionBg
        case .context, .hunkHeader: return SwiftUI.Color.clear
        }
    }

    var textColor: SwiftUI.Color {
        switch line.type {
        case .addition: return AppTheme.diffAddition
        case .deletion: return AppTheme.diffDeletion
        case .context, .hunkHeader: return AppTheme.textPrimary
        }
    }
}

struct HunkLineRow: View {
    @Environment(ThemeManager.self) private var themeManager

    let line: DiffLine
    let showLineNumber: Bool

    var body: some View {
        HStack(spacing: 0) {
            if showLineNumber {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Text(line.oldLineNumber.map { String($0) } ?? "")
                        .frame(width: 35, alignment: .trailing)
                    Text(line.newLineNumber.map { String($0) } ?? "")
                        .frame(width: 35, alignment: .trailing)
                }
                .font(DesignTokens.Typography.commitHash)
                .foregroundStyle(AppTheme.textMuted)
                .padding(.trailing, DesignTokens.Spacing.sm)
                .background(lineNumberBackground)
            }

            Text(linePrefix)
                .foregroundStyle(prefixColor)
                .frame(width: 16)

            Text(line.content)
                .foregroundStyle(textColor)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .textSelection(.enabled)
        }
        .font(DesignTokens.Typography.diffLine)
        .padding(.vertical, DesignTokens.Spacing.xxs)
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .background(backgroundColor)
        .frame(maxWidth: .infinity, alignment: .leading)
        .diffLineContextMenu(line: line)
    }

    var linePrefix: String {
        switch line.type {
        case .addition: return "+"
        case .deletion: return "-"
        case .context: return " "
        case .hunkHeader: return "@"
        }
    }

    var prefixColor: SwiftUI.Color {
        switch line.type {
        case .addition: return AppTheme.success
        case .deletion: return AppTheme.error
        default: return AppTheme.textMuted
        }
    }

    var backgroundColor: SwiftUI.Color {
        switch line.type {
        case .addition: return AppTheme.success.opacity(0.1)
        case .deletion: return AppTheme.error.opacity(0.1)
        default: return SwiftUI.Color.clear
        }
    }

    var lineNumberBackground: SwiftUI.Color {
        switch line.type {
        case .addition: return AppTheme.success.opacity(0.06)
        case .deletion: return AppTheme.error.opacity(0.06)
        default: return AppTheme.backgroundSecondary
        }
    }

    var textColor: SwiftUI.Color {
        switch line.type {
        case .addition: return AppTheme.success
        case .deletion: return AppTheme.error
        default: return AppTheme.textPrimary
        }
    }
}

struct HunkHeaderRow: View {
    @Environment(ThemeManager.self) private var themeManager

    let header: String
    let hunkIndex: Int
    var onDiscardHunk: ((Int) -> Void)? = nil

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "text.alignleft")
                .font(DesignTokens.Typography.caption2)
                .foregroundStyle(AppTheme.textSecondary)
            Text(header)
                .font(DesignTokens.Typography.commitHash)

            Spacer()

            // Discard hunk button
            if let onDiscardHunk {
                Button {
                    onDiscardHunk(hunkIndex)
                } label: {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        Image(systemName: "trash")
                            .font(DesignTokens.Typography.caption2)
                            .foregroundStyle(AppTheme.error)
                        Text("Discard Hunk")
                            .font(DesignTokens.Typography.caption2.weight(.medium))
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .background(AppTheme.error.opacity(0.15))
                .foregroundStyle(AppTheme.error)
                .clipShape(.rect(cornerRadius: DesignTokens.CornerRadius.sm))
                .help("Discard all changes in this hunk")
            }
        }
        .foregroundStyle(AppTheme.accent)
        .padding(.vertical, DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
        .padding(.horizontal, DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.accent.opacity(0.08))
    }
}

struct EmptyLineRow: View {
    @Environment(ThemeManager.self) private var themeManager

    let showLineNumber: Bool

    var body: some View {
        HStack(spacing: 0) {
            if showLineNumber {
                Text("")
                    .font(DesignTokens.Typography.commitHash)
                    .foregroundStyle(AppTheme.textMuted)
                    .frame(width: 45, alignment: .trailing)
                    .padding(.trailing, DesignTokens.Spacing.sm)
                    .background(AppTheme.backgroundSecondary)
            }
            Text(" ")
                .frame(width: 16)
            Spacer()
        }
        .font(DesignTokens.Typography.diffLine)
        .padding(.vertical, DesignTokens.Spacing.xxs)
        .background(AppTheme.backgroundTertiary.opacity(0.3))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
