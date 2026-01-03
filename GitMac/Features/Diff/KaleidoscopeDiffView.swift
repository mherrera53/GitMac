import SwiftUI

// MARK: - Kaleidoscope Diff View (Main Container)

/// Professional diff viewer matching Kaleidoscope design exactly
/// Features: file list sidebar (LEFT), Blocks/Fluid/Unified views, Swap A/B button
struct KaleidoscopeDiffView: View {
    let files: [FileDiff]
    // Optional commits for history view
    let commits: [Commit]
    @Binding var selectedCommitA: Commit?
    @Binding var selectedCommitB: Commit?
    
    @State private var selectedFile: FileDiff?
    @State private var viewMode: KaleidoscopeViewMode = .blocks
    @State private var showLineNumbers = true
    @State private var showWhitespace = false
    @State private var showFileList = true
    @State private var showConnectionLines = true
    @State private var showHistory = false
    @State private var showMinimap = true
    @State private var swappedAB = false // For Swap A/B functionality
    @State private var scrollOffset: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var minimapScrollTrigger: UUID = UUID() // Unique trigger for minimap clicks

    @StateObject private var themeManager = ThemeManager.shared

    // Select first file by default
    init(
        files: [FileDiff],
        commits: [Commit] = [],
        selectedCommitA: Binding<Commit?> = .constant(nil),
        selectedCommitB: Binding<Commit?> = .constant(nil)
    ) {
        self.files = files
        self.commits = commits
        self._selectedCommitA = selectedCommitA
        self._selectedCommitB = selectedCommitB
        self._selectedFile = State(initialValue: files.first)
    }

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        VStack(spacing: 0) {
            // Toolbar (Kaleidoscope-style)
            kaleidoscopeToolbar

            Rectangle()
                .fill(theme.border)
                .frame(height: 1)

            // Main content area
            HStack(spacing: 0) {
                // File list sidebar (LEFT side - Kaleidoscope style)
                if showFileList {
                    KaleidoscopeFileList(
                        files: files,
                        selectedFile: $selectedFile
                    )

                    Rectangle()
                        .fill(theme.border)
                        .frame(width: 1)
                }

                // Diff view (main area)
                // Diff view (main area) with Minimap Overlay
                ZStack(alignment: .trailing) {
                    if let file = selectedFile {
                        let currentHunks = swappedAB ? swapHunks(file.hunks) : file.hunks
                        
                        if viewMode == .unified {
                            let unifiedLines = KaleidoscopePairingEngine.calculateUnifiedLines(from: currentHunks)
                            diffContentView(for: file, pairedLines: [], unifiedLines: unifiedLines)
                                .frame(maxWidth: .infinity)
                            
                            if showMinimap {
                                KaleidoscopeMinimapWrapper(
                                    rows: minimapRows(from: unifiedLines),
                                    scrollOffset: $scrollOffset,
                                    viewportHeight: $viewportHeight,
                                    contentHeight: $contentHeight,
                                    minimapScrollTriggerAction: { minimapScrollTrigger = UUID() }
                                )
                                .frame(width: 80)
                                .padding(.trailing, 4)
                                .padding(.vertical, 4)
                            }
                        } else {
                            let pairedLines = KaleidoscopePairingEngine.calculatePairs(from: currentHunks)
                            diffContentView(for: file, pairedLines: pairedLines, unifiedLines: [])
                                .frame(maxWidth: .infinity)
                            
                            if showMinimap {
                                KaleidoscopeMinimapWrapper(
                                    rows: minimapRows(from: pairedLines),
                                    scrollOffset: $scrollOffset,
                                    viewportHeight: $viewportHeight,
                                    contentHeight: $contentHeight,
                                    minimapScrollTriggerAction: { minimapScrollTrigger = UUID() }
                                )
                                .frame(width: 80)
                                .padding(.trailing, 4)
                                .padding(.vertical, 4)
                            }
                        }
                    } else {
                        emptyStateView
                    }
                }
                
                Rectangle()
                    .fill(theme.border)
                    .frame(width: 1)
                
                // History Sidebar (RIGHT side)
                if showHistory && !commits.isEmpty {
                    CommitHistorySidebar(
                        commits: commits,
                        selectedCommitA: $selectedCommitA,
                        selectedCommitB: $selectedCommitB
                    )
                    .transition(.move(edge: .trailing))
                }
            }
        }
        .background(theme.background)
        .onAppear {
            // Initialize content height based on first file
            recalculateContentHeight()
        }
        .onChange(of: viewMode) { _, _ in
            // Force recalculation when switching between Blocks/Fluid/Unified
            recalculateContentHeight()
            scrollOffset = 0 // Reset scroll position
        }
        .onChange(of: selectedFile?.id) { _, _ in
            // Recalculate when file selection changes
            recalculateContentHeight()
            scrollOffset = 0
        }
        .onChange(of: showMinimap) { _, newValue in
            // Force recalculation when minimap is toggled
            if newValue {
                recalculateContentHeight()
            }
        }
    }
    
    /// Recalculates content height based on current view mode and selected file
    private func recalculateContentHeight() {
        guard let file = selectedFile else { return }
        let hunks = swappedAB ? swapHunks(file.hunks) : file.hunks
        
        let lineCount: Int
        if viewMode == .unified {
            lineCount = KaleidoscopePairingEngine.calculateUnifiedLines(from: hunks).count
        } else {
            lineCount = KaleidoscopePairingEngine.calculatePairs(from: hunks).count
        }
        
        contentHeight = CGFloat(lineCount) * 24
    }

    // MARK: - Components

    private var kaleidoscopeToolbar: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // File List toggle (LEFT)
            ToolbarToggle(
                icon: "sidebar.left",
                isActive: showFileList,
                tooltip: "File List"
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showFileList.toggle()
                }
            }
            // History toggle - Always visible (will work when commits are loaded)
            ToolbarToggle(
                icon: "clock.arrow.circlepath",
                isActive: showHistory,
                tooltip: "History"
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showHistory.toggle()
                }
            }
            
            // Connection lines toggle - Always visible
            ToolbarToggle(
                icon: "link",
                isActive: showConnectionLines,
                tooltip: "Connection Lines"
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showConnectionLines.toggle()
                }
            }

            Rectangle()
                .fill(AppTheme.border)
                .frame(width: 1, height: 24)

            // View mode selector (Blocks/Fluid/Unified)
            viewModeSelector

            Rectangle()
                .fill(AppTheme.border)
                .frame(width: 1, height: 24)

            // Swap A/B button (IMPORTANT Kaleidoscope feature!)
            Button {
                swappedAB.toggle()
            } label: {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(DesignTokens.Typography.callout)
                    Text("Swap A/B")
                        .font(DesignTokens.Typography.caption.weight(.medium))
                }
                .foregroundColor(AppTheme.accent)
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .background(AppTheme.accent.opacity(0.1))
                .cornerRadius(DesignTokens.CornerRadius.sm)
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(AppTheme.border)
                .frame(width: 1, height: 24)

            // Options
            HStack(spacing: DesignTokens.Spacing.xs) {
                ToolbarToggle(
                    icon: "number",
                    isActive: showLineNumbers,
                    tooltip: "Line Numbers"
                ) {
                    showLineNumbers.toggle()
                }

                ToolbarToggle(
                    icon: "space",
                    isActive: showWhitespace,
                    tooltip: "Show Whitespace"
                ) {
                    showWhitespace.toggle()
                }
                
                ToolbarToggle(
                    icon: "map",
                    isActive: showMinimap,
                    tooltip: "Minimap"
                ) {
                     withAnimation {
                        showMinimap.toggle()
                    }
                }
            }

            Spacer()

            // Current file info
            if let file = selectedFile {
                Text((file.displayPath as NSString).lastPathComponent)
                    .font(DesignTokens.Typography.body.weight(.semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)

                DiffStatsView.badges(
                    additions: file.additions,
                    deletions: file.deletions,
                    size: .small
                )
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(AppTheme.toolbar)
    }

    private var viewModeSelector: some View {
        HStack(spacing: 2) {
            ForEach(KaleidoscopeViewMode.allCases, id: \.self) { mode in
                ViewModeButton(
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
        .background(AppTheme.backgroundTertiary)
        .cornerRadius(DesignTokens.CornerRadius.md)
    }

    @ViewBuilder
    private func diffContentView(for file: FileDiff, pairedLines: [DiffPairWithConnection], unifiedLines: [UnifiedLine]) -> some View {
        let hunks = swappedAB ? swapHunks(file.hunks) : file.hunks

        switch viewMode {
            case .blocks:
                // Traditional side-by-side (like Split)
                KaleidoscopeSplitDiffView(
                    pairedLines: pairedLines,
                    showLineNumbers: showLineNumbers,
                    showConnectionLines: showConnectionLines,
                    isFluidMode: false,
                    scrollOffset: $scrollOffset,
                    viewportHeight: $viewportHeight,
                    contentHeight: $contentHeight,
                    minimapScrollTrigger: $minimapScrollTrigger
                )

            case .fluid:
                // Fluid view with connection lines (enhanced version)
                KaleidoscopeSplitDiffView(
                    pairedLines: pairedLines,
                    showLineNumbers: showLineNumbers,
                    showConnectionLines: showConnectionLines,
                    isFluidMode: true,
                    scrollOffset: $scrollOffset,
                    viewportHeight: $viewportHeight,
                    contentHeight: $contentHeight,
                    minimapScrollTrigger: $minimapScrollTrigger
                )

        case .unified:
            // True Unified view with A/B labels in margin
            KaleidoscopeUnifiedView(
                hunks: hunks,
                showLineNumbers: showLineNumbers,
                scrollOffset: $scrollOffset,
                viewportHeight: $viewportHeight,
                contentHeight: $contentHeight
            )
        }
    }

    private func minimapRows(from pairedLines: [DiffPairWithConnection]) -> [MinimapRow] {
        pairedLines.map { pair in
            let color: Color = switch pair.connectionType {
            case .addition: AppTheme.diffAddition
            case .deletion: AppTheme.diffDeletion
            case .change: AppTheme.diffChange
            case .none: 
                if pair.hunkHeader != nil {
                    AppTheme.accent.opacity(0.4)
                } else {
                    Color.clear
                }
            }
            return MinimapRow(id: pair.id, color: color, isHeader: pair.hunkHeader != nil)
        }
    }

    private func minimapRows(from unifiedLines: [UnifiedLine]) -> [MinimapRow] {
        unifiedLines.map { line in
            let color: Color = switch line.type {
            case .addition: AppTheme.diffAddition
            case .deletion: AppTheme.diffDeletion
            case .hunkHeader: AppTheme.accent.opacity(0.4)
            case .context: Color.clear
            }
            return MinimapRow(id: line.id, color: color, isHeader: line.type == .hunkHeader)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.textMuted)

            Text("No file selected")
                .font(DesignTokens.Typography.title3)
                .foregroundColor(AppTheme.textPrimary)

            Text("Select a file from the list to view changes")
                .font(DesignTokens.Typography.body)
                .foregroundColor(AppTheme.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func swapHunks(_ hunks: [DiffHunk]) -> [DiffHunk] {
        // Swap A and B sides by reversing line types
        hunks.map { hunk in
            DiffHunk(
                header: hunk.header,
                oldStart: hunk.newStart,
                oldLines: hunk.newLines,
                newStart: hunk.oldStart,
                newLines: hunk.oldLines,
                lines: hunk.lines.map { line in
                    var newLine = line
                    if line.type == .addition {
                        newLine = DiffLine(
                            type: .deletion,
                            content: line.content,
                            oldLineNumber: line.newLineNumber,
                            newLineNumber: line.oldLineNumber
                        )
                    } else if line.type == .deletion {
                        newLine = DiffLine(
                            type: .addition,
                            content: line.content,
                            oldLineNumber: line.newLineNumber,
                            newLineNumber: line.oldLineNumber
                        )
                    }
                    return newLine
                }
            )
        }
    }
    
    // Calculate normalized scroll ratio (0-1) for minimap
    private func calculateScrollRatio() -> CGFloat {
        guard contentHeight > viewportHeight, contentHeight > 0 else { return 0 }
        let maxScroll = contentHeight - viewportHeight
        guard maxScroll > 0 else { return 0 }
        let ratio = max(0, min(1, scrollOffset / maxScroll))
        // Debug log for scroll sync
        NSLog("🔍 [Minimap] scrollOffset: %.1f, contentHeight: %.1f, viewportHeight: %.1f, maxScroll: %.1f, ratio: %.3f", scrollOffset, contentHeight, viewportHeight, maxScroll, ratio)
        return ratio
    }
    
    // Calculate viewport ratio (0-1) for minimap lens
    private func calculateViewportRatio() -> CGFloat {
        guard contentHeight > 0 else { return 1 }
        return min(1, viewportHeight / contentHeight)
    }

    @ViewBuilder
    private var changesOnlyView: some View {
        ScrollView {
            if let file = selectedFile {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    ForEach(file.hunks) { hunk in
                        changesHunkView(hunk: hunk)
                    }
                }
                .padding()
            }
        }
    }

    @ViewBuilder
    private func changesHunkView(hunk: DiffHunk) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hunk header
            Text(hunk.header)
                .font(DesignTokens.Typography.caption.monospaced())
                .foregroundColor(AppTheme.accent)
                .padding(DesignTokens.Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.accent.opacity(0.08))

            // Only show changed lines
            ForEach(hunk.lines.filter { $0.type != .context }) { line in
                changesLineView(line: line)
            }
        }
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(DesignTokens.CornerRadius.lg)
    }

    @ViewBuilder
    private func changesLineView(line: DiffLine) -> some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: line.type == .addition ? "plus" : "minus")
                .font(DesignTokens.Typography.caption2)
                .foregroundColor(line.type == .addition ? AppTheme.diffAddition : AppTheme.diffDeletion)

            Text(line.content)
                .font(DesignTokens.Typography.diffLine)
                .foregroundColor(AppTheme.textPrimary)
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, 4)
        .background(line.type == .addition ? AppTheme.diffAdditionBg : AppTheme.diffDeletionBg)
    }
}

