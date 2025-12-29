import SwiftUI
import AppKit

// MARK: - Search Result

/// Represents a search match in the diff
public struct DiffSearchMatch: Identifiable, Equatable {
    public let id = UUID()
    public let hunkIndex: Int
    public let lineIndex: Int
    public let range: Range<String.Index>
    public let lineContent: String

    /// Y offset for scrolling to this match
    public var yOffset: CGFloat = 0
}

// MARK: - Search State

/// Manages search state for diff view
@MainActor
public class DiffSearchState: ObservableObject {
    @Published public var query: String = ""
    @Published public var matches: [DiffSearchMatch] = []
    @Published public var currentMatchIndex: Int = 0
    @Published public var isSearching: Bool = false
    @Published public var caseSensitive: Bool = false
    @Published public var useRegex: Bool = false

    public var currentMatch: DiffSearchMatch? {
        guard !matches.isEmpty, currentMatchIndex < matches.count else { return nil }
        return matches[currentMatchIndex]
    }

    public var matchCount: Int { matches.count }

    public var hasMatches: Bool { !matches.isEmpty }

    public func nextMatch() {
        guard !matches.isEmpty else { return }
        currentMatchIndex = (currentMatchIndex + 1) % matches.count
    }

    public func previousMatch() {
        guard !matches.isEmpty else { return }
        currentMatchIndex = (currentMatchIndex - 1 + matches.count) % matches.count
    }

    public func clearSearch() {
        query = ""
        matches = []
        currentMatchIndex = 0
    }

    /// Search within hunks
    public func search(in hunks: [StreamingDiffHunk]) {
        guard !query.isEmpty else {
            matches = []
            currentMatchIndex = 0
            return
        }

        isSearching = true
        var foundMatches: [DiffSearchMatch] = []

        let searchOptions: String.CompareOptions = caseSensitive ? [] : .caseInsensitive

        for (hunkIndex, hunk) in hunks.enumerated() {
            guard let lines = hunk.lines else { continue }

            for (lineIndex, line) in lines.enumerated() {
                var searchRange = line.content.startIndex..<line.content.endIndex

                while let range = line.content.range(of: query, options: searchOptions, range: searchRange) {
                    let match = DiffSearchMatch(
                        hunkIndex: hunkIndex,
                        lineIndex: lineIndex,
                        range: range,
                        lineContent: line.content
                    )
                    foundMatches.append(match)

                    // Move past this match for next iteration
                    searchRange = range.upperBound..<line.content.endIndex
                }
            }
        }

        matches = foundMatches
        currentMatchIndex = 0
        isSearching = false
    }
}

// MARK: - Search Bar View

/// Search bar for diff view
struct DiffSearchBar: View {
    @StateObject private var themeManager = ThemeManager.shared

    @ObservedObject var searchState: DiffSearchState
    @FocusState private var isFocused: Bool
    var onClose: () -> Void

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // Search icon
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppTheme.textMuted)
                .font(DesignTokens.Typography.callout)

            // Search field
            TextField("Search in diff...", text: $searchState.query)
                .textFieldStyle(.plain)
                .font(DesignTokens.Typography.callout)
                .focused($isFocused)
                .onSubmit {
                    searchState.nextMatch()
                }

            // Match counter
            if !searchState.query.isEmpty {
                if searchState.hasMatches {
                    Text("\(searchState.currentMatchIndex + 1)/\(searchState.matchCount)")
                        .font(DesignTokens.Typography.caption.weight(.medium))
                        .foregroundColor(AppTheme.textSecondary)
                        .monospacedDigit()
                } else {
                    Text("No matches")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(AppTheme.error)
                }
            }

            Divider()
                .frame(height: DesignTokens.Size.iconMD)

            // Navigation buttons
            Button {
                searchState.previousMatch()
            } label: {
                Image(systemName: "chevron.up")
                    .font(DesignTokens.Typography.caption.weight(.medium))
                    .foregroundColor(AppTheme.textSecondary)
            }
            .buttonStyle(.plain)
            .disabled(!searchState.hasMatches)
            .keyboardShortcut("g", modifiers: [.command, .shift])

            Button {
                searchState.nextMatch()
            } label: {
                Image(systemName: "chevron.down")
                    .font(DesignTokens.Typography.caption.weight(.medium))
                    .foregroundColor(AppTheme.textSecondary)
            }
            .buttonStyle(.plain)
            .disabled(!searchState.hasMatches)
            .keyboardShortcut("g", modifiers: .command)

            Divider()
                .frame(height: DesignTokens.Size.iconMD)

            // Options
            Toggle(isOn: $searchState.caseSensitive) {
                Text("Aa")
                    .font(DesignTokens.Typography.caption2.weight(.bold))
            }
            .toggleStyle(.button)
            .buttonStyle(.plain)
            .help("Case Sensitive")

            // Close button
            Button {
                searchState.clearSearch()
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(DesignTokens.Typography.caption2.weight(.medium))
                    .foregroundColor(AppTheme.textMuted)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(AppTheme.toolbar)
        .cornerRadius(DesignTokens.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                .stroke(Color.Theme(themeManager.colors).border, lineWidth: 1)
        )
        .onAppear {
            isFocused = true
        }
    }
}

