import SwiftUI
import Splash
import DifferenceKit

// NOTE: The following components have been extracted to separate files in Features/Diff/Renderers:
// - WordLevelDiff (DiffSegment, WordLevelDiffResult, WordLevelDiff enum)
// - DiffLineContextMenu (View extensions for context menus)
// - DiffMinimap (OptimizedMinimapView, DiffScrollOffsetKey)
// - DiffScrollViews (UnifiedDiffScrollView, DiffPair, IdentifiedDiffLine)
// - DiffSyntaxHighlighter (SyntaxHighlightedText)
// - DiffParser (DiffParser struct)
// - DiffLineRenderers (DiffLineRow, InlineDiffLineRow, HunkLineRow, HunkHeaderRow, EmptyLineRow)
// - BinaryFileRenderers (BinaryFileView, ImagePreviewView, PDFPreviewView, GenericBinaryView, CheckerboardPattern)
// - LargeFileDiffRenderer (LargeFileDiffViewWrapper, LargeFileDiffNSView)

/// Complete diff viewer with multiple view modes - OPTIMIZED
/// Includes full Kaleidoscope integration for professional diff viewing
struct DiffView: View {
    let fileDiff: FileDiff
    var repoPath: String? = nil
    @AppStorage("diffViewMode") private var viewMode: DiffViewMode = .split
    @AppStorage("diffShowLineNumbers") private var showLineNumbers = true
    @AppStorage("diffWordWrap") private var wordWrap = false
    @AppStorage("diffShowMinimap") private var showMinimap = true
        @State private var scrollOffset: CGFloat = 0
    @State private var viewportHeight: CGFloat = 400
    @State private var contentHeight: CGFloat = 1000
    @StateObject private var themeManager = ThemeManager.shared
    
    // History and Blame panel states
    @State private var showHistory = false
    @State private var showBlame = false
    @State private var minimapScrollTrigger: UUID = UUID()

    // History diff override (when selecting commits)
    @State private var overrideHunks: [DiffHunk]? = nil
    @State private var isLoadingHistoryDiff = false
    
    // Kaleidoscope integration states
    @State private var selectedCommitA: Commit? = nil
    @State private var selectedCommitB: Commit? = nil
    @State private var availableCommits: [Commit] = []
    @State private var commitsLoaded = false
    @State private var commitsLoadedForPath: String? = nil
    @State private var kaleidoscopeViewMode: KaleidoscopeViewMode = .blocks

    // Kaleidoscope performance caches (avoid recomputing on scroll)
    @State private var cachedHunksById: [UUID: DiffHunk] = [:]
    @State private var cachedPairedLines: [DiffPairWithConnection] = []
    @State private var cachedUnifiedLines: [UnifiedLine] = []
    @State private var kaleidoscopeRenderVersion: Int = 0

    private var effectiveHunks: [DiffHunk] {
        overrideHunks ?? fileDiff.hunks
    }

    private var allowPatchActions: Bool {
        // Historical diffs should not offer stage/discard
        overrideHunks == nil
    }

    // Calculate line count for accurate minimap
    // Calculate line count for accurate minimap
    private var totalLineCount: Int {
        var count = 0
        for hunk in effectiveHunks {
            count += 1 // hunk header

            if viewMode == .inline || viewMode == .preview {
                // Inline mode counts all lines
                count += hunk.lines.count
            } else {
                // Split mode collapses deletions and additions into single rows
                var i = 0
                let lines = hunk.lines
                while i < lines.count {
                    let line = lines[i]
                    if line.type == .context {
                        count += 1
                        i += 1
                    } else if line.type == .deletion {
                        var dels = 0
                        while i < lines.count && lines[i].type == .deletion { dels += 1; i += 1 }
                        var adds = 0
                        while i < lines.count && lines[i].type == .addition { adds += 1; i += 1 }
                        count += max(dels, adds)
                    } else if line.type == .addition {
                        count += 1
                        i += 1
                    } else {
                         i += 1
                    }
                }
            }
        }
        return max(count, 1)
    }

    // Threshold for "large file" - switch to optimized inline view
    // Threshold for "large file" - switch to optimized inline view
    private let largeFileLineThreshold = 1000000

    private var isLargeFile: Bool {
        totalLineCount > largeFileLineThreshold
    }

    // Estimated content height (22px per line)
    private var estimatedContentHeight: CGFloat {
        CGFloat(visualRowCount) * 22.0
    }

    private var visualRowCount: Int {
        if viewMode == .split {
            // In split view, we pair simultaneous deletions and additions.
            // visualRows ≈ hunks + context + max(deletions, additions) in blocks
            var count = 0
            for hunk in effectiveHunks {
                count += 1 // Header
                
                var i = 0
                let lines = hunk.lines
                while i < lines.count {
                    let line = lines[i]
                    if line.type == .context {
                        count += 1
                        i += 1
                    } else {
                        // Block counting logic (matches OptimizedSplitDiffView)
                        var deletions = 0
                        var j = i
                        while j < lines.count && lines[j].type == .deletion {
                            deletions += 1
                            j += 1
                        }
                        
                        var additions = 0
                        var k = j
                        while k < lines.count && lines[k].type == .addition {
                            additions += 1
                            k += 1
                        }
                        
                        count += max(deletions, additions)
                        i = k
                        if i == j { i += 1 } // Safety
                    }
                }
            }
            return count
        } else {
            // Unified/Inline: just sum of lines + headers
            return effectiveHunks.reduce(0) { $0 + $1.lines.count + 1 }
        }
    }

    // Exact scroll position based on real physics
    private var scrollPosition: CGFloat {
        guard contentHeight > viewportHeight else { return 0 }
        return min(1, max(0, scrollOffset / (contentHeight - viewportHeight)))
    }

    private var viewportRatio: CGFloat {
        guard contentHeight > 0 else { return 1 }
        return min(1, max(0.05, viewportHeight / contentHeight))
    }

    private var isMarkdown: Bool {
        let ext = (fileDiff.displayPath as NSString).pathExtension.lowercased()
        return ext == "md" || ext == "markdown" || ext == "mdown"
    }
    
    // Helper to reconstruct old file content from hunks
    private var reconstructedOldContent: String {
        var lines: [String] = []
        for hunk in fileDiff.hunks {
            for line in hunk.lines {
                if line.type != .addition {
                    lines.append(line.content)
                }
            }
        }
        return lines.joined(separator: "\n")
    }
    
    // Helper to reconstruct new file content from hunks
    private var reconstructedNewContent: String {
        var lines: [String] = []
        for hunk in fileDiff.hunks {
            for line in hunk.lines {
                if line.type != .deletion {
                    lines.append(line.content)
                }
            }
        }
        return lines.joined(separator: "\n")
    }

    private var previewContent: String {
        var lines: [String] = []
        for hunk in effectiveHunks {
            for line in hunk.lines {
                if line.type == .addition || line.type == .context {
                    let printable = line.content.filter { char in
                        !char.isNewline && !(char.unicodeScalars.first?.properties.generalCategory == .control)
                    }
                    lines.append(printable)
                }
            }
        }
        return lines.joined(separator: "\n")
    }

    var body: some View {
        let theme = Color.Theme(themeManager.colors)
        
        VStack(spacing: 0) {
            DiffToolbar(
                filename: fileDiff.displayPath,
                additions: fileDiff.additions,
                deletions: fileDiff.deletions,
                viewMode: $viewMode,
                showLineNumbers: $showLineNumbers,
                wordWrap: $wordWrap,
                isMarkdown: isMarkdown,
                showMinimap: $showMinimap,
                onHistoryTap: {
                    showHistory.toggle()
                    loadCommitsIfNeeded()
                },
                onBlameTap: { showBlame = true }
            )

            Rectangle()
                .fill(theme.border)
                .frame(height: 1)

            HStack(spacing: 0) {
                Group {
                    if fileDiff.isBinary {
                        BinaryFileView(filename: fileDiff.displayPath, repoPath: repoPath)
                    } else if isLargeFile {
                        LargeFileDiffViewWrapper(
                            hunks: effectiveHunks,
                            showLineNumbers: showLineNumbers,
                            scrollOffset: $scrollOffset,
                            viewportHeight: $viewportHeight
                        )
                    } else if viewMode.isKaleidoscopeMode {
                        kaleidoscopeContent(theme: theme)
                    } else {
                        standardContent(theme: theme)
                    }
                }

                if showHistory {
                    Rectangle()
                        .fill(theme.border)
                        .frame(width: 1)

                    CommitHistorySidebar(
                        commits: availableCommits,
                        selectedCommitA: $selectedCommitA,
                        selectedCommitB: $selectedCommitB
                    )
                }
            }
        }
        .background(theme.backgroundSecondary)
        .onAppear {
            rebuildKaleidoscopeCaches()
        }
        .onChange(of: fileDiff.hunks) { _, _ in
            rebuildKaleidoscopeCaches()
        }
        .onChange(of: fileDiff.newPath) { _, _ in
            commitsLoaded = false
            commitsLoadedForPath = nil
            availableCommits = []
            selectedCommitA = nil
            selectedCommitB = nil

            if showHistory {
                loadCommitsIfNeeded()
            }
        }
        .onChange(of: overrideHunks?.count ?? -1) { _, _ in
            rebuildKaleidoscopeCaches()
        }
        .onChange(of: showHistory) { _, newValue in
            if !newValue {
                selectedCommitA = nil
                selectedCommitB = nil
                overrideHunks = nil
                isLoadingHistoryDiff = false
            }
        }
        .onChange(of: selectedCommitA) { _, _ in
            loadHistoryDiffIfNeeded()
        }
        .onChange(of: selectedCommitB) { _, _ in
            loadHistoryDiffIfNeeded()
        }
        .onChange(of: showLineNumbers) { _, _ in
            kaleidoscopeRenderVersion &+= 1
        }
        .onChange(of: viewMode) { _, _ in
            kaleidoscopeRenderVersion &+= 1
        }
        .sheet(isPresented: $showBlame) {
            BlameSheet(path: fileDiff.newPath, repoPath: repoPath ?? "")
        }
    }

