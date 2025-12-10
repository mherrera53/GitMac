import SwiftUI
import Splash

// MARK: - Diff Line Context Menu Extension

extension View {
    /// Adds a context menu with copy actions to a diff line view
    func diffLineContextMenu(line: DiffLine) -> some View {
        self.contextMenu {
            Button {
                ContextMenuHelper.copyToClipboard(line.content)
                ToastManager.shared.show("Line content copied")
            } label: {
                Label("Copy Line Content", systemImage: "doc.on.doc")
            }

            Button {
                let lineNum = line.newLineNumber ?? line.oldLineNumber ?? 0
                let prefix: String
                switch line.type {
                case .addition: prefix = "+"
                case .deletion: prefix = "-"
                default: prefix = " "
                }
                let text = "\(lineNum): \(prefix)\(line.content)"
                ContextMenuHelper.copyToClipboard(text)
                ToastManager.shared.show("Line copied with number")
            } label: {
                Label("Copy with Line Number", systemImage: "list.number")
            }

            if line.type != .context && line.type != .hunkHeader {
                Divider()

                // Stage/discard hints (hunk-level actions available in toolbar)
                Text("Use hunk actions for stage/discard")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

/// Complete diff viewer with multiple view modes
struct DiffView: View {
    let fileDiff: FileDiff
    var repoPath: String? = nil
    @State private var viewMode: DiffViewMode = .split
    @State private var showLineNumbers = true
    @State private var wordWrap = false

    /// Check if file is markdown
    private var isMarkdown: Bool {
        let ext = (fileDiff.displayPath as NSString).pathExtension.lowercased()
        return ext == "md" || ext == "markdown" || ext == "mdown"
    }

    /// Get full content for preview mode (new file state)
    private var previewContent: String {
        // Reconstruct the new file content from diff hunks
        var lines: [String] = []
        for hunk in fileDiff.hunks {
            for line in hunk.lines {
                switch line.type {
                case .addition, .context:
                    lines.append(line.content)
                case .deletion:
                    break // Skip deleted lines in preview
                case .hunkHeader:
                    break
                }
            }
        }
        return lines.joined(separator: "\n")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            DiffToolbar(
                filename: fileDiff.displayPath,
                additions: fileDiff.additions,
                deletions: fileDiff.deletions,
                viewMode: $viewMode,
                showLineNumbers: $showLineNumbers,
                wordWrap: $wordWrap,
                isMarkdown: isMarkdown
            )

            Rectangle()
                .fill(GitKrakenTheme.border)
                .frame(height: 1)

            // Content
            if fileDiff.isBinary {
                BinaryFileView(filename: fileDiff.displayPath, repoPath: repoPath)
            } else {
                switch viewMode {
                case .split:
                    SplitDiffView(
                        hunks: fileDiff.hunks,
                        showLineNumbers: showLineNumbers,
                        filename: fileDiff.displayPath
                    )
                case .inline:
                    InlineDiffView(
                        hunks: fileDiff.hunks,
                        showLineNumbers: showLineNumbers,
                        filename: fileDiff.displayPath
                    )
                case .hunk:
                    HunkDiffView(
                        hunks: fileDiff.hunks,
                        showLineNumbers: showLineNumbers
                    )
                case .preview:
                    // Show rendered markdown with Mermaid support
                    MarkdownView(content: previewContent, fileName: fileDiff.displayPath)
                }
            }
        }
        .background(GitKrakenTheme.background)
    }
}

enum DiffViewMode: String, CaseIterable {
    case split = "Split"
    case inline = "Inline"
    case hunk = "Hunk"
    case preview = "Preview"

    var icon: String {
        switch self {
        case .split: return "rectangle.split.2x1"
        case .inline: return "rectangle.stack"
        case .hunk: return "text.alignleft"
        case .preview: return "eye"
        }
    }

    /// Modes available for regular files
    static var standardModes: [DiffViewMode] {
        [.split, .inline, .hunk]
    }

    /// Modes available for markdown files (includes preview)
    static var markdownModes: [DiffViewMode] {
        [.split, .inline, .hunk, .preview]
    }
}

// MARK: - Diff Toolbar (GitKraken Style)

struct DiffToolbar: View {
    let filename: String
    let additions: Int
    let deletions: Int
    @Binding var viewMode: DiffViewMode
    @Binding var showLineNumbers: Bool
    @Binding var wordWrap: Bool
    var isMarkdown: Bool = false

    /// Available modes based on file type
    private var availableModes: [DiffViewMode] {
        isMarkdown ? DiffViewMode.markdownModes : DiffViewMode.standardModes
    }

    var body: some View {
        HStack(spacing: 16) {
            // File info
            HStack(spacing: 8) {
                Image(systemName: "doc.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.blue)

                Text(filename)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(GitKrakenTheme.textPrimary)
                    .lineLimit(1)
            }

            // Stats badges
            HStack(spacing: 8) {
                // Additions badge
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold))
                    Text("\(additions)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(GitKrakenTheme.accentGreen)
                .cornerRadius(4)

                // Deletions badge
                HStack(spacing: 4) {
                    Image(systemName: "minus")
                        .font(.system(size: 9, weight: .bold))
                    Text("\(deletions)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(GitKrakenTheme.accentRed)
                .cornerRadius(4)
            }

            Spacer()

            // View options
            HStack(spacing: 4) {
                ToolbarButton(
                    icon: "number",
                    isActive: showLineNumbers,
                    tooltip: "Line numbers"
                ) {
                    showLineNumbers.toggle()
                }

                ToolbarButton(
                    icon: "text.word.spacing",
                    isActive: wordWrap,
                    tooltip: "Word wrap"
                ) {
                    wordWrap.toggle()
                }
            }

            // Divider
            Rectangle()
                .fill(GitKrakenTheme.border)
                .frame(width: 1, height: 20)

            // View mode selector
            HStack(spacing: 2) {
                ForEach(availableModes, id: \.self) { mode in
                    DiffModeButton(
                        mode: mode,
                        isSelected: viewMode == mode
                    ) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            viewMode = mode
                        }
                    }
                }
            }
            .padding(3)
            .background(GitKrakenTheme.backgroundTertiary)
            .cornerRadius(6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(GitKrakenTheme.toolbar)
    }
}

// MARK: - Toolbar Button

struct ToolbarButton: View {
    let icon: String
    let isActive: Bool
    let tooltip: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isActive ? GitKrakenTheme.accent : GitKrakenTheme.textSecondary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isActive ? GitKrakenTheme.accent.opacity(0.15) : (isHovered ? GitKrakenTheme.hover : SwiftUI.Color.clear))
                )
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Diff Mode Button

struct DiffModeButton: View {
    let mode: DiffViewMode
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: mode.icon)
                    .font(.system(size: 10, weight: .medium))
                Text(mode.rawValue)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : GitKrakenTheme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? GitKrakenTheme.accent : (isHovered ? GitKrakenTheme.hover : SwiftUI.Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Split Diff View (Side by Side) with Synchronized Scrolling

struct SplitDiffView: View {
    let hunks: [DiffHunk]
    let showLineNumbers: Bool
    let filename: String

    // Build paired lines for proper alignment
    private var pairedLines: [(left: DiffLine?, right: DiffLine?, hunkHeader: String?)] {
        var pairs: [(left: DiffLine?, right: DiffLine?, hunkHeader: String?)] = []

        for hunk in hunks {
            // Add hunk header as a special row
            pairs.append((left: nil, right: nil, hunkHeader: hunk.header))

            // Group consecutive deletions and additions for better pairing
            var i = 0
            let lines = hunk.lines

            while i < lines.count {
                let line = lines[i]

                if line.type == .context {
                    pairs.append((left: line, right: line, hunkHeader: nil))
                    i += 1
                } else if line.type == .deletion {
                    // Collect consecutive deletions
                    var deletions: [DiffLine] = []
                    while i < lines.count && lines[i].type == .deletion {
                        deletions.append(lines[i])
                        i += 1
                    }

                    // Collect consecutive additions
                    var additions: [DiffLine] = []
                    while i < lines.count && lines[i].type == .addition {
                        additions.append(lines[i])
                        i += 1
                    }

                    // Pair them up
                    let maxCount = max(deletions.count, additions.count)
                    for j in 0..<maxCount {
                        let del = j < deletions.count ? deletions[j] : nil
                        let add = j < additions.count ? additions[j] : nil
                        pairs.append((left: del, right: add, hunkHeader: nil))
                    }
                } else if line.type == .addition {
                    // Standalone addition (no preceding deletion)
                    pairs.append((left: nil, right: line, hunkHeader: nil))
                    i += 1
                } else {
                    i += 1
                }
            }
        }

        return pairs
    }

    var body: some View {
        GeometryReader { geometry in
            let halfWidth = geometry.size.width / 2 - 1

            ScrollView([.vertical, .horizontal]) {
                HStack(spacing: 0) {
                    // Left side (old)
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(pairedLines.enumerated()), id: \.offset) { index, pair in
                            if let header = pair.hunkHeader {
                                SplitHunkHeaderRow(header: header)
                                    .frame(width: halfWidth)
                            } else if let line = pair.left {
                                SplitDiffLineRow(
                                    line: line,
                                    side: .left,
                                    showLineNumber: showLineNumbers,
                                    pairedLine: pair.right
                                )
                                .frame(width: halfWidth)
                            } else {
                                EmptyLineRow(showLineNumber: showLineNumbers)
                                    .frame(width: halfWidth)
                            }
                        }
                    }
                    .frame(width: halfWidth)

                    // Divider
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 2)

                    // Right side (new)
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(pairedLines.enumerated()), id: \.offset) { index, pair in
                            if let header = pair.hunkHeader {
                                SplitHunkHeaderRow(header: header)
                                    .frame(width: halfWidth)
                            } else if let line = pair.right {
                                SplitDiffLineRow(
                                    line: line,
                                    side: .right,
                                    showLineNumber: showLineNumbers,
                                    pairedLine: pair.left
                                )
                                .frame(width: halfWidth)
                            } else {
                                EmptyLineRow(showLineNumber: showLineNumbers)
                                    .frame(width: halfWidth)
                            }
                        }
                    }
                    .frame(width: halfWidth)
                }
            }
        }
    }
}

