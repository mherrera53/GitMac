import SwiftUI
import AppKit

/// Syntax Highlighter for Diffs - Makes code changes readable
/// Uses fast regex-based highlighting (faster than tree-sitter for diffs)
struct SyntaxHighlightedDiffLine: View {
    let content: String
    let language: ProgrammingLanguage
    let lineType: DiffLineType
    
    var body: some View {
        Text(highlightedContent)
            .font(.system(.body, design: .monospaced))
    }
    
    private var highlightedContent: AttributedString {
        let highlighter = SyntaxHighlighter.shared
        var attributed = highlighter.highlight(content, language: language)
        
        // Apply diff-specific styling
        attributed.foregroundColor = lineTypeColor
        
        return attributed
    }
    
    private var lineTypeColor: Color? {
        switch lineType {
        case .addition:
            return nil // Use syntax colors
        case .deletion:
            return nil // Use syntax colors
        case .context:
            return AppTheme.syntaxComment
        case .hunkHeader:
            return AppTheme.syntaxKeyword
        }
    }
}

// MARK: - Syntax Highlighter

@MainActor
class SyntaxHighlighter {
    static let shared = SyntaxHighlighter()

    private var cache: [String: AttributedString] = [:]
    private let maxCacheSize = 1000
    
    func highlight(_ code: String, language: ProgrammingLanguage) -> AttributedString {
        let cacheKey = "\(language.rawValue):\(code.hashValue)"
        
        // Check cache
        if let cached = getCached(cacheKey) {
            return cached
        }
        
        // Highlight
        let attributed = performHighlighting(code, language: language)
        
        // Cache result
        setCached(cacheKey, attributed)
        
        return attributed
    }
    
    private func performHighlighting(_ code: String, language: ProgrammingLanguage) -> AttributedString {
        var attributed = AttributedString(code)
        
        // Apply patterns based on language
        let patterns = language.syntaxPatterns
        
        for pattern in patterns {
            applyPattern(pattern, to: &attributed, in: code)
        }
        
        return attributed
    }
    
    private func applyPattern(_ pattern: SyntaxPattern, to attributed: inout AttributedString, in code: String) {
        guard let regex = try? NSRegularExpression(pattern: pattern.regex, options: []) else {
            return
        }
        
        let nsRange = NSRange(code.startIndex..., in: code)
        let matches = regex.matches(in: code, options: [], range: nsRange)
        
        for match in matches {
            if let range = Range(match.range, in: code),
               let attrRange = Range<AttributedString.Index>(range, in: attributed) {
                attributed[attrRange].foregroundColor = pattern.color
                if pattern.bold {
                    attributed[attrRange].font = .system(.body, design: .monospaced).bold()
                }
                if pattern.italic {
                    attributed[attrRange].font = .system(.body, design: .monospaced).italic()
                }
            }
        }
    }
    
    // MARK: - Cache Management

    private func getCached(_ key: String) -> AttributedString? {
        cache[key]
    }

    private func setCached(_ key: String, _ value: AttributedString) {
        // Limit cache size
        if cache.count >= maxCacheSize {
            // Remove random entries (simple eviction)
            let keysToRemove = Array(cache.keys.prefix(100))
            keysToRemove.forEach { cache.removeValue(forKey: $0) }
        }

        cache[key] = value
    }
}

// MARK: - Programming Languages

enum ProgrammingLanguage: String {
    case swift
    case objectiveC = "objective-c"
    case javascript
    case typescript
    case python
    case ruby
    case go
    case rust
    case c
    case cpp = "c++"
    case java
    case kotlin
    case csharp = "c#"
    case php
    case html
    case css
    case json
    case yaml
    case xml
    case markdown
    case shell
    case sql
    case plaintext
    
    var syntaxPatterns: [SyntaxPattern] {
        switch self {
        case .swift:
            return swiftPatterns
        case .javascript, .typescript:
            return javascriptPatterns
        case .python:
            return pythonPatterns
        case .ruby:
            return rubyPatterns
        case .go:
            return goPatterns
        case .rust:
            return rustPatterns
        case .json:
            return jsonPatterns
        default:
            return genericPatterns
        }
    }
    
    static func detect(from filename: String) -> ProgrammingLanguage {
        let ext = URL(fileURLWithPath: filename).pathExtension.lowercased()
        
        switch ext {
        case "swift": return .swift
        case "m", "mm": return .objectiveC
        case "js", "jsx", "mjs": return .javascript
        case "ts", "tsx": return .typescript
        case "py": return .python
        case "rb": return .ruby
        case "go": return .go
        case "rs": return .rust
        case "c", "h": return .c
        case "cpp", "cc", "cxx", "hpp": return .cpp
        case "java": return .java
        case "kt", "kts": return .kotlin
        case "cs": return .csharp
        case "php": return .php
        case "html", "htm": return .html
        case "css", "scss", "sass": return .css
        case "json": return .json
        case "yml", "yaml": return .yaml
        case "xml": return .xml
        case "md", "markdown": return .markdown
        case "sh", "bash", "zsh": return .shell
        case "sql": return .sql
        default: return .plaintext
        }
    }
}

