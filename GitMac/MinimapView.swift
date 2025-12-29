import SwiftUI

/// Minimap View - Visual overview for large files (like Sublime Text)
/// Shows the entire file with color-coded changes
struct MinimapView: View {
    let hunks: [DiffHunk]
    let totalLines: Int
    @Binding var scrollPosition: CGFloat
    let contentHeight: CGFloat
    
    @State private var isHovered = false
    
    private let minimapWidth: CGFloat = 100
    private let lineHeight: CGFloat = 2 // Condensed line height in minimap
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Background
                Color(nsColor: .controlBackgroundColor)
                    .opacity(0.9)
                
                // Minimap content
                minimapContent(geometry: geometry)
                
                // Viewport indicator
                viewportIndicator(geometry: geometry)
                
                // Hover overlay
                if isHovered {
                    AppTheme.shadow.opacity(0.1)
                }
            }
            .frame(width: minimapWidth)
            .onHover { isHovered = $0 }
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleClick(at: value.location, in: geometry)
                    }
            )
        }
    }
    
    // MARK: - Minimap Content
    
    private func minimapContent(geometry: GeometryProxy) -> some View {
        Canvas { context, size in
            // Draw all lines
            let minimapHeight = geometry.size.height
            let scale = minimapHeight / CGFloat(totalLines * 20) // Assuming 20px per line in main view
            
            for hunk in hunks {
                for (index, line) in hunk.lines.enumerated() {
                    let lineNumber = hunk.oldStart + index
                    let y = CGFloat(lineNumber) * lineHeight * scale
                    
                    let color = lineColor(for: line.type)
                    let rect = CGRect(x: 0, y: y, width: size.width, height: lineHeight * scale)
                    
                    context.fill(
                        Path(rect),
                        with: .color(color)
                    )
                }
            }
        }
    }
    
    // MARK: - Viewport Indicator
    
    private func viewportIndicator(geometry: GeometryProxy) -> some View {
        let minimapHeight = geometry.size.height
        let scale = minimapHeight / contentHeight
        let viewportHeight = geometry.size.height * scale
        let viewportY = scrollPosition * scale
        
        return Rectangle()
            .fill(AppTheme.accent.opacity(0.3))
            .frame(width: minimapWidth, height: viewportHeight)
            .offset(y: viewportY)
            .overlay(
                Rectangle()
                    .stroke(AppTheme.accent, lineWidth: 1)
            )
    }
    
    // MARK: - Helpers
    
    @MainActor
    private func lineColor(for type: DiffLineType) -> Color {
        switch type {
        case .addition:
            return AppTheme.success.opacity(0.6)
        case .deletion:
            return AppTheme.error.opacity(0.6)
        case .context:
            return AppTheme.textMuted.opacity(0.2)
        case .hunkHeader:
            return AppTheme.accent.opacity(0.4)
        }
    }
    
    private func handleClick(at location: CGPoint, in geometry: GeometryProxy) {
        let minimapHeight = geometry.size.height
        let scale = contentHeight / minimapHeight
        let targetScroll = location.y * scale
        
        scrollPosition = min(max(targetScroll, 0), contentHeight - geometry.size.height)
    }
}

// MARK: - Minimap with Scroll View Integration

struct DiffViewWithMinimap: View {
    let filePath: String
    let hunks: [DiffHunk]
    
    @State private var scrollPosition: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var showMinimap = true
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Main diff view
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(hunks) { hunk in
                                HunkView(hunk: hunk)
                                    .id(hunk.id)
                            }
                        }
                        .background(
                            GeometryReader { contentGeometry in
                                Color.clear
                                    .preference(
                                        key: ContentHeightPreferenceKey.self,
                                        value: contentGeometry.size.height
                                    )
                            }
                        )
                    }
                    .coordinateSpace(name: "scroll")
                }
                .onPreferenceChange(ContentHeightPreferenceKey.self) { height in
                    contentHeight = height
                }
                
                // Minimap
                if showMinimap {
                    Divider()
                    
                    MinimapView(
                        hunks: hunks,
                        totalLines: totalLines,
                        scrollPosition: $scrollPosition,
                        contentHeight: contentHeight
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        showMinimap.toggle()
                    } label: {
                        Image(systemName: showMinimap ? "sidebar.right" : "sidebar.right.slash")
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .help(showMinimap ? "Hide Minimap" : "Show Minimap")
                }
            }
        }
    }
    
    private var totalLines: Int {
        hunks.reduce(0) { $0 + $1.lines.count }
    }
}

// MARK: - Preference Keys