// MARK: - Split View Components

struct SplitHunkHeaderRow: View {
    let header: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "text.alignleft")
                .font(.system(size: 10))
            Text(header)
                .font(.system(size: 11, design: .monospaced))
        }
        .foregroundColor(GitKrakenTheme.accent)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GitKrakenTheme.accent.opacity(0.08))
    }
}

struct SplitDiffLineRow: View {
    let line: DiffLine
    let side: DiffSide
    let showLineNumber: Bool
    let pairedLine: DiffLine?

    var lineNumber: Int? {
        switch side {
        case .left: return line.oldLineNumber
        case .right: return line.newLineNumber
        }
    }

    // Compute word-level diff if there's a paired line
    private var highlightedContent: AttributedString {
        guard let paired = pairedLine,
              line.type != .context,
              paired.type != .context else {
            return AttributedString(line.content)
        }

        // Simple word-level diff
        let myWords = line.content.components(separatedBy: CharacterSet.whitespaces)
        let otherWords = paired.content.components(separatedBy: CharacterSet.whitespaces)

        var result = AttributedString()

        for (index, word) in myWords.enumerated() {
            var wordAttr = AttributedString(word)

            // Check if word differs
            if index >= otherWords.count || word != otherWords[index] {
                // Highlight changed word
                wordAttr.backgroundColor = line.type == .addition ?
                    GitKrakenTheme.accentGreen.opacity(0.35) : GitKrakenTheme.accentRed.opacity(0.35)
            }

            result.append(wordAttr)
            if index < myWords.count - 1 {
                result.append(AttributedString(" "))
            }
        }

        return result
    }