    private func rebuildKaleidoscopeCaches() {
        let hunks = effectiveHunks
        cachedHunksById = Dictionary(uniqueKeysWithValues: hunks.map { ($0.id, $0) })
        cachedPairedLines = KaleidoscopePairingEngine.calculatePairs(from: hunks)
        cachedUnifiedLines = KaleidoscopePairingEngine.calculateUnifiedLines(from: hunks)
        kaleidoscopeRenderVersion &+= 1
    }

    private func loadHistoryDiffIfNeeded() {
        guard showHistory else { return }
        guard repoPath != nil else { return }
        Task {
            await loadHistoryDiff()
        }
    }

    @MainActor
    private func loadHistoryDiff() async {
        guard let repoPath else { return }
        func normalizePath(_ path: String) -> String {
            if path.hasPrefix("a/") { return String(path.dropFirst(2)) }
            if path.hasPrefix("b/") { return String(path.dropFirst(2)) }
            return path
        }

        let primaryPath = normalizePath(fileDiff.newPath)
        var candidatePaths: [String] = [primaryPath]
        if let old = fileDiff.oldPath {
            let normalizedOld = normalizePath(old)
            if normalizedOld != primaryPath {
                candidatePaths.append(normalizedOld)
            }
        }

        let requestedCommitASHA = selectedCommitA?.sha
        let requestedCommitBSHA = selectedCommitB?.sha

        // No selection => back to working tree diff
        if selectedCommitA == nil && selectedCommitB == nil {
            overrideHunks = nil
            rebuildKaleidoscopeCaches()
            return
        }

        isLoadingHistoryDiff = true
        defer { isLoadingHistoryDiff = false }

        do {
            let engine = GitEngine()

            var diffString: String = ""
            if let b = selectedCommitB {
                if let a = selectedCommitA {
                    for path in candidatePaths {
                        let out = try await engine.getDiff(from: a.sha, to: b.sha, filePath: path, at: repoPath)
                        if !out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            diffString = out
                            break
                        }
                    }

                    if diffString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        for path in candidatePaths {
                            let out = try await engine.getDiff(from: b.sha, to: a.sha, filePath: path, at: repoPath)
                            if !out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                diffString = out
                                break
                            }
                        }
                    }

                    if diffString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        let out = try await engine.getDiff(from: a.sha, to: b.sha, at: repoPath)
                        if !out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            diffString = out
                        }
                    }
                } else {
                    for path in candidatePaths {
                        let out = try await engine.getCommitFileDiff(sha: b.sha, filePath: path, at: repoPath)
                        if !out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            diffString = out
                            break
                        }
                    }

                    if diffString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        let out = try await engine.getCommitDiff(sha: b.sha, at: repoPath)
                        if !out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            diffString = out
                        }
                    }
                }
            } else if let a = selectedCommitA {
                for path in candidatePaths {
                    let out = try await engine.getCommitFileDiff(sha: a.sha, filePath: path, at: repoPath)
                    if !out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        diffString = out
                        break
                    }
                }

                if diffString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let out = try await engine.getCommitDiff(sha: a.sha, at: repoPath)
                    if !out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        diffString = out
                    }
                }
            } else {
                overrideHunks = nil
                return
            }

            if diffString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                overrideHunks = []
                rebuildKaleidoscopeCaches()
                return
            }

            let files = await DiffParser.parseAsync(diffString)
            let normalizedTargets = Set(candidatePaths.map(normalizePath))
            let targetFilename = URL(fileURLWithPath: primaryPath).lastPathComponent
            let matched = files.first(where: {
                normalizedTargets.contains(normalizePath($0.newPath)) || normalizedTargets.contains(normalizePath($0.oldPath ?? ""))
            }) ?? files.first(where: { $0.filename == targetFilename })

            // Prevent races: only apply if selection is still the same.
            guard showHistory else { return }
            guard selectedCommitA?.sha == requestedCommitASHA,
                  selectedCommitB?.sha == requestedCommitBSHA else {
                return
            }

            overrideHunks = matched?.hunks ?? files.first?.hunks ?? []

            // Reset scroll so minimap and view are consistent
            scrollOffset = 0
            minimapScrollTrigger = UUID()

            // Force Kaleidoscope caches to rebuild even if hunk count didn't change.
            rebuildKaleidoscopeCaches()
        } catch {
            overrideHunks = []
            rebuildKaleidoscopeCaches()
        }
    }

    @ViewBuilder
    private func kaleidoscopeContent(theme: SwiftUI.Color.Theme) -> some View {
        let hunksById = cachedHunksById

        switch viewMode {
        case .kaleidoscopeBlocks, .kaleidoscopeFluid:
            let pairedLines = cachedPairedLines
            HStack(spacing: 0) {
                KaleidoscopeSplitDiffView(
                    pairedLines: pairedLines,
                    filePath: fileDiff.newPath,
                    hunksById: hunksById,
                    repoPath: repoPath,
                    allowPatchActions: allowPatchActions,
                    contentVersion: kaleidoscopeRenderVersion,
                    showLineNumbers: showLineNumbers,
                    showConnectionLines: true,
                    isFluidMode: viewMode == .kaleidoscopeFluid,
                    scrollOffset: $scrollOffset,
                    viewportHeight: $viewportHeight,
                    contentHeight: $contentHeight,
                    minimapScrollTrigger: $minimapScrollTrigger
                )

                if showMinimap {
                    Rectangle()
                        .fill(theme.border)
                        .frame(width: 1)

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
        case .kaleidoscopeUnified:
            let unifiedLines = cachedUnifiedLines
            HStack(spacing: 0) {
                KaleidoscopeUnifiedView(
                    unifiedLines: unifiedLines,
                    showLineNumbers: showLineNumbers,
                    scrollOffset: $scrollOffset,
                    viewportHeight: $viewportHeight,
                    contentHeight: $contentHeight,
                    minimapScrollTrigger: $minimapScrollTrigger,
                    contentVersion: kaleidoscopeRenderVersion
                )

                if showMinimap {
                    Rectangle()
                        .fill(theme.border)
                        .frame(width: 1)

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
            }
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func standardContent(theme: SwiftUI.Color.Theme) -> some View {
        HStack(spacing: 0) {
            switch viewMode {
            case .split:
                OptimizedSplitDiffView(
                    hunks: effectiveHunks,
                    showLineNumbers: showLineNumbers,
                    scrollOffset: $scrollOffset,
                    viewportHeight: $viewportHeight,
                    contentHeight: $contentHeight
                )
                .id(fileDiff.id)
            case .inline:
                OptimizedInlineDiffView(
                    hunks: effectiveHunks,
                    showLineNumbers: showLineNumbers,
                    scrollOffset: $scrollOffset,
                    viewportHeight: $viewportHeight,
                    contentHeight: $contentHeight
                )
            case .hunk:
                HunkDiffView(
                    hunks: effectiveHunks,
                    showLineNumbers: showLineNumbers,
                    scrollOffset: $scrollOffset,
                    viewportHeight: $viewportHeight,
                    contentHeight: $contentHeight
                )
            case .preview:
                MarkdownView(content: previewContent, fileName: fileDiff.displayPath)
            case .kaleidoscopeBlocks, .kaleidoscopeFluid, .kaleidoscopeUnified:
                EmptyView()
            }

            if showMinimap && viewMode != .preview {
                Rectangle()
                    .fill(theme.border)
                    .frame(width: 1)

                OptimizedMinimapView(
                    rows: minimapRows(from: effectiveHunks),
                    scrollPosition: scrollPosition,
                    viewportRatio: viewportRatio,
                    onScrollToPosition: { normalizedPos in
                        NSLog("🔵 [DiffView] Minimap clicked! normalizedPos: %.3f", normalizedPos)
                        let maxScroll = max(0, contentHeight - viewportHeight)
                        let newOffset = normalizedPos * maxScroll
                        NSLog("🔵 [DiffView] Calculated newOffset: %.1f (maxScroll: %.1f)", newOffset, maxScroll)
                        scrollOffset = newOffset
                        minimapScrollTrigger = UUID()
                    }
                )
                .frame(width: 60)
            }
        }
    }

    private func minimapRows(from pairedLines: [DiffPairWithConnection]) -> [MinimapRow] {
        let theme = Color.Theme(themeManager.colors)
        return pairedLines.map { pair in
            let color: SwiftUI.Color = switch pair.connectionType {
            case .addition: theme.diffAddition
            case .deletion: theme.diffDeletion
            case .change: theme.info
            case .none:
                pair.hunkHeader != nil ? theme.accent.opacity(0.4) : SwiftUI.Color.clear
            }
            return MinimapRow(id: pair.id, color: color, isHeader: pair.hunkHeader != nil)
        }
    }

    private func minimapRows(from unifiedLines: [UnifiedLine]) -> [MinimapRow] {
        let theme = Color.Theme(themeManager.colors)
        return unifiedLines.map { line in
            let color: SwiftUI.Color = switch line.type {
            case .addition: theme.diffAddition
            case .deletion: theme.diffDeletion
            case .hunkHeader: theme.accent.opacity(0.4)
            case .context: SwiftUI.Color.clear
            }
            return MinimapRow(id: line.id, color: color, isHeader: line.type == .hunkHeader)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Load commits for kaleidoscope history sidebar
    private func loadCommitsIfNeeded() {
        guard let repoPath = repoPath else { return }
        if commitsLoaded, commitsLoadedForPath == fileDiff.newPath, !availableCommits.isEmpty { return }
        
        Task {
            do {
                let gitService = GitService()
                // Create a Repository object from the path
                let repository = Repository(
                    id: UUID(),
                    path: repoPath,
                    name: (repoPath as NSString).lastPathComponent
                )
                gitService.currentRepository = repository
                let commits = try await gitService.getCommitsForFileV2(filePath: fileDiff.newPath, limit: 200)
                await MainActor.run {
                    self.availableCommits = commits
                    self.commitsLoaded = !commits.isEmpty
                    self.commitsLoadedForPath = self.fileDiff.newPath
                }
            } catch {
                print("Failed to load commits: \(error)")
                await MainActor.run {
                    self.commitsLoaded = false
                    self.commitsLoadedForPath = nil
                }
            }
        }
    }
    private func minimapRows(from hunks: [DiffHunk]) -> [MinimapRow] {
        let theme = Color.Theme(themeManager.colors)
        var rows: [MinimapRow] = []
        var id = 0
        for hunk in hunks {
            id += 1
            rows.append(MinimapRow(id: id, color: theme.accent.opacity(0.3), isHeader: true))
            for line in hunk.lines {
                id += 1
                let color: SwiftUI.Color = switch line.type {
                case .addition: theme.diffAddition
                case .deletion: theme.diffDeletion
                default: SwiftUI.Color.clear
                }
                rows.append(MinimapRow(id: id, color: color, isHeader: false))
            }
        }
        return rows
    }
}

// MARK: - History and Blame Sheet Wrappers

struct FileHistorySheet: View {
    let path: String
    let repoPath: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = HistoryViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("File History: \(path.components(separatedBy: "/").last ?? path)")
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
            }
            .padding()
            .background(AppTheme.backgroundSecondary)
            
            Divider()
            
            FileHistoryView(path: path, viewModel: viewModel)
        }
        .frame(minWidth: 800, minHeight: 500)
        .background(AppTheme.background)
        .onAppear {
            viewModel.repositoryPath = repoPath
        }
    }
}

struct BlameSheet: View {
    let path: String
    let repoPath: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = HistoryViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Blame: \(path.components(separatedBy: "/").last ?? path)")
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
            }
            .padding()
            .background(AppTheme.backgroundSecondary)
            
            Divider()
            
            BlameView(path: path, viewModel: viewModel)
        }
        .frame(minWidth: 800, minHeight: 500)
        .background(AppTheme.background)
        .onAppear {
            viewModel.repositoryPath = repoPath
        }
    }
}




