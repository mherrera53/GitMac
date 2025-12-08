import SwiftUI

/// GitKraken-style theme colors
struct GitKrakenTheme {
    // Main backgrounds - GitKraken dark theme
    static let background = Color(hex: "1b1e23")
    static let backgroundSecondary = Color(hex: "222429")
    static let backgroundTertiary = Color(hex: "2b2e33")
    static let sidebar = Color(hex: "141417")
    static let panel = Color(hex: "1f2227")
    static let toolbar = Color(hex: "141417")

    // Text colors
    static let textPrimary = Color(hex: "d8dee9")
    static let textSecondary = Color(hex: "8b949e")
    static let textMuted = Color(hex: "6e7681")

    // Accent colors
    static let accent = Color(hex: "0d94e4")  // GitKraken blue
    static let accentGreen = Color(hex: "2ecc71")
    static let accentOrange = Color(hex: "f39c12")
    static let accentRed = Color(hex: "e74c3c")
    static let accentPurple = Color(hex: "9b59b6")
    static let accentCyan = Color(hex: "00d4aa")

    // Border
    static let border = Color(hex: "30363d")
    static let borderLight = Color(hex: "484f58")

    // Selection
    static let selection = Color(hex: "0d94e4").opacity(0.3)
    static let hover = Color.white.opacity(0.05)

    // Graph lane colors (GitKraken style - reordered for visual impact)
    static let laneColors: [Color] = [
        Color(hex: "0d94e4"),  // Blue (main)
        Color(hex: "9b59b6"),  // Purple
        Color(hex: "e91e63"),  // Pink/Magenta
        Color(hex: "2ecc71"),  // Green
        Color(hex: "f39c12"),  // Orange
        Color(hex: "00d4aa"),  // Cyan
        Color(hex: "e74c3c"),  // Red
        Color(hex: "3498db"),  // Light Blue
        Color(hex: "1abc9c"),  // Teal
        Color(hex: "f1c40f"),  // Yellow
    ]
}

/// Manages the application theme
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @AppStorage("appearance") var appearance: String = "dark" {
        didSet {
            applyAppearance()
        }
    }

    private init() {
        applyAppearance()
    }

    func applyAppearance() {
        // Force dark mode for GitKraken style
        NSApp.appearance = NSAppearance(named: .darkAqua)
    }
}

// MARK: - Colors

extension SwiftUI.Color {
    // Git status colors - GitKraken style
    static let gitAdded = GitKrakenTheme.accentGreen
    static let gitModified = GitKrakenTheme.accentOrange
    static let gitDeleted = GitKrakenTheme.accentRed
    static let gitRenamed = GitKrakenTheme.accent
    static let gitUntracked = GitKrakenTheme.textMuted
    static let gitConflict = GitKrakenTheme.accentRed

    // Branch colors for the commit graph - GitKraken style
    static let branchColors: [Color] = GitKrakenTheme.laneColors

    // Diff colors - GitKraken style
    static let diffAddedBackground = GitKrakenTheme.accentGreen.opacity(0.15)
    static let diffDeletedBackground = GitKrakenTheme.accentRed.opacity(0.15)
    static let diffAddedText = GitKrakenTheme.accentGreen
    static let diffDeletedText = GitKrakenTheme.accentRed

    // UI colors - GitKraken style
    static let sidebarBackground = GitKrakenTheme.sidebar
    static let toolbarBackground = GitKrakenTheme.toolbar
    static let panelBackground = GitKrakenTheme.panel

    /// Initialize from hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    /// Get a branch color by index
    static func branchColor(_ index: Int) -> Color {
        branchColors[index % branchColors.count]
    }
}

// MARK: - File Type Icons

struct FileTypeIcon {
    static func icon(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()

        switch ext {
        // Programming languages
        case "swift": return "swift"
        case "py": return "python"
        case "js", "jsx": return "js"
        case "ts", "tsx": return "ts"
        case "java": return "java"
        case "rb": return "ruby"
        case "go": return "go"
        case "rs": return "rust"
        case "cpp", "cc", "cxx", "c++": return "cpp"
        case "c", "h": return "c"
        case "cs": return "csharp"
        case "php": return "php"
        case "kt": return "kotlin"

        // Web
        case "html", "htm": return "html"
        case "css", "scss", "sass", "less": return "css"
        case "vue": return "vue"
        case "svelte": return "svelte"

        // Data
        case "json": return "json"
        case "xml": return "xml"
        case "yaml", "yml": return "yaml"
        case "toml": return "toml"
        case "csv": return "csv"
        case "sql": return "database"

        // Documents
        case "md", "markdown": return "markdown"
        case "txt": return "text"
        case "pdf": return "pdf"
        case "doc", "docx": return "word"

        // Images
        case "png", "jpg", "jpeg", "gif", "svg", "ico", "webp":
            return "image"

        // Config
        case "gitignore", "gitattributes": return "git"
        case "env": return "env"
        case "dockerfile": return "docker"

        // Shell
        case "sh", "bash", "zsh": return "shell"

        default:
            return "file"
        }
    }

    static func systemIcon(for filename: String) -> String {
        let type = icon(for: filename)

        switch type {
        case "swift": return "swift"
        case "image": return "photo"
        case "json", "xml", "yaml", "toml": return "curlybraces"
        case "markdown", "text": return "doc.text"
        case "pdf": return "doc.richtext"
        case "database": return "cylinder"
        case "git": return "arrow.triangle.branch"
        case "docker": return "shippingbox"
        case "shell": return "terminal"
        default: return "doc"
        }
    }

    static func color(for filename: String) -> Color {
        let type = icon(for: filename)

        switch type {
        case "swift": return .orange
        case "python": return .blue
        case "js", "ts": return .yellow
        case "java": return .red
        case "go": return .cyan
        case "rust": return .orange
        case "html": return .orange
        case "css": return .blue
        case "json": return .yellow
        case "markdown": return .gray
        case "shell": return .green
        case "git": return .orange
        case "docker": return .blue
        default: return .gray
        }
    }
}

// MARK: - View Modifiers

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct HoverEffect: ViewModifier {
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .background(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }

    func hoverEffect() -> some View {
        modifier(HoverEffect())
    }
}

// MARK: - Text Styles

extension Font {
    static let commitMessage = Font.system(.body, design: .default)
    static let commitSHA = Font.system(.caption, design: .monospaced)
    static let codeBlock = Font.system(.body, design: .monospaced)
    static let diffLine = Font.system(.caption, design: .monospaced)
}