    var body: some View {
        HStack(spacing: 0) {
            if showLineNumber {
                Text(lineNumber.map { String($0) } ?? "")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 45, alignment: .trailing)
                    .padding(.trailing, 8)
                    .background(lineNumberBackground)
            }

            // Change indicator
            Text(changeIndicator)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(indicatorColor)
                .frame(width: 16)

            // Content with word-level highlighting
            Text(highlightedContent)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(textColor)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
        .padding(.trailing, 8)
        .background(backgroundColor)
        .diffLineContextMenu(line: line)
    }

    var changeIndicator: String {
        switch line.type {
        case .addition: return "+"
        case .deletion: return "-"
        case .context: return " "
        case .hunkHeader: return "@@"
        }
    }

    var indicatorColor: SwiftUI.Color {
        switch line.type {
        case .addition: return GitKrakenTheme.accentGreen
        case .deletion: return GitKrakenTheme.accentRed
        default: return GitKrakenTheme.textMuted
        }
    }

    var backgroundColor: SwiftUI.Color {
        switch line.type {
        case .addition: return GitKrakenTheme.accentGreen.opacity(0.12)
        case .deletion: return GitKrakenTheme.accentRed.opacity(0.12)
        case .context, .hunkHeader: return SwiftUI.Color.clear
        }
    }

    var lineNumberBackground: SwiftUI.Color {
        switch line.type {
        case .addition: return GitKrakenTheme.accentGreen.opacity(0.06)
        case .deletion: return GitKrakenTheme.accentRed.opacity(0.06)
        case .context, .hunkHeader: return GitKrakenTheme.backgroundSecondary
        }
    }

    var textColor: SwiftUI.Color {
        switch line.type {
        case .addition: return GitKrakenTheme.accentGreen
        case .deletion: return GitKrakenTheme.accentRed
        case .context, .hunkHeader: return GitKrakenTheme.textPrimary
        }
    }
}

