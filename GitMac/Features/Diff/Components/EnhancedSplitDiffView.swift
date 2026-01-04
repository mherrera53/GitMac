import SwiftUI

// MARK: - Enhanced Split Diff View

/// High-performance split diff view with Kaleidoscope-style features
struct EnhancedSplitDiffView: View {
    let fileDiff: FileDiff
    @Binding var showHistory: Bool
    @Binding var showBlame: Bool
    @Binding var showMinimap: Bool
    
    @State private var selectedLines: Set<Int> = []
    @State private var scrollOffset: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var minimapScrollTrigger = UUID()
    
    @StateObject private var themeManager = ThemeManager.shared
    
    private let pairedLines: [DiffPairWithConnection]
    
    init(fileDiff: FileDiff, showHistory: Binding<Bool>, showBlame: Binding<Bool>, showMinimap: Binding<Bool>) {
        self.fileDiff = fileDiff
        self._showHistory = showHistory
        self._showBlame = showBlame
        self._showMinimap = showMinimap
        self.pairedLines = KaleidoscopePairingEngine.calculatePairs(from: fileDiff.hunks)
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Main diff view with minimap
                VStack(spacing: 0) {
                    // Toolbar
                    EnhancedDiffToolbar(
                        filename: fileDiff.displayPath,
                        additions: fileDiff.additions,
                        deletions: fileDiff.deletions,
                        showHistory: $showHistory,
                        showBlame: $showBlame,
                        showMinimap: $showMinimap,
                        onDiscardLines: discardSelectedLines
                    )
                    
                    // Split view with connection overlay
                    ZStack(alignment: .topLeading) {
                        // Base split view
                        KaleidoscopeSplitDiffView(
                            pairedLines: pairedLines,
                            showLineNumbers: true,
                            showConnectionLines: true,
                            isFluidMode: false,
                            scrollOffset: $scrollOffset,
                            viewportHeight: $viewportHeight,
                            contentHeight: $contentHeight,
                            minimapScrollTrigger: $minimapScrollTrigger
                        )
                        
                        // Connection overlay spanning both panes
                        if showMinimap {
                            ConnectionOverlay(
                                pairedLines: pairedLines,
                                viewportWidth: geometry.size.width - (showMinimap ? 120 : 0)
                            )
                        }
                    }
                }
                
                // Minimap
                if showMinimap {
                    Rectangle()
                        .fill(themeManager.currentTheme.border)
                        .frame(width: 1)
                    
                    DiffMinimap(
                        pairedLines: pairedLines,
                        scrollOffset: $scrollOffset,
                        viewportHeight: $viewportHeight,
                        contentHeight: $contentHeight,
                        minimapScrollTrigger: $minimapScrollTrigger
                    )
                    .frame(width: 120)
                }
            }
            
            // History/Blame overlay
            if showHistory || showBlame {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                EnhancedHistoryBlameView(
                    fileDiff: fileDiff,
                    showHistory: showHistory,
                    showBlame: showBlame,
                    onClose: {
                        showHistory = false
                        showBlame = false
                    }
                )
            }
        }
        .background(themeManager.currentTheme.background)
    }
    
    private func discardSelectedLines(_ lines: [DiffLine]) {
        // Implement discard logic using PatchManipulator
        print("Discarding \(lines.count) selected lines")
    }
}

// MARK: - Connection Overlay

/// Overlay that draws connection lines spanning both panes
struct ConnectionOverlay: View {
    let pairedLines: [DiffPairWithConnection]
    let viewportWidth: CGFloat
    
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        Canvas { context, size in
            let paneWidth = viewportWidth / 2
            
            for pair in pairedLines {
                if let connection = pair.connection {
                    // Draw bezier curve spanning both panes
                    var path = Path()
                    
                    let startY = CGFloat(pair.index) * 22
                    
                    // Start from left pane
                    path.move(to: CGPoint(x: paneWidth - 2, y: startY))
                    
                    // Control points for smooth curve
                    let midX = paneWidth
                    let controlY1 = startY + 5
                    let controlY2 = startY - 5
                    
                    path.addCurve(
                        to: CGPoint(x: paneWidth + 2, y: startY),
                        control1: CGPoint(x: midX, y: controlY1),
                        control2: CGPoint(x: midX, y: controlY2)
                    )
                    
                    // Style based on connection type
                    let color: Color
                    let lineWidth: CGFloat
                    
                    switch connection {
                    case .addition:
                        color = themeManager.currentTheme.diff.addition
                        lineWidth = 2
                    case .deletion:
                        color = themeManager.currentTheme.diff.deletion
                        lineWidth = 2
                    case .modification:
                        color = themeManager.currentTheme.diff.modification
                        lineWidth = 3
                    }
                    
                    context.stroke(
                        path,
                        with: .color(color.opacity(0.6)),
                        lineWidth: lineWidth
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Enhanced History/Blame View

/// Unified view for history and blame with diff visualization
struct EnhancedHistoryBlameView: View {
    let fileDiff: FileDiff
    let showHistory: Bool
    let showBlame: Bool
    let onClose: () -> Void
    
    @State private var selectedCommit: Commit?
    @State private var commits: [Commit] = []
    
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(themeManager.currentTheme.textSecondary)
                }
                
                Spacer()
                
                Text(showHistory ? "History" : "Blame")
                    .font(.headline)
                    .foregroundColor(themeManager.currentTheme.text)
                
                Spacer()
                
                // Toggle between history and blame
                Picker("Mode", selection: showHistory ? .constant(true) : .constant(false)) {
                    Text("History").tag(true)
                    Text("Blame").tag(false)
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 200)
            }
            .padding()
            .background(themeManager.currentTheme.backgroundSecondary)
            
            // Content
            HSplitView {
                // List view
                VStack {
                    if showHistory {
                        List(commits, id: \.id, selection: $selectedCommit) { commit in
                            CommitRowView(commit: commit)
                        }
                    } else {
                        BlameListView(path: fileDiff.newPath)
                    }
                }
                .frame(minWidth: 300)
                
                // Diff view
                if let commit = selectedCommit {
                    VStack {
                        Text("Changes in \(commit.hash.prefix(8))")
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.textSecondary)
                        
                        // Show diff for selected commit
                        KaleidoscopeDiffView(
                            files: [fileDiff],
                            commits: [commit],
                            selectedCommitA: .constant(commit),
                            selectedCommitB: .constant(nil)
                        )
                    }
                } else {
                    VStack {
                        Text("Select a commit to view changes")
                            .foregroundColor(themeManager.currentTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(width: 1000, height: 700)
        .background(themeManager.currentTheme.background)
        .cornerRadius(12)
        .shadow(radius: 20)
    }
}

// MARK: - Support Views

struct CommitRowView: View {
    let commit: Commit
    
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(commit.message)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(themeManager.currentTheme.text)
            
            HStack {
                Text(commit.hash.prefix(8))
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.textSecondary)
                
                Spacer()
                
                Text(commit.author)
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.textSecondary)
                
                Text(commit.date, style: .relative)
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct BlameListView: View {
    let path: String
    
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        List {
            Text("Blame information for \(path)")
                .foregroundColor(themeManager.currentTheme.textSecondary)
        }
    }
}