struct ContentHeightPreferenceKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Enhanced Minimap with More Features

struct AdvancedMinimapView: View {
    let hunks: [DiffHunk]
    let totalLines: Int
    @Binding var scrollPosition: CGFloat
    let contentHeight: CGFloat
    
    @State private var isHovered = false
    @State private var hoveredLine: Int?
    @State private var showTooltip = false
    
    private let minimapWidth: CGFloat = 120
    private let lineHeight: CGFloat = 1.5
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Background with gradient
                LinearGradient(
                    colors: [
                        Color(nsColor: .controlBackgroundColor).opacity(0.95),
                        Color(nsColor: .controlBackgroundColor).opacity(0.85)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                
                // Minimap layers
                ZStack(alignment: .topLeading) {
                    // Base code visualization
                    codeVisualization(geometry: geometry)
                    
                    // Change highlights
                    changeHighlights(geometry: geometry)
                    
                    // Hunk boundaries
                    hunkBoundaries(geometry: geometry)
                    
                    // Viewport indicator
                    viewportIndicator(geometry: geometry)
                    
                    // Hover tooltip
                    if showTooltip, let line = hoveredLine {
                        tooltipView(for: line)
                            .offset(x: minimapWidth + 10, y: CGFloat(line) * lineHeight)
                    }
                }
                
                // Border
                Rectangle()
                    .stroke(AppTheme.textSecondary.opacity(0.3), lineWidth: 1)
            }
            .frame(width: minimapWidth)
            .onHover { isHovered = $0 }
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleInteraction(at: value.location, in: geometry)
                    }
            )
        }
    }

    // MARK: - Code Visualization
    
    private func codeVisualization(geometry: GeometryProxy) -> some View {
        Canvas { context, size in
            let minimapHeight = geometry.size.height
            
            // Draw simplified code structure
            for i in 0..<totalLines {
                let y = CGFloat(i) * lineHeight
                
                if y > minimapHeight { break }
                
                // Vary opacity to simulate code density
                let opacity = Double.random(in: 0.05...0.15)
                let color = AppTheme.textMuted.opacity(opacity)
                
                let rect = CGRect(
                    x: 10,
                    y: y,
                    width: size.width - 20,
                    height: lineHeight
                )
                
                context.fill(
                    Path(rect),
                    with: .color(color)
                )
            }
        }
    }
    
    // MARK: - Change Highlights
    
    private func changeHighlights(geometry: GeometryProxy) -> some View {
        Canvas { context, size in
            for hunk in hunks {
                for (index, line) in hunk.lines.enumerated() {
                    let lineNumber = hunk.oldStart + index
                    let y = CGFloat(lineNumber) * lineHeight
                    
                    guard line.type != .context else { continue }
                    
                    let color = changeColor(for: line.type)
                    let rect = CGRect(
                        x: 0,
                        y: y,
                        width: size.width,
                        height: lineHeight * 2 // Slightly taller for visibility
                    )
                    
                    context.fill(
                        Path(rect),
                        with: .color(color)
                    )
                }
            }
        }
    }
    
    // MARK: - Hunk Boundaries
    
    private func hunkBoundaries(geometry: GeometryProxy) -> some View {
        Canvas { context, size in
            for hunk in hunks {
                let y = CGFloat(hunk.oldStart) * lineHeight
                
                // Draw horizontal line at hunk start
                let path = Path { p in
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: size.width, y: y))
                }
                
                context.stroke(
                    path,
                    with: .color(AppTheme.accent.opacity(0.5)),
                    lineWidth: 1
                )
            }
        }
    }
    
    // MARK: - Viewport Indicator
    
    private func viewportIndicator(geometry: GeometryProxy) -> some View {
        let minimapHeight = geometry.size.height
        let scale = minimapHeight / contentHeight
        let viewportHeight = max(geometry.size.height * scale, 20) // Minimum 20px
        let viewportY = scrollPosition * scale
        
        return RoundedRectangle(cornerRadius: 4)
            .fill(AppTheme.accent.opacity(0.2))
            .frame(width: minimapWidth - 4, height: viewportHeight)
            .offset(x: 2, y: viewportY)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(AppTheme.accent.opacity(0.6), lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.2), radius: 2)
    }
    
    // MARK: - Tooltip
    
    private func tooltipView(for line: Int) -> some View {
        let hunk = hunkAt(line: line)
        
        return VStack(alignment: .leading, spacing: 4) {
            Text("Line \(line)")
                .font(.caption)
                .fontWeight(.bold)
            
            if let hunk = hunk {
                Text(hunk.header)
                    .font(.system(size: 10, design: .monospaced))
                    .lineLimit(1)
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(radius: 4)
        )
    }
    
    // MARK: - Helpers
    
    private func changeColor(for type: DiffLineType) -> Color {
        switch type {
        case .addition:
            return AppTheme.success.opacity(0.7)
        case .deletion:
            return AppTheme.error.opacity(0.7)
        case .context:
            return Color.clear
        case .hunkHeader:
            return AppTheme.accent.opacity(0.5)
        }
    }
    
    private func handleInteraction(at location: CGPoint, in geometry: GeometryProxy) {
        // Update scroll position
        let minimapHeight = geometry.size.height
        let scale = contentHeight / minimapHeight
        let targetScroll = location.y * scale
        
        scrollPosition = min(max(targetScroll, 0), contentHeight - geometry.size.height)
        
        // Update hovered line
        let line = Int(location.y / lineHeight)
        hoveredLine = line
        showTooltip = true
    }
    
    private func hunkAt(line: Int) -> DiffHunk? {
        for hunk in hunks {
            let start = hunk.oldStart
            let end = start + hunk.lines.count
            
            if line >= start && line < end {
                return hunk
            }
        }
        
        return nil
    }
}