// MARK: - Kaleidoscope Diff Models (Consolidated for compilation)

enum ConnectionType {
    case none
    case change
    case deletion
    case addition
}

struct DiffPairWithConnection: Identifiable {
    let id: Int
    let left: DiffLine?
    let right: DiffLine?
    let hunkHeader: String?
    let connectionType: ConnectionType
    
    init(id: Int, left: DiffLine?, right: DiffLine?, hunkHeader: String?, connectionType: ConnectionType) {
        self.id = id
        self.left = left
        self.right = right
        self.hunkHeader = hunkHeader
        self.connectionType = connectionType
    }
}

// MARK: - Pairing Logic

enum KaleidoscopePairingEngine {
    static func calculatePairs(from hunks: [DiffHunk]) -> [DiffPairWithConnection] {
        var pairs: [DiffPairWithConnection] = []
        var pairId = 0

        for hunk in hunks {
            pairId += 1
            pairs.append(DiffPairWithConnection(
                id: pairId,
                left: nil,
                right: nil,
                hunkHeader: hunk.header,
                connectionType: .none
            ))

            var i = 0
            let lines = hunk.lines

            while i < lines.count {
                let line = lines[i]

                if line.type == .context {
                    pairId += 1
                    pairs.append(DiffPairWithConnection(
                        id: pairId,
                        left: line,
                        right: line,
                        hunkHeader: nil,
                        connectionType: .none
                    ))
                    i += 1
                } else {
                    var deletions: [DiffLine] = []
                    var additions: [DiffLine] = []

                    var j = i
                    while j < lines.count && lines[j].type == .deletion {
                        deletions.append(lines[j])
                        j += 1
                    }

                    var k = j
                    while k < lines.count && lines[k].type == .addition {
                        additions.append(lines[k])
                        k += 1
                    }

                    let maxCount = max(deletions.count, additions.count)

                    if maxCount > 0 {
                        for idx in 0..<maxCount {
                            pairId += 1
                            let left = idx < deletions.count ? deletions[idx] : nil
                            let right = idx < additions.count ? additions[idx] : nil

                            let connectionType: ConnectionType
                            if left != nil && right != nil {
                                connectionType = .change
                            } else if left != nil {
                                connectionType = .deletion
                            } else {
                                connectionType = .addition
                            }

                            pairs.append(DiffPairWithConnection(
                                id: pairId,
                                left: left,
                                right: right,
                                hunkHeader: nil,
                                connectionType: connectionType
                            ))
                        }

                        i = k
                    } else {
                        i += 1
                    }
                }
            }
        }
        return pairs
    }
}