// MARK: - Syntax Patterns

struct SyntaxPattern {
    let regex: String
    let color: Color
    let bold: Bool
    let italic: Bool
    
    init(regex: String, color: Color, bold: Bool = false, italic: Bool = false) {
        self.regex = regex
        self.color = color
        self.bold = bold
        self.italic = italic
    }
}

// MARK: - Swift Patterns

private let swiftPatterns: [SyntaxPattern] = [
    // Keywords
    SyntaxPattern(
        regex: "\\b(func|var|let|class|struct|enum|protocol|extension|import|return|if|else|switch|case|for|while|guard|defer|throw|try|catch|async|await|actor)\\b",
        color: .purple,
        bold: true
    ),
    
    // Types
    SyntaxPattern(
        regex: "\\b(String|Int|Double|Float|Bool|Array|Dictionary|Set|Optional|Any|AnyObject|Void)\\b",
        color: .blue,
        bold: true
    ),
    
    // Attributes
    SyntaxPattern(
        regex: "@\\w+",
        color: .orange
    ),
    
    // Strings
    SyntaxPattern(
        regex: "\"[^\"\\\\]*(\\\\.[^\"\\\\]*)*\"",
        color: .red
    ),
    
    // Numbers
    SyntaxPattern(
        regex: "\\b\\d+(\\.\\d+)?\\b",
        color: .cyan
    ),
    
    // Comments
    SyntaxPattern(
        regex: "//.*$",
        color: .green,
        italic: true
    ),
    SyntaxPattern(
        regex: "/\\*[^*]*\\*+(?:[^/*][^*]*\\*+)*/",
        color: .green,
        italic: true
    ),
    
    // Functions
    SyntaxPattern(
        regex: "\\b([a-zA-Z_][a-zA-Z0-9_]*)\\s*\\(",
        color: .yellow
    ),
]

// MARK: - JavaScript Patterns

private let javascriptPatterns: [SyntaxPattern] = [
    // Keywords
    SyntaxPattern(
        regex: "\\b(function|const|let|var|class|extends|return|if|else|switch|case|for|while|break|continue|import|export|default|async|await|try|catch|throw|new)\\b",
        color: .purple,
        bold: true
    ),
    
    // Types
    SyntaxPattern(
        regex: "\\b(undefined|null|true|false)\\b",
        color: .blue
    ),
    
    // Strings
    SyntaxPattern(
        regex: "['\"`][^'\"` \\\\]*(\\\\.[^'\"`\\\\]*)*['\"`]",
        color: .red
    ),
    
    // Numbers
    SyntaxPattern(
        regex: "\\b\\d+(\\.\\d+)?\\b",
        color: .cyan
    ),
    
    // Comments
    SyntaxPattern(
        regex: "//.*$",
        color: .green,
        italic: true
    ),
]

// MARK: - Python Patterns

private let pythonPatterns: [SyntaxPattern] = [
    // Keywords
    SyntaxPattern(
        regex: "\\b(def|class|import|from|return|if|elif|else|for|while|break|continue|pass|lambda|try|except|finally|raise|with|as|async|await)\\b",
        color: .purple,
        bold: true
    ),
    
    // Strings
    SyntaxPattern(
        regex: "['\"][^'\"\\\\]*(\\\\.[^'\"\\\\]*)*['\"]",
        color: .red
    ),
    
    // Decorators
    SyntaxPattern(
        regex: "@\\w+",
        color: .orange
    ),
    
    // Comments
    SyntaxPattern(
        regex: "#.*$",
        color: .green,
        italic: true
    ),
]

// MARK: - Ruby Patterns

private let rubyPatterns: [SyntaxPattern] = [
    // Keywords
    SyntaxPattern(
        regex: "\\b(def|class|module|end|if|elsif|else|unless|case|when|for|while|until|break|next|return|yield|begin|rescue|ensure|raise|require|include)\\b",
        color: .purple,
        bold: true
    ),
    
    // Strings
    SyntaxPattern(
        regex: "['\"][^'\"\\\\]*(\\\\.[^'\"\\\\]*)*['\"]",
        color: .red
    ),
    
    // Symbols
    SyntaxPattern(
        regex: ":\\w+",
        color: .cyan
    ),
    
    // Comments
    SyntaxPattern(
        regex: "#.*$",
        color: .green,
        italic: true
    ),
]

// MARK: - Go Patterns