// MARK: - Inline Diff View

struct InlineDiffView: View {
    let hunks: [DiffHunk]
    let showLineNumbers: Bool
    let filename: String

    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(hunks) { hunk in
                    HunkHeaderRow(header: hunk.header)

                    ForEach(hunk.lines) { line in
                        InlineDiffLineRow(
                            line: line,
                            showLineNumbers: showLineNumbers,
                            filename: filename
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Hunk Diff View

struct HunkDiffView: View {
    let hunks: [DiffHunk]
    let showLineNumbers: Bool
    var filePath: String? = nil
    var isStaged: Bool = false
    var onStageHunk: ((Int) -> Void)? = nil
    var onUnstageHunk: ((Int) -> Void)? = nil
    var onDiscardHunk: ((Int) -> Void)? = nil

    @State private var collapsedHunks: Set<Int> = []

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Summary header
                HunkSummaryHeader(
                    hunkCount: hunks.count,
                    totalAdditions: hunks.reduce(0) { $0 + $1.lines.filter { $0.type == .addition }.count },
                    totalDeletions: hunks.reduce(0) { $0 + $1.lines.filter { $0.type == .deletion }.count }
                )

                ForEach(Array(hunks.enumerated()), id: \.element.id) { index, hunk in
                    CollapsibleHunkCard(
                        hunk: hunk,
                        hunkIndex: index,
                        totalHunks: hunks.count,
                        showLineNumbers: showLineNumbers,
                        showActions: onStageHunk != nil || onUnstageHunk != nil,
                        isStaged: isStaged,
                        isCollapsed: collapsedHunks.contains(index),
                        onToggleCollapse: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if collapsedHunks.contains(index) {
                                    collapsedHunks.remove(index)
                                } else {
                                    collapsedHunks.insert(index)
                                }
                            }
                        },
                        onStage: { onStageHunk?(index) },
                        onUnstage: { onUnstageHunk?(index) },
                        onDiscard: { onDiscardHunk?(index) }
                    )
                }
            }
            .padding()
        }
    }
}

// MARK: - Hunk Summary Header

struct HunkSummaryHeader: View {
    let hunkCount: Int
    let totalAdditions: Int
    let totalDeletions: Int

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 12))
                Text("\(hunkCount) hunk\(hunkCount == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(GitKrakenTheme.textSecondary)

            Spacer()

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                    Text("\(totalAdditions)")
                }
                .foregroundColor(GitKrakenTheme.accentGreen)

                HStack(spacing: 4) {
                    Image(systemName: "minus")
                        .font(.system(size: 10, weight: .bold))
                    Text("\(totalDeletions)")
                }
                .foregroundColor(GitKrakenTheme.accentRed)
            }
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(GitKrakenTheme.backgroundSecondary)
        .cornerRadius(8)
    }
}

// MARK: - Collapsible Hunk Card

struct CollapsibleHunkCard: View {
    let hunk: DiffHunk
    let hunkIndex: Int
    let totalHunks: Int
    let showLineNumbers: Bool
    let showActions: Bool
    let isStaged: Bool
    let isCollapsed: Bool
    var onToggleCollapse: (() -> Void)?
    var onStage: (() -> Void)?
    var onUnstage: (() -> Void)?
    var onDiscard: (() -> Void)?

    @State private var isHovered = false

    private var additions: Int {
        hunk.lines.filter { $0.type == .addition }.count
    }