enum UnifiedSide {
    case a
    case b
    case both
}

struct UnifiedLine: Identifiable {
    let id: Int
    let content: String
    let type: DiffLineType
    let side: UnifiedSide
    let oldLineNumber: Int?
    let newLineNumber: Int?
    let pairedContent: String?
    
    init(id: Int, content: String, type: DiffLineType, side: UnifiedSide, oldLineNumber: Int?, newLineNumber: Int?, pairedContent: String?) {
        self.id = id
        self.content = content
        self.type = type
        self.side = side
        self.oldLineNumber = oldLineNumber
        self.newLineNumber = newLineNumber
        self.pairedContent = pairedContent
    }
}

extension KaleidoscopePairingEngine {
    static func calculateUnifiedLines(from hunks: [DiffHunk]) -> [UnifiedLine] {
        var lines: [UnifiedLine] = []
        var lineId = 0

        for hunk in hunks {
            lineId += 1
            lines.append(UnifiedLine(
                id: lineId,
                content: hunk.header,
                type: .hunkHeader,
                side: .both,
                oldLineNumber: nil,
                newLineNumber: nil,
                pairedContent: nil
            ))

            var i = 0
            let hunkLines = hunk.lines
            while i < hunkLines.count {
                let line = hunkLines[i]
                lineId += 1
                
                let side: UnifiedSide
                var pairedContent: String? = nil
                
                if line.type == .deletion {
                    side = .a
                    if i + 1 < hunkLines.count && hunkLines[i + 1].type == .addition {
                        pairedContent = hunkLines[i + 1].content
                    }
                } else if line.type == .addition {
                    side = .b
                    if i > 0 && hunkLines[i - 1].type == .deletion {
                        pairedContent = hunkLines[i - 1].content
                    }
                } else {
                    side = .both
                }

                lines.append(UnifiedLine(
                    id: lineId,
                    content: line.content,
                    type: line.type,
                    side: side,
                    oldLineNumber: line.oldLineNumber,
                    newLineNumber: line.newLineNumber,
                    pairedContent: pairedContent
                ))
                
                i += 1
            }
        }
        return lines
    }
}