// MARK: - Minimap Settings

struct MinimapSettings: Codable {
    var enabled: Bool = true
    var width: CGFloat = 100
    var showCodeStructure: Bool = true
    var showHunkBoundaries: Bool = true
    var highlightCurrentLine: Bool = true
    
    static let `default` = MinimapSettings()
}

// MARK: - Minimap Integration Example

struct DiffViewerWithFullFeatures: View {
    let filePath: String
    let hunks: [DiffHunk]
    
    @State private var scrollPosition: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var minimapSettings = MinimapSettings.default
    @State private var selectedHunk: DiffHunk?
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            diffToolbar
            
            Divider()
            
            // Content with minimap
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // Main diff view
                    mainDiffView
                    
                    // Minimap
                    if minimapSettings.enabled {
                        Divider()
                        
                        AdvancedMinimapView(
                            hunks: hunks,
                            totalLines: totalLines,
                            scrollPosition: $scrollPosition,
                            contentHeight: contentHeight
                        )
                        .frame(width: minimapSettings.width)
                    }
                }
            }
        }
    }
    
    private var diffToolbar: some View {
        HStack {
            Text(filePath)
                .font(.headline)
            
            Spacer()
            
            // Stats
            DiffStatsView(
                additions: totalAdditions,
                deletions: totalDeletions
            )
            
            // Minimap toggle
            Button {
                withAnimation {
                    minimapSettings.enabled.toggle()
                }
            } label: {
                Image(systemName: minimapSettings.enabled ? "sidebar.right" : "sidebar.right.slash")
                    .foregroundColor(AppTheme.textSecondary)
            }
            .buttonStyle(.borderless)
            .help("Toggle Minimap")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    private var mainDiffView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(hunks) { hunk in
                    HunkView(hunk: hunk)
                        .onTapGesture {
                            selectedHunk = hunk
                        }
                }
            }
            .background(
                GeometryReader { contentGeometry in
                    Color.clear
                        .preference(
                            key: ContentHeightPreferenceKey.self,
                            value: contentGeometry.size.height
                        )
                }
            )
        }
        .onPreferenceChange(ContentHeightPreferenceKey.self) { height in
            contentHeight = height
        }
    }
    
    private var totalLines: Int {
        hunks.reduce(0) { $0 + $1.lines.count }
    }
    
    private var totalAdditions: Int {
        hunks.reduce(0) { $0 + $1.lines.filter { $0.type == .addition }.count }
    }

    private var totalDeletions: Int {
        hunks.reduce(0) { $0 + $1.lines.filter { $0.type == .deletion }.count }
    }
}

// MARK: - Simple Hunk View (placeholder)

struct HunkView: View {
    let hunk: DiffHunk
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hunk header
            Text(hunk.header)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(AppTheme.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.accent.opacity(0.05))
            
            // Lines
            ForEach(hunk.lines) { line in
                HStack(spacing: 0) {
                    Text(line.content)
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(lineBackground(for: line.type))
            }
        }
    }
    
    private func lineBackground(for type: DiffLineType) -> Color {
        switch type {
        case .addition:
            return AppTheme.success.opacity(0.1)
        case .deletion:
            return AppTheme.error.opacity(0.1)
        case .context:
            return Color.clear
        case .hunkHeader:
            return AppTheme.accent.opacity(0.1)
        }
    }
}
