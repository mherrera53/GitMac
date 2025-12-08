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
        let name = (filename as NSString).lastPathComponent.lowercased()

        // Check special filenames first
        if name == "dockerfile" || name.hasPrefix("dockerfile.") { return "docker" }
        if name == "makefile" || name == "gnumakefile" { return "makefile" }
        if name == "gemfile" || name == "rakefile" { return "ruby" }
        if name == "podfile" { return "cocoapods" }
        if name == "cartfile" { return "carthage" }
        if name.hasSuffix(".d.ts") { return "ts-def" }

        switch ext {
        // === Programming Languages ===
        // Swift
        case "swift", "swiftmodule", "swiftdeps", "swiftconstvalues": return "swift"

        // JavaScript/TypeScript
        case "js", "jsx", "mjs", "cjs": return "js"
        case "ts", "tsx", "mts", "cts": return "ts"

        // PHP
        case "php", "phtml", "phps", "inc": return "php"

        // Python
        case "py", "pyw", "pyx", "pxd": return "python"

        // Java/JVM
        case "java": return "java"
        case "kt", "kts": return "kotlin"
        case "gradle": return "gradle"
        case "jar": return "jar"

        // C/C++/Objective-C
        case "c": return "c"
        case "h", "hh", "hpp": return "header"
        case "cpp", "cc", "cxx", "c++": return "cpp"
        case "m", "mm": return "objc"

        // C#/.NET
        case "cs": return "csharp"
        case "dll", "exe": return "dotnet"

        // Ruby
        case "rb", "erb", "rake": return "ruby"

        // Go
        case "go": return "go"

        // Rust
        case "rs": return "rust"

        // Other languages
        case "lua": return "lua"
        case "r": return "r"
        case "pl", "pm": return "perl"
        case "coffee": return "coffee"
        case "scala": return "scala"
        case "clj", "cljs": return "clojure"
        case "ex", "exs": return "elixir"
        case "erl", "hrl": return "erlang"
        case "hs": return "haskell"
        case "ml", "mli": return "ocaml"
        case "fs", "fsx": return "fsharp"
        case "vb": return "vb"
        case "dart": return "dart"
        case "elm": return "elm"
        case "proto": return "protobuf"
        case "graphql", "gql": return "graphql"
        case "wasm", "wat": return "wasm"

        // === Web Technologies ===
        case "html", "htm", "xhtml": return "html"
        case "css": return "css"
        case "scss", "sass": return "sass"
        case "less": return "less"
        case "styl": return "stylus"
        case "vue": return "vue"
        case "svelte": return "svelte"
        case "ejs", "hbs", "handlebars": return "template"
        case "tpl", "jst": return "template"
        case "pug", "jade": return "pug"

        // === Data/Config Files ===
        case "json", "json5": return "json"
        case "xml", "xsd", "xsl", "xslt": return "xml"
        case "yaml", "yml": return "yaml"
        case "toml": return "toml"
        case "ini", "cfg", "conf": return "config"
        case "csv", "tsv": return "csv"
        case "sql", "sqlite", "db": return "database"
        case "env": return "env"
        case "properties": return "properties"
        case "plist": return "plist"
        case "neon": return "neon"

        // === Documents ===
        case "md", "markdown", "mdx": return "markdown"
        case "txt", "text": return "text"
        case "rst": return "rst"
        case "pdf": return "pdf"
        case "doc", "docx": return "word"
        case "xls", "xlsx": return "excel"
        case "ppt", "pptx": return "powerpoint"
        case "rtf": return "rtf"
        case "tex", "latex": return "latex"
        case "log": return "log"
        case "po", "pot", "mo": return "i18n"

        // === Images ===
        case "png", "jpg", "jpeg", "gif", "bmp", "tiff", "tif": return "image"
        case "svg": return "svg"
        case "ico", "icns": return "icon"
        case "webp", "avif", "heic", "heif": return "image"
        case "psd": return "photoshop"
        case "ai", "eps": return "illustrator"
        case "sketch": return "sketch"
        case "fig", "figma": return "figma"
        case "xd": return "xd"
        case "raw", "cr2", "nef", "arw": return "raw"
        case "cur": return "cursor"

        // === Fonts ===
        case "ttf", "otf": return "font"
        case "woff", "woff2": return "webfont"
        case "eot": return "font"
        case "pfb", "afm", "ufm": return "font"

        // === Audio ===
        case "mp3", "wav", "aac", "flac", "m4a", "ogg", "wma": return "audio"
        case "mid", "midi": return "midi"
        case "pcm": return "audio"

        // === Video ===
        case "mp4", "mov", "avi", "mkv", "webm", "wmv", "flv", "m4v": return "video"

        // === Archives ===
        case "zip", "rar", "7z", "tar", "gz", "bz2", "xz", "z": return "archive"
        case "dmg", "iso", "img": return "disk"
        case "deb", "rpm": return "package"
        case "pack", "idx": return "gitpack"

        // === Git/Version Control ===
        case "gitignore", "gitattributes", "gitkeep", "gitmodules": return "git"

        // === Config/Linting ===
        case "eslintrc", "eslintignore": return "eslint"
        case "prettierrc", "prettierignore": return "prettier"
        case "babelrc": return "babel"
        case "editorconfig": return "editorconfig"
        case "npmignore", "npmrc": return "npm"
        case "nvmrc": return "nvm"
        case "jshintrc", "jshintignore": return "jshint"
        case "stylelintrc": return "stylelint"
        case "browserslistrc": return "browserslist"

        // === Shell/Scripts ===
        case "sh", "bash", "zsh", "fish": return "shell"
        case "ps1", "psm1", "psd1": return "powershell"
        case "bat", "cmd": return "batch"

        // === DevOps/CI ===
        case "dockerfile": return "docker"
        case "dockerignore": return "docker"
        case "vagrantfile": return "vagrant"
        case "tf", "tfvars": return "terraform"
        case "k8s", "helm": return "kubernetes"

        // === Certificates/Keys ===
        case "pem", "crt", "cer", "key", "pub", "priv": return "certificate"
        case "p12", "pfx": return "certificate"

        // === Build/Binary ===
        case "o", "a", "so", "dylib": return "binary"
        case "d": return "dependency"
        case "map": return "sourcemap"
        case "lock": return "lock"
        case "snap": return "snapshot"

        // === iOS/macOS Development ===
        case "xcodeproj", "xcworkspace": return "xcode"
        case "storyboard", "xib", "nib": return "interface"
        case "xcassets": return "assets"
        case "entitlements": return "entitlements"
        case "xcconfig": return "xcconfig"
        case "modulemap": return "modulemap"
        case "dia": return "diagram"

        // === Android ===
        case "apk", "aab": return "android"
        case "iml": return "intellij"

        // === Email ===
        case "eml", "msg": return "email"

        // === Other ===
        case "flow": return "flow"
        case "bnf", "ebnf": return "grammar"
        case "dot", "gv": return "graphviz"
        case "sample": return "sample"
        case "stub": return "stub"
        case "bak", "backup", "old": return "backup"
        case "tmp", "temp": return "temp"
        case "patch", "diff": return "diff"
        case "htaccess": return "apache"
        case "nginx": return "nginx"
        case "node": return "node"
        case "nix": return "nix"
        case "bcmap": return "cmap"
        case "pdl": return "protocol"
        case "fdf": return "formdata"
        case "dcm": return "dicom"
        case "rev": return "revision"

        default:
            return "file"
        }
    }

    static func systemIcon(for filename: String) -> String {
        let type = icon(for: filename)

        switch type {
        // Languages
        case "swift": return "swift"
        case "js", "ts", "ts-def": return "chevron.left.forwardslash.chevron.right"
        case "php": return "p.circle"
        case "python": return "chevron.left.forwardslash.chevron.right"
        case "java", "kotlin", "gradle", "jar": return "cup.and.saucer"
        case "c", "cpp", "header", "objc": return "c.circle"
        case "csharp", "dotnet": return "number"
        case "ruby": return "diamond"
        case "go": return "g.circle"
        case "rust": return "gearshape.2"
        case "lua", "perl", "r": return "function"
        case "coffee": return "cup.and.saucer"
        case "scala", "clojure", "elixir", "erlang", "haskell", "ocaml", "fsharp": return "function"
        case "dart": return "d.circle"
        case "elm": return "leaf"
        case "wasm": return "memorychip"

        // Web
        case "html": return "globe"
        case "css", "sass", "less", "stylus": return "paintbrush"
        case "vue": return "v.circle"
        case "svelte": return "s.circle"
        case "template", "pug": return "doc.text"

        // Data
        case "json", "xml", "yaml", "toml", "config", "properties", "plist", "neon": return "curlybraces"
        case "csv": return "tablecells"
        case "database": return "cylinder"
        case "graphql": return "point.3.connected.trianglepath.dotted"
        case "protobuf": return "doc.badge.gearshape"
        case "env": return "key"

        // Documents
        case "markdown", "text", "rst": return "doc.text"
        case "pdf": return "doc.richtext"
        case "word": return "doc.text.fill"
        case "excel": return "tablecells.fill"
        case "powerpoint": return "rectangle.on.rectangle"
        case "rtf", "latex": return "doc.text"
        case "log": return "doc.text.magnifyingglass"
        case "i18n": return "globe"

        // Images
        case "image": return "photo"
        case "svg": return "square.on.circle"
        case "icon", "cursor": return "app"
        case "photoshop", "illustrator": return "paintpalette"
        case "sketch", "figma", "xd": return "pencil.and.outline"
        case "raw": return "camera"

        // Fonts
        case "font", "webfont": return "textformat"

        // Audio/Video
        case "audio", "midi", "pcm": return "waveform"
        case "video": return "film"

        // Archives
        case "archive", "package": return "doc.zipper"
        case "disk": return "externaldrive"
        case "gitpack": return "shippingbox"

        // Git/VCS
        case "git": return "arrow.triangle.branch"

        // Config/Linting
        case "eslint", "jshint", "stylelint": return "checkmark.shield"
        case "prettier": return "wand.and.stars"
        case "babel": return "b.circle"
        case "editorconfig": return "slider.horizontal.3"
        case "npm", "nvm": return "shippingbox"
        case "browserslist": return "list.bullet"

        // Shell
        case "shell", "powershell", "batch": return "terminal"

        // DevOps
        case "docker": return "shippingbox"
        case "vagrant": return "v.circle"
        case "terraform": return "building.2"
        case "kubernetes": return "helm"

        // Certificates
        case "certificate": return "lock.shield"

        // Build
        case "binary", "dependency": return "gearshape"
        case "sourcemap": return "map"
        case "lock": return "lock"
        case "snapshot": return "camera.metering.spot"

        // iOS/macOS
        case "xcode": return "hammer"
        case "interface": return "uiwindow.split.2x1"
        case "assets": return "photo.on.rectangle"
        case "entitlements": return "checkmark.seal"
        case "xcconfig", "modulemap": return "gearshape"
        case "diagram": return "point.3.connected.trianglepath.dotted"

        // Android
        case "android": return "apps.iphone"
        case "intellij": return "i.circle"

        // Email
        case "email": return "envelope"

        // Other
        case "flow": return "arrow.right.arrow.left"
        case "grammar": return "text.book.closed"
        case "graphviz": return "point.3.connected.trianglepath.dotted"
        case "sample": return "doc"
        case "stub": return "doc.badge.plus"
        case "backup": return "clock.arrow.circlepath"
        case "temp": return "clock"
        case "diff": return "plus.forwardslash.minus"
        case "apache", "nginx": return "server.rack"
        case "node": return "n.circle"
        case "nix": return "snowflake"
        case "protocol": return "doc.badge.gearshape"
        case "dicom": return "cross.case"
        case "formdata": return "doc.badge.ellipsis"
        case "revision": return "clock.arrow.2.circlepath"
        case "cmap": return "character"

        default: return "doc"
        }
    }

    static func color(for filename: String) -> Color {
        let type = icon(for: filename)

        switch type {
        // Languages
        case "swift": return .orange
        case "js", "ts", "ts-def": return .yellow
        case "php": return .indigo
        case "python": return .blue
        case "java": return .red
        case "kotlin": return .purple
        case "c", "cpp", "header", "objc": return .blue
        case "csharp", "dotnet": return .purple
        case "ruby": return .red
        case "go": return .cyan
        case "rust": return .orange
        case "coffee": return .brown
        case "dart": return .blue
        case "elixir": return .purple
        case "lua": return .blue
        case "scala": return .red
        case "wasm": return .purple

        // Web
        case "html": return .orange
        case "css": return .blue
        case "sass", "less", "stylus": return .pink
        case "vue": return .green
        case "svelte": return .orange

        // Data
        case "json": return .yellow
        case "yaml": return .red
        case "xml": return .orange
        case "database": return .blue
        case "graphql": return .pink
        case "env": return .yellow

        // Documents
        case "markdown": return .blue
        case "pdf": return .red
        case "word": return .blue
        case "excel": return .green
        case "powerpoint": return .orange

        // Images
        case "image", "svg": return .purple
        case "photoshop": return .blue
        case "illustrator": return .orange
        case "sketch": return .yellow
        case "figma": return .purple
        case "xd": return .pink

        // Fonts
        case "font", "webfont": return .gray

        // Audio/Video
        case "audio": return .pink
        case "video": return .purple

        // Archives
        case "archive": return .brown
        case "disk": return .gray

        // Git
        case "git": return .orange

        // Config
        case "eslint": return .purple
        case "prettier": return .pink
        case "babel": return .yellow
        case "docker": return .blue
        case "npm": return .red
        case "terraform": return .purple
        case "kubernetes": return .blue

        // Shell
        case "shell": return .green
        case "powershell": return .blue
        case "batch": return .gray

        // Certificates
        case "certificate": return .green

        // iOS
        case "xcode": return .blue
        case "interface": return .blue
        case "entitlements": return .orange

        // Android
        case "android": return .green

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
