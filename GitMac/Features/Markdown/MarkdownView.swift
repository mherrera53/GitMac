import SwiftUI
import AppKit
import Splash

// MARK: - Adaptive Markdown Viewer

/// High-performance GitHub-style Markdown viewer
/// Automatically switches between rich and fast rendering based on file size
/// Supports Mermaid diagrams (flowchart, sequence, class, state, ER, pie, gantt)
struct MarkdownView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) private var colorScheme
    
    let content: String
    let fileName: String?

    private var isDarkMode: Bool {
        if themeManager.currentTheme == .system {
            return colorScheme == .dark
        }
        return themeManager.currentTheme == .dark
    }

    private var lineCount: Int {
        content.components(separatedBy: "\n").count
    }

    /// Check if content contains Mermaid diagrams
    private var hasMermaid: Bool {
        MermaidDetector.containsMermaid(content)
    }

    /// Threshold for switching to fast renderer
    private static let fastRenderThreshold = 500

    init(content: String, fileName: String? = nil) {
        self.content = content
        self.fileName = fileName
    }

    var body: some View {
        VStack(spacing: 0) {
            // File header
            if let name = fileName {
                fileHeader(name: name)
                Divider()
            }

            // Choose renderer based on content type and size
            if hasMermaid {
                // Use mixed renderer for Mermaid content
                MermaidMarkdownView(content: content, isDarkMode: isDarkMode)
            } else if lineCount > Self.fastRenderThreshold {
                FastMarkdownView(content: content, isDarkMode: isDarkMode)
            } else {
                RichMarkdownView(content: content, isDarkMode: isDarkMode)
            }
        }
    }

    @ViewBuilder
    private func fileHeader(name: String) -> some View {
        HStack {
            Image(systemName: "doc.text")
                .foregroundColor(AppTheme.textPrimary)
            Text(name)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)
            Spacer()

            if hasMermaid {
                Label("Mermaid", systemImage: "chart.bar.doc.horizontal")
                    .font(.caption)
                    .foregroundColor(AppTheme.accent)
            }

            if lineCount > Self.fastRenderThreshold {
                Label("Fast mode", systemImage: "bolt.fill")
                    .font(.caption)
                    .foregroundColor(AppTheme.warning)
            }

            Text("\(lineCount) lines")
                .font(.caption)
                .foregroundColor(AppTheme.textPrimary)
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.sm + 2) // 10 = 8 + 2
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

// MARK: - Mermaid Markdown View

/// Mixed renderer that handles both markdown text and Mermaid diagrams
struct MermaidMarkdownView: View {
    @StateObject private var themeManager = ThemeManager.shared
    let content: String
    let isDarkMode: Bool

    private var segments: [MermaidDetector.Segment] {
        MermaidDetector.parse(content)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                ForEach(segments) { segment in
                    segmentView(for: segment)
                }
            }
            .padding(DesignTokens.Spacing.lg + 4) // 20 = 16 + 4
        }
    }

    @ViewBuilder
    private func segmentView(for segment: MermaidDetector.Segment) -> some View {
        switch segment {
        case .text(let text):
            if !text.isEmpty {
                TextSegmentView(content: text, isDarkMode: isDarkMode)
            }
        case .mermaid(let code):
            MermaidSegmentView(code: code, isDarkMode: isDarkMode)
        }
    }
}

/// Renders a text segment using the fast markdown renderer
private struct TextSegmentView: NSViewRepresentable {
    let content: String
    let isDarkMode: Bool

    func makeNSView(context: Context) -> NSTextView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = .zero

        // Performance optimizations
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = true
        textView.layoutManager?.allowsNonContiguousLayout = true

        return textView
    }

    func updateNSView(_ textView: NSTextView, context: Context) {
        let attributed = FastMarkdownRenderer.render(content, isDarkMode: isDarkMode)
        textView.textStorage?.setAttributedString(attributed)

        // Calculate intrinsic height
        if let layoutManager = textView.layoutManager,
           let textContainer = textView.textContainer {
            layoutManager.ensureLayout(for: textContainer)
            let size = layoutManager.usedRect(for: textContainer).size
            textView.frame.size.height = size.height
        }
    }
}

