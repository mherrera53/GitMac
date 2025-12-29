import SwiftUI
import AppKit
import Splash

// MARK: - Universal File Content Viewer

/// High-performance file viewer that handles any file type
/// Automatically detects format and applies appropriate rendering
struct FileContentView: View {
    let content: String
    let fileName: String
    let showLineNumbers: Bool

    @Environment(\.colorScheme) private var colorScheme

    init(content: String, fileName: String, showLineNumbers: Bool = true) {
        self.content = content
        self.fileName = fileName
        self.showLineNumbers = showLineNumbers
    }

    private var fileType: FileType {
        FileType.detect(from: fileName)
    }

    private var lineCount: Int {
        content.components(separatedBy: "\n").count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Use MarkdownView for markdown files (with Mermaid support)
            if fileType == .markdown {
                MarkdownView(content: content, fileName: fileName)
            } else {
                // File header
                fileHeader

                Divider()

                // Content view based on file type
                FastFileContentView(
                    content: content,
                    fileType: fileType,
                    showLineNumbers: showLineNumbers,
                    isDarkMode: colorScheme == .dark
                )
            }
        }
    }

    private var fileHeader: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: fileType.icon)
                .foregroundColor(fileType.iconColor)

            Text(fileName)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)

            Text("(\(fileType.displayName))")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(AppTheme.textPrimary)

            Spacer()

            if lineCount > 500 {
                Label("Fast mode", systemImage: "bolt.fill")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.warning)
            }

            Text("\(lineCount) lines")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(AppTheme.textPrimary)
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.xs + 6)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

// MARK: - File Type Detection

enum FileType {
    case markdown
    case swift
    case javascript
    case typescript
    case python
    case ruby
    case go
    case rust
    case java
    case kotlin
    case csharp
    case cpp
    case c
    case objectiveC
    case php
    case html
    case css
    case scss
    case json
    case yaml
    case xml
    case sql
    case shell
    case dockerfile
    case gitignore
    case plainText

    static func detect(from fileName: String) -> FileType {
        let ext = (fileName as NSString).pathExtension.lowercased()
        let name = (fileName as NSString).lastPathComponent.lowercased()

        // Special files
        switch name {
        case "dockerfile": return .dockerfile
        case ".gitignore", ".dockerignore": return .gitignore
        case "makefile", "gemfile", "rakefile": return .ruby
        case "podfile": return .ruby
        case "package.json", "tsconfig.json", "composer.json": return .json
        default: break
        }

        // By extension
        switch ext {
        case "md", "markdown", "mdown", "mkd": return .markdown
        case "swift": return .swift
        case "js", "mjs", "cjs": return .javascript
        case "ts", "tsx": return .typescript
        case "py", "pyw", "pyi": return .python
        case "rb", "erb", "rake": return .ruby
        case "go": return .go
        case "rs": return .rust
        case "java": return .java
        case "kt", "kts": return .kotlin
        case "cs": return .csharp
        case "cpp", "cc", "cxx", "hpp", "hxx": return .cpp
        case "c", "h": return .c
        case "m", "mm": return .objectiveC
        case "php": return .php
        case "html", "htm", "xhtml": return .html
        case "css": return .css
        case "scss", "sass", "less": return .scss
        case "json", "jsonc": return .json
        case "yaml", "yml": return .yaml
        case "xml", "plist", "xib", "storyboard": return .xml
        case "sql": return .sql
        case "sh", "bash", "zsh", "fish": return .shell
        case "txt", "log", "bak", "back", "backup", "old", "orig": return .plainText
        default: return .plainText
        }
    }

    var displayName: String {
        switch self {
        case .markdown: return "Markdown"
        case .swift: return "Swift"
        case .javascript: return "JavaScript"
        case .typescript: return "TypeScript"
        case .python: return "Python"
        case .ruby: return "Ruby"
        case .go: return "Go"
        case .rust: return "Rust"
        case .java: return "Java"
        case .kotlin: return "Kotlin"
        case .csharp: return "C#"
        case .cpp: return "C++"
        case .c: return "C"
        case .objectiveC: return "Objective-C"
        case .php: return "PHP"
        case .html: return "HTML"
        case .css: return "CSS"
        case .scss: return "SCSS"
        case .json: return "JSON"
        case .yaml: return "YAML"
        case .xml: return "XML"
        case .sql: return "SQL"
        case .shell: return "Shell"
        case .dockerfile: return "Dockerfile"
        case .gitignore: return "Git Ignore"
        case .plainText: return "Plain Text"
        }
    }