// MARK: - Navigation State

/// Manages navigation between changes
@MainActor
public class DiffNavigationState: ObservableObject {
    @Published public var changePositions: [ChangePosition] = []
    @Published public var currentChangeIndex: Int = 0

    public struct ChangePosition: Identifiable {
        public let id = UUID()
        public let hunkIndex: Int
        public let lineIndex: Int
        public let type: DiffLineType
        public let yOffset: CGFloat
    }

    public var currentChange: ChangePosition? {
        guard !changePositions.isEmpty, currentChangeIndex < changePositions.count else { return nil }
        return changePositions[currentChangeIndex]
    }

    public var changeCount: Int { changePositions.count }

    public func nextChange() {
        guard !changePositions.isEmpty else { return }
        currentChangeIndex = (currentChangeIndex + 1) % changePositions.count
    }

    public func previousChange() {
        guard !changePositions.isEmpty else { return }
        currentChangeIndex = (currentChangeIndex - 1 + changePositions.count) % changePositions.count
    }

    public func nextAddition() {
        guard !changePositions.isEmpty else { return }
        let startIndex = currentChangeIndex
        var index = (startIndex + 1) % changePositions.count

        while index != startIndex {
            if changePositions[index].type == .addition {
                currentChangeIndex = index
                return
            }
            index = (index + 1) % changePositions.count
        }
    }

    public func nextDeletion() {
        guard !changePositions.isEmpty else { return }
        let startIndex = currentChangeIndex
        var index = (startIndex + 1) % changePositions.count

        while index != startIndex {
            if changePositions[index].type == .deletion {
                currentChangeIndex = index
                return
            }
            index = (index + 1) % changePositions.count
        }
    }

    /// Build change positions from hunks
    public func buildChangePositions(from hunks: [StreamingDiffHunk], lineHeight: CGFloat = 18) {
        var positions: [ChangePosition] = []
        var yOffset: CGFloat = 0

        for (hunkIndex, hunk) in hunks.enumerated() {
            yOffset += lineHeight + 8 // Header

            if hunk.isCollapsed {
                yOffset += lineHeight // Collapsed indicator
            } else if let lines = hunk.lines {
                for (lineIndex, line) in lines.enumerated() {
                    if line.type == .addition || line.type == .deletion {
                        positions.append(ChangePosition(
                            hunkIndex: hunkIndex,
                            lineIndex: lineIndex,
                            type: line.type,
                            yOffset: yOffset
                        ))
                    }
                    yOffset += lineHeight
                }
            }

            yOffset += 8 // Spacing
        }

        changePositions = positions
        currentChangeIndex = 0
    }
}

// MARK: - Navigation Toolbar

/// Toolbar for navigating between changes
struct DiffNavigationToolbar: View {
    @ObservedObject var navigationState: DiffNavigationState
    var onNavigate: (CGFloat) -> Void

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            // Previous change
            Button {
                navigationState.previousChange()
                if let change = navigationState.currentChange {
                    onNavigate(change.yOffset)
                }
            } label: {
                Image(systemName: "arrow.up")
                    .font(DesignTokens.Typography.caption.weight(.medium))
                    .foregroundColor(AppTheme.textSecondary)
            }
            .buttonStyle(.plain)
            .help("Previous Change (⌘↑)")
            .keyboardShortcut(.upArrow, modifiers: .command)