// MARK: - Large File Split Diff View Wrapper

struct LargeFileSplitDiffViewWrapper: View {
    @StateObject private var themeManager = ThemeManager.shared
    
    let hunks: [DiffHunk]
    let showLineNumbers: Bool
    
    private var totalLineCount: Int {
        hunks.reduce(0) { $0 + $1.lines.count + 1 }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Left pane
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(hunks.enumerated()), id: \.offset) { hunkIndex, hunk in
                        // Hunk header
                        FastHunkHeader(header: hunk.header)
                        
                        // Left side lines
                        ForEach(Array(hunk.lines.enumerated()), id: \.offset) { lineIndex, line in
                            if line.type != .addition {
                                FastDiffLine(
                                    line: line,
                                    side: .left,
                                    showLineNumber: showLineNumbers,
                                    paired: nil
                                )
                            } else {
                                FastEmptyLine(
                                    showLineNumber: showLineNumbers,
                                    isDeleted: false,
                                    isAdded: true
                                )
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            
            // Divider
            Rectangle()
                .fill(Color(.separatorColor))
                .frame(width: 1)
            
            // Right pane
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(hunks.enumerated()), id: \.offset) { hunkIndex, hunk in
                        // Hunk header
                        FastHunkHeader(header: hunk.header)
                        
                        // Right side lines
                        ForEach(Array(hunk.lines.enumerated()), id: \.offset) { lineIndex, line in
                            if line.type != .deletion {
                                FastDiffLine(
                                    line: line,
                                    side: .right,
                                    showLineNumber: showLineNumbers,
                                    paired: nil
                                )
                            } else {
                                FastEmptyLine(
                                    showLineNumber: showLineNumbers,
                                    isDeleted: true,
                                    isAdded: false
                                )
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Optimized Split Diff View

struct OptimizedSplitDiffView: View {
    let hunks: [DiffHunk]
    let showLineNumbers: Bool
    @Binding var scrollOffset: CGFloat
    @Binding var viewportHeight: CGFloat
    @Binding var contentHeight: CGFloat

    @StateObject private var themeManager = ThemeManager.shared

    private var pairs: [DiffPair] {
        // ... (implementation hidden, same as before)
        var pairs: [DiffPair] = []
        var pairId = 0
        
        for hunk in hunks {
            pairId += 1
            pairs.append(DiffPair(id: pairId, left: nil, right: nil, hunkHeader: hunk.header))
            
            var i = 0
            let lines = hunk.lines
            
            while i < lines.count {
                let line = lines[i]
                
                if line.type == .context {
                    pairId += 1
                    pairs.append(DiffPair(id: pairId, left: line, right: line, hunkHeader: nil))
                    i += 1
                } else {
                    // Collect block of changes
                    var deletions: [DiffLine] = []
                    var additions: [DiffLine] = []
                    
                    // Consume consecutive deletions
                    var j = i
                    while j < lines.count && lines[j].type == .deletion {
                        deletions.append(lines[j])
                        j += 1
                    }
                    
                    // Consume consecutive additions
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
                            pairs.append(DiffPair(id: pairId, left: left, right: right, hunkHeader: nil))
                        }
                        
                        i = k
                    } else {
                        // Should technically not happen if log is correct, but safety advance
                        i += 1
                    }
                }
            }
        }
        return pairs
    }

    var body: some View {
        let theme = Color.Theme(themeManager.colors)
        let rows = pairs

        let contentVersion = {
            var v = showLineNumbers ? 1 : 0
            v &+= hunks.count &* 31
            v &+= hunks.reduce(0) { $0 &+ $1.header.hashValue } &* 131
            v &+= hunks.reduce(0) { $0 &+ $1.lines.count } &* 17
            return v
        }()

        func desiredContentHeight(from rows: [DiffPair]) -> CGFloat {
            var total: CGFloat = 0
            for row in rows {
                total += row.hunkHeader != nil ? 27 : 22
            }
            return max(total, 1)
        }

        let desiredHeight = desiredContentHeight(from: rows)

        return SynchronizedSplitDiffScrollView(
            scrollOffset: $scrollOffset,
            viewportHeight: $viewportHeight,
            contentHeight: $contentHeight,
            contentVersion: contentVersion
        ) {
            SplitDiffContentView(pairs: rows, side: .left, showLineNumbers: showLineNumbers)
                .background(theme.background)
        } rightContent: {
            SplitDiffContentView(pairs: rows, side: .right, showLineNumbers: showLineNumbers)
                .background(theme.background)
        }
        .background(theme.background)
        .onAppear {
            if abs(contentHeight - desiredHeight) > 0.5 {
                contentHeight = desiredHeight
            }
        }
        .onChange(of: hunks.count) { _, _ in
            let newDesired = desiredContentHeight(from: rows)
            if abs(contentHeight - newDesired) > 0.5 {
                contentHeight = newDesired
            }
        }
        .onChange(of: hunks.reduce(0) { $0 + $1.lines.count }) { _, _ in
            let newDesired = desiredContentHeight(from: rows)
            if abs(contentHeight - newDesired) > 0.5 {
                contentHeight = newDesired
            }
        }
    }
}

// MARK: - Synchronized Split Diff Scroll View

/// NSViewRepresentable wrapper for split diff with synchronized horizontal and vertical scrolling
struct SynchronizedSplitDiffScrollView<LeftContent: View, RightContent: View>: NSViewRepresentable {
    @Binding var scrollOffset: CGFloat
    @Binding var viewportHeight: CGFloat
    @Binding var contentHeight: CGFloat
    let contentVersion: Int
    @ViewBuilder let leftContent: () -> LeftContent
    @ViewBuilder let rightContent: () -> RightContent

    func makeNSView(context: Context) -> NSView {
        let containerView = NSView()

        // Create left scroll view
        let leftScrollView = NSScrollView()
        leftScrollView.hasVerticalScroller = true
        leftScrollView.hasHorizontalScroller = true
        leftScrollView.autohidesScrollers = false
        leftScrollView.borderType = .noBorder
        leftScrollView.drawsBackground = false
        leftScrollView.verticalScrollElasticity = .none
        leftScrollView.horizontalScrollElasticity = .none

        // Create right scroll view
        let rightScrollView = NSScrollView()
        rightScrollView.hasVerticalScroller = true
        rightScrollView.hasHorizontalScroller = true
        rightScrollView.autohidesScrollers = false
        rightScrollView.borderType = .noBorder
        rightScrollView.drawsBackground = false
        rightScrollView.verticalScrollElasticity = .none
        rightScrollView.horizontalScrollElasticity = .none

        // Create hosting views for SwiftUI content
        let leftHostingView = NSHostingView(rootView: leftContent())
        let rightHostingView = NSHostingView(rootView: rightContent())

        leftScrollView.documentView = leftHostingView
        rightScrollView.documentView = rightHostingView

        // Store references in coordinator
        context.coordinator.leftScrollView = leftScrollView
        context.coordinator.rightScrollView = rightScrollView
        context.coordinator.containerView = containerView
        context.coordinator.leftHostingView = leftHostingView
        context.coordinator.rightHostingView = rightHostingView
        context.coordinator.lastContentVersion = contentVersion

        // Add scroll notification observers
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrollViewDidScroll(_:)),
            name: NSView.boundsDidChangeNotification,
            object: leftScrollView.contentView
        )

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrollViewDidScroll(_:)),
            name: NSView.boundsDidChangeNotification,
            object: rightScrollView.contentView
        )

        // Layout scroll views side by side with divider
        containerView.addSubview(leftScrollView)

        let divider = NSView()
        divider.wantsLayer = true
        divider.layer?.backgroundColor = NSColor(Color.Theme(ThemeManager.shared.colors).border).cgColor
        containerView.addSubview(divider)

        containerView.addSubview(rightScrollView)

        // Store divider reference
        context.coordinator.divider = divider

        // Initialize viewport and content height after layout
        DispatchQueue.main.async {
            // Force initial layout
            containerView.needsLayout = true
            containerView.layoutSubtreeIfNeeded()

            // Update viewport height
            viewportHeight = containerView.bounds.height

            // Update content height from document views
            if let leftDocView = leftScrollView.documentView,
               let rightDocView = rightScrollView.documentView {
                let maxHeight = max(leftDocView.fittingSize.height, rightDocView.fittingSize.height)
                if maxHeight > 0 {
                    contentHeight = maxHeight
                }
            }
        }

        return containerView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let leftScrollView = context.coordinator.leftScrollView,
              let rightScrollView = context.coordinator.rightScrollView,
              let divider = context.coordinator.divider else { return }

        if context.coordinator.lastContentVersion != contentVersion {
            context.coordinator.leftHostingView?.rootView = leftContent()
            context.coordinator.rightHostingView?.rootView = rightContent()
            context.coordinator.lastContentVersion = contentVersion
        }

        divider.layer?.backgroundColor = NSColor(Color.Theme(ThemeManager.shared.colors).border).cgColor

        // Update layout
        let frame = nsView.bounds
        let dividerWidth: CGFloat = 2
        let halfWidth = (frame.width - dividerWidth) / 2

        leftScrollView.frame = NSRect(x: 0, y: 0, width: halfWidth, height: frame.height)
        divider.frame = NSRect(x: halfWidth, y: 0, width: dividerWidth, height: frame.height)
        rightScrollView.frame = NSRect(x: halfWidth + dividerWidth, y: 0, width: halfWidth, height: frame.height)

        // Sync document view sizes (ensure height is large enough for full scrolling)
        if let leftDocView = leftScrollView.documentView,
           let rightDocView = rightScrollView.documentView {
            let fittedHeight = max(leftDocView.fittingSize.height, rightDocView.fittingSize.height)
            let desiredHeight = max(contentHeight, fittedHeight, frame.height)
            let leftWidth = max(leftDocView.fittingSize.width, halfWidth)
            let rightWidth = max(rightDocView.fittingSize.width, halfWidth)

            leftDocView.frame = NSRect(x: 0, y: 0, width: leftWidth, height: desiredHeight)
            rightDocView.frame = NSRect(x: 0, y: 0, width: rightWidth, height: desiredHeight)

            // Update contentHeight binding
            if desiredHeight > 0, context.coordinator.lastContentHeight != desiredHeight {
                context.coordinator.lastContentHeight = desiredHeight
                DispatchQueue.main.async {
                    contentHeight = desiredHeight
                }
            }
        }

        // Update viewport height
        if frame.height > 0, context.coordinator.lastViewportHeight != frame.height {
            context.coordinator.lastViewportHeight = frame.height
            DispatchQueue.main.async {
                viewportHeight = frame.height
            }
        }

        // Handle programmatic scrolling from SwiftUI (e.g., minimap clicks)
        if !context.coordinator.isSyncing {
            let maxScroll = max(0, contentHeight - frame.height)
            let targetY = max(0, min(scrollOffset, maxScroll))
            if abs(context.coordinator.lastAppliedProgrammaticScrollOffset - targetY) > 0.5 {
                context.coordinator.lastAppliedProgrammaticScrollOffset = targetY
                let targetPoint = NSPoint(x: 0, y: targetY)
                leftScrollView.contentView.scroll(to: targetPoint)
                rightScrollView.contentView.scroll(to: targetPoint)
                leftScrollView.reflectScrolledClipView(leftScrollView.contentView)
                rightScrollView.reflectScrolledClipView(rightScrollView.contentView)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject {
        var parent: SynchronizedSplitDiffScrollView
        var isSyncing = false

        weak var leftScrollView: NSScrollView?
        weak var rightScrollView: NSScrollView?
        weak var leftHostingView: NSHostingView<LeftContent>?
        weak var rightHostingView: NSHostingView<RightContent>?
        weak var containerView: NSView?
        weak var divider: NSView?

        var lastViewportHeight: CGFloat = 0
        var lastContentHeight: CGFloat = 0
        var lastAppliedProgrammaticScrollOffset: CGFloat = -1
        var lastContentVersion: Int = -1

        private var lastScrollTime: Date = Date()
        private let scrollDebounceInterval: TimeInterval = 0.016 // ~60fps

        init(_ parent: SynchronizedSplitDiffScrollView) {
            self.parent = parent
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        @MainActor @objc func scrollViewDidScroll(_ notification: Notification) {
            guard !isSyncing else { return }
            guard let clipView = notification.object as? NSClipView else { return }

            // Debounce rapid scroll events
            let now = Date()
            guard now.timeIntervalSince(lastScrollTime) >= scrollDebounceInterval else { return }
            lastScrollTime = now

            isSyncing = true
            defer { isSyncing = false }

            let scrollPosition = clipView.bounds.origin

            // Determine which scroll view triggered the event
            if clipView == leftScrollView?.contentView {
                // Left scrolled, sync to right
                rightScrollView?.contentView.scroll(to: scrollPosition)
                if let right = rightScrollView {
                    right.reflectScrolledClipView(right.contentView)
                }
            } else if clipView == rightScrollView?.contentView {
                // Right scrolled, sync to left
                leftScrollView?.contentView.scroll(to: scrollPosition)
                if let left = leftScrollView {
                    left.reflectScrolledClipView(left.contentView)
                }
            }

            // Update SwiftUI binding for minimap integration (already on main thread)
            let newOffset = max(0, scrollPosition.y)
            if parent.scrollOffset != newOffset {
                DispatchQueue.main.async {
                    self.parent.scrollOffset = newOffset
                }
            }

            // Update viewport height if container is available
            if let container = containerView {
                let newViewport = container.bounds.height
                if newViewport > 0, self.parent.viewportHeight != newViewport {
                    DispatchQueue.main.async {
                        self.parent.viewportHeight = newViewport
                    }
                }
            }
        }
    }
}

// MARK: - Split Diff Content View

/// Renders one side (left or right) of the split diff
struct SplitDiffContentView: View {
    let pairs: [DiffPair]
    let side: DiffSide
    let showLineNumbers: Bool

    var body: some View {
        LazyVStack(spacing: 0, pinnedViews: []) {
            ForEach(pairs) { pair in
                if let header = pair.hunkHeader {
                    // Hunk header - same on both sides
                    FastHunkHeader(header: header)
                } else {
                    // Render line for this side
                    if let line = lineForSide(pair, side) {
                        FastDiffLine(
                            line: line,
                            side: side,
                            showLineNumber: showLineNumbers,
                            paired: pairedLine(pair, side)
                        )
                    } else {
                        // Empty line on this side
                        FastEmptyLine(
                            showLineNumber: showLineNumbers,
                            isDeleted: side == .left && pair.right?.type == .addition,
                            isAdded: side == .right && pair.left?.type == .deletion
                        )
                    }
                }
            }
        }
    }

    private func lineForSide(_ pair: DiffPair, _ side: DiffSide) -> DiffLine? {
        side == .left ? pair.left : pair.right
    }

    private func pairedLine(_ pair: DiffPair, _ side: DiffSide) -> DiffLine? {
        side == .left ? pair.right : pair.left
    }
}

// MARK: - Optimized Inline Diff View

struct OptimizedInlineDiffView: View {
    let hunks: [DiffHunk]
    let showLineNumbers: Bool
    @Binding var scrollOffset: CGFloat
    @Binding var viewportHeight: CGFloat
    @Binding var contentHeight: CGFloat

    private var allLines: [IdentifiedDiffLine] {
        var result: [IdentifiedDiffLine] = []
        var lineId = 0
        for hunk in hunks {
            lineId += 1
            result.append(IdentifiedDiffLine(id: lineId, line: nil, hunkHeader: hunk.header))
            for line in hunk.lines {
                lineId += 1
                result.append(IdentifiedDiffLine(id: lineId, line: line, hunkHeader: nil))
            }
        }
        return result
    }

    var body: some View {
        UnifiedDiffScrollView(scrollOffset: $scrollOffset, viewportHeight: $viewportHeight) {
            VStack(spacing: 0) {
                LazyVStack(spacing: 0) {
                    ForEach(allLines) { item in
                        if let header = item.hunkHeader {
                            FastHunkHeader(header: header)
                        } else if let line = item.line {
                            FastInlineLine(line: line, showLineNumber: showLineNumbers)
                        }
                    }
                }
            }
        }
    }
}



// FastHunkHeader, FastEmptyLine, FastDiffLine, FastInlineLine are now in UI/Components/Diff/DiffLineView.swift
// DiffViewMode, DiffToolbar, ToolbarButton, DiffModeButton are now in UI/Components/Diff/DiffToolbar.swift
// DiffSide enum is now in UI/Components/Diff/DiffLineView.swift

// MARK: - Diff Toolbar components moved to UI/Components/Diff/DiffToolbar.swift

// MARK: - Split Diff View (Side by Side) with Synchronized Scrolling

struct SplitDiffView: View {
    let hunks: [DiffHunk]
    let showLineNumbers: Bool
    let filename: String
    @StateObject private var themeManager = ThemeManager.shared

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
        let theme = Color.Theme(themeManager.colors)

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
                        .fill(theme.border)
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
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "text.alignleft")
                .font(DesignTokens.Typography.caption2)
            Text(header)
                .font(DesignTokens.Typography.commitHash)
        }
        .foregroundColor(theme.accent)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .padding(.horizontal, DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.accent.opacity(0.08))
    }
}

struct SplitDiffLineRow: View {
    let line: DiffLine
    let side: DiffSide
    let showLineNumber: Bool
    let pairedLine: DiffLine?
    @StateObject private var themeManager = ThemeManager.shared

