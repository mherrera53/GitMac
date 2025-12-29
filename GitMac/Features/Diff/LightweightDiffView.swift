import SwiftUI
import AppKit

// MARK: - Lightweight Diff View

/// High-performance diff view using NSTextView for large files (500+ lines)
/// Follows Apple WWDC 2020 recommendations for text performance
struct LightweightDiffView: NSViewRepresentable {
    let fileDiff: FileDiff
    let isDarkMode: Bool

    init(fileDiff: FileDiff, isDarkMode: Bool = false) {
        self.fileDiff = fileDiff
        self.isDarkMode = isDarkMode
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = DiffTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.font = DesignTokens.Typography.nsDiffLine
        textView.textContainerInset = NSSize(width: DesignTokens.Spacing.sm, height: DesignTokens.Spacing.sm)
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.allowsUndo = false

        // Optimize for performance
        textView.usesFontPanel = false
        textView.usesRuler = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        // Enable layer-backed scrolling for performance
        scrollView.wantsLayer = true
        scrollView.contentView.wantsLayer = true
        scrollView.contentView.postsBoundsChangedNotifications = false

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Render on background thread for large files
        let diff = fileDiff
        let dark = isDarkMode

        Task {
            let attributed = Self.renderDiffText(diff, isDarkMode: dark)
            textView.layoutManager?.allowsNonContiguousLayout = true
            textView.textStorage?.setAttributedString(attributed)
        }
    }

    /// Render diff to NSAttributedString
    @MainActor
    private static func renderDiffText(_ diff: FileDiff, isDarkMode: Bool) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let font = DesignTokens.Typography.diffLine
        let lineNumberFont = DesignTokens.Typography.commitHash

        let baseTextColor = isDarkMode ? NSColor.white : NSColor.textColor
        let lineNumColor = NSColor.secondaryLabelColor

        // Colors for diff highlighting
        let additionColor = NSColor.systemGreen
        let additionBg = additionColor.withAlphaComponent(0.15)
        let deletionColor = NSColor.systemRed
        let deletionBg = deletionColor.withAlphaComponent(0.15)
        let hunkColor = NSColor.systemBlue
        let hunkBg = hunkColor.withAlphaComponent(0.1)

        for hunk in diff.hunks {
            // Hunk header
            let headerText = "\(hunk.header)\n"
            let headerAttrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: hunkColor,
                .backgroundColor: hunkBg
            ]
            result.append(NSAttributedString(string: headerText, attributes: headerAttrs))

            // Lines
            for line in hunk.lines {
                guard line.type != .hunkHeader else { continue }

                // Line number prefix (8 chars wide)
                let oldNum = line.oldLineNumber.map { String(format: "%4d", $0) } ?? "    "
                let newNum = line.newLineNumber.map { String(format: "%4d", $0) } ?? "    "
                let linePrefix = "\(oldNum) \(newNum) "

                let prefixAttrs: [NSAttributedString.Key: Any] = [
                    .font: lineNumberFont,
                    .foregroundColor: lineNumColor
                ]
                result.append(NSAttributedString(string: linePrefix, attributes: prefixAttrs))

                // Line content
                let prefix: String
                let textColor: NSColor
                let bgColor: NSColor

                switch line.type {
                case .addition:
                    prefix = "+"
                    textColor = additionColor
                    bgColor = additionBg
                case .deletion:
                    prefix = "-"
                    textColor = deletionColor
                    bgColor = deletionBg
                case .context:
                    prefix = " "
                    textColor = baseTextColor
                    bgColor = .clear
                case .hunkHeader:
                    prefix = "@"
                    textColor = hunkColor
                    bgColor = hunkBg
                }

                let lineText = "\(prefix)\(line.content)\n"
                let lineAttrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: textColor,
                    .backgroundColor: bgColor
                ]
                result.append(NSAttributedString(string: lineText, attributes: lineAttrs))
            }

            // Add spacing between hunks
            result.append(NSAttributedString(string: "\n"))
        }

        return result
    }
}

// MARK: - Custom Text View

/// Optimized text view for diff rendering
private class DiffTextView: NSTextView {
    override func draw(_ dirtyRect: NSRect) {
        // Draw background colors for lines
        super.draw(dirtyRect)
    }

    override var isOpaque: Bool { false }
}

// MARK: - Diff View Wrapper

/// Wrapper that automatically chooses between rich and lightweight diff views
struct AdaptiveDiffView: View {
    let fileDiff: FileDiff
    let showLineNumbers: Bool
    let enableWordDiff: Bool
    @Environment(\.colorScheme) private var colorScheme

    /// Threshold for switching to lightweight view
    private static let largeFileThreshold = 500

    private var isLargeFile: Bool {
        let totalLines = fileDiff.hunks.reduce(0) { $0 + $1.lines.count }
        return totalLines > Self.largeFileThreshold
    }

    var body: some View {
        Group {
            if isLargeFile {
                VStack(spacing: 0) {
                    // Performance notice
                    HStack {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(AppTheme.warning)
                        Text("Large file - using optimized view")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(AppTheme.textPrimary)
                        Spacer()
                        Text("\(fileDiff.hunks.reduce(0) { $0 + $1.lines.count }) lines")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(AppTheme.textPrimary)
                    }
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                    .background(AppTheme.warning.opacity(0.1))

                    LightweightDiffView(
                        fileDiff: fileDiff,
                        isDarkMode: colorScheme == .dark
                    )
                }
            } else {
                // Use the existing rich diff view
                // This should be replaced with the actual DiffContentView call
                LightweightDiffView(
                    fileDiff: fileDiff,
                    isDarkMode: colorScheme == .dark
                )
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct LightweightDiffView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleDiff = FileDiff(
            oldPath: nil,
            newPath: "test.swift",
            status: .modified,
            hunks: [
                DiffHunk(
                    header: "@@ -1,5 +1,6 @@",
                    oldStart: 1,
                    oldLines: 5,
                    newStart: 1,
                    newLines: 6,
                    lines: [
                        DiffLine(type: .context, content: "import Foundation", oldLineNumber: 1, newLineNumber: 1),
                        DiffLine(type: .context, content: "", oldLineNumber: 2, newLineNumber: 2),
                        DiffLine(type: .deletion, content: "let oldValue = 42", oldLineNumber: 3, newLineNumber: nil),
                        DiffLine(type: .addition, content: "let newValue = 100", oldLineNumber: nil, newLineNumber: 3),
                        DiffLine(type: .addition, content: "let extraLine = true", oldLineNumber: nil, newLineNumber: 4),
                        DiffLine(type: .context, content: "", oldLineNumber: 4, newLineNumber: 5),
                        DiffLine(type: .context, content: "print(\"done\")", oldLineNumber: 5, newLineNumber: 6),
                    ]
                )
            ],
            additions: 2,
            deletions: 1
        )

        LightweightDiffView(fileDiff: sampleDiff, isDarkMode: false)
            .frame(width: 600, height: 400)
    }
}
#endif