            // Next change
            Button {
                navigationState.nextChange()
                if let change = navigationState.currentChange {
                    onNavigate(change.yOffset)
                }
            } label: {
                Image(systemName: "arrow.down")
                    .font(DesignTokens.Typography.caption.weight(.medium))
                    .foregroundColor(AppTheme.textSecondary)
            }
            .buttonStyle(.plain)
            .help("Next Change (⌘↓)")
            .keyboardShortcut(.downArrow, modifiers: .command)

            Divider()
                .frame(height: DesignTokens.Size.iconMD)

            // Jump to additions
            Button {
                navigationState.nextAddition()
                if let change = navigationState.currentChange {
                    onNavigate(change.yOffset)
                }
            } label: {
                HStack(spacing: DesignTokens.Spacing.xxs) {
                    Image(systemName: "plus")
                        .font(DesignTokens.Typography.caption2.weight(.bold))
                    Text("Next")
                        .font(DesignTokens.Typography.caption2)
                }
                .foregroundColor(AppTheme.success)
            }
            .buttonStyle(.plain)
            .help("Next Addition")

            // Jump to deletions
            Button {
                navigationState.nextDeletion()
                if let change = navigationState.currentChange {
                    onNavigate(change.yOffset)
                }
            } label: {
                HStack(spacing: DesignTokens.Spacing.xxs) {
                    Image(systemName: "minus")
                        .font(DesignTokens.Typography.caption2.weight(.bold))
                    Text("Next")
                        .font(DesignTokens.Typography.caption2)
                }
                .foregroundColor(AppTheme.error)
            }
            .buttonStyle(.plain)
            .help("Next Deletion")

            Spacer()

            // Change counter
            if navigationState.changeCount > 0 {
                Text("\(navigationState.currentChangeIndex + 1)/\(navigationState.changeCount) changes")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.textSecondary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.xs)
    }
}

// MARK: - Status Bar

/// Status bar showing diff metrics and LFM status
struct DiffStatusBar: View {
    let stats: DiffPreflightStats?
    let isLargeFileMode: Bool
    let parseTimeMs: Double?
    let renderTimeMs: Double?
    let cacheStats: (entries: Int, bytesUsed: Int)?

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.lg) {
            // File stats
            if let stats = stats {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    // Additions
                    HStack(spacing: DesignTokens.Spacing.xxs) {
                        Image(systemName: "plus")
                            .font(DesignTokens.Typography.caption2.weight(.bold))
                        Text("\(stats.additions)")
                            .monospacedDigit()
                    }
                    .foregroundColor(AppTheme.success)

                    // Deletions
                    HStack(spacing: DesignTokens.Spacing.xxs) {
                        Image(systemName: "minus")
                            .font(DesignTokens.Typography.caption2.weight(.bold))
                        Text("\(stats.deletions)")
                            .monospacedDigit()
                    }
                    .foregroundColor(AppTheme.error)
                }
                .font(DesignTokens.Typography.caption.weight(.medium))
            }

            Divider()
                .frame(height: DesignTokens.Spacing.md)

            // LFM indicator
            if isLargeFileMode {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "bolt.fill")
                        .font(DesignTokens.Typography.caption2)
                    Text("Large File Mode")
                        .font(DesignTokens.Typography.caption2.weight(.medium))
                }
                .foregroundColor(AppTheme.warning)
            }

            Spacer()

            // Performance metrics (debug)
            #if DEBUG
            if let parseTime = parseTimeMs {
                Text("Parse: \(String(format: "%.1f", parseTime))ms")
                    .font(DesignTokens.Typography.caption2.monospaced())
                    .foregroundColor(AppTheme.textMuted)
            }

            if let renderTime = renderTimeMs {
                Text("Render: \(String(format: "%.1f", renderTime))ms")
                    .font(DesignTokens.Typography.caption2.monospaced())
                    .foregroundColor(renderTime > 16 ? AppTheme.error : AppTheme.textMuted)
            }

            if let cache = cacheStats {
                Text("Cache: \(cache.entries) (\(formatBytes(cache.bytesUsed)))")
                    .font(DesignTokens.Typography.caption2.monospaced())
                    .foregroundColor(AppTheme.textMuted)
            }
            #endif
        }
        .font(DesignTokens.Typography.caption)
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(AppTheme.toolbar)
    }

    private func formatBytes(_ bytes: Int) -> String {
        if bytes >= 1_048_576 {
            return String(format: "%.1fMB", Double(bytes) / 1_048_576)
        } else if bytes >= 1024 {
            return String(format: "%.1fKB", Double(bytes) / 1024)
        }
        return "\(bytes)B"
    }
}