// MARK: - Commit History Sidebar (Consolidated for compilation)

struct CommitHistorySidebar: View {
    let commits: [Commit]
    @Binding var selectedCommitA: Commit?
    @Binding var selectedCommitB: Commit?
    @State private var filterText: String = ""
    @State private var currentChangeIndex: Int = 0
    @StateObject private var themeManager = ThemeManager.shared

    private var filteredCommits: [Commit] {
        if filterText.isEmpty {
            return commits
        }
        return commits.filter { commit in
            commit.message.localizedCaseInsensitiveContains(filterText) ||
            commit.author.localizedCaseInsensitiveContains(filterText) ||
            commit.shortSHA.localizedCaseInsensitiveContains(filterText)
        }
    }

    private var totalChanges: Int {
        commits.count
    }

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        VStack(spacing: 0) {
            headerView
            Divider()
            searchBarView
            Divider()
            ScrollView {
                LazyVStack(spacing: DesignTokens.Spacing.xs) {
                    ForEach(filteredCommits) { commit in
                        CommitHistoryRow(
                            commit: commit,
                            isSelectedA: selectedCommitA?.id == commit.id,
                            isSelectedB: selectedCommitB?.id == commit.id,
                            onSelectA: { selectedCommitA = commit },
                            onSelectB: { selectedCommitB = commit }
                        )
                    }
                }
                .padding(DesignTokens.Spacing.sm)
            }
            .background(theme.background)
            Divider()
            changeNavigationFooter
        }
        .frame(width: 320)
        .background(theme.backgroundSecondary)
    }

    private var headerView: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundColor(AppTheme.accent)
            Text("History")
                .font(DesignTokens.Typography.headline.weight(.semibold))
                .foregroundColor(AppTheme.textPrimary)
            Spacer()
            Text("\(totalChanges)")
                .font(DesignTokens.Typography.caption.monospaced())
                .foregroundColor(AppTheme.textMuted)
                .padding(.horizontal, DesignTokens.Spacing.xs)
                .background(AppTheme.backgroundTertiary)
                .cornerRadius(DesignTokens.CornerRadius.sm)
        }
        .padding(DesignTokens.Spacing.md)
    }

    private var searchBarView: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppTheme.textMuted)
            TextField("Filter Commits", text: $filterText)
                .textFieldStyle(.plain)
            if !filterText.isEmpty {
                Button { filterText = "" } label: { Image(systemName: "xmark.circle.fill") }
                .buttonStyle(.plain)
            }
        }
        .padding(DesignTokens.Spacing.sm)
        .background(AppTheme.backgroundTertiary)
        .cornerRadius(DesignTokens.CornerRadius.md)
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
    }

    private var changeNavigationFooter: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Button {
                if currentChangeIndex > 0 {
                    currentChangeIndex -= 1
                    selectCommitAtIndex(currentChangeIndex)
                }
            } label: { Image(systemName: "chevron.up") }
            .buttonStyle(.plain)
            .disabled(currentChangeIndex <= 0)

            Text("Change \(currentChangeIndex + 1) of \(totalChanges)")
                .font(DesignTokens.Typography.caption.monospaced())

            Button {
                if currentChangeIndex < totalChanges - 1 {
                    currentChangeIndex += 1
                    selectCommitAtIndex(currentChangeIndex)
                }
            } label: { Image(systemName: "chevron.down") }
            .buttonStyle(.plain)
            .disabled(currentChangeIndex >= totalChanges - 1)
        }
        .padding(DesignTokens.Spacing.sm)
        .background(AppTheme.backgroundTertiary)
    }

    private func selectCommitAtIndex(_ index: Int) {
        guard index >= 0, index < commits.count else { return }
        let commit = commits[index]
        if selectedCommitA == nil { selectedCommitA = commit } else { selectedCommitB = commit }
    }
}

