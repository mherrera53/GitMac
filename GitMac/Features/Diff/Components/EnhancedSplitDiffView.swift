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

    private let pairedLines: [DiffPairWithConnection]
    private let hunksById: [UUID: DiffHunk]

    init(fileDiff: FileDiff, showHistory: Binding<Bool>, showBlame: Binding<Bool>, showMinimap: Binding<Bool>) {
        self.fileDiff = fileDiff
        self._showHistory = showHistory
        self._showBlame = showBlame
        self._showMinimap = showMinimap
        self.pairedLines = KaleidoscopePairingEngine.calculatePairs(from: fileDiff.hunks)

        // Build hunksById dictionary
        var hunks: [UUID: DiffHunk] = [:]
        for hunk in fileDiff.hunks {
            hunks[hunk.id] = hunk
        }
        self.hunksById = hunks
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
                            filePath: fileDiff.newPath,
                            hunksById: hunksById,
                            repoPath: nil,
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

                // Minimap placeholder - will show change indicators
                if showMinimap {
                    Rectangle()
                        .fill(AppTheme.border)
                        .frame(width: 1)

                    EnhancedDiffMinimap(
                        pairedLines: pairedLines,
                        scrollOffset: $scrollOffset,
                        viewportHeight: viewportHeight,
                        contentHeight: contentHeight
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
        .background(AppTheme.background)
    }

    private func discardSelectedLines(_ lines: [DiffLine]) {
        // TODO: Implement discard logic using PatchManipulator
    }
}

// MARK: - Enhanced Diff Minimap

/// Simple minimap showing change locations
struct EnhancedDiffMinimap: View {
    let pairedLines: [DiffPairWithConnection]
    @Binding var scrollOffset: CGFloat
    let viewportHeight: CGFloat
    let contentHeight: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let scale = geometry.size.height / max(contentHeight, 1)

            ZStack(alignment: .topLeading) {
                // Background
                Rectangle()
                    .fill(AppTheme.backgroundSecondary)

                // Change indicators
                ForEach(pairedLines) { pair in
                    let yPos = CGFloat(pair.id) * 2 * scale

                    if pair.connectionType != .none {
                        Rectangle()
                            .fill(colorForConnection(pair.connectionType))
                            .frame(width: geometry.size.width, height: max(2, 4 * scale))
                            .offset(y: yPos)
                    }
                }

                // Viewport indicator
                Rectangle()
                    .fill(AppTheme.accent.opacity(0.3))
                    .frame(width: geometry.size.width, height: viewportHeight * scale)
                    .offset(y: scrollOffset * scale)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { location in
            // Jump to location in diff
        }
    }

    private func colorForConnection(_ type: ConnectionType) -> Color {
        switch type {
        case .addition:
            return AppTheme.success
        case .deletion:
            return AppTheme.error
        case .change:
            return AppTheme.warning
        case .none:
            return .clear
        }
    }
}

// MARK: - Connection Overlay

/// Overlay that draws connection lines spanning both panes
struct ConnectionOverlay: View {
    let pairedLines: [DiffPairWithConnection]
    let viewportWidth: CGFloat

    var body: some View {
        Canvas { context, size in
            let paneWidth = viewportWidth / 2

            for pair in pairedLines {
                if pair.connectionType != .none {
                    // Draw bezier curve spanning both panes
                    var path = Path()

                    let startY = CGFloat(pair.id) * 22

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

                    switch pair.connectionType {
                    case .addition:
                        color = AppTheme.success
                        lineWidth = 2
                    case .deletion:
                        color = AppTheme.error
                        lineWidth = 2
                    case .change:
                        color = AppTheme.warning
                        lineWidth = 3
                    case .none:
                        color = .clear
                        lineWidth = 0
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

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                }

                Spacer()

                Text(showHistory ? "History" : "Blame")
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)

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
            .background(AppTheme.backgroundSecondary)

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
                        Text("Changes in \(commit.shortSHA)")
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)

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
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(width: 1000, height: 700)
        .background(AppTheme.background)
        .cornerRadius(12)
        .shadow(radius: 20)
    }
}

// MARK: - Support Views

struct CommitRowView: View {
    let commit: Commit

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(commit.message)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(AppTheme.textPrimary)

            HStack {
                Text(commit.shortSHA)
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)

                Spacer()

                Text(commit.author)
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)

                Text(commit.authorDate, style: .relative)
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct BlameListView: View {
    let path: String

    var body: some View {
        List {
            Text("Blame information for \(path)")
                .foregroundColor(AppTheme.textSecondary)
        }
    }
}