// MARK: - Side-by-Side View

/// Side-by-side diff view for medium-sized files
struct SideBySideDiffView: View {
    let hunks: [StreamingDiffHunk]
    let showLineNumbers: Bool

    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let columnWidth = (geometry.size.width - 20) / 2

            HStack(spacing: 0) {
                // Left side (old/deletions)
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(hunks) { hunk in
                            if let lines = hunk.lines {
                                SideBySideHunkView(
                                    hunk: hunk,
                                    lines: lines,
                                    side: .left,
                                    showLineNumbers: showLineNumbers
                                )
                            }
                        }
                    }
                }
                .frame(width: columnWidth)
                .background(AppTheme.background)

                // Divider
                Rectangle()
                    .fill(Color.Theme(themeManager.colors).border)
                    .frame(width: 1)

                // Gutter with line connectors
                Rectangle()
                    .fill(AppTheme.backgroundSecondary)
                    .frame(width: 18)

                // Right side (new/additions)
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(hunks) { hunk in
                            if let lines = hunk.lines {
                                SideBySideHunkView(
                                    hunk: hunk,
                                    lines: lines,
                                    side: .right,
                                    showLineNumbers: showLineNumbers
                                )
                            }
                        }
                    }
                }
                .frame(width: columnWidth)
                .background(AppTheme.background)
            }
        }
    }
}

/// Individual hunk in side-by-side view
private struct SideBySideHunkView: View {
    let hunk: StreamingDiffHunk
    let lines: [DiffLine]
    let side: Side
    let showLineNumbers: Bool

    enum Side {
        case left, right
    }

    var body: some View {
        VStack(spacing: 0) {
            // Hunk header
            HStack {
                Text(hunk.header)
                    .font(DesignTokens.Typography.caption.monospaced())
                    .foregroundColor(AppTheme.accent)
                Spacer()
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(AppTheme.accent.opacity(0.1))

            // Lines
            ForEach(Array(filteredLines.enumerated()), id: \.offset) { index, line in
                SideBySideLineRow(line: line, side: side, showLineNumber: showLineNumbers)
            }
        }
    }

    private var filteredLines: [DiffLine] {
        switch side {
        case .left:
            // Show context and deletions
            return lines.filter { $0.type == .context || $0.type == .deletion }
        case .right:
            // Show context and additions
            return lines.filter { $0.type == .context || $0.type == .addition }
        }
    }
}

/// Single line in side-by-side view
private struct SideBySideLineRow: View {
    let line: DiffLine
    let side: SideBySideHunkView.Side
    let showLineNumber: Bool

    var body: some View {
        HStack(spacing: 0) {
            if showLineNumber {
                Text(lineNumber)
                    .font(DesignTokens.Typography.caption.monospaced())
                    .foregroundColor(AppTheme.textMuted)
                    .frame(width: 40, alignment: .trailing)
                    .padding(.trailing, DesignTokens.Spacing.sm)
                    .background(lineNumberBackground)
            }

            Text(line.content)
                .font(DesignTokens.Typography.callout.monospaced())
                .foregroundColor(textColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DesignTokens.Spacing.xs)
        }
        .padding(.vertical, 1)
        .background(backgroundColor)
    }