    private var deletions: Int {
        hunk.lines.filter { $0.type == .deletion }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hunk header (always visible)
            HStack(spacing: 8) {
                // Collapse toggle
                Button(action: { onToggleCollapse?() }) {
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(GitKrakenTheme.textSecondary)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)

                // Hunk number badge
                Text("Hunk \(hunkIndex + 1)/\(totalHunks)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(GitKrakenTheme.accent)
                    .cornerRadius(4)

                // Line range
                Text("Lines \(hunk.oldStart)-\(hunk.oldStart + hunk.oldLines) → \(hunk.newStart)-\(hunk.newStart + hunk.newLines)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(GitKrakenTheme.textMuted)

                // Change stats
                HStack(spacing: 6) {
                    if additions > 0 {
                        Text("+\(additions)")
                            .foregroundColor(GitKrakenTheme.accentGreen)
                    }
                    if deletions > 0 {
                        Text("-\(deletions)")
                            .foregroundColor(GitKrakenTheme.accentRed)
                    }
                }
                .font(.system(size: 11, weight: .medium, design: .monospaced))

                Spacer()

                // Actions (visible on hover)
                if showActions && isHovered && !isCollapsed {
                    HStack(spacing: 6) {
                        if !isStaged {
                            Button {
                                onStage?()
                            } label: {
                                Label("Stage", systemImage: "plus.circle.fill")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(GitKrakenTheme.accentGreen)
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)

                            Button {
                                onDiscard?()
                            } label: {
                                Label("Discard", systemImage: "trash")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(GitKrakenTheme.accentRed)
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button {
                                onUnstage?()
                            } label: {
                                Label("Unstage", systemImage: "minus.circle.fill")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(GitKrakenTheme.accentOrange)
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(GitKrakenTheme.accent.opacity(0.08))

            // Lines (collapsible)
            if !isCollapsed {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(hunk.lines) { line in
                        HunkLineRow(line: line, showLineNumber: showLineNumbers)
                    }
                }
            } else {
                // Collapsed preview
                HStack(spacing: 8) {
                    Text("...")
                        .foregroundColor(GitKrakenTheme.textMuted)
                    Text("\(hunk.lines.count) lines")
                        .font(.system(size: 11))
                        .foregroundColor(GitKrakenTheme.textMuted)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(GitKrakenTheme.backgroundTertiary)
            }
        }
        .background(GitKrakenTheme.backgroundSecondary)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHovered ? GitKrakenTheme.accent.opacity(0.6) : GitKrakenTheme.border, lineWidth: isHovered ? 2 : 1)
        )
        .onHover { isHovered = $0 }
    }
}

// MARK: - Hunk Card with Actions
struct HunkCard: View {
    let hunk: DiffHunk
    let hunkIndex: Int
    let showLineNumbers: Bool
    let showActions: Bool
    let isStaged: Bool
    var onStage: (() -> Void)?
    var onUnstage: (() -> Void)?
    var onDiscard: (() -> Void)?
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hunk header with actions
            HStack {
                Text(hunk.header)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)

                Spacer()

                if showActions && isHovered {
                    HStack(spacing: 8) {
                        if !isStaged {
                            // Stage this hunk
                            Button {
                                onStage?()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Stage Hunk")
                                }
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(GitKrakenTheme.accentGreen)
                                .cornerRadius(4)
                            }
                            .buttonStyle(.plain)

                            // Discard this hunk
                            Button {
                                onDiscard?()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "trash")
                                    Text("Discard")
                                }
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(GitKrakenTheme.accentRed)
                                .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                        } else {
                            // Unstage this hunk
                            Button {
                                onUnstage?()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "minus.circle.fill")
                                    Text("Unstage Hunk")
                                }
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(GitKrakenTheme.accentOrange)
                                .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Text("Lines \(hunk.oldStart)-\(hunk.oldStart + hunk.oldLines)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(8)
            .background(Color.blue.opacity(0.1))

            // Lines
            VStack(alignment: .leading, spacing: 0) {
                ForEach(hunk.lines) { line in
                    HunkLineRow(line: line, showLineNumber: showLineNumbers)
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHovered ? GitKrakenTheme.accent.opacity(0.5) : Color.secondary.opacity(0.2), lineWidth: isHovered ? 2 : 1)
        )
        .onHover { isHovered = $0 }
    }
}

// MARK: - Line Components

enum DiffSide {
    case left, right
}

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
                .foregroundColor(GitKrakenTheme.textMuted)
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
        case .addition: return GitKrakenTheme.accentGreen
        case .deletion: return GitKrakenTheme.accentRed
        default: return GitKrakenTheme.textMuted
        }
    }

    var backgroundColor: SwiftUI.Color {
        switch line.type {
        case .addition: return GitKrakenTheme.accentGreen.opacity(0.1)
        case .deletion: return GitKrakenTheme.accentRed.opacity(0.1)
        default: return SwiftUI.Color.clear
        }
    }

    var lineNumberBackground: SwiftUI.Color {
        switch line.type {
        case .addition: return GitKrakenTheme.accentGreen.opacity(0.06)
        case .deletion: return GitKrakenTheme.accentRed.opacity(0.06)
        default: return GitKrakenTheme.backgroundSecondary
        }
    }

    var textColor: SwiftUI.Color {
        switch line.type {
        case .addition: return GitKrakenTheme.accentGreen
        case .deletion: return GitKrakenTheme.accentRed
        default: return GitKrakenTheme.textPrimary
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
        .foregroundColor(GitKrakenTheme.accent)
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GitKrakenTheme.accent.opacity(0.08))
    }
}

struct EmptyLineRow: View {
    let showLineNumber: Bool

    var body: some View {
        HStack(spacing: 0) {
            if showLineNumber {
                Text("")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(GitKrakenTheme.textMuted)
                    .frame(width: 45, alignment: .trailing)
                    .padding(.trailing, 8)
                    .background(GitKrakenTheme.backgroundSecondary)
            }
            Text(" ")
                .frame(width: 16)
            Spacer()
        }
        .font(.system(size: 12, design: .monospaced))
        .padding(.vertical, 2)
        .background(GitKrakenTheme.backgroundTertiary.opacity(0.3))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct BinaryFileView: View {
    let filename: String
    var repoPath: String? = nil

    private var isImage: Bool {
        let ext = (filename as NSString).pathExtension.lowercased()
        return ["png", "jpg", "jpeg", "gif", "webp", "bmp", "tiff", "ico", "svg"].contains(ext)
    }

    private var isPDF: Bool {
        let ext = (filename as NSString).pathExtension.lowercased()
        return ext == "pdf"
    }

    private var fullPath: URL? {
        guard let repoPath = repoPath else { return nil }
        return URL(fileURLWithPath: repoPath).appendingPathComponent(filename)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if isImage, let path = fullPath {
                    // Image preview
                    ImagePreviewView(imageURL: path, filename: filename)
                } else if isPDF, let path = fullPath {
                    // PDF preview
                    PDFPreviewView(pdfURL: path, filename: filename)
                } else {
                    // Generic binary file
                    GenericBinaryView(filename: filename)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}

// MARK: - Image Preview
struct ImagePreviewView: View {
    let imageURL: URL
    let filename: String
    @State private var imageSize: CGSize = .zero

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: "photo")
                    .foregroundColor(.blue)
                Text(filename)
                    .font(.headline)
                Spacer()
                if imageSize != .zero {
                    Text("\(Int(imageSize.width)) × \(Int(imageSize.height))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                }
            }

            // Image preview with max size
            if let nsImage = NSImage(contentsOf: imageURL) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 800, maxHeight: 600)
                    .background(
                        // Checkerboard pattern for transparent images
                        CheckerboardPattern()
                    )
                    .cornerRadius(8)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    .onAppear {
                        imageSize = nsImage.size
                    }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.yellow)
                    Text("Could not load image")
                        .foregroundColor(.secondary)
                }
                .frame(height: 200)
            }

            // File info
            if let attrs = try? FileManager.default.attributesOfItem(atPath: imageURL.path),
               let fileSize = attrs[.size] as? Int64 {
                Text(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Checkerboard Pattern (for transparent images)
struct CheckerboardPattern: View {
    var body: some View {
        Canvas { context, size in
            let squareSize: CGFloat = 10
            let light = Color.gray.opacity(0.2)
            let dark = Color.gray.opacity(0.3)

            for row in 0..<Int(size.height / squareSize) + 1 {
                for col in 0..<Int(size.width / squareSize) + 1 {
                    let isLight = (row + col) % 2 == 0
                    let rect = CGRect(
                        x: CGFloat(col) * squareSize,
                        y: CGFloat(row) * squareSize,
                        width: squareSize,
                        height: squareSize
                    )
                    context.fill(Rectangle().path(in: rect), with: .color(isLight ? light : dark))
                }
            }
        }
    }
}

// MARK: - PDF Preview
struct PDFPreviewView: View {
    let pdfURL: URL
    let filename: String

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "doc.richtext")
                    .foregroundColor(.red)
                Text(filename)
                    .font(.headline)
                Spacer()
            }

            // Quick Look preview or fallback
            if let pdfData = try? Data(contentsOf: pdfURL),
               let pdfDoc = NSPDFImageRep(data: pdfData) {
                VStack {
                    Image(nsImage: pdfDoc.pdfImage ?? NSImage())
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 600, maxHeight: 800)
                        .background(Color.white)
                        .cornerRadius(8)
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)

                    Text("\(pdfDoc.pageCount) page(s)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 48))
                        .foregroundColor(.red)
                    Text("PDF Document")
                        .font(.headline)
                    Button("Open in Preview") {
                        NSWorkspace.shared.open(pdfURL)
                    }
                }
                .frame(height: 200)
            }
        }
    }
}