struct CommitHistoryRow: View {
    let commit: Commit
    let isSelectedA: Bool
    let isSelectedB: Bool
    let onSelectA: () -> Void
    let onSelectB: () -> Void

    @State private var isHovered = false
    @StateObject private var themeManager = ThemeManager.shared

    private var initials: String {
        let components = commit.author.components(separatedBy: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1)) + String(components[1].prefix(1))
        }
        return String(commit.author.prefix(2))
    }

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            VStack(spacing: 4) {
                Button { onSelectA() } label: {
                    Text("A").font(.caption2.bold()).frame(width: 20, height: 20)
                        .background(isSelectedA ? AppTheme.accent : AppTheme.backgroundTertiary)
                        .foregroundColor(isSelectedA ? .white : AppTheme.textMuted).cornerRadius(4)
                }.buttonStyle(.plain)
                Button { onSelectB() } label: {
                    Text("B").font(.caption2.bold()).frame(width: 20, height: 20)
                        .background(isSelectedB ? AppTheme.info : AppTheme.backgroundTertiary)
                        .foregroundColor(isSelectedB ? .white : AppTheme.textMuted).cornerRadius(4)
                }.buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(commit.author).font(.caption.weight(.medium)).foregroundColor(AppTheme.textPrimary)
                Text(commit.summary).font(.caption).foregroundColor(AppTheme.textSecondary).lineLimit(1)
                Text(commit.shortSHA).font(.caption2.monospaced()).foregroundColor(AppTheme.textMuted)
            }
        }
        .padding(DesignTokens.Spacing.sm)
        .background(isHovered ? AppTheme.hover : Color.clear)
        .cornerRadius(DesignTokens.CornerRadius.md)
        .onHover { isHovered = $0 }
    }
}