    var lineNumber: Int? {
        switch side {
        case .left: return line.oldLineNumber
        case .right: return line.newLineNumber
        }
    }

    // Compute character-level diff (Kaleidoscope-style)
    private var highlightedContent: AttributedString {
        guard let paired = pairedLine,
              line.type != .context,
              paired.type != .context else {
            return AttributedString(line.content)
        }

        // Determine old and new content based on line types
        let oldContent = line.type == .deletion ? line.content : paired.content
        let newContent = line.type == .addition ? line.content : paired.content

        // Get character-level diff
        let diffResult = WordLevelDiff.compare(oldLine: oldContent, newLine: newContent)

        // Use appropriate segments based on which side we're rendering
        let segments = line.type == .deletion ? diffResult.oldSegments : diffResult.newSegments

        var result = AttributedString()

        for segment in segments {
            var segmentAttr = AttributedString(segment.text)

            switch segment.type {
            case .unchanged:
                // No special highlighting
                break
            case .added:
                segmentAttr.backgroundColor = AppTheme.diffAddition.opacity(0.4)
                segmentAttr.foregroundColor = AppTheme.diffAddition
            case .removed:
                segmentAttr.backgroundColor = AppTheme.diffDeletion.opacity(0.4)
                segmentAttr.foregroundColor = AppTheme.diffDeletion
            case .changed:
                let color = line.type == .addition ? AppTheme.diffAddition : AppTheme.diffDeletion
                segmentAttr.backgroundColor = color.opacity(0.4)
            }

            result.append(segmentAttr)
        }

        return result
    }

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        HStack(spacing: 0) {
            if showLineNumber {
                Text(lineNumber.map { String($0) } ?? "")
                    .font(DesignTokens.Typography.commitHash)
                    .foregroundColor(theme.text)
                    .frame(width: 45, alignment: .trailing)
                    .padding(.trailing, DesignTokens.Spacing.sm)
                    .background(lineNumberBackground(theme: theme))
            }

            // Change indicator
            Text(changeIndicator)
                .font(DesignTokens.Typography.diffLine)
                .foregroundColor(indicatorColor(theme: theme))
                .frame(width: 16)

            // Content with word-level highlighting
            Text(highlightedContent)
                .font(DesignTokens.Typography.diffLine)
                .foregroundColor(textColor(theme: theme))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, DesignTokens.Spacing.xxs)
        .padding(.trailing, DesignTokens.Spacing.sm)
        .background(backgroundColor(theme: theme))
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