    var icon: String {
        switch self {
        case .markdown: return "doc.richtext"
        case .swift: return "swift"
        case .javascript, .typescript: return "curlybraces"
        case .python: return "chevron.left.forwardslash.chevron.right"
        case .ruby: return "diamond"
        case .go: return "function"
        case .rust: return "gearshape.2"
        case .java, .kotlin: return "cup.and.saucer"
        case .csharp: return "number"
        case .cpp, .c, .objectiveC: return "c.square"
        case .php: return "p.square"
        case .html: return "chevron.left.slash.chevron.right"
        case .css, .scss: return "paintbrush"
        case .json: return "curlybraces.square"
        case .yaml: return "list.bullet.indent"
        case .xml: return "chevron.left.slash.chevron.right"
        case .sql: return "cylinder"
        case .shell: return "terminal"
        case .dockerfile: return "shippingbox"
        case .gitignore: return "eye.slash"
        case .plainText: return "doc.text"
        }
    }

    var iconColor: SwiftUI.Color {
        switch self {
        case .markdown: return .blue
        case .swift: return .orange
        case .javascript: return .yellow
        case .typescript: return .blue
        case .python: return .green
        case .ruby: return .red
        case .go: return .cyan
        case .rust: return .orange
        case .java: return .red
        case .kotlin: return .purple
        case .csharp: return .purple
        case .cpp, .c: return .blue
        case .objectiveC: return .orange
        case .php: return .indigo
        case .html: return .orange
        case .css, .scss: return .blue
        case .json: return .yellow
        case .yaml: return .pink
        case .xml: return .orange
        case .sql: return .blue
        case .shell: return .green
        case .dockerfile: return .blue
        case .gitignore: return .gray
        case .plainText: return .secondary
        }
    }

    var useSyntaxHighlighting: Bool {
        switch self {
        case .swift, .javascript, .typescript, .python, .ruby, .go, .rust,
             .java, .kotlin, .csharp, .cpp, .c, .objectiveC, .php:
            return true
        default:
            return false
        }
    }

    var useMarkdownRendering: Bool {
        self == .markdown
    }
}

// MARK: - Fast File Content View

struct FastFileContentView: NSViewRepresentable {
    let content: String
    let fileType: FileType
    let showLineNumbers: Bool
    let isDarkMode: Bool

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = createOptimizedScrollView()
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        let attributed: NSAttributedString

        if fileType.useMarkdownRendering {
            attributed = FastMarkdownRenderer.render(content, isDarkMode: isDarkMode)
        } else if fileType.useSyntaxHighlighting && fileType == .swift {
            attributed = renderSwiftWithSplash()
        } else {
            attributed = renderCode()
        }