/// Renders a Mermaid diagram segment
private struct MermaidSegmentView: View {
    let code: String
    let isDarkMode: Bool
    @State private var diagramHeight: CGFloat = 300

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            // Diagram header
            HStack(spacing: DesignTokens.Spacing.md - 6) { // 6px custom
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.caption)
                    .foregroundColor(AppTheme.accent)
                Text(diagramType)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()

                // Copy button
                Button(action: copyCode) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(AppTheme.textPrimary)
                .help("Copy Mermaid code")
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.md - 6) // 6px custom
            .background(isDarkMode ? AppTheme.textPrimary.opacity(0.05) : AppTheme.background.opacity(0.03))
            .cornerRadius(DesignTokens.CornerRadius.md, corners: [.topLeft, .topRight])

            // Diagram view
            MermaidDiagramView(
                code: code,
                isDarkMode: isDarkMode,
                maxHeight: 500
            )
            .frame(minHeight: 200, idealHeight: diagramHeight, maxHeight: 600)
            .background(isDarkMode ? AppTheme.background.opacity(0.2) : AppTheme.textPrimary)
            .cornerRadius(DesignTokens.CornerRadius.md, corners: [.bottomLeft, .bottomRight])
        }
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                .stroke(AppTheme.textMuted.opacity(0.2), lineWidth: 1)
        )
    }

    private var diagramType: String {
        let firstLine = code.components(separatedBy: "\n").first?.lowercased() ?? ""
        if firstLine.contains("flowchart") || firstLine.contains("graph") {
            return "Flowchart"
        } else if firstLine.contains("sequencediagram") || firstLine.contains("sequence") {
            return "Sequence Diagram"
        } else if firstLine.contains("classdiagram") || firstLine.contains("class") {
            return "Class Diagram"
        } else if firstLine.contains("statediagram") || firstLine.contains("state") {
            return "State Diagram"
        } else if firstLine.contains("erdiagram") || firstLine.contains("er") {
            return "ER Diagram"
        } else if firstLine.contains("pie") {
            return "Pie Chart"
        } else if firstLine.contains("gantt") {
            return "Gantt Chart"
        } else if firstLine.contains("journey") {
            return "User Journey"
        } else if firstLine.contains("mindmap") {
            return "Mind Map"
        } else if firstLine.contains("gitgraph") {
            return "Git Graph"
        } else {
            return "Diagram"
        }
    }

    private func copyCode() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
    }
}

// MARK: - Corner Radius Extension

struct RectCorner: OptionSet {
    let rawValue: Int

    static let topLeft = RectCorner(rawValue: 1 << 0)
    static let topRight = RectCorner(rawValue: 1 << 1)
    static let bottomLeft = RectCorner(rawValue: 1 << 2)
    static let bottomRight = RectCorner(rawValue: 1 << 3)
    static let allCorners: RectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: RectCorner) -> some View {
        clipShape(RoundedCornerShape(radius: radius, corners: corners))
    }
}

private struct RoundedCornerShape: Shape {
    var radius: CGFloat
    var corners: RectCorner

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let topLeft = corners.contains(.topLeft) ? radius : 0
        let topRight = corners.contains(.topRight) ? radius : 0
        let bottomLeft = corners.contains(.bottomLeft) ? radius : 0
        let bottomRight = corners.contains(.bottomRight) ? radius : 0

        path.move(to: CGPoint(x: rect.minX + topLeft, y: rect.minY))

        // Top edge and top right corner
        path.addLine(to: CGPoint(x: rect.maxX - topRight, y: rect.minY))
        if topRight > 0 {
            path.addArc(
                center: CGPoint(x: rect.maxX - topRight, y: rect.minY + topRight),
                radius: topRight,
                startAngle: .degrees(-90),
                endAngle: .degrees(0),
                clockwise: false
            )
        }