extension NSPDFImageRep {
    var pdfImage: NSImage? {
        let image = NSImage(size: bounds.size)
        image.addRepresentation(self)
        return image
    }
}

// MARK: - Generic Binary View
struct GenericBinaryView: View {
    let filename: String

    private var fileExtension: String {
        (filename as NSString).pathExtension.lowercased()
    }

    private var fileIcon: String {
        switch fileExtension {
        case "zip", "tar", "gz", "7z", "rar": return "doc.zipper"
        case "dmg", "iso": return "externaldrive"
        case "app": return "app.badge.checkmark"
        case "ttf", "otf", "woff", "woff2": return "textformat"
        case "mp3", "wav", "aac", "flac", "m4a": return "waveform"
        case "mp4", "mov", "avi", "mkv", "webm": return "film"
        case "sqlite", "db": return "cylinder"
        default: return "doc.fill"
        }
    }

    private var fileTypeName: String {
        switch fileExtension {
        case "zip": return "ZIP Archive"
        case "tar": return "TAR Archive"
        case "gz": return "GZIP Archive"
        case "7z": return "7-Zip Archive"
        case "rar": return "RAR Archive"
        case "dmg": return "Disk Image"
        case "iso": return "ISO Image"
        case "app": return "Application"
        case "ttf", "otf": return "Font File"
        case "woff", "woff2": return "Web Font"
        case "mp3": return "MP3 Audio"
        case "wav": return "WAV Audio"
        case "aac": return "AAC Audio"
        case "flac": return "FLAC Audio"
        case "m4a": return "M4A Audio"
        case "mp4": return "MP4 Video"
        case "mov": return "QuickTime Video"
        case "avi": return "AVI Video"
        case "mkv": return "MKV Video"
        case "webm": return "WebM Video"
        case "sqlite", "db": return "Database"
        default: return "Binary File"
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: fileIcon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text(fileTypeName)
                .font(.headline)

            Text(filename)
                .foregroundColor(.secondary)

            Text("Cannot display diff for binary files")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxHeight: 300)
    }
}