        textView.textStorage?.setAttributedString(attributed)
    }

    private func createOptimizedScrollView() -> NSScrollView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: DesignTokens.Spacing.lg, height: DesignTokens.Spacing.md)

        // Performance
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.usesFontPanel = false
        textView.usesRuler = false
        textView.allowsUndo = false
        textView.layoutManager?.allowsNonContiguousLayout = true

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.wantsLayer = true

        return scrollView
    }

    // MARK: - Renderers

    private func renderSwiftWithSplash() -> NSAttributedString {
        let fontSize: CGFloat = 13 // DesignTokens.Typography.body base size
        let theme: Splash.Theme = isDarkMode ? .midnight(withFont: .init(size: fontSize)) : .presentation(withFont: .init(size: fontSize))
        let highlighter = Splash.SyntaxHighlighter(format: AttributedStringOutputFormat(theme: theme))

        if showLineNumbers {
            return addLineNumbers(to: highlighter.highlight(content))
        } else {
            return highlighter.highlight(content)
        }
    }

    private func renderCode() -> NSAttributedString {
        let styles = CodeStyles(isDarkMode: isDarkMode, fileType: fileType)
        let result = NSMutableAttributedString()

        let lines = content.components(separatedBy: "\n")
        let lineNumWidth = String(lines.count).count

        for (index, line) in lines.enumerated() {
            // Line number
            if showLineNumbers {
                let lineNum = String(format: "%\(lineNumWidth)d  ", index + 1)
                result.append(NSAttributedString(string: lineNum, attributes: styles.lineNumber))
            }

            // Syntax highlight the line
            let highlightedLine = highlightLine(line, styles: styles)
            result.append(highlightedLine)
            result.append(NSAttributedString(string: "\n", attributes: styles.plain))
        }

        return result
    }

    private func highlightLine(_ line: String, styles: CodeStyles) -> NSAttributedString {
        let result = NSMutableAttributedString()

        // Simple keyword-based highlighting
        var remaining = line[...]

        while !remaining.isEmpty {
            // Check for string literals
            if remaining.first == "\"" || remaining.first == "'" {
                let quote = remaining.first!
                var endIndex = remaining.index(after: remaining.startIndex)

                while endIndex < remaining.endIndex {
                    if remaining[endIndex] == quote && remaining[remaining.index(before: endIndex)] != "\\" {
                        endIndex = remaining.index(after: endIndex)
                        break
                    }
                    endIndex = remaining.index(after: endIndex)
                }

                let str = String(remaining[..<endIndex])
                result.append(NSAttributedString(string: str, attributes: styles.string))
                remaining = remaining[endIndex...]
                continue
            }

            // Check for comments
            if remaining.hasPrefix("//") || remaining.hasPrefix("#") {
                let comment = String(remaining)
                result.append(NSAttributedString(string: comment, attributes: styles.comment))
                break
            }

            if remaining.hasPrefix("/*") {
                if let endRange = remaining.range(of: "*/") {
                    let comment = String(remaining[..<endRange.upperBound])
                    result.append(NSAttributedString(string: comment, attributes: styles.comment))
                    remaining = remaining[endRange.upperBound...]
                    continue
                }
            }

            // Check for numbers
            if let first = remaining.first, first.isNumber {
                var endIndex = remaining.startIndex
                while endIndex < remaining.endIndex && (remaining[endIndex].isNumber || remaining[endIndex] == ".") {
                    endIndex = remaining.index(after: endIndex)
                }
                let num = String(remaining[..<endIndex])
                result.append(NSAttributedString(string: num, attributes: styles.number))
                remaining = remaining[endIndex...]
                continue
            }

            // Check for keywords
            if let first = remaining.first, first.isLetter || first == "_" {
                var endIndex = remaining.startIndex
                while endIndex < remaining.endIndex && (remaining[endIndex].isLetter || remaining[endIndex].isNumber || remaining[endIndex] == "_") {
                    endIndex = remaining.index(after: endIndex)
                }
                let word = String(remaining[..<endIndex])

                if styles.keywords.contains(word) {
                    result.append(NSAttributedString(string: word, attributes: styles.keyword))
                } else if styles.types.contains(word) {
                    result.append(NSAttributedString(string: word, attributes: styles.type))
                } else {
                    result.append(NSAttributedString(string: word, attributes: styles.plain))
                }
                remaining = remaining[endIndex...]
                continue
            }

            // Regular character
            result.append(NSAttributedString(string: String(remaining.first!), attributes: styles.plain))
            remaining = remaining.dropFirst()
        }

        return result
    }

    private func addLineNumbers(to attributed: NSAttributedString) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let lines = attributed.string.components(separatedBy: "\n")
        let lineNumWidth = String(lines.count).count

        let lineNumAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular), // DesignTokens.Typography.callout
            .foregroundColor: NSColor.tertiaryLabelColor
        ]

        var currentLocation = 0
        for (index, line) in lines.enumerated() {
            let lineNum = String(format: "%\(lineNumWidth)d  ", index + 1)
            result.append(NSAttributedString(string: lineNum, attributes: lineNumAttrs))

            let lineRange = NSRange(location: currentLocation, length: line.utf16.count)
            if lineRange.location + lineRange.length <= attributed.length {
                result.append(attributed.attributedSubstring(from: lineRange))
            }

            if index < lines.count - 1 {
                result.append(NSAttributedString(string: "\n"))
                currentLocation += line.utf16.count + 1
            }
        }

        return result
    }
}