    func indicatorColor(theme: SwiftUI.Color.Theme) -> SwiftUI.Color {
        switch line.type {
        case .addition: return AppTheme.diffAddition
        case .deletion: return AppTheme.diffDeletion
        default: return theme.text
        }
    }

    func backgroundColor(theme: SwiftUI.Color.Theme) -> SwiftUI.Color {
        switch line.type {
        case .addition: return AppTheme.diffAdditionBg
        case .deletion: return AppTheme.diffDeletionBg
        case .context, .hunkHeader: return SwiftUI.Color.clear
        }
    }

    func lineNumberBackground(theme: SwiftUI.Color.Theme) -> SwiftUI.Color {
        switch line.type {
        case .addition: return AppTheme.diffLineNumberBg
        case .deletion: return AppTheme.diffLineNumberBg
        case .context, .hunkHeader: return theme.backgroundSecondary
        }
    }

    func textColor(theme: SwiftUI.Color.Theme) -> SwiftUI.Color {
        switch line.type {
        case .addition: return AppTheme.diffAddition
        case .deletion: return AppTheme.diffDeletion
        case .context, .hunkHeader: return theme.text
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
                ForEach(Array(hunks.enumerated()), id: \.element.id) { index, hunk in
                    HunkHeaderRow(header: hunk.header, hunkIndex: index)

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

    @Binding var scrollOffset: CGFloat
    @Binding var viewportHeight: CGFloat
    var contentHeight: Binding<CGFloat>? = nil
    var viewId: String = "DiffScrollView"
    @State private var collapsedHunks: Set<Int> = []
    @State private var selectedHunks: Set<Int> = []
    @State private var isSelectionMode: Bool = false

    private var hasActions: Bool {
        onStageHunk != nil || onUnstageHunk != nil || onDiscardHunk != nil
    }

    private var totalAdditions: Int {
        hunks.reduce(0) { total, hunk in
            total + hunk.lines.filter { $0.type == .addition }.count
        }
    }

    private var totalDeletions: Int {
        hunks.reduce(0) { total, hunk in
            total + hunk.lines.filter { $0.type == .deletion }.count
        }
    }

    var body: some View {
        UnifiedDiffScrollView(
            scrollOffset: $scrollOffset,
            viewportHeight: $viewportHeight,
            contentHeight: contentHeight,
            id: viewId
        ) {
            contentView
        }
    }

    @ViewBuilder
    private var contentView: some View {
        VStack(spacing: 0) {
            LazyVStack(spacing: DesignTokens.Spacing.md) {
                headerView
                hunksList
            }
            .padding()
        }
    }

    @ViewBuilder
    private var headerView: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            HunkSummaryHeader(
                hunkCount: hunks.count,
                totalAdditions: totalAdditions,
                totalDeletions: totalDeletions
            )

            Spacer()

            if hasActions && hunks.count > 1 {
                selectionToolbar
            }
        }
    }

    @ViewBuilder
    private var selectionToolbar: some View {
        HunkSelectionToolbar(
            isSelectionMode: $isSelectionMode,
            selectedCount: selectedHunks.count,
            totalCount: hunks.count,
            isStaged: isStaged,
            onSelectAll: selectAllHunks,
            onDeselectAll: deselectAllHunks,
            onStageSelected: stageSelectionAction,
            onUnstageSelected: unstageSelectionAction,
            onDiscardSelected: discardSelectionAction
        )
    }

    private var stageSelectionAction: (() -> Void)? {
        if onStageHunk != nil {
            return stageSelectedHunks
        }
        return nil
    }

    private var unstageSelectionAction: (() -> Void)? {
        if onUnstageHunk != nil {
            return unstageSelectedHunks
        }
        return nil
    }

    private var discardSelectionAction: (() -> Void)? {
        if onDiscardHunk != nil {
            return discardSelectedHunks
        }
        return nil
    }

    private func selectAllHunks() {
        selectedHunks = Set(0..<hunks.count)
    }

    private func deselectAllHunks() {
        selectedHunks.removeAll()
    }

    @ViewBuilder
    private var hunksList: some View {
        ForEach(Array(hunks.enumerated()), id: \.element.id) { index, hunk in
            CollapsibleHunkCard(
                hunk: hunk,
                hunkIndex: index,
                totalHunks: hunks.count,
                showLineNumbers: showLineNumbers,
                showActions: onStageHunk != nil || onUnstageHunk != nil,
                isStaged: isStaged,
                isCollapsed: collapsedHunks.contains(index),
                isSelectionMode: isSelectionMode,
                isSelected: selectedHunks.contains(index),
                onToggleCollapse: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if collapsedHunks.contains(index) {
                            collapsedHunks.remove(index)
                        } else {
                            collapsedHunks.insert(index)
                        }
                    }
                },
                onToggleSelection: {
                    if selectedHunks.contains(index) {
                        selectedHunks.remove(index)
                    } else {
                        selectedHunks.insert(index)
                    }
                },
                onStage: { onStageHunk?(index) },
                onUnstage: { onUnstageHunk?(index) },
                onDiscard: { onDiscardHunk?(index) }
            )
        }
    }

    private func stageSelectedHunks() {
        for index in selectedHunks.sorted() {
            onStageHunk?(index)
        }
        selectedHunks.removeAll()
        isSelectionMode = false
    }

    private func unstageSelectedHunks() {
        for index in selectedHunks.sorted() {
            onUnstageHunk?(index)
        }
        selectedHunks.removeAll()
        isSelectionMode = false
    }

    private func discardSelectedHunks() {
        // Discard in reverse order to avoid index shifting issues
        for index in selectedHunks.sorted().reversed() {
            onDiscardHunk?(index)
        }
        selectedHunks.removeAll()
        isSelectionMode = false
    }
}

// MARK: - Hunk Summary Header

struct HunkSummaryHeader: View {
    let hunkCount: Int
    let totalAdditions: Int
    let totalDeletions: Int
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        HStack(spacing: DesignTokens.Spacing.lg) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: "text.alignleft")
                    .font(DesignTokens.Typography.callout)
                Text("\(hunkCount) hunk\(hunkCount == 1 ? "" : "s")")
                    .font(DesignTokens.Typography.callout.weight(.medium))
            }
            .foregroundColor(theme.text)

            Spacer()

            HStack(spacing: DesignTokens.Spacing.md) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "plus")
                        .font(DesignTokens.Typography.caption2.weight(.bold))
                    Text("\(totalAdditions)")
                }
                .foregroundColor(AppTheme.diffAddition)

                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "minus")
                        .font(DesignTokens.Typography.caption2.weight(.bold))
                    Text("\(totalDeletions)")
                }
                .foregroundColor(AppTheme.diffDeletion)
            }
            .font(DesignTokens.Typography.callout.weight(.semibold).monospaced())
        }
        .padding(.horizontal, DesignTokens.Spacing.md + DesignTokens.Spacing.xxs)
        .padding(.vertical, DesignTokens.Spacing.sm + DesignTokens.Spacing.xxs)
        .background(theme.backgroundSecondary)
        .cornerRadius(DesignTokens.CornerRadius.lg)
    }
}

// MARK: - Hunk Selection Toolbar

