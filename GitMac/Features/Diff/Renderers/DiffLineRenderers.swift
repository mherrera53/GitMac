import SwiftUI

// MARK: - Diff Line Renderers

struct DiffLineRow: View {
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
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .trailing)
                    .padding(.trailing, 8)
            }

            Text(line.content)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(textColor)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 1)
        .padding(.horizontal, 4)
        .background(backgroundColor)
        .diffLineContextMenu(line: line)
    }

    var backgroundColor: SwiftUI.Color {
        switch line.type {
        case .addition: return SwiftUI.Color.green.opacity(0.15)
        case .deletion: return SwiftUI.Color.red.opacity(0.15)
        case .context, .hunkHeader: return SwiftUI.Color.clear
        }
    }

    var textColor: SwiftUI.Color {
        switch line.type {
        case .addition: return SwiftUI.Color.green
        case .deletion: return SwiftUI.Color.red
        case .context, .hunkHeader: return SwiftUI.Color.primary
        }
    }
}

struct InlineDiffLineRow: View {
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
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.trailing, 8)
            }

            // Indicator
            Text(lineIndicator)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(indicatorColor)
                .frame(width: 16)

            // Content
            Text(line.content)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(textColor)
                .textSelection(.enabled)
        }
        .padding(.vertical, 1)
        .padding(.horizontal, 4)
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
        case .addition: return .green
        case .deletion: return .red
        case .context: return .secondary
        case .hunkHeader: return .blue
        }
    }

    var backgroundColor: SwiftUI.Color {
        switch line.type {
        case .addition: return SwiftUI.Color.green.opacity(0.15)
        case .deletion: return SwiftUI.Color.red.opacity(0.15)
        case .context, .hunkHeader: return SwiftUI.Color.clear
        }
    }

    var textColor: SwiftUI.Color {
        switch line.type {
        case .addition: return SwiftUI.Color.green
        case .deletion: return SwiftUI.Color.red
        case .context, .hunkHeader: return SwiftUI.Color.primary
        }
    }
}

struct HunkLineRow: View {
    let line: DiffLine
    let showLineNumber: Bool

    var body: some View {
        HStack(spacing: 0) {
            if showLineNumber {
                HStack(spacing: 4) {
                    Text(line.oldLineNumber.map { String($0) } ?? "")
                        .frame(width: 35, alignment: .trailing)
                    Text(line.newLineNumber.map { String($0) } ?? "")
                        .frame(width: 35, alignment: .trailing)
                }
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(AppTheme.textMuted)
                .padding(.trailing, 8)
                .background(lineNumberBackground)
            }

            Text(linePrefix)
                .foregroundColor(prefixColor)
                .frame(width: 16)

            Text(line.content)
                .foregroundColor(textColor)
                .textSelection(.enabled)
        }
        .font(.system(size: 12, design: .monospaced))
        .padding(.vertical, 2)
        .padding(.horizontal, 8)
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
        case .addition: return AppTheme.accentGreen
        case .deletion: return AppTheme.accentRed
        default: return AppTheme.textMuted
        }
    }

    var backgroundColor: SwiftUI.Color {
        switch line.type {
        case .addition: return AppTheme.accentGreen.opacity(0.1)
        case .deletion: return AppTheme.accentRed.opacity(0.1)
        default: return SwiftUI.Color.clear
        }
    }

    var lineNumberBackground: SwiftUI.Color {
        switch line.type {
        case .addition: return AppTheme.accentGreen.opacity(0.06)
        case .deletion: return AppTheme.accentRed.opacity(0.06)
        default: return AppTheme.backgroundSecondary
        }
    }

    var textColor: SwiftUI.Color {
        switch line.type {
        case .addition: return AppTheme.accentGreen
        case .deletion: return AppTheme.accentRed
        default: return AppTheme.textPrimary
        }
    }
}

struct HunkHeaderRow: View {
    let header: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "text.alignleft")
                .font(.system(size: 10))
            Text(header)
                .font(.system(size: 11, design: .monospaced))
        }
        .foregroundColor(AppTheme.accent)
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.accent.opacity(0.08))
    }
}

struct EmptyLineRow: View {
    let showLineNumber: Bool

    var body: some View {
        HStack(spacing: 0) {
            if showLineNumber {
                Text("")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(AppTheme.textMuted)
                    .frame(width: 45, alignment: .trailing)
                    .padding(.trailing, 8)
                    .background(AppTheme.backgroundSecondary)
            }
            Text(" ")
                .frame(width: 16)
            Spacer()
        }
        .font(.system(size: 12, design: .monospaced))
        .padding(.vertical, 2)
        .background(AppTheme.backgroundTertiary.opacity(0.3))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