// MARK: - Code Styles

struct CodeStyles {
    let plain: [NSAttributedString.Key: Any]
    let keyword: [NSAttributedString.Key: Any]
    let type: [NSAttributedString.Key: Any]
    let string: [NSAttributedString.Key: Any]
    let comment: [NSAttributedString.Key: Any]
    let number: [NSAttributedString.Key: Any]
    let lineNumber: [NSAttributedString.Key: Any]
    let keywords: Set<String>
    let types: Set<String>

    init(isDarkMode: Bool, fileType: FileType) {
        let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular) // DesignTokens.Typography.body base
        let textColor = isDarkMode ? NSColor.white : NSColor.textColor

        plain = [.font: font, .foregroundColor: textColor]

        keyword = [
            .font: font,
            .foregroundColor: isDarkMode ?
                NSColor(calibratedRed: 0.99, green: 0.37, blue: 0.53, alpha: 1) :
                NSColor(calibratedRed: 0.61, green: 0.10, blue: 0.58, alpha: 1)
        ]

        type = [
            .font: font,
            .foregroundColor: isDarkMode ?
                NSColor(calibratedRed: 0.56, green: 0.80, blue: 0.98, alpha: 1) :
                NSColor(calibratedRed: 0.11, green: 0.38, blue: 0.56, alpha: 1)
        ]

        string = [
            .font: font,
            .foregroundColor: isDarkMode ?
                NSColor(calibratedRed: 0.99, green: 0.51, blue: 0.39, alpha: 1) :
                NSColor(calibratedRed: 0.77, green: 0.10, blue: 0.09, alpha: 1)
        ]

        comment = [
            .font: font,
            .foregroundColor: isDarkMode ?
                NSColor(calibratedRed: 0.51, green: 0.56, blue: 0.61, alpha: 1) :
                NSColor(calibratedRed: 0.42, green: 0.47, blue: 0.52, alpha: 1)
        ]

        number = [
            .font: font,
            .foregroundColor: isDarkMode ?
                NSColor(calibratedRed: 0.82, green: 0.68, blue: 0.98, alpha: 1) :
                NSColor(calibratedRed: 0.11, green: 0.38, blue: 0.94, alpha: 1)
        ]