    private var lineNumber: String {
        switch side {
        case .left:
            return line.oldLineNumber.map { String($0) } ?? ""
        case .right:
            return line.newLineNumber.map { String($0) } ?? ""
        }
    }

    private var backgroundColor: Color {
        switch line.type {
        case .addition:
            return AppTheme.success.opacity(0.15)
        case .deletion:
            return AppTheme.error.opacity(0.15)
        default:
            return .clear
        }
    }

    private var lineNumberBackground: Color {
        switch line.type {
        case .addition:
            return AppTheme.success.opacity(0.08)
        case .deletion:
            return AppTheme.error.opacity(0.08)
        default:
            return AppTheme.backgroundSecondary
        }
    }

    private var textColor: Color {
        switch line.type {
        case .addition:
            return AppTheme.success
        case .deletion:
            return AppTheme.error
        default:
            return AppTheme.textPrimary
        }
    }
}

// MARK: - Copy Selection

/// Handles copying selected diff content
struct DiffCopyManager {
    /// Copy selected lines to clipboard
    static func copyLines(_ lines: [DiffLine], includeLineNumbers: Bool = false, includePrefixes: Bool = true) {
        var text = ""

        for line in lines {
            if includeLineNumbers {
                let lineNum = line.newLineNumber ?? line.oldLineNumber ?? 0
                text += String(format: "%4d ", lineNum)
            }

            if includePrefixes {
                let prefix: String
                switch line.type {
                case .addition: prefix = "+"
                case .deletion: prefix = "-"
                case .context: prefix = " "
                case .hunkHeader: prefix = "@"
                }
                text += prefix
            }

            text += line.content + "\n"
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        ToastManager.shared.show("\(lines.count) line\(lines.count == 1 ? "" : "s") copied")
    }

    /// Copy hunk as patch
    static func copyHunkAsPatch(_ hunk: DiffHunk, filePath: String) {
        var patch = "--- a/\(filePath)\n"
        patch += "+++ b/\(filePath)\n"
        patch += hunk.header + "\n"

        for line in hunk.lines {
            let prefix: String
            switch line.type {
            case .addition: prefix = "+"
            case .deletion: prefix = "-"
            case .context: prefix = " "
            case .hunkHeader: prefix = ""
            }
            patch += prefix + line.content + "\n"
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(patch, forType: .string)

        ToastManager.shared.show("Hunk copied as patch")
    }
}

// MARK: - Integrated Diff Viewer

/// Complete diff viewer with search, navigation, and mode switching
struct EnhancedDiffViewer: View {
    let filePath: String
    let repoPath: String
    let staged: Bool

    @StateObject private var searchState = DiffSearchState()
    @StateObject private var navigationState = DiffNavigationState()

    @State private var hunks: [StreamingDiffHunk] = []
    @State private var isLoading = true
    @State private var error: Error?
    @State private var options: DiffOptions = .default
    @State private var isLargeFileMode = false
    @State private var showSearch = false
    @State private var viewMode: ViewMode = .unified
    @State private var preflightStats: DiffPreflightStats?
    @State private var parseTimeMs: Double?

    private let diffEngine = DiffEngine()

    enum ViewMode {
        case unified
        case sideBySide
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            diffToolbar

            // Search bar (if visible)
            if showSearch {
                DiffSearchBar(searchState: searchState) {
                    showSearch = false
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.sm)
            }

            // Navigation toolbar
            if !hunks.isEmpty {
                DiffNavigationToolbar(navigationState: navigationState) { yOffset in
                    // TODO: Scroll to position
                }
                .background(AppTheme.backgroundSecondary)
            }

            Divider()

            // Content
            Group {
                if isLoading {
                    loadingView
                } else if let error = error {
                    errorView(error)
                } else if hunks.isEmpty {
                    emptyView
                } else {
                    diffContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Status bar
            DiffStatusBar(
                stats: preflightStats,
                isLargeFileMode: isLargeFileMode,
                parseTimeMs: parseTimeMs,
                renderTimeMs: nil,
                cacheStats: nil
            )
        }
        .background(AppTheme.background)
        .task {
            await loadDiff()
        }
        .onChange(of: searchState.query) { _ in
            searchState.search(in: hunks)
        }
    }

    // MARK: - Subviews

    private var diffToolbar: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // View mode picker (only if not LFM)
            if !isLargeFileMode {
                Picker("", selection: $viewMode) {
                    Image(systemName: "text.alignleft")
                        .foregroundColor(AppTheme.textSecondary)
                        .tag(ViewMode.unified)
                    Image(systemName: "rectangle.split.2x1")
                        .foregroundColor(AppTheme.textSecondary)
                        .tag(ViewMode.sideBySide)
                }
                .pickerStyle(.segmented)
                .frame(width: 80)
            }

            Spacer()

            // Search toggle
            Button {
                showSearch.toggle()
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(DesignTokens.Typography.callout)
                    .foregroundColor(AppTheme.textSecondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("f", modifiers: .command)

            // LFM badge
            if isLargeFileMode {
                LFMStatusBadge(isActive: true, stats: preflightStats)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(AppTheme.toolbar)
    }

    private var loadingView: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            ProgressView()
            Text("Loading diff...")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(AppTheme.textPrimary)
        }
    }

    private func errorView(_ error: Error) -> some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(DesignTokens.Typography.iconXXXL)
                .foregroundColor(AppTheme.warning)
            Text("Failed to load diff")
                .font(.headline)
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundColor(AppTheme.textPrimary)
        }
    }

    private var emptyView: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "doc.text")
                .font(DesignTokens.Typography.iconXXXL)
                .foregroundColor(AppTheme.textMuted)
            Text("No changes")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)
        }
    }

    @ViewBuilder
    private var diffContent: some View {
        if isLargeFileMode {
            LargeDiffView(
                hunks: hunks,
                filePath: filePath,
                isStaged: staged,
                options: options,
                onExpandHunk: { expandHunk(at: $0) },
                onCollapseHunk: { collapseHunk(at: $0) },
                searchQuery: $searchState.query,
                currentMatchIndex: $searchState.currentMatchIndex
            )
        } else {
            switch viewMode {
            case .unified:
                unifiedDiffView
            case .sideBySide:
                SideBySideDiffView(hunks: hunks, showLineNumbers: true)
            }
        }
    }

    private var unifiedDiffView: some View {
        ScrollView {
            LazyVStack(spacing: DesignTokens.Spacing.md) {
                ForEach(Array(hunks.enumerated()), id: \.element.id) { index, hunk in
                    if let diffHunk = hunk.toDiffHunk() {
                        CollapsibleHunkCard(
                            hunk: diffHunk,
                            hunkIndex: index,
                            totalHunks: hunks.count,
                            showLineNumbers: true,
                            showActions: !staged,
                            isStaged: staged,
                            isCollapsed: hunk.isCollapsed,
                            onToggleCollapse: {
                                if hunks[index].isCollapsed {
                                    expandHunk(at: index)
                                } else {
                                    collapseHunk(at: index)
                                }
                            }
                        )
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Actions

    private func loadDiff() async {
        isLoading = true
        error = nil

        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            // Preflight
            let stats = try await diffEngine.preflight(file: filePath, staged: staged, at: repoPath)
            preflightStats = stats
            isLargeFileMode = stats.isLargeFile
            options = stats.suggestedOptions

            // Load hunks
            var loadedHunks: [StreamingDiffHunk] = []
            for try await hunk in diffEngine.diff(file: filePath, staged: staged, at: repoPath, options: options) {
                loadedHunks.append(hunk)
            }

            let endTime = CFAbsoluteTimeGetCurrent()
            parseTimeMs = (endTime - startTime) * 1000

            await MainActor.run {
                self.hunks = loadedHunks
                self.isLoading = false
                navigationState.buildChangePositions(from: loadedHunks)
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
        }
    }

    private func expandHunk(at index: Int) {
        guard index < hunks.count else { return }
        hunks[index].isCollapsed = false
        navigationState.buildChangePositions(from: hunks)
    }

    private func collapseHunk(at index: Int) {
        guard index < hunks.count else { return }
        hunks[index].isCollapsed = true
        navigationState.buildChangePositions(from: hunks)
    }
}