private let goPatterns: [SyntaxPattern] = [
    // Keywords
    SyntaxPattern(
        regex: "\\b(func|var|const|type|struct|interface|package|import|return|if|else|switch|case|for|range|go|defer|chan|select|break|continue)\\b",
        color: .purple,
        bold: true
    ),
    
    // Types
    SyntaxPattern(
        regex: "\\b(int|int8|int16|int32|int64|uint|uint8|uint16|uint32|uint64|float32|float64|string|bool|byte|rune|error)\\b",
        color: .blue
    ),
    
    // Strings
    SyntaxPattern(
        regex: "\"[^\"\\\\]*(\\\\.[^\"\\\\]*)*\"",
        color: .red
    ),
    
    // Comments
    SyntaxPattern(
        regex: "//.*$",
        color: .green,
        italic: true
    ),
]

// MARK: - Rust Patterns

private let rustPatterns: [SyntaxPattern] = [
    // Keywords
    SyntaxPattern(
        regex: "\\b(fn|let|mut|const|static|struct|enum|trait|impl|pub|use|mod|crate|self|super|return|if|else|match|for|while|loop|break|continue|async|await)\\b",
        color: .purple,
        bold: true
    ),
    
    // Types
    SyntaxPattern(
        regex: "\\b(i8|i16|i32|i64|i128|u8|u16|u32|u64|u128|f32|f64|bool|char|str|String|Vec|Option|Result)\\b",
        color: .blue
    ),
    
    // Attributes
    SyntaxPattern(
        regex: "#\\[\\w+\\]",
        color: .orange
    ),
    
    // Strings
    SyntaxPattern(
        regex: "\"[^\"\\\\]*(\\\\.[^\"\\\\]*)*\"",
        color: .red
    ),
    
    // Comments
    SyntaxPattern(
        regex: "//.*$",
        color: .green,
        italic: true
    ),
]

// MARK: - JSON Patterns

private let jsonPatterns: [SyntaxPattern] = [
    // Keys
    SyntaxPattern(
        regex: "\"[^\"]+\"\\s*:",
        color: .blue
    ),
    
    // Strings
    SyntaxPattern(
        regex: "\"[^\"\\\\]*(\\\\.[^\"\\\\]*)*\"",
        color: .red
    ),
    
    // Numbers
    SyntaxPattern(
        regex: "\\b\\d+(\\.\\d+)?\\b",
        color: .cyan
    ),
    
    // Booleans & null
    SyntaxPattern(
        regex: "\\b(true|false|null)\\b",
        color: .purple
    ),
]

// MARK: - Generic Patterns

private let genericPatterns: [SyntaxPattern] = [
    // Strings
    SyntaxPattern(
        regex: "['\"][^'\"\\\\]*(\\\\.[^'\"\\\\]*)*['\"]",
        color: .red
    ),
    
    // Numbers
    SyntaxPattern(
        regex: "\\b\\d+(\\.\\d+)?\\b",
        color: .cyan
    ),
]

// MARK: - Highlighted Diff View Integration

struct HighlightedDiffView: View {
    let filePath: String
    let hunks: [DiffHunk]
    
    @State private var language: ProgrammingLanguage
    
    init(filePath: String, hunks: [DiffHunk]) {
        self.filePath = filePath
        self.hunks = hunks
        self._language = State(initialValue: ProgrammingLanguage.detect(from: filePath))
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(hunks) { hunk in
                    VStack(alignment: .leading, spacing: 0) {
                        // Hunk header
                        HunkHeaderView(hunk: hunk, isSelected: false)
                        
                        // Highlighted lines
                        ForEach(Array(hunk.lines.enumerated()), id: \.offset) { _, line in
                            HighlightedDiffLineView(
                                line: line,
                                language: language
                            )
                        }
                    }
                }
            }
        }
    }
}

struct HighlightedDiffLineView: View {
    let line: DiffLine
    let language: ProgrammingLanguage
    
    var body: some View {
        HStack(spacing: 0) {
            // Line numbers
            HStack(spacing: 4) {
                Text(line.oldLineNumber.map { "\($0)" } ?? " ")
                    .frame(width: 50, alignment: .trailing)
                
                Text(line.newLineNumber.map { "\($0)" } ?? " ")
                    .frame(width: 50, alignment: .trailing)
            }
            .foregroundColor(AppTheme.textPrimary)
            .padding(.horizontal, 8)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            
            // Highlighted content
            SyntaxHighlightedDiffLine(
                content: line.content,
                language: language,
                lineType: line.type
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 2)
        }
        .background(lineBackgroundColor)
        .font(.system(.body, design: .monospaced))
    }
    
    private var lineBackgroundColor: Color {
        switch line.type {
        case .addition:
            return AppTheme.diffAdditionBg
        case .deletion:
            return AppTheme.diffDeletionBg
        case .context:
            return Color.clear
        case .hunkHeader:
            return AppTheme.syntaxKeyword.opacity(0.1)
        }
    }
}

// MARK: - Hunk Header View

struct HunkHeaderView: View {
    let hunk: DiffHunk
    let isSelected: Bool

    var body: some View {
        HStack {
            Text(hunk.header)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(AppTheme.syntaxKeyword)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(AppTheme.syntaxKeyword.opacity(0.1))
    }
}