        lineNumber = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular), // DesignTokens.Typography.callout
            .foregroundColor: NSColor.tertiaryLabelColor
        ]

        // Keywords by language family
        switch fileType {
        case .swift, .kotlin:
            keywords = ["func", "var", "let", "class", "struct", "enum", "protocol", "extension",
                       "if", "else", "guard", "switch", "case", "default", "for", "while", "repeat",
                       "return", "throw", "try", "catch", "defer", "import", "public", "private",
                       "internal", "fileprivate", "open", "static", "final", "override", "mutating",
                       "async", "await", "actor", "nil", "true", "false", "self", "super", "init",
                       "deinit", "where", "as", "is", "in", "inout", "throws", "rethrows", "lazy",
                       "weak", "unowned", "some", "any", "associatedtype", "typealias"]
            types = ["String", "Int", "Double", "Float", "Bool", "Array", "Dictionary", "Set",
                    "Optional", "Result", "Error", "Void", "Any", "AnyObject", "Self", "Type",
                    "URL", "Data", "Date", "UUID", "CGFloat", "CGPoint", "CGSize", "CGRect",
                    "View", "State", "Binding", "Published", "ObservableObject", "Environment"]

        case .javascript, .typescript:
            keywords = ["function", "const", "let", "var", "class", "extends", "implements",
                       "if", "else", "switch", "case", "default", "for", "while", "do",
                       "return", "throw", "try", "catch", "finally", "import", "export", "from",
                       "async", "await", "new", "this", "super", "null", "undefined", "true", "false",
                       "typeof", "instanceof", "in", "of", "delete", "void", "yield", "static",
                       "public", "private", "protected", "interface", "type", "enum", "abstract"]
            types = ["String", "Number", "Boolean", "Object", "Array", "Function", "Promise",
                    "Map", "Set", "Date", "RegExp", "Error", "Symbol", "any", "unknown", "never"]

        case .python:
            keywords = ["def", "class", "if", "elif", "else", "for", "while", "try", "except",
                       "finally", "with", "as", "import", "from", "return", "yield", "raise",
                       "pass", "break", "continue", "lambda", "and", "or", "not", "in", "is",
                       "None", "True", "False", "async", "await", "global", "nonlocal", "assert"]
            types = ["str", "int", "float", "bool", "list", "dict", "set", "tuple", "bytes",
                    "type", "object", "Exception", "None"]

        case .go:
            keywords = ["func", "var", "const", "type", "struct", "interface", "map", "chan",
                       "if", "else", "switch", "case", "default", "for", "range", "select",
                       "return", "break", "continue", "goto", "fallthrough", "defer", "go",
                       "package", "import", "nil", "true", "false", "iota"]
            types = ["string", "int", "int8", "int16", "int32", "int64", "uint", "uint8",
                    "uint16", "uint32", "uint64", "float32", "float64", "complex64", "complex128",
                    "bool", "byte", "rune", "error", "any"]

        case .rust:
            keywords = ["fn", "let", "mut", "const", "static", "struct", "enum", "trait", "impl",
                       "if", "else", "match", "loop", "while", "for", "return", "break", "continue",
                       "pub", "mod", "use", "crate", "super", "self", "Self", "as", "in", "ref",
                       "move", "async", "await", "dyn", "where", "unsafe", "extern", "type"]
            types = ["String", "str", "i8", "i16", "i32", "i64", "i128", "isize",
                    "u8", "u16", "u32", "u64", "u128", "usize", "f32", "f64",
                    "bool", "char", "Vec", "Option", "Result", "Box", "Rc", "Arc"]

        case .java, .csharp:
            keywords = ["public", "private", "protected", "static", "final", "abstract", "class",
                       "interface", "extends", "implements", "if", "else", "switch", "case",
                       "default", "for", "while", "do", "return", "throw", "try", "catch", "finally",
                       "new", "this", "super", "null", "true", "false", "void", "import", "package",
                       "instanceof", "synchronized", "volatile", "transient", "native", "enum",
                       "async", "await", "var", "using", "namespace", "virtual", "override", "sealed"]
            types = ["String", "int", "long", "short", "byte", "float", "double", "boolean", "char",
                    "Integer", "Long", "Float", "Double", "Boolean", "Object", "List", "Map", "Set",
                    "ArrayList", "HashMap", "HashSet", "Exception", "Void"]

        case .ruby:
            keywords = ["def", "end", "class", "module", "if", "elsif", "else", "unless", "case",
                       "when", "while", "until", "for", "do", "begin", "rescue", "ensure", "raise",
                       "return", "yield", "break", "next", "redo", "retry", "self", "super",
                       "nil", "true", "false", "and", "or", "not", "in", "then", "attr_accessor",
                       "attr_reader", "attr_writer", "require", "include", "extend", "prepend"]
            types = ["String", "Integer", "Float", "Array", "Hash", "Symbol", "Proc", "Lambda",
                    "Class", "Module", "Object", "NilClass", "TrueClass", "FalseClass"]

        case .php:
            keywords = ["function", "class", "interface", "trait", "extends", "implements",
                       "public", "private", "protected", "static", "final", "abstract",
                       "if", "else", "elseif", "switch", "case", "default", "for", "foreach",
                       "while", "do", "return", "throw", "try", "catch", "finally",
                       "new", "echo", "print", "die", "exit", "include", "require", "use",
                       "namespace", "null", "true", "false", "const", "global", "array", "fn"]
            types = ["string", "int", "float", "bool", "array", "object", "callable", "iterable",
                    "void", "mixed", "null", "self", "static", "parent"]

        case .shell:
            keywords = ["if", "then", "else", "elif", "fi", "case", "esac", "for", "while",
                       "do", "done", "in", "function", "return", "exit", "break", "continue",
                       "local", "export", "readonly", "declare", "typeset", "unset", "shift",
                       "true", "false", "source", "alias", "eval", "exec", "trap"]
            types = []

        case .sql:
            keywords = ["SELECT", "FROM", "WHERE", "JOIN", "LEFT", "RIGHT", "INNER", "OUTER",
                       "ON", "AND", "OR", "NOT", "IN", "IS", "NULL", "LIKE", "BETWEEN",
                       "ORDER", "BY", "ASC", "DESC", "GROUP", "HAVING", "LIMIT", "OFFSET",
                       "INSERT", "INTO", "VALUES", "UPDATE", "SET", "DELETE", "CREATE",
                       "TABLE", "INDEX", "VIEW", "DROP", "ALTER", "ADD", "COLUMN", "PRIMARY",
                       "KEY", "FOREIGN", "REFERENCES", "UNIQUE", "DEFAULT", "CHECK", "CONSTRAINT",
                       "select", "from", "where", "join", "left", "right", "inner", "outer",
                       "on", "and", "or", "not", "in", "is", "null", "like", "between",
                       "order", "by", "asc", "desc", "group", "having", "limit", "offset",
                       "insert", "into", "values", "update", "set", "delete", "create",
                       "table", "index", "view", "drop", "alter", "add", "column", "primary",
                       "key", "foreign", "references", "unique", "default", "check", "constraint"]
            types = ["INT", "INTEGER", "VARCHAR", "TEXT", "BOOLEAN", "DATE", "TIMESTAMP",
                    "FLOAT", "DOUBLE", "DECIMAL", "BLOB", "CHAR", "BIGINT", "SMALLINT",
                    "int", "integer", "varchar", "text", "boolean", "date", "timestamp",
                    "float", "double", "decimal", "blob", "char", "bigint", "smallint"]

        default:
            keywords = []
            types = []
        }
    }
}