struct HunkSelectionToolbar: View {
    @Binding var isSelectionMode: Bool
    let selectedCount: Int
    let totalCount: Int
    var isStaged: Bool = false
    var onSelectAll: (() -> Void)?
    var onDeselectAll: (() -> Void)?
    var onStageSelected: (() -> Void)?
    var onUnstageSelected: (() -> Void)?
    var onDiscardSelected: (() -> Void)?
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        HStack(spacing: DesignTokens.Spacing.sm) {
            // Toggle selection mode
            Button {
                withAnimation(DesignTokens.Animation.fastEasing) {
                    isSelectionMode.toggle()
                    if !isSelectionMode {
                        onDeselectAll?()
                    }
                }
            } label: {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: isSelectionMode ? "checkmark.square.fill" : "square.dashed")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(theme.textSecondary)
                    Text("Select")
                        .font(DesignTokens.Typography.caption.weight(.medium))
                }
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .background(isSelectionMode ? theme.accent.opacity(0.2) : Color.clear)
                .cornerRadius(DesignTokens.CornerRadius.sm)
            }
            .buttonStyle(.plain)
            .foregroundColor(isSelectionMode ? theme.accent : theme.text)

            if isSelectionMode {
                Divider()
                    .frame(height: 16)

                // Selection counter
                Text("\(selectedCount)/\(totalCount)")
                    .font(DesignTokens.Typography.caption.monospaced())
                    .foregroundColor(theme.text)

                // Select/Deselect all buttons
                Button("All") { onSelectAll?() }
                    .font(DesignTokens.Typography.caption2.weight(.medium))
                    .buttonStyle(.plain)
                    .foregroundColor(theme.accent)

                Button("None") { onDeselectAll?() }
                    .font(DesignTokens.Typography.caption2.weight(.medium))
                    .buttonStyle(.plain)
                    .foregroundColor(theme.text)

                if selectedCount > 0 {
                    Divider()
                        .frame(height: 16)

                    // Bulk actions
                    if !isStaged, let stageSelected = onStageSelected {
                        Button {
                            stageSelected()
                        } label: {
                            HStack(spacing: DesignTokens.Spacing.xxs + 1) {
                                Image(systemName: "plus.circle.fill")
                                    .font(DesignTokens.Typography.caption2)
                                    .foregroundColor(theme.success)
                                Text("Stage")
                                    .font(DesignTokens.Typography.caption2.weight(.medium))
                            }
                            .padding(.horizontal, DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
                            .padding(.vertical, DesignTokens.Spacing.xxs + 1)
                            .background(AppTheme.diffAddition)
                            .foregroundColor(AppTheme.textPrimary)
                            .cornerRadius(DesignTokens.CornerRadius.sm)
                        }
                        .buttonStyle(.plain)
                    }

                    if isStaged, let unstageSelected = onUnstageSelected {
                        Button {
                            unstageSelected()
                        } label: {
                            HStack(spacing: DesignTokens.Spacing.xxs + 1) {
                                Image(systemName: "minus.circle.fill")
                                    .font(DesignTokens.Typography.caption2)
                                    .foregroundColor(theme.error)
                                Text("Unstage")
                                    .font(DesignTokens.Typography.caption2.weight(.medium))
                            }
                            .padding(.horizontal, DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
                            .padding(.vertical, DesignTokens.Spacing.xxs + 1)
                            .background(AppTheme.warning)
                            .foregroundColor(AppTheme.textPrimary)
                            .cornerRadius(DesignTokens.CornerRadius.sm)
                        }
                        .buttonStyle(.plain)
                    }

                    if !isStaged, let discardSelected = onDiscardSelected {
                        Button {
                            discardSelected()
                        } label: {
                            HStack(spacing: DesignTokens.Spacing.xxs + 1) {
                                Image(systemName: "trash")
                                    .font(DesignTokens.Typography.caption2)
                                    .foregroundColor(theme.error)
                                Text("Discard")
                                    .font(DesignTokens.Typography.caption2.weight(.medium))
                            }
                            .padding(.horizontal, DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
                            .padding(.vertical, DesignTokens.Spacing.xxs + 1)
                            .background(AppTheme.diffDeletion)
                            .foregroundColor(AppTheme.textPrimary)
                            .cornerRadius(DesignTokens.CornerRadius.sm)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
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
    var isSelectionMode: Bool = false
    var isSelected: Bool = false
    var onToggleCollapse: (() -> Void)?
    var onToggleSelection: (() -> Void)?
    var onStage: (() -> Void)?
    var onUnstage: (() -> Void)?
    var onDiscard: (() -> Void)?

    @State private var isHovered = false
    @StateObject private var themeManager = ThemeManager.shared

    private var additions: Int {
        hunk.lines.filter { $0.type == .addition }.count
    }

    private var deletions: Int {
        hunk.lines.filter { $0.type == .deletion }.count
    }

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        VStack(alignment: .leading, spacing: 0) {
            // Hunk header (always visible)
            HStack(spacing: DesignTokens.Spacing.sm) {
                // Selection checkbox (visible in selection mode)
                if isSelectionMode {
                    Button {
                        onToggleSelection?()
                    } label: {
                        Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                            .font(DesignTokens.Typography.headline)
                            .foregroundColor(isSelected ? theme.accent : theme.text)
                    }
                    .buttonStyle(.plain)
                }

                // Collapse toggle
                Button(action: { onToggleCollapse?() }) {
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(DesignTokens.Typography.caption2.weight(.bold))
                        .foregroundColor(theme.text)
                        .frame(width: DesignTokens.Size.iconMD, height: DesignTokens.Size.iconMD)
                }
                .buttonStyle(.plain)

                // Hunk number badge
                Text("Hunk \(hunkIndex + 1)/\(totalHunks)")
                    .font(DesignTokens.Typography.caption2.weight(.semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .padding(.horizontal, DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
                    .padding(.vertical, DesignTokens.Spacing.xxs)
                    .background(theme.accent)
                    .cornerRadius(DesignTokens.CornerRadius.sm)

                // Line range
                Text("Lines \(hunk.oldStart)-\(hunk.oldStart + hunk.oldLines) → \(hunk.newStart)-\(hunk.newStart + hunk.newLines)")
                    .font(DesignTokens.Typography.caption.monospaced())
                    .foregroundColor(theme.text)

                // Change stats
                HStack(spacing: DesignTokens.Spacing.xs) {
                    if additions > 0 {
                        Text("+\(additions)")
                            .foregroundColor(AppTheme.diffAddition)
                    }
                    if deletions > 0 {
                        Text("-\(deletions)")
                            .foregroundColor(AppTheme.diffDeletion)
                    }
                }
                .font(DesignTokens.Typography.caption.weight(.medium).monospaced())

                Spacer()

                // Actions (visible on hover)
                if showActions && isHovered && !isCollapsed {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        if !isStaged {
                            Button {
                                onStage?()
                            } label: {
                                Label("Stage", systemImage: "plus.circle.fill")
                                    .font(DesignTokens.Typography.caption.weight(.medium))
                                    .foregroundColor(AppTheme.textPrimary)
                                    .padding(.horizontal, DesignTokens.Spacing.sm)
                                    .padding(.vertical, DesignTokens.Spacing.xs)
                                    .background(AppTheme.diffAddition)
                                    .cornerRadius(DesignTokens.CornerRadius.sm)
                            }
                            .buttonStyle(.plain)

                            Button {
                                onDiscard?()
                            } label: {
                                Label("Discard", systemImage: "trash")
                                    .font(DesignTokens.Typography.caption.weight(.medium))
                                    .foregroundColor(AppTheme.textPrimary)
                                    .padding(.horizontal, DesignTokens.Spacing.sm)
                                    .padding(.vertical, DesignTokens.Spacing.xs)
                                    .background(AppTheme.diffDeletion)
                                    .cornerRadius(DesignTokens.CornerRadius.sm)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button {
                                onUnstage?()
                            } label: {
                                Label("Unstage", systemImage: "minus.circle.fill")
                                    .font(DesignTokens.Typography.caption.weight(.medium))
                                    .foregroundColor(AppTheme.textPrimary)
                                    .padding(.horizontal, DesignTokens.Spacing.sm)
                                    .padding(.vertical, DesignTokens.Spacing.xs)
                                    .background(AppTheme.warning)
                                    .cornerRadius(DesignTokens.CornerRadius.sm)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(theme.accent.opacity(0.08))

            // Lines (collapsible)
            if !isCollapsed {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(hunk.lines) { line in
                        HunkLineRow(line: line, showLineNumber: showLineNumbers)
                    }
                }
            } else {
                // Collapsed preview
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Text("...")
                        .foregroundColor(theme.text)
                    Text("\(hunk.lines.count) lines")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(theme.text)
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.backgroundTertiary)
            }
        }
        .background(isSelected ? theme.accent.opacity(0.1) : theme.backgroundSecondary)
        .cornerRadius(DesignTokens.CornerRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                .stroke(
                    isSelected ? theme.accent : (isHovered ? theme.accent.opacity(0.6) : theme.border),
                    lineWidth: isSelected || isHovered ? 2 : 1
                )
        )
        .onHover { isHovered = $0 }
        .onTapGesture {
            if isSelectionMode {
                onToggleSelection?()
            }
        }
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
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        VStack(alignment: .leading, spacing: 0) {
            // Hunk header with actions
            HStack {
                Text(hunk.header)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(theme.text)

                Spacer()

                if showActions && isHovered {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        if !isStaged {
                            // Stage this hunk
                            Button {
                                onStage?()
                            } label: {
                                HStack(spacing: DesignTokens.Spacing.xs) {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Stage Hunk")
                                }
                                .font(DesignTokens.Typography.caption.weight(.medium))
                                .foregroundColor(AppTheme.textPrimary)
                                .padding(.horizontal, DesignTokens.Spacing.sm)
                                .padding(.vertical, DesignTokens.Spacing.xs)
                                .background(AppTheme.diffAddition)
                                .cornerRadius(DesignTokens.CornerRadius.sm)
                            }
                            .buttonStyle(.plain)

                            // Discard this hunk
                            Button {
                                onDiscard?()
                            } label: {
                                HStack(spacing: DesignTokens.Spacing.xs) {
                                    Image(systemName: "trash")
                                    Text("Discard")
                                }
                                .font(DesignTokens.Typography.caption.weight(.medium))
                                .foregroundColor(AppTheme.textPrimary)
                                .padding(.horizontal, DesignTokens.Spacing.sm)
                                .padding(.vertical, DesignTokens.Spacing.xs)
                                .background(AppTheme.diffDeletion)
                                .cornerRadius(DesignTokens.CornerRadius.sm)
                            }
                            .buttonStyle(.plain)
                        } else {
                            // Unstage this hunk
                            Button {
                                onUnstage?()
                            } label: {
                                HStack(spacing: DesignTokens.Spacing.xs) {
                                    Image(systemName: "minus.circle.fill")
                                    Text("Unstage Hunk")
                                }
                                .font(DesignTokens.Typography.caption.weight(.medium))
                                .foregroundColor(AppTheme.textPrimary)
                                .padding(.horizontal, DesignTokens.Spacing.sm)
                                .padding(.vertical, DesignTokens.Spacing.xs)
                                .background(AppTheme.warning)
                                .cornerRadius(DesignTokens.CornerRadius.sm)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Text("Lines \(hunk.oldStart)-\(hunk.oldStart + hunk.oldLines)")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(theme.text)
            }
            .padding(DesignTokens.Spacing.sm)
            .background(theme.info.opacity(0.1))

            // Lines
            VStack(alignment: .leading, spacing: 0) {
                ForEach(hunk.lines) { line in
                    HunkLineRow(line: line, showLineNumber: showLineNumbers)
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .cornerRadius(DesignTokens.CornerRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                .stroke(isHovered ? theme.accent.opacity(0.5) : theme.border, lineWidth: isHovered ? 2 : 1)
        )
        .onHover { isHovered = $0 }
    }
}















/// Line model for large diff view
private struct LargeDiffLine: Identifiable {
    let id: Int
    let type: DiffLineType
    let content: String
    let oldLineNumber: Int?
    let newLineNumber: Int?
    let hunkIndex: Int
}

/// Simple line view for large diffs (minimal overhead)
private struct LargeDiffLineView: View {
    let line: LargeDiffLine
    let showLineNumbers: Bool
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        HStack(spacing: 0) {
            if line.type == .hunkHeader {
                // Hunk header
                Text(line.content)
                    .font(DesignTokens.Typography.commitHash)
                    .foregroundColor(AppTheme.info)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                    .background(SwiftUI.Color.cyan.opacity(0.1))
            } else {
                // Regular line
                if showLineNumbers {
                    HStack(spacing: DesignTokens.Spacing.xxs) {
                        Text(line.oldLineNumber.map { "\($0)" } ?? "")
                            .frame(width: 35, alignment: .trailing)
                        Text(line.newLineNumber.map { "\($0)" } ?? "")
                            .frame(width: 35, alignment: .trailing)
                    }
                    .font(DesignTokens.Typography.commitHash)
                    .foregroundColor(theme.text.opacity(0.7))
                    .padding(.trailing, DesignTokens.Spacing.xs)
                }

                Text(prefix)
                    .font(DesignTokens.Typography.diffLine)
                    .foregroundColor(prefixColor(theme: theme))
                    .frame(width: 14)

                Text(line.content)
                    .font(DesignTokens.Typography.diffLine)
                    .foregroundColor(textColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(height: 22)
        .background(backgroundColor)
    }

    private var prefix: String {
        switch line.type {
        case .addition: return "+"
        case .deletion: return "-"
        case .context: return " "
        case .hunkHeader: return "@"
        }
    }

    private func prefixColor(theme: SwiftUI.Color.Theme) -> SwiftUI.Color {
        switch line.type {
        case .addition: return theme.diffAddition
        case .deletion: return theme.diffDeletion
        default: return theme.text
        }
    }

    private var textColor: SwiftUI.Color {
        let theme = Color.Theme(themeManager.colors)
        switch line.type {
        case .addition: return theme.diffAddition
        case .deletion: return theme.diffDeletion
        default: return theme.text
        }
    }

    private var backgroundColor: SwiftUI.Color {
        let theme = Color.Theme(themeManager.colors)
        switch line.type {
        case .addition: return theme.diffAdditionBg
        case .deletion: return theme.diffDeletionBg
        default: return .clear
        }
    }
}

/// Custom NSView for high-performance diff rendering
/// Only draws visible lines for O(1) scroll performance

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

// MARK: - DifferenceKit Split Diff View

struct DifferenceKitSplitDiffView: View {
    @StateObject private var viewModel = DiffViewModel()
    @State private var scrollOffset: CGFloat = 0
    
    let oldText: String
    let newText: String
    let showLineNumbers: Bool = true
    
    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    ZStack(alignment: .topLeading) {
                        // Main content with synchronized scrolling
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.diffRows) { row in
                                DiffRowView(
                                    row: row,
                                    showLineNumbers: showLineNumbers,
                                    width: geometry.size.width
                                )
                                .id("row_\(row.id)")
                            }
                        }
                        .background(
                            GeometryReader { scrollGeometry in
                                Color.clear.preference(
                                    key: ScrollOffsetKey.self,
                                    value: -scrollGeometry.frame(in: .named("scroll")).minY
                                )
                            }
                        )
                    }
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetKey.self) { offset in
                    scrollOffset = offset
                }
                .onAppear {
                    viewModel.calculateDiff(oldText: oldText, newText: newText)
                }
                .onChange(of: oldText) { _, new in
                    viewModel.calculateDiff(oldText: new, newText: newText)
                }
                .onChange(of: newText) { _, new in
                    viewModel.calculateDiff(oldText: oldText, newText: new)
                }
            }
        }
        .background(Color(.textBackgroundColor))
    }
}

// MARK: - Diff Row View

struct DiffRowView: View {
    let row: DKDiffRow
    let showLineNumbers: Bool
    let width: CGFloat
    
    private let gutterWidth: CGFloat = 60
    private let paneWidth: CGFloat
    
    init(row: DKDiffRow, showLineNumbers: Bool, width: CGFloat) {
        self.row = row
        self.showLineNumbers = showLineNumbers
        self.width = width
        self.paneWidth = (width - gutterWidth) / 2
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Left pane
            DiffPaneView(
                content: row.left,
                side: .left,
                showLineNumbers: showLineNumbers,
                width: paneWidth,
                pairedContent: row.right
            )
            
            // Gutter
            Rectangle()
                .fill(Color(.controlBackgroundColor))
                .frame(width: gutterWidth)
            
            // Right pane
            DiffPaneView(
                content: row.right,
                side: .right,
                showLineNumbers: showLineNumbers,
                width: paneWidth,
                pairedContent: row.left
            )
        }
        .frame(height: 24)
    }
}

// MARK: - Diff Pane View

struct DiffPaneView: View {
    let content: DKDiffLineContent
    let side: DKDiffSide
    let showLineNumbers: Bool
    let width: CGFloat
    let pairedContent: DKDiffLineContent
    
    var body: some View {
        HStack(spacing: 0) {
            if showLineNumbers {
                Text(lineNumber)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .trailing)
                    .padding(.trailing, 8)
                    .background(lineNumberBackground)
            }
            
            Text(changeIndicator)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(indicatorColor)
                .frame(width: 20)
            
            // Content with intra-line highlighting
            if case .content(let text, _) = content, 
               case .content(let pairedText, _) = pairedContent,
               diffType == .deleted || diffType == .added {
                Text(highlightedContent(text: text, pairedText: pairedText))
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(textColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 8)
            } else {
                Text(contentText)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(textColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 8)
            }
        }
        .frame(width: width)
        .background(backgroundColor)
    }
    
    private var lineNumber: String {
        switch content {
        case .content(_, let lineNumber):
            return String(lineNumber)
        case .spacer:
            return ""
        }
    }
    
    private var contentText: String {
        switch content {
        case .content(let text, _):
            return text
        case .spacer:
            return ""
        }
    }
    
    private var changeIndicator: String {
        switch diffType {
        case .added: return "+"
        case .deleted: return "-"
        default: return " "
        }
    }
    
    private var diffType: DKDiffLineType {
        switch (content, pairedContent) {
        case (.content, .spacer):
            return side == .left ? .deleted : .added
        case (.spacer, .content):
            return .spacer
        case (.content, .content):
            return .unchanged
        case (.spacer, .spacer):
            return .spacer
        }
    }
    
    private var indicatorColor: SwiftUI.Color {
        switch diffType {
        case .added: return SwiftUI.Color(red: 0.373, green: 0.722, blue: 0.471) // #5FB878
        case .deleted: return SwiftUI.Color(red: 0.851, green: 0.325, blue: 0.31) // #D9534F
        default: return .secondary
        }
    }
    
    private var textColor: SwiftUI.Color {
        switch diffType {
        case .added: return SwiftUI.Color(red: 0.373, green: 0.722, blue: 0.471) // #5FB878
        case .deleted: return SwiftUI.Color(red: 0.851, green: 0.325, blue: 0.31) // #D9534F
        default: return .primary
        }
    }
    
    private var backgroundColor: SwiftUI.Color {
        switch diffType {
        case .added: return SwiftUI.Color(red: 0.373, green: 0.722, blue: 0.471, opacity: 0.25)
        case .deleted: return SwiftUI.Color(red: 0.851, green: 0.325, blue: 0.31, opacity: 0.25)
        case .spacer: return SwiftUI.Color.clear
        default: return SwiftUI.Color.clear
        }
    }
    
    private var lineNumberBackground: SwiftUI.Color {
        switch diffType {
        case .added, .deleted: return SwiftUI.Color(.controlBackgroundColor).opacity(0.5)
        default: return SwiftUI.Color(.controlBackgroundColor)
        }
    }
    
    private func highlightedContent(text: String, pairedText: String) -> AttributedString {
        let diffResult = DKWordLevelDiff.compare(oldLine: text, newLine: pairedText)
        let segments = diffType == .deleted ? diffResult.oldSegments : diffResult.newSegments
        
        var result = AttributedString()
        
        for segment in segments {
            var segmentAttr = AttributedString(segment.text)
            
            switch segment.type {
            case .unchanged:
                break
            case .added:
                segmentAttr.backgroundColor = SwiftUI.Color(red: 0.373, green: 0.722, blue: 0.471, opacity: 0.4)
                segmentAttr.foregroundColor = SwiftUI.Color(red: 0.373, green: 0.722, blue: 0.471)
            case .removed:
                segmentAttr.backgroundColor = SwiftUI.Color(red: 0.851, green: 0.325, blue: 0.31, opacity: 0.4)
                segmentAttr.foregroundColor = SwiftUI.Color(red: 0.851, green: 0.325, blue: 0.31)
            case .changed:
                let color = diffType == .added ? 
                    SwiftUI.Color(red: 0.373, green: 0.722, blue: 0.471) : 
                    SwiftUI.Color(red: 0.851, green: 0.325, blue: 0.31)
                segmentAttr.backgroundColor = color.opacity(0.4)
            }
            
            result.append(segmentAttr)
        }
        
        return result
    }
}

// MARK: - DK Diff Side

enum DKDiffSide {
    case left
    case right
}

// MARK: - Scroll Offset Preference Key

struct ScrollOffsetKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - DK Diff Line Types

enum DKDiffLineType {
    case unchanged
    case added
    case deleted
    case spacer
}

enum DKDiffLineContent {
    case content(String, lineNumber: Int)
    case spacer
}

// MARK: - DK Diff Row Model

struct DKDiffRow: Identifiable {
    let id = UUID()
    let left: DKDiffLineContent
    let right: DKDiffLineContent
}

// MARK: - Diff ViewModel

class DiffViewModel: ObservableObject {
    @Published var diffRows: [DKDiffRow] = []
    
    // MARK: - Public Methods
    
    func calculateDiff(oldText: String, newText: String) {
        let oldLines = oldText.components(separatedBy: .newlines)
        let newLines = newText.components(separatedBy: .newlines)
        
        // Create differentiable elements
        let oldElements = oldLines.enumerated().map { index, content in
            DiffElement(content: content, index: index, side: .old)
        }
        
        let newElements = newLines.enumerated().map { index, content in
            DiffElement(content: content, index: index, side: .new)
        }
        
        // Calculate changeset using DifferenceKit
        let changeset = StagedChangeset(source: oldElements, target: newElements)
        
        // Apply gap insertion algorithm using the changeset
        var finalRows: [DKDiffRow] = []
        
        for stage in changeset {
            for deletion in stage.elementDeleted {
                // Add deleted line to left, spacer to right
                let element = oldElements[deletion.element]
                finalRows.append(DKDiffRow(
                    left: .content(element.content, lineNumber: element.index + 1),
                    right: .spacer
                ))
            }
            
            for insertion in stage.elementInserted {
                // Add spacer to left, inserted line to right
                let element = newElements[insertion.element]
                finalRows.append(DKDiffRow(
                    left: .spacer,
                    right: .content(element.content, lineNumber: element.index + 1)
                ))
            }
            
            for move in stage.elementMoved {
                // Handle moves - for now treat as unchanged line
                let newElement = newElements[move.target.element]
                finalRows.append(DKDiffRow(
                    left: .content(newElement.content, lineNumber: move.source.element + 1),
                    right: .content(newElement.content, lineNumber: move.target.element + 1)
                ))
            }
        }
        
        // Add unchanged lines that weren't in the changeset
        var processedOldIndices = Set<Int>()
        var processedNewIndices = Set<Int>()
        
        for stage in changeset {
            for deletion in stage.elementDeleted {
                processedOldIndices.insert(deletion.element)
            }
            
            for insertion in stage.elementInserted {
                processedNewIndices.insert(insertion.element)
            }
            
            for move in stage.elementMoved {
                processedOldIndices.insert(move.source.element)
                processedNewIndices.insert(move.target.element)
            }
        }
        
        // Find unchanged lines and add them
        var oldIndex = 0
        var newIndex = 0
        var allRows: [DKDiffRow] = []
        
        while oldIndex < oldLines.count || newIndex < newLines.count {
            if oldIndex < oldLines.count && newIndex < newLines.count {
                if !processedOldIndices.contains(oldIndex) && 
                   !processedNewIndices.contains(newIndex) && 
                   oldLines[oldIndex] == newLines[newIndex] {
                    // Unchanged line
                    allRows.append(DKDiffRow(
                        left: .content(oldLines[oldIndex], lineNumber: oldIndex + 1),
                        right: .content(newLines[newIndex], lineNumber: newIndex + 1)
                    ))
                    oldIndex += 1
                    newIndex += 1
                } else {
                    // Find the next unchanged line
                    let (nextOld, nextNew) = findNextUnchangedLines(
                        oldLines: oldLines,
                        newLines: newLines,
                        oldStart: oldIndex,
                        newStart: newIndex,
                        processedOld: processedOldIndices,
                        processedNew: processedNewIndices
                    )
                    
                    // Add deletions from old
                    for i in oldIndex..<nextOld {
                        if !processedOldIndices.contains(i) {
                            allRows.append(DKDiffRow(
                                left: .content(oldLines[i], lineNumber: i + 1),
                                right: .spacer
                            ))
                        }
                    }
                    
                    // Add insertions to new
                    for i in newIndex..<nextNew {
                        if !processedNewIndices.contains(i) {
                            allRows.append(DKDiffRow(
                                left: .spacer,
                                right: .content(newLines[i], lineNumber: i + 1)
                            ))
                        }
                    }
                    
                    oldIndex = nextOld
                    newIndex = nextNew
                }
            } else {
                break
            }
        }
        
        // Merge the changeset rows with unchanged rows
        self.diffRows = mergeChangesetRows(changesetRows: finalRows, unchangedRows: allRows)
    }
    
    // MARK: - Private Methods
    
    private func findNextUnchangedLines(
        oldLines: [String],
        newLines: [String],
        oldStart: Int,
        newStart: Int,
        processedOld: Set<Int>,
        processedNew: Set<Int>
    ) -> (oldIndex: Int, newIndex: Int) {
        var oldIndex = oldStart
        var newIndex = newStart
        
        // Look ahead to find the next unchanged line
        let maxLookahead = 20
        
        while oldIndex < oldLines.count && newIndex < newLines.count && 
              (oldIndex - oldStart < maxLookahead || newIndex - newStart < maxLookahead) {
            
            if !processedOld.contains(oldIndex) && 
               !processedNew.contains(newIndex) && 
               oldLines[oldIndex] == newLines[newIndex] {
                return (oldIndex, newIndex)
            }
            
            // Advance indices to find the next match
            if oldIndex - oldStart < maxLookahead {
                oldIndex += 1
            }
            if newIndex - newStart < maxLookahead {
                newIndex += 1
            }
        }
        
        return (min(oldIndex, oldLines.count), min(newIndex, newLines.count))
    }
    
    private func mergeChangesetRows(changesetRows: [DKDiffRow], unchangedRows: [DKDiffRow]) -> [DKDiffRow] {
        // Create a map of line numbers to changeset rows for quick lookup
        var deletionMap: [Int: DKDiffRow] = [:]
        var insertionMap: [Int: DKDiffRow] = [:]
        
        for row in changesetRows {
            switch (row.left, row.right) {
            case (.content(_, let lineNumber), .spacer):
                deletionMap[lineNumber] = row
            case (.spacer, .content(_, let lineNumber)):
                insertionMap[lineNumber] = row
            default:
                break
            }
        }
        
        // Merge unchanged rows with changeset rows
        var merged: [DKDiffRow] = []
        
        for row in unchangedRows {
            switch (row.left, row.right) {
            case (.content(_, let oldLineNumber), .content(_, let newLineNumber)):
                // Add any deletions before this unchanged line
                if let deletion = deletionMap[oldLineNumber] {
                    merged.append(deletion)
                }
                
                // Add any insertions before this unchanged line
                if let insertion = insertionMap[newLineNumber] {
                    merged.append(insertion)
                }
                
                // Add the unchanged line
                merged.append(row)
            default:
                break
            }
        }
        
        // Add any remaining deletions or insertions
        for row in changesetRows {
            switch (row.left, row.right) {
            case (.content, .spacer), (.spacer, .content):
                if !merged.contains(where: { $0.id == row.id }) {
                    merged.append(row)
                }
            default:
                break
            }
        }
        
        return merged
    }
}

// MARK: - Diff Element for DifferenceKit

struct DiffElement: Differentiable {
    let content: String
    let index: Int
    let side: Side
    
    enum Side {
        case old
        case new
    }
    
    var differenceIdentifier: String {
        return "\(side)_\(index)_\(content)"
    }
    
    func isContentEqual(to source: DiffElement) -> Bool {
        return content == source.content
    }
}

// MARK: - DK Intra-line Diff

struct DKWordLevelDiff {
    struct Segment {
        let text: String
        let type: SegmentType
        
        enum SegmentType {
            case unchanged
            case added
            case removed
            case changed
        }
    }
    
    static func compare(oldLine: String, newLine: String) -> (oldSegments: [Segment], newSegments: [Segment]) {
        let oldWords = oldLine.components(separatedBy: .whitespacesAndNewlines)
        let newWords = newLine.components(separatedBy: .whitespacesAndNewlines)
        
        let oldElements = oldWords.map { DKWordElement(content: $0) }
        let newElements = newWords.map { DKWordElement(content: $0) }
        
        let changeset = StagedChangeset(source: oldElements, target: newElements)
        
        var oldSegments: [Segment] = []
        var newSegments: [Segment] = []
        
        for stage in changeset {
            for deletion in stage.elementDeleted {
                oldSegments.append(Segment(text: oldElements[deletion.element].content, type: .removed))
            }
            
            for insertion in stage.elementInserted {
                newSegments.append(Segment(text: newElements[insertion.element].content, type: .added))
            }
            
            // Moves are ignored for word-level diff
        }
        
        return (oldSegments, newSegments)
    }
}

struct DKWordElement: Differentiable {
    let content: String
    
    var differenceIdentifier: String {
        return content
    }
    
    func isContentEqual(to source: DKWordElement) -> Bool {
        return content == source.content
    }
}