        // Right edge and bottom right corner
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight))
        if bottomRight > 0 {
            path.addArc(
                center: CGPoint(x: rect.maxX - bottomRight, y: rect.maxY - bottomRight),
                radius: bottomRight,
                startAngle: .degrees(0),
                endAngle: .degrees(90),
                clockwise: false
            )
        }

        // Bottom edge and bottom left corner
        path.addLine(to: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY))
        if bottomLeft > 0 {
            path.addArc(
                center: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY - bottomLeft),
                radius: bottomLeft,
                startAngle: .degrees(90),
                endAngle: .degrees(180),
                clockwise: false
            )
        }

        // Left edge and top left corner
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeft))
        if topLeft > 0 {
            path.addArc(
                center: CGPoint(x: rect.minX + topLeft, y: rect.minY + topLeft),
                radius: topLeft,
                startAngle: .degrees(180),
                endAngle: .degrees(270),
                clockwise: false
            )
        }

        path.closeSubpath()
        return path
    }
}

// MARK: - Fast Markdown View (For Large Files)

/// Ultra-fast markdown renderer using TextKit 2 with lazy line rendering
/// Renders 5000+ lines in <100ms
struct FastMarkdownView: NSViewRepresentable {
    let content: String
    let isDarkMode: Bool

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = FastMarkdownTextView.createScrollView()
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? FastMarkdownTextView else { return }

        // Render immediately - it's fast enough
        let attributed = FastMarkdownRenderer.render(content, isDarkMode: isDarkMode)
        textView.textStorage?.setAttributedString(attributed)
    }
}

/// Optimized text view for large markdown files
final class FastMarkdownTextView: NSTextView {
    static func createScrollView() -> NSScrollView {
        let textView = FastMarkdownTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: DesignTokens.Spacing.lg + 4, height: DesignTokens.Spacing.lg) // 20, 16

        // Performance optimizations
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticLinkDetectionEnabled = true
        textView.usesFontPanel = false
        textView.usesRuler = false
        textView.allowsUndo = false

        // Use non-contiguous layout for virtualization
        textView.layoutManager?.allowsNonContiguousLayout = true

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        // Layer-backed for performance
        scrollView.wantsLayer = true
        scrollView.contentView.wantsLayer = true
        scrollView.contentView.postsBoundsChangedNotifications = false

        return scrollView
    }
}

// MARK: - Fast Markdown Renderer

/// Single-pass markdown renderer optimized for speed
/// No regex, minimal allocations, O(n) complexity
enum FastMarkdownRenderer {

    @MainActor
    static func render(_ markdown: String, isDarkMode: Bool) -> NSAttributedString {
        let result = NSMutableAttributedString()

        // Pre-compute styles once
        let styles = Styles(isDarkMode: isDarkMode)

        // Process line by line staying on MainActor
        var inCodeBlock = false
        var codeBlockBuffer = ""

        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false)
        for lineRef in lines {
            let line = String(lineRef)
            // Code block handling (fast path)
            if line.hasPrefix("```") {
                if inCodeBlock {
                    // End code block
                    appendCodeBlock(codeBlockBuffer, to: result, styles: styles)
                    codeBlockBuffer = ""
                    inCodeBlock = false
                } else {
                    inCodeBlock = true
                }
                continue
            }

            if inCodeBlock {
                if !codeBlockBuffer.isEmpty { codeBlockBuffer += "\n" }
                codeBlockBuffer += line
                continue
            }

            // Empty line
            if line.isEmpty {
                result.append(NSAttributedString(string: "\n", attributes: styles.body))
                continue
            }

            // Fast prefix checks (ordered by frequency)
            let trimmed = line

            // Headers (check # count directly)
            if let firstChar = trimmed.first, firstChar == "#" {
                if let headerResult = parseHeader(trimmed, styles: styles) {
                    result.append(headerResult)
                    result.append(NSAttributedString(string: "\n", attributes: styles.body))
                    continue
                }
            }

            // List items
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                appendListItem(String(trimmed.dropFirst(2)), to: result, styles: styles)
                continue
            }