// MARK: - Syntax Highlighter

struct SyntaxHighlightedText: View {
    let code: String
    let language: String

    private var highlightedCode: AttributedString {
        guard let grammar = grammar(for: language) else {
            return AttributedString(code)
        }

        let highlighter = Splash.SyntaxHighlighter(
            format: AttributedStringOutputFormat(theme: .sundellsColors(withFont: .init(size: 12)))
        )

        let highlighted = highlighter.highlight(code)
        return AttributedString(highlighted)
    }

    var body: some View {
        Text(highlightedCode)
            .font(.system(.body, design: .monospaced))
    }

    private func grammar(for language: String) -> Grammar? {
        switch language.lowercased() {
        case "swift": return SwiftGrammar()
        default: return nil
        }
    }
}

// MARK: - Diff Parser

struct DiffParser {
    /// Parse a unified diff string into FileDiff objects
    static func parse(_ diffString: String) -> [FileDiff] {
        var files: [FileDiff] = []
        var currentFile: (oldPath: String?, newPath: String, hunks: [DiffHunk], additions: Int, deletions: Int)?
        var currentHunk: (header: String, oldStart: Int, oldLines: Int, newStart: Int, newLines: Int, lines: [DiffLine])?

        let lines = diffString.components(separatedBy: .newlines)
        var oldLineNum = 0
        var newLineNum = 0

        for line in lines {
            if line.hasPrefix("diff --git") {
                // Save previous file
                if var file = currentFile {
                    if let hunk = currentHunk {
                        file.hunks.append(DiffHunk(
                            header: hunk.header,
                            oldStart: hunk.oldStart,
                            oldLines: hunk.oldLines,
                            newStart: hunk.newStart,
                            newLines: hunk.newLines,
                            lines: hunk.lines
                        ))
                    }
                    files.append(FileDiff(
                        oldPath: file.oldPath,
                        newPath: file.newPath,
                        status: determineStatus(file.oldPath, file.newPath),
                        hunks: file.hunks,
                        additions: file.additions,
                        deletions: file.deletions
                    ))
                }
                currentFile = nil
                currentHunk = nil
            } else if line.hasPrefix("--- ") {
                let path = String(line.dropFirst(4))
                if currentFile == nil {
                    currentFile = (oldPath: path == "/dev/null" ? nil : path, newPath: "", hunks: [], additions: 0, deletions: 0)
                } else {
                    currentFile?.oldPath = path == "/dev/null" ? nil : path
                }
            } else if line.hasPrefix("+++ ") {
                let path = String(line.dropFirst(4)).replacingOccurrences(of: "b/", with: "")
                if currentFile == nil {
                    currentFile = (oldPath: nil, newPath: path, hunks: [], additions: 0, deletions: 0)
                } else {
                    currentFile?.newPath = path
                }
            } else if line.hasPrefix("@@") {
                // Save previous hunk
                if let hunk = currentHunk {
                    currentFile?.hunks.append(DiffHunk(
                        header: hunk.header,
                        oldStart: hunk.oldStart,
                        oldLines: hunk.oldLines,
                        newStart: hunk.newStart,
                        newLines: hunk.newLines,
                        lines: hunk.lines
                    ))
                }

                // Parse hunk header: @@ -oldStart,oldLines +newStart,newLines @@
                let pattern = #"@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@"#
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {

                    let oldStart = Int(line[Range(match.range(at: 1), in: line)!]) ?? 0
                    let oldLines = match.range(at: 2).location != NSNotFound ?
                        Int(line[Range(match.range(at: 2), in: line)!]) ?? 1 : 1
                    let newStart = Int(line[Range(match.range(at: 3), in: line)!]) ?? 0
                    let newLines = match.range(at: 4).location != NSNotFound ?
                        Int(line[Range(match.range(at: 4), in: line)!]) ?? 1 : 1

                    oldLineNum = oldStart
                    newLineNum = newStart

                    currentHunk = (header: line, oldStart: oldStart, oldLines: oldLines, newStart: newStart, newLines: newLines, lines: [])
                }
            } else if currentHunk != nil {
                let type: DiffLineType
                var content = line
                var oldNum: Int? = nil
                var newNum: Int? = nil

                if line.hasPrefix("+") {
                    type = .addition
                    content = String(line.dropFirst())
                    newNum = newLineNum
                    newLineNum += 1
                    currentFile?.additions += 1
                } else if line.hasPrefix("-") {
                    type = .deletion
                    content = String(line.dropFirst())
                    oldNum = oldLineNum
                    oldLineNum += 1
                    currentFile?.deletions += 1
                } else if line.hasPrefix(" ") {
                    type = .context
                    content = String(line.dropFirst())
                    oldNum = oldLineNum
                    newNum = newLineNum
                    oldLineNum += 1
                    newLineNum += 1
                } else {
                    type = .context
                    oldNum = oldLineNum
                    newNum = newLineNum
                    oldLineNum += 1
                    newLineNum += 1
                }

                currentHunk?.lines.append(DiffLine(
                    type: type,
                    content: content,
                    oldLineNumber: oldNum,
                    newLineNumber: newNum
                ))
            }
        }

        // Save last file
        if var file = currentFile {
            if let hunk = currentHunk {
                file.hunks.append(DiffHunk(
                    header: hunk.header,
                    oldStart: hunk.oldStart,
                    oldLines: hunk.oldLines,
                    newStart: hunk.newStart,
                    newLines: hunk.newLines,
                    lines: hunk.lines
                ))
            }
            files.append(FileDiff(
                oldPath: file.oldPath,
                newPath: file.newPath,
                status: determineStatus(file.oldPath, file.newPath),
                hunks: file.hunks,
                additions: file.additions,
                deletions: file.deletions
            ))
        }

        return files
    }

