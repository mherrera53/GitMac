import SwiftUI
import WebKit

// MARK: - Mermaid Diagram View

/// Renders Mermaid diagrams using WKWebView with mermaid.js
/// Supports: flowchart, sequence, class, state, ER, pie, gantt, journey, mindmap
/// Optimized: Reuses WKWebView and updates diagram via JavaScript when only code changes
struct MermaidDiagramView: NSViewRepresentable {
    let code: String
    let isDarkMode: Bool
    let maxHeight: CGFloat

    init(code: String, isDarkMode: Bool = false, maxHeight: CGFloat = 400) {
        self.code = code
        self.isDarkMode = isDarkMode
        self.maxHeight = maxHeight
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        // Enable content caching
        config.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")

        // Initial load
        context.coordinator.lastIsDarkMode = isDarkMode
        context.coordinator.lastCode = code
        context.coordinator.isLoaded = false
        let html = generateHTML(code: code, isDarkMode: isDarkMode)
        webView.loadHTMLString(html, baseURL: nil)

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator

        // If theme changed, we need to reload entire HTML
        if coordinator.lastIsDarkMode != isDarkMode {
            coordinator.lastIsDarkMode = isDarkMode
            coordinator.lastCode = code
            coordinator.isLoaded = false
            let html = generateHTML(code: code, isDarkMode: isDarkMode)
            webView.loadHTMLString(html, baseURL: nil)
            return
        }

        // If only code changed and page is loaded, update via JavaScript
        if coordinator.lastCode != code {
            coordinator.lastCode = code

            if coordinator.isLoaded {
                // Update diagram via JavaScript without reloading HTML
                let escapedCode = escapeCodeForJS(code)
                let js = """
                (async function() {
                    const container = document.getElementById('diagram');
                    try {
                        // Remove old SVG element if exists
                        const oldSvg = document.getElementById('mermaid-svg');
                        if (oldSvg) oldSvg.remove();

                        const { svg } = await mermaid.render('mermaid-svg', `\(escapedCode)`);
                        container.innerHTML = svg;
                        return document.body.scrollHeight;
                    } catch (error) {
                        container.innerHTML = '<div class="error">Mermaid Error: ' + error.message + '</div>';
                        return document.body.scrollHeight;
                    }
                })();
                """
                webView.evaluateJavaScript(js) { height, _ in
                    if let h = height as? CGFloat {
                        webView.frame.size.height = min(h, 600)
                    }
                }
            } else {
                // Page not yet loaded, reload HTML
                let html = generateHTML(code: code, isDarkMode: isDarkMode)
                webView.loadHTMLString(html, baseURL: nil)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var lastCode: String = ""
        var lastIsDarkMode: Bool = false
        var isLoaded: Bool = false

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoaded = true
            // Adjust height based on content
            webView.evaluateJavaScript("document.body.scrollHeight") { [weak self] height, _ in
                guard self != nil else { return }
                if let h = height as? CGFloat {
                    webView.frame.size.height = min(h, 600)
                }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoaded = false
        }
    }

    /// Escape code for safe JavaScript string interpolation
    private func escapeCodeForJS(_ code: String) -> String {
        code
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    private func generateHTML(code: String, isDarkMode: Bool) -> String {
        let theme = isDarkMode ? "dark" : "default"
        let bgColor = isDarkMode ? "#1e1e1e" : "#ffffff"
        let textColor = isDarkMode ? "#d4d4d4" : "#333333"

        // Escape code for JavaScript
        let escapedCode = code
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
            .replacingOccurrences(of: "\n", with: "\\n")

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                * {
                    margin: 0;
                    padding: 0;
                    box-sizing: border-box;
                }
                body {
                    background-color: \(bgColor);
                    color: \(textColor);
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    padding: 16px;
                    display: flex;
                    justify-content: center;
                    align-items: flex-start;
                }
                #diagram {
                    max-width: 100%;
                    overflow-x: auto;
                }
                .mermaid {
                    display: flex;
                    justify-content: center;
                }
                svg {
                    max-width: 100%;
                    height: auto;
                }
                .error {
                    color: #e74c3c;
                    font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, monospace;
                    font-size: 12px;
                    padding: 12px;
                    background: \(isDarkMode ? "#2d1f1f" : "#fdf2f2");
                    border-radius: 6px;
                    border: 1px solid \(isDarkMode ? "#5c3030" : "#f5c6c6");
                }
            </style>
            <script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>
        </head>
        <body>
            <div id="diagram"></div>
            <script>
                mermaid.initialize({
                    startOnLoad: false,
                    theme: '\(theme)',
                    securityLevel: 'loose',
                    fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
                    flowchart: {
                        curve: 'basis',
                        padding: 20
                    },
                    sequence: {
                        diagramMarginX: 20,
                        diagramMarginY: 20,
                        actorMargin: 50,
                        width: 150,
                        height: 65,
                        boxMargin: 10,
                        boxTextMargin: 5,
                        noteMargin: 10,
                        messageMargin: 35
                    },
                    gantt: {
                        titleTopMargin: 25,
                        barHeight: 20,
                        barGap: 4,
                        topPadding: 50,
                        leftPadding: 75
                    }
                });

                async function renderDiagram() {
                    const container = document.getElementById('diagram');
                    try {
                        const code = `\(escapedCode)`;
                        const { svg } = await mermaid.render('mermaid-svg', code);
                        container.innerHTML = svg;
                    } catch (error) {
                        container.innerHTML = '<div class="error">Mermaid Error: ' + error.message + '</div>';
                    }
                }

                renderDiagram();
            </script>
        </body>
        </html>
        """
    }
}

// MARK: - Mermaid Code Block Detection

/// Utility to detect and extract Mermaid code blocks from markdown
enum MermaidDetector {

    /// Represents a segment of markdown content
    enum Segment: Identifiable {
        case text(String)
        case mermaid(String)

        var id: String {
            switch self {
            case .text(let content): return "text-\(content.hashValue)"
            case .mermaid(let code): return "mermaid-\(code.hashValue)"
            }
        }
    }

    /// Parse markdown into segments of text and mermaid diagrams
    static func parse(_ markdown: String) -> [Segment] {
        var segments: [Segment] = []
        var currentText = ""
        var inMermaidBlock = false
        var mermaidCode = ""
        let lines = markdown.components(separatedBy: "\n")
        var i = 0

        while i < lines.count {
            let line = lines[i]

            // Check for mermaid code block start
            if line.lowercased().hasPrefix("```mermaid") {
                // Save any accumulated text
                if !currentText.isEmpty {
                    segments.append(.text(currentText.trimmingCharacters(in: .whitespacesAndNewlines)))
                    currentText = ""
                }
                inMermaidBlock = true
                i += 1
                continue
            }

            // Check for code block end
            if inMermaidBlock && line.hasPrefix("```") {
                if !mermaidCode.isEmpty {
                    segments.append(.mermaid(mermaidCode.trimmingCharacters(in: .whitespacesAndNewlines)))
                    mermaidCode = ""
                }
                inMermaidBlock = false
                i += 1
                continue
            }

            if inMermaidBlock {
                if !mermaidCode.isEmpty { mermaidCode += "\n" }
                mermaidCode += line
            } else {
                if !currentText.isEmpty { currentText += "\n" }
                currentText += line
            }

            i += 1
        }

        // Add any remaining content
        if !currentText.isEmpty {
            segments.append(.text(currentText.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        if !mermaidCode.isEmpty {
            segments.append(.mermaid(mermaidCode.trimmingCharacters(in: .whitespacesAndNewlines)))
        }

        return segments
    }

    /// Check if markdown contains any Mermaid diagrams
    static func containsMermaid(_ markdown: String) -> Bool {
        markdown.lowercased().contains("```mermaid")
    }
}

// MARK: - SwiftUI Wrapper for Inline Mermaid

/// A compact mermaid diagram view for inline display
struct InlineMermaidView: View {
    let code: String
    @Environment(\.colorScheme) private var colorScheme
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            // Header bar
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .foregroundColor(AppTheme.accent)
                    Text("Mermaid Diagram")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(AppTheme.textPrimary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(AppTheme.textPrimary)
                        .font(.caption)
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.sm)
                .background(colorScheme == .dark ? AppTheme.textPrimary.opacity(0.05) : AppTheme.background.opacity(0.03))
                .cornerRadius(DesignTokens.CornerRadius.md)
            }
            .buttonStyle(.plain)

            if isExpanded {
                MermaidDiagramView(
                    code: code,
                    isDarkMode: colorScheme == .dark,
                    maxHeight: 400
                )
                .frame(minHeight: 200, maxHeight: 500)
                .cornerRadius(DesignTokens.CornerRadius.lg)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                        .stroke(AppTheme.textMuted.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct MermaidDiagramView_Previews: PreviewProvider {
    static let flowchartCode = """
    flowchart TD
        A[Start] --> B{Is it working?}
        B -->|Yes| C[Great!]
        B -->|No| D[Debug]
        D --> B
        C --> E[End]
    """

    static let sequenceCode = """
    sequenceDiagram
        participant Client
        participant Server
        participant Database

        Client->>Server: Request
        Server->>Database: Query
        Database-->>Server: Results
        Server-->>Client: Response
    """

    static let classCode = """
    classDiagram
        class Animal {
            +String name
            +int age
            +makeSound()
        }
        class Dog {
            +fetch()
        }
        class Cat {
            +scratch()
        }
        Animal <|-- Dog
        Animal <|-- Cat
    """

    static var previews: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Text("Flowchart").font(.headline)
            MermaidDiagramView(code: flowchartCode, isDarkMode: false)
                .frame(height: 300)

            Text("Sequence Diagram").font(.headline)
            MermaidDiagramView(code: sequenceCode, isDarkMode: true)
                .frame(height: 300)
        }
        .padding()
        .frame(width: 600, height: 700)
    }
}
#endif