// MARK: - Splash Theme Extension

extension Splash.Theme {
    static func midnight(withFont font: Splash.Font) -> Splash.Theme {
        Splash.Theme(
            font: font,
            plainTextColor: NSColor(calibratedRed: 0.9, green: 0.9, blue: 0.9, alpha: 1),
            tokenColors: [
                Splash.TokenType.keyword: NSColor(calibratedRed: 0.99, green: 0.37, blue: 0.53, alpha: 1),
                Splash.TokenType.string: NSColor(calibratedRed: 0.99, green: 0.51, blue: 0.39, alpha: 1),
                Splash.TokenType.type: NSColor(calibratedRed: 0.56, green: 0.80, blue: 0.98, alpha: 1),
                Splash.TokenType.call: NSColor(calibratedRed: 0.56, green: 0.80, blue: 0.98, alpha: 1),
                Splash.TokenType.number: NSColor(calibratedRed: 0.82, green: 0.68, blue: 0.98, alpha: 1),
                Splash.TokenType.comment: NSColor(calibratedRed: 0.51, green: 0.56, blue: 0.61, alpha: 1),
                Splash.TokenType.property: NSColor(calibratedRed: 0.56, green: 0.80, blue: 0.98, alpha: 1),
                Splash.TokenType.dotAccess: NSColor(calibratedRed: 0.56, green: 0.80, blue: 0.98, alpha: 1),
                Splash.TokenType.preprocessing: NSColor(calibratedRed: 0.99, green: 0.75, blue: 0.52, alpha: 1)
            ],
            backgroundColor: NSColor(calibratedRed: 0.15, green: 0.16, blue: 0.18, alpha: 1)
        )
    }
}

// MARK: - Preview

#if DEBUG
struct FileContentView_Previews: PreviewProvider {
    static let swiftCode = """
    import Foundation

    struct User: Codable {
        let id: Int
        let name: String
        var isActive: Bool = true

        func greet() -> String {
            return "Hello, \\(name)!"
        }
    }

    // Create a new user
    let user = User(id: 1, name: "John")
    print(user.greet())
    """

    static var previews: some View {
        FileContentView(content: swiftCode, fileName: "User.swift")
            .frame(width: 600, height: 400)
    }
}
#endif