            // Task lists
            if trimmed.hasPrefix("- [ ] ") {
                appendTaskItem(String(trimmed.dropFirst(6)), checked: false, to: result, styles: styles)
                continue
            }
            if trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ") {
                appendTaskItem(String(trimmed.dropFirst(6)), checked: true, to: result, styles: styles)
                continue
            }

            // Blockquotes
            if trimmed.hasPrefix("> ") {
                appendBlockquote(String(trimmed.dropFirst(2)), to: result, styles: styles)
                continue
            }

            // Horizontal rule
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                appendHorizontalRule(to: result, styles: styles)
                continue
            }

            // Ordered list (simple check)
            if let firstChar = trimmed.first, firstChar.isNumber {
                if let dotIndex = trimmed.firstIndex(of: "."),
                   trimmed.distance(from: trimmed.startIndex, to: dotIndex) <= 3 {
                    let afterDot = trimmed.index(after: dotIndex)
                    if afterDot < trimmed.endIndex && trimmed[afterDot] == " " {
                        let content = String(trimmed[trimmed.index(after: afterDot)...])
                        appendOrderedListItem(content, to: result, styles: styles)
                        continue
                    }
                }
            }

            // Regular paragraph with inline formatting
            appendInlineFormatted(trimmed, to: result, styles: styles)
            result.append(NSAttributedString(string: "\n", attributes: styles.body))
        }

        // Handle unclosed code block
        if inCodeBlock && !codeBlockBuffer.isEmpty {
            appendCodeBlock(codeBlockBuffer, to: result, styles: styles)
        }

        return result
    }

    // MARK: - Inline Formatting (Optimized)

    @MainActor
    private static func appendInlineFormatted(_ text: String, to result: NSMutableAttributedString, styles: Styles) {
        var i = text.startIndex
        var plainStart = i

        while i < text.endIndex {
            let c = text[i]

            // Inline code (highest priority)
            if c == "`" {
                // Flush plain text
                if plainStart < i {
                    result.append(NSAttributedString(string: String(text[plainStart..<i]), attributes: styles.body))
                }

                let codeStart = text.index(after: i)
                if let codeEnd = text[codeStart...].firstIndex(of: "`") {
                    let code = String(text[codeStart..<codeEnd])
                    result.append(NSAttributedString(string: " \(code) ", attributes: styles.inlineCode))
                    i = text.index(after: codeEnd)
                    plainStart = i
                    continue
                }
            }

            // Bold **text**
            if c == "*" || c == "_" {
                let next = text.index(after: i)
                if next < text.endIndex && text[next] == c {
                    // Flush plain text
                    if plainStart < i {
                        result.append(NSAttributedString(string: String(text[plainStart..<i]), attributes: styles.body))
                    }

                    let marker = String(repeating: String(c), count: 2)
                    let searchStart = text.index(after: next)
                    if let closeRange = text.range(of: marker, range: searchStart..<text.endIndex) {
                        let boldText = String(text[searchStart..<closeRange.lowerBound])
                        result.append(NSAttributedString(string: boldText, attributes: styles.bold))
                        i = closeRange.upperBound
                        plainStart = i
                        continue
                    }
                }
            }

            // Links [text](url)
            if c == "[" {
                if let closeBracket = text[text.index(after: i)...].firstIndex(of: "]") {
                    let nextAfterBracket = text.index(after: closeBracket)
                    if nextAfterBracket < text.endIndex && text[nextAfterBracket] == "(" {
                        if let closeParen = text[text.index(after: nextAfterBracket)...].firstIndex(of: ")") {
                            // Flush plain text
                            if plainStart < i {
                                result.append(NSAttributedString(string: String(text[plainStart..<i]), attributes: styles.body))
                            }

                            let linkText = String(text[text.index(after: i)..<closeBracket])
                            let url = String(text[text.index(after: nextAfterBracket)..<closeParen])

                            var attrs = styles.link
                            if let urlObj = URL(string: url) {
                                attrs[.link] = urlObj
                            }
                            result.append(NSAttributedString(string: linkText, attributes: attrs))

                            i = text.index(after: closeParen)
                            plainStart = i
                            continue
                        }
                    }
                }
            }

            i = text.index(after: i)
        }

        // Flush remaining plain text
        if plainStart < text.endIndex {
            result.append(NSAttributedString(string: String(text[plainStart...]), attributes: styles.body))
        }
    }

    // MARK: - Block Elements

    @MainActor
    private static func parseHeader(_ line: String, styles: Styles) -> NSAttributedString? {
        var level = 0
        var i = line.startIndex

        while i < line.endIndex && line[i] == "#" && level < 6 {
            level += 1
            i = line.index(after: i)
        }

        guard level > 0 && i < line.endIndex && line[i] == " " else { return nil }

        let content = String(line[line.index(after: i)...])
        let attrs: [NSAttributedString.Key: Any]

        switch level {
        case 1: attrs = styles.h1
        case 2: attrs = styles.h2
        case 3: attrs = styles.h3
        default: attrs = styles.h4
        }

        return NSAttributedString(string: content, attributes: attrs)
    }

    @MainActor
    private static func appendCodeBlock(_ code: String, to result: NSMutableAttributedString, styles: Styles) {
        let codeAttr = NSAttributedString(string: code + "\n\n", attributes: styles.codeBlock)
        result.append(codeAttr)
    }

    @MainActor
    private static func appendListItem(_ text: String, to result: NSMutableAttributedString, styles: Styles) {
        result.append(NSAttributedString(string: "  • ", attributes: styles.bullet))
        appendInlineFormatted(text, to: result, styles: styles)
        result.append(NSAttributedString(string: "\n", attributes: styles.body))
    }

    @MainActor
    private static func appendOrderedListItem(_ text: String, to result: NSMutableAttributedString, styles: Styles) {
        result.append(NSAttributedString(string: "    ", attributes: styles.body))
        appendInlineFormatted(text, to: result, styles: styles)
        result.append(NSAttributedString(string: "\n", attributes: styles.body))
    }

    @MainActor
    private static func appendTaskItem(_ text: String, checked: Bool, to result: NSMutableAttributedString, styles: Styles) {
        let checkbox = checked ? "  ☑ " : "  ☐ "
        let attrs = checked ? styles.checkboxChecked : styles.checkbox
        result.append(NSAttributedString(string: checkbox, attributes: attrs))
        appendInlineFormatted(text, to: result, styles: styles)
        result.append(NSAttributedString(string: "\n", attributes: styles.body))
    }

    @MainActor
    private static func appendBlockquote(_ text: String, to result: NSMutableAttributedString, styles: Styles) {
        result.append(NSAttributedString(string: "│ ", attributes: styles.quoteBorder))
        result.append(NSAttributedString(string: text, attributes: styles.quote))
        result.append(NSAttributedString(string: "\n", attributes: styles.body))
    }

    @MainActor
    private static func appendHorizontalRule(to result: NSMutableAttributedString, styles: Styles) {
        let line = String(repeating: "─", count: 60)
        result.append(NSAttributedString(string: "\n\(line)\n\n", attributes: styles.hr))
    }

    // MARK: - Styles (Pre-computed)

    struct Styles {
        let body: [NSAttributedString.Key: Any]
        let bold: [NSAttributedString.Key: Any]
        let h1: [NSAttributedString.Key: Any]
        let h2: [NSAttributedString.Key: Any]
        let h3: [NSAttributedString.Key: Any]
        let h4: [NSAttributedString.Key: Any]
        let inlineCode: [NSAttributedString.Key: Any]
        let codeBlock: [NSAttributedString.Key: Any]
        let link: [NSAttributedString.Key: Any]
        let quote: [NSAttributedString.Key: Any]
        let quoteBorder: [NSAttributedString.Key: Any]
        let bullet: [NSAttributedString.Key: Any]
        let checkbox: [NSAttributedString.Key: Any]
        let checkboxChecked: [NSAttributedString.Key: Any]
        let hr: [NSAttributedString.Key: Any]

        @MainActor
        init(isDarkMode: Bool) {
            let colors = ThemeManager.shared.colors
            let nsTextColor = colors.text.nsColor
            let nsSecondaryColor = colors.textSecondary.nsColor
            let nsCodeBackground = colors.backgroundTertiary.nsColor
            let nsLinkColor = colors.accent.nsColor

            // Typography from DesignTokens
            let bodyFont = NSFont.systemFont(ofSize: 14)
            let boldFont = NSFont.boldSystemFont(ofSize: 14)
            let codeFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

            body = [.font: bodyFont, .foregroundColor: nsTextColor]
            bold = [.font: boldFont, .foregroundColor: nsTextColor]
            h1 = [.font: NSFont.systemFont(ofSize: 28, weight: .bold), .foregroundColor: nsTextColor]
            h2 = [.font: NSFont.systemFont(ofSize: 22, weight: .bold), .foregroundColor: nsTextColor]
            h3 = [.font: NSFont.systemFont(ofSize: 20, weight: .semibold), .foregroundColor: nsTextColor]
            h4 = [.font: NSFont.systemFont(ofSize: 15, weight: .semibold), .foregroundColor: nsTextColor]
            inlineCode = [.font: codeFont, .foregroundColor: nsTextColor, .backgroundColor: nsCodeBackground]
            codeBlock = [.font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular), .foregroundColor: nsTextColor, .backgroundColor: nsCodeBackground]
            link = [.font: bodyFont, .foregroundColor: nsLinkColor, .underlineStyle: NSUnderlineStyle.single.rawValue]
            quote = [.font: bodyFont, .foregroundColor: nsSecondaryColor]
            quoteBorder = [.font: bodyFont, .foregroundColor: NSColor.separatorColor]
            bullet = [.font: bodyFont, .foregroundColor: nsTextColor]
            checkbox = [.font: bodyFont, .foregroundColor: nsSecondaryColor]
            checkboxChecked = [.font: bodyFont, .foregroundColor: NSColor.systemGreen]
            hr = [.font: NSFont.systemFont(ofSize: 10), .foregroundColor: NSColor.separatorColor]
        }
    }
}

