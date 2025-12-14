import SwiftUI
import AppKit

// MARK: - Tiled Diff View (NSView with Direct Drawing)

/// High-performance diff view using NSView with direct CoreText drawing
/// Optimized for very large files (50k–500k+ lines) with constant-height lines
class TiledDiffView: NSView {
    // MARK: - Properties
    
    var hunks: [DiffHunk] = [] {
        didSet {
            updateMetrics()
            needsDisplay = true
        }
    }
    
    var showLineNumbers: Bool = true {
        didSet { needsDisplay = true }
    }
    
    var isLFMActive: Bool = false
    
    private let lineHeight: CGFloat = 22
    private let gutterWidth: CGFloat = 100  // For line numbers
    private let contentInset: CGFloat = 8
    
    private var totalLines: Int = 0
    private var flatLines: [FlatLine] = []  // Flattened representation
    
    // Colors
    private let additionBg = NSColor.systemGreen.withAlphaComponent(0.15)
    private let additionFg = NSColor.systemGreen
    private let deletionBg = NSColor.systemRed.withAlphaComponent(0.15)
    private let deletionFg = NSColor.systemRed
    private let hunkBg = NSColor.systemBlue.withAlphaComponent(0.1)
    private let hunkFg = NSColor.systemBlue
    private let contextFg = NSColor.textColor
    private let lineNumberFg = NSColor.secondaryLabelColor
    
    // Font
    private let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    private let lineNumberFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
    
    // MARK: - Initialization
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
    }
    
    // MARK: - Layout
    
    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: CGFloat(totalLines) * lineHeight)
    }
    
    override func updateLayer() {
        super.updateLayer()
        layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
    }
    
    // MARK: - Drawing
    
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // Calculate visible line range (O(1) thanks to constant height)
        let firstLine = max(0, Int(dirtyRect.minY / lineHeight))
        let lastLine = min(totalLines, Int(dirtyRect.maxY / lineHeight) + 1)
        
        // Draw only visible lines
        for lineIndex in firstLine..<lastLine {
            guard lineIndex < flatLines.count else { break }
            
            let flatLine = flatLines[lineIndex]
            let y = CGFloat(lineIndex) * lineHeight
            let lineRect = NSRect(x: 0, y: y, width: bounds.width, height: lineHeight)
            
            drawLine(flatLine, in: lineRect, context: context)
        }
    }
    
    private func drawLine(_ flatLine: FlatLine, in rect: NSRect, context: CGContext) {
        // Background
        let bgColor: NSColor
        switch flatLine.type {
        case .addition: bgColor = additionBg
        case .deletion: bgColor = deletionBg
        case .hunkHeader: bgColor = hunkBg
        case .context: bgColor = .clear
        }
        
        if bgColor != .clear {
            context.setFillColor(bgColor.cgColor)
            context.fill(rect)
        }
        
        // Line numbers
        if showLineNumbers && flatLine.type != .hunkHeader {
            let oldNum = flatLine.oldLineNumber.map { String(format: "%4d", $0) } ?? "    "
            let newNum = flatLine.newLineNumber.map { String(format: "%4d", $0) } ?? "    "
            let lineNumText = "\(oldNum) \(newNum)"
            
            let attrs: [NSAttributedString.Key: Any] = [
                .font: lineNumberFont,
                .foregroundColor: lineNumberFg
            ]
            
            let lineNumRect = NSRect(
                x: contentInset,
                y: rect.minY + 4,
                width: gutterWidth - contentInset * 2,
                height: lineHeight
            )
            
            lineNumText.draw(in: lineNumRect, withAttributes: attrs)
        }
        
        // Content
        let textColor: NSColor
        switch flatLine.type {
        case .addition: textColor = additionFg
        case .deletion: textColor = deletionFg
        case .hunkHeader: textColor = hunkFg
        case .context: textColor = contextFg
        }
        
        let prefix: String
        switch flatLine.type {
        case .addition: prefix = "+"
        case .deletion: prefix = "-"
        case .context: prefix = " "
        case .hunkHeader: prefix = ""
        }
        
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor
        ]
        
        let contentX = showLineNumbers ? gutterWidth : contentInset
        let contentText = prefix + flatLine.content
        let contentRect = NSRect(
            x: contentX + contentInset,
            y: rect.minY + 4,
            width: rect.width - contentX - contentInset * 2,
            height: lineHeight
        )
        
        contentText.draw(in: contentRect, withAttributes: attrs)
    }
    
    // MARK: - Metrics
    
    private func updateMetrics() {
        // Flatten hunks into lines for O(1) access
        flatLines = []
        
        for hunk in hunks {
            // Add hunk header
            flatLines.append(FlatLine(
                type: .hunkHeader,
                content: hunk.header,
                oldLineNumber: nil,
                newLineNumber: nil
            ))
            
            // Add lines
            for line in hunk.lines {
                flatLines.append(FlatLine(
                    type: line.type,
                    content: line.content,
                    oldLineNumber: line.oldLineNumber,
                    newLineNumber: line.newLineNumber
                ))
            }
        }
        
        totalLines = flatLines.count
        invalidateIntrinsicContentSize()
    }
    
    // MARK: - Interaction
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}