    private static func determineStatus(_ oldPath: String?, _ newPath: String) -> FileStatusType {
        if oldPath == nil || oldPath == "/dev/null" {
            return .added
        } else if newPath.isEmpty || newPath == "/dev/null" {
            return .deleted
        } else if oldPath != newPath {
            return .renamed
        }
        return .modified
    }
}

// #Preview {
//     let sampleDiff = FileDiff(
//         oldPath: "test.swift",
//         newPath: "test.swift",
//         status: .modified,
//         hunks: [
//             DiffHunk(
//                 header: "@@ -1,5 +1,7 @@",
//                 oldStart: 1,
//                 oldLines: 5,
//                 newStart: 1,
//                 newLines: 7,
//                 lines: [
//                     DiffLine(type: .context, content: "import Foundation", oldLineNumber: 1, newLineNumber: 1),
//                     DiffLine(type: .addition, content: "import SwiftUI", oldLineNumber: nil, newLineNumber: 2),
//                     DiffLine(type: .context, content: "", oldLineNumber: 2, newLineNumber: 3),
//                     DiffLine(type: .deletion, content: "class OldClass {", oldLineNumber: 3, newLineNumber: nil),
//                     DiffLine(type: .addition, content: "struct NewStruct {", oldLineNumber: nil, newLineNumber: 4),
//                     DiffLine(type: .context, content: "    let value: Int", oldLineNumber: 4, newLineNumber: 5),
//                     DiffLine(type: .context, content: "}", oldLineNumber: 5, newLineNumber: 6),
//                 ]
//             )
//         ],
//         additions: 2,
//         deletions: 1
//     )
// 
//     DiffView(fileDiff: sampleDiff)
//         .frame(width: 800, height: 500)
// }
