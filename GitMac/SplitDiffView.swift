import SwiftUI

/// Split Diff View - Side-by-side comparison (with advanced features)
/// Optimized for performance with large files
struct SplitDiffView: View {
    let filePath: String
    let oldContent: String
    let newContent: String
    let hunks: [DiffHunk]
    
    @State private var viewMode: DiffViewMode = .unified
    @State private var showWhitespace = false
    @State private var contextLines = 3
    @State private var selectedHunk: DiffHunk?
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbarView
            
            Divider()
            
            // Diff content
            switch viewMode {
            case .unified:
                unifiedDiffView
            case .split:
                splitDiffView
            }
        }
    }
    
    // MARK: - Toolbar
    
    private var toolbarView: some View {
        HStack(spacing: 12) {
            // View mode picker
            Picker("View Mode", selection: $viewMode) {
                Label("Unified", systemImage: "list.bullet").tag(DiffViewMode.unified)
                Label("Split", systemImage: "rectangle.split.2x1").tag(DiffViewMode.split)
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
            
            Divider().frame(height: 20)
            
            // Options
            Toggle("Show Whitespace", isOn: $showWhitespace)
                .toggleStyle(.checkbox)
            
            Divider().frame(height: 20)
            
            // Context lines
            Stepper("Context: \(contextLines)", value: $contextLines, in: 0...10)
                .frame(width: 150)
            
            Spacer()
            
            // Stats
            diffStatsView
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    private var diffStatsView: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(AppTheme.success)
                Text("\(totalAdditions)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(AppTheme.success)
            }
            
            HStack(spacing: 4) {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(AppTheme.error)
                Text("\(totalDeletions)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(AppTheme.error)
            }
            
            Text("•")
                .foregroundColor(AppTheme.textPrimary)
            
            Text("\(hunks.count) hunks")
                .font(.caption)
                .foregroundColor(AppTheme.textPrimary)
        }
    }
    
    // MARK: - Unified Diff
    
    private var unifiedDiffView: some View {
        ScrollView([.horizontal, .vertical]) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(hunks) { hunk in
                    UnifiedHunkView(
                        hunk: hunk,
                        showWhitespace: showWhitespace,
                        isSelected: selectedHunk?.id == hunk.id
                    )
                    .onTapGesture {
                        selectedHunk = hunk
                    }
                }
            }
            .font(.system(.body, design: .monospaced))
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
    
    // MARK: - Split Diff
    
    private var splitDiffView: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Old (left)
                VStack(spacing: 0) {
                    // Header
                    DiffPaneHeader(title: "Original", color: AppTheme.error)

                    Divider()

                    // Content
                    ScrollView([.horizontal, .vertical]) {
                        SplitDiffPane(
                            hunks: hunks,
                            side: .old,
                            showWhitespace: showWhitespace,
                            selectedHunk: $selectedHunk
                        )
                    }
                    .background(Color(nsColor: .textBackgroundColor))
                }
                .frame(width: geometry.size.width / 2)

                Divider()

                // New (right)
                VStack(spacing: 0) {
                    // Header
                    DiffPaneHeader(title: "Modified", color: AppTheme.success)
                    
                    Divider()
                    
                    // Content
                    ScrollView([.horizontal, .vertical]) {
                        SplitDiffPane(
                            hunks: hunks,
                            side: .new,
                            showWhitespace: showWhitespace,
                            selectedHunk: $selectedHunk
                        )
                    }
                    .background(Color(nsColor: .textBackgroundColor))
                }
                .frame(width: geometry.size.width / 2)
            }
        }
    }
    
    // MARK: - Helpers
    
    private var totalAdditions: Int {
        hunks.reduce(0) { $0 + $1.additions }
    }
    
    private var totalDeletions: Int {
        hunks.reduce(0) { $0 + $1.deletions }
    }
}

// MARK: - Diff View Mode

enum DiffViewMode {
    case unified
    case split
}

// MARK: - Unified Hunk View

struct UnifiedHunkView: View {
    let hunk: DiffHunk
    let showWhitespace: Bool
    let isSelected: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hunk header
            HunkHeaderView(hunk: hunk, isSelected: isSelected)
            
            // Lines
            ForEach(Array(hunk.lines.enumerated()), id: \.offset) { index, line in
                UnifiedDiffLine(
                    line: line,
                    lineNumber: hunk.oldStart + index,
                    showWhitespace: showWhitespace
                )
            }
        }
    }
}

struct UnifiedDiffLine: View {
    let line: DiffLine
    let lineNumber: Int
    let showWhitespace: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            // Line numbers (old & new)
            HStack(spacing: 4) {
                Text(line.oldLineNumber.map { "\($0)" } ?? " ")
                    .frame(width: 50, alignment: .trailing)
                    .foregroundColor(AppTheme.textPrimary)
                
                Text(line.newLineNumber.map { "\($0)" } ?? " ")
                    .frame(width: 50, alignment: .trailing)
                    .foregroundColor(AppTheme.textPrimary)
            }
            .padding(.horizontal, 8)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            
            // Content
            Text(processedContent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 2)
        }
        .background(lineBackgroundColor)
        .font(.system(.body, design: .monospaced))
    }
    
    private var processedContent: String {
        var content = line.content
        
        if showWhitespace {
            content = content
                .replacingOccurrences(of: " ", with: "·")
                .replacingOccurrences(of: "\t", with: "→   ")
        }
        
        return content
    }
    
    private var lineBackgroundColor: Color {
        switch line.type {
        case .addition:
            return AppTheme.diffAdditionBg
        case .deletion:
            return AppTheme.diffDeletionBg
        case .context:
            return Color.clear
        }
    }
}