// MARK: - Kaleidoscope View Mode (Exact names from Kaleidoscope)

enum KaleidoscopeViewMode: String, CaseIterable {
    case blocks = "Blocks"
    case fluid = "Fluid"
    case unified = "Unified"

    var icon: String {
        switch self {
        case .blocks: return "rectangle.split.2x1"
        case .fluid: return "point.3.connected.trianglepath.dotted"
        case .unified: return "rectangle.stack"
        }
    }
}

// MARK: - View Mode Button

struct ViewModeButton: View {
    let mode: KaleidoscopeViewMode
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: mode.icon)
                    .font(DesignTokens.Typography.caption2)
                    .foregroundColor(isSelected ? .white : AppTheme.textSecondary)

                Text(mode.rawValue)
                    .font(DesignTokens.Typography.caption.weight(.medium))
            }
            .foregroundColor(isSelected ? .white : AppTheme.textSecondary)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                    .fill(isSelected ? AppTheme.accent : (isHovered ? AppTheme.hover : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Toolbar Toggle

struct ToolbarToggle: View {
    let icon: String
    let isActive: Bool
    let tooltip: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(DesignTokens.Typography.callout)
                .foregroundColor(isActive ? AppTheme.accent : AppTheme.textSecondary)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                        .fill(isActive ? AppTheme.accent.opacity(0.15) : (isHovered ? AppTheme.hover : Color.clear))
                )
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Toolbar Button (defined in DiffToolbar.swift - removed duplicate)

// MARK: - Preview