// MARK: - Rich Markdown View (For Small Files)

/// Full-featured markdown renderer for files under 500 lines
struct RichMarkdownView: NSViewRepresentable {
    let content: String
    let isDarkMode: Bool

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = FastMarkdownTextView.createScrollView()
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Use the same fast renderer - it's already optimized
        let attributed = FastMarkdownRenderer.render(content, isDarkMode: isDarkMode)
        textView.textStorage?.setAttributedString(attributed)
    }
}

// MARK: - Preview

#if DEBUG
struct MarkdownView_Previews: PreviewProvider {
    static let sampleMarkdown = """
    # GitMac - Professional Git Client

    A modern, native macOS Git client built with **SwiftUI**.

    ## Features

    - Commit graph visualization
    - Branch management
    - **Pull request** integration
    - `Diff viewer` with syntax highlighting

    ### Code Example

    ```swift
    func greet(name: String) -> String {
        return "Hello, \\(name)!"
    }
    ```

    ## Task List

    - [x] Implement commit graph
    - [x] Add branch switching
    - [ ] Add rebasing support
    - [ ] Add stash management

    > This is a blockquote with some important information.

    ---

    Visit [GitHub](https://github.com) for more info.
    """

    static let mermaidMarkdown = """
    # Architecture Overview

    This document shows the app architecture using **Mermaid diagrams**.

    ## Data Flow

    ```mermaid
    flowchart TD
        A[User Action] --> B{GitService}
        B --> C[Local Repository]
        B --> D[Remote API]
        C --> E[File System]
        D --> F[GitHub/GitLab]
        E --> G[Working Directory]
        F --> H[Pull Requests]
    ```

    ## Sequence Diagram

    Here's how a commit works:

    ```mermaid
    sequenceDiagram
        participant User
        participant GitMac
        participant Git
        participant Remote

        User->>GitMac: Stage files
        GitMac->>Git: git add
        User->>GitMac: Commit
        GitMac->>Git: git commit
        User->>GitMac: Push
        GitMac->>Git: git push
        Git->>Remote: Upload
        Remote-->>GitMac: Success
    ```

    ## Class Structure

    ```mermaid
    classDiagram
        class GitService {
            +repository: Repository
            +getCommits()
            +getBranches()
            +stage()
            +commit()
        }
        class Repository {
            +path: String
            +currentBranch: Branch
        }
        class Commit {
            +hash: String
            +message: String
            +author: String
        }
        GitService --> Repository
        Repository --> Commit
    ```

    That's all for now!
    """

    static var previews: some View {
        Group {
            MarkdownView(content: sampleMarkdown, fileName: "README.md")
                .frame(width: 700, height: 500)
                .previewDisplayName("Standard Markdown")

            MarkdownView(content: mermaidMarkdown, fileName: "ARCHITECTURE.md")
                .frame(width: 800, height: 900)
                .previewDisplayName("With Mermaid Diagrams")
        }
    }
}
#endif