// MARK: - Split Diff Pane

enum DiffSide {
    case old
    case new
}

struct SplitDiffPane: View {
    let hunks: [DiffHunk]
    let side: DiffSide
    let showWhitespace: Bool
    @Binding var selectedHunk: DiffHunk?
    
    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(hunks) { hunk in
                VStack(alignment: .leading, spacing: 0) {
                    // Hunk header
                    HunkHeaderView(hunk: hunk, isSelected: selectedHunk?.id == hunk.id)
                    
                    // Lines for this side
                    ForEach(Array(hunk.lines.enumerated()), id: \.offset) { index, line in
                        if shouldShowLine(line, for: side) {
                            SplitDiffLine(
                                line: line,
                                side: side,
                                showWhitespace: showWhitespace
                            )
                        }
                    }
                }
                .onTapGesture {
                    selectedHunk = hunk
                }
            }
        }
        .font(.system(.body, design: .monospaced))
    }
    
    private func shouldShowLine(_ line: DiffLine, for side: DiffSide) -> Bool {
        switch (side, line.type) {
        case (.old, .addition):
            return false // Don't show additions in old pane
        case (.new, .deletion):
            return false // Don't show deletions in new pane
        default:
            return true
        }
    }
}

struct SplitDiffLine: View {
    let line: DiffLine
    let side: DiffSide
    let showWhitespace: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            // Line number
            Text(lineNumber)
                .frame(width: 60, alignment: .trailing)
                .foregroundColor(AppTheme.textPrimary)
                .padding(.horizontal, 8)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            
            // Content
            Text(processedContent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 2)
        }
        .background(lineBackgroundColor)
        .font(.system(.body, design: .monospaced))
    }
    
    private var lineNumber: String {
        switch side {
        case .old:
            return line.oldLineNumber.map { "\($0)" } ?? " "
        case .new:
            return line.newLineNumber.map { "\($0)" } ?? " "
        }
    }
    
    private var processedContent: String {
        var content = line.content
        
        if showWhitespace {
            content = content
                .replacingOccurrences(of: " ", with: "·")
                .replacingOccurrences(of: "\t", with: "→   ")
        }
        
        return content
    }
    
    private var lineBackgroundColor: Color {
        switch (side, line.type) {
        case (.old, .deletion):
            return AppTheme.diffDeletionBg
        case (.new, .addition):
            return AppTheme.diffAdditionBg
        default:
            return Color.clear
        }
    }
}

// MARK: - Supporting Views

struct DiffPaneHeader: View {
    let title: String
    let color: Color
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.textPrimary)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct HunkHeaderView: View {
    let hunk: DiffHunk
    let isSelected: Bool
    
    var body: some View {
        HStack {
            Text(hunk.header)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(AppTheme.accent)
            
            Spacer()
            
            // Stats
            HStack(spacing: 8) {
                if hunk.additions > 0 {
                    HStack(spacing: 2) {
                        Text("+\(hunk.additions)")
                            .foregroundColor(AppTheme.success)
                    }
                }
                
                if hunk.deletions > 0 {
                    HStack(spacing: 2) {
                        Text("-\(hunk.deletions)")
                            .foregroundColor(AppTheme.error)
                    }
                }
            }
            .font(.system(.caption, design: .monospaced))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isSelected ? AppTheme.accent.opacity(0.2) : AppTheme.accent.opacity(0.05))
    }
}

// MARK: - Advanced Features

/// Inline change highlighting within lines
struct InlineChangeHighlighter {
    /// Highlight character-level differences between two strings
    static func highlightDifferences(old: String, new: String) -> (AttributedString, AttributedString) {
        let oldChars = Array(old)
        let newChars = Array(new)
        
        // Use LCS (Longest Common Subsequence) for better diff
        let lcs = longestCommonSubsequence(oldChars, newChars)
        
        var oldAttr = AttributedString(old)
        var newAttr = AttributedString(new)
        
        // Highlight differences
        // TODO: Implement character-level highlighting
        
        return (oldAttr, newAttr)
    }
    
    /// Compute Longest Common Subsequence for character-level diff
    private static func longestCommonSubsequence<T: Equatable>(_ a: [T], _ b: [T]) -> [[Int]] {
        let m = a.count
        let n = b.count
        var lcs = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        for i in 1...m {
            for j in 1...n {
                if a[i-1] == b[j-1] {
                    lcs[i][j] = lcs[i-1][j-1] + 1
                } else {
                    lcs[i][j] = max(lcs[i-1][j], lcs[i][j-1])
                }
            }
        }
        
        return lcs
    }
}

// MARK: - Performance Optimizations

/// Virtual scrolling for large diffs (render only visible lines)
class DiffVirtualScroller: ObservableObject {
    @Published var visibleRange: Range<Int> = 0..<100
    
    let lineHeight: CGFloat = 20
    let bufferLines = 50 // Extra lines to render above/below viewport
    
    func updateVisibleRange(scrollOffset: CGFloat, viewportHeight: CGFloat, totalLines: Int) {
        let startLine = max(0, Int(scrollOffset / lineHeight) - bufferLines)
        let endLine = min(totalLines, Int((scrollOffset + viewportHeight) / lineHeight) + bufferLines)
        
        visibleRange = startLine..<endLine
    }
}