// MARK: - Flat Line Model

/// Flattened line representation for fast access
private struct FlatLine {
    let type: DiffLineType
    let content: String
    let oldLineNumber: Int?
    let newLineNumber: Int?
}

// MARK: - SwiftUI Wrapper

/// SwiftUI wrapper for TiledDiffView
struct TiledDiffViewRepresentable: NSViewRepresentable {
    let hunks: [DiffHunk]
    let showLineNumbers: Bool
    let isLFMActive: Bool
    
    func makeNSView(context: Context) -> NSScrollView {
        let diffView = TiledDiffView()
        diffView.showLineNumbers = showLineNumbers
        diffView.isLFMActive = isLFMActive
        diffView.hunks = hunks
        
        let scrollView = NSScrollView()
        scrollView.documentView = diffView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = .textBackgroundColor
        
        // Enable layer-backed scrolling for performance
        scrollView.wantsLayer = true
        scrollView.contentView.wantsLayer = true
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let diffView = scrollView.documentView as? TiledDiffView else { return }
        
        diffView.showLineNumbers = showLineNumbers
        diffView.isLFMActive = isLFMActive
        
        // Only update if hunks actually changed
        if diffView.hunks.count != hunks.count {
            diffView.hunks = hunks
        }
    }
}

// MARK: - Optimized Diff View with Auto LFM

/// Automatically chooses between rich and tiled diff view based on file size
struct OptimizedDiffView: View {
    let fileDiff: FileDiff
    let options: DiffOptions
    let state: DiffState
    
    @State private var viewMode: DiffViewMode = .split
    @State private var showLineNumbers = true
    
    private var shouldUseTiledView: Bool {
        state.isLFMActive || totalLines > 10_000
    }
    
    private var totalLines: Int {
        fileDiff.hunks.reduce(0) { $0 + $1.lines.count }
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
                wordWrap: .constant(false),
                isMarkdown: false,
                showMinimap: .constant(false)
            )
            
            Divider()
            
            // Status bar with LFM indicator
            if state.isLFMActive || !state.degradations.isEmpty {
                DiffStatusBar(state: state)
                Divider()
            }
            
            // Content
            Group {
                if shouldUseTiledView {
                    // Use tiled view for large files
                    TiledDiffViewRepresentable(
                        hunks: fileDiff.hunks,
                        showLineNumbers: showLineNumbers,
                        isLFMActive: state.isLFMActive
                    )
                } else {
                    // Use rich diff view for normal files
                    switch viewMode {
                    case .split:
                        OptimizedSplitDiffView(
                            hunks: fileDiff.hunks,
                            showLineNumbers: showLineNumbers,
                            scrollOffset: .constant(0),
                            viewportHeight: .constant(400)
                        )
                    case .inline:
                        OptimizedInlineDiffView(
                            hunks: fileDiff.hunks,
                            showLineNumbers: showLineNumbers,
                            scrollOffset: .constant(0),
                            viewportHeight: .constant(400)
                        )
                    case .hunk:
                        HunkDiffView(hunks: fileDiff.hunks, showLineNumbers: showLineNumbers)
                    case .preview:
                        Text("Preview not available")
                    }
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}

// MARK: - Diff Status Bar

struct DiffStatusBar: View {
    let state: DiffState
    
    var body: some View {
        HStack(spacing: 16) {
            // LFM indicator
            if state.isLFMActive {
                Label("Large File Mode", systemImage: "bolt.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(4)
            }
            
            // Degradations
            ForEach(state.degradations) { degradation in
                Label(degradation.description, systemImage: degradation.icon)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .help(degradation.reason)
            }
            
            Spacer()
            
            // Performance metrics
            HStack(spacing: 12) {
                if state.parseTimeSeconds > 0 {
                    Text("Parse: \(state.parseTimeSeconds, specifier: "%.2f")s")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if state.memoryUsageBytes > 0 {
                    Text("Memory: \(ByteCountFormatter.string(fromByteCount: Int64(state.memoryUsageBytes), countStyle: .memory))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("\(state.materializedHunks)/\(state.totalHunks) hunks")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
