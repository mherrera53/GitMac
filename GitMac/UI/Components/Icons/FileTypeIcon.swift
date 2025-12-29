import SwiftUI

// MARK: - File Type Icon

/// Displays an icon representing a file type based on its extension or name
struct FileTypeIcon: View {
    let fileName: String
    var size: IconSize = .medium

    enum IconSize {
        case small
        case medium
        case large

        var dimension: CGFloat {
            switch self {
            case .small: return 12
            case .medium: return 16
            case .large: return 20
            }
        }
    }

    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: size.dimension))
            .foregroundColor(iconColor)
    }

    // MARK: - Icon Selection

    private var iconName: String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        let name = (fileName as NSString).lastPathComponent.lowercased()

        // Special files
        if name == "readme.md" || name == "readme" {
            return "doc.text"
        }
        if name == "license" || name == "license.txt" || name == "license.md" {
            return "doc.plaintext"
        }
        if name == ".gitignore" || name == ".gitattributes" {
            return "git.branch"
        }
        if name == "package.json" || name == "package-lock.json" {
            return "shippingbox"
        }
        if name == "dockerfile" || name == "docker-compose.yml" {
            return "shippingbox.fill"
        }

        // By extension
        switch ext {
        // Source code
        case "swift":
            return "swift"
        case "js", "jsx", "ts", "tsx":
            return "curlybraces"
        case "py":
            return "chevron.left.forwardslash.chevron.right"
        case "java", "kt":
            return "cup.and.saucer"
        case "go":
            return "hare"
        case "rs":
            return "gearshape.2"
        case "c", "cpp", "cc", "h", "hpp":
            return "c.circle"
        case "rb":
            return "diamond"
        case "php":
            return "p.circle"
        case "cs":
            return "number"
        case "sh", "bash", "zsh":
            return "terminal"

        // Web
        case "html", "htm":
            return "chevron.left.forwardslash.chevron.right"
        case "css", "scss", "sass", "less":
            return "paintbrush"
        case "json":
            return "curlybraces.square"
        case "xml":
            return "doc.text"
        case "yaml", "yml":
            return "list.bullet.rectangle"

        // Documentation
        case "md", "markdown":
            return "doc.richtext"
        case "txt":
            return "doc.plaintext"
        case "pdf":
            return "doc.fill"
        case "doc", "docx":
            return "doc.text.fill"

        // Images
        case "png", "jpg", "jpeg", "gif", "svg", "webp", "ico":
            return "photo"
        case "psd", "ai", "sketch", "fig", "figma":
            return "paintpalette"

        // Data
        case "sql", "db", "sqlite":
            return "cylinder"
        case "csv":
            return "tablecells"
        case "xls", "xlsx":
            return "tablecells.fill"

        // Archives
        case "zip", "tar", "gz", "rar", "7z":
            return "doc.zipper"

        // Config
        case "toml", "ini", "conf", "config":
            return "gearshape"
        case "env":
            return "key"

        // Fonts
        case "ttf", "otf", "woff", "woff2":
            return "textformat"

        // Video/Audio
        case "mp4", "mov", "avi", "mkv":
            return "film"
        case "mp3", "wav", "flac", "m4a":
            return "music.note"

        // Folders
        case "":
            if fileName.hasSuffix("/") {
                return "folder.fill"
            }
            return "doc"

        default:
            return "doc"
        }
    }

    // MARK: - Color Mapping

    private var iconColor: Color {
        let ext = (fileName as NSString).pathExtension.lowercased()

        switch ext {
        case "swift":
            return AppTheme.fileSwift
        case "js", "jsx":
            return AppTheme.fileJavaScript
        case "ts", "tsx":
            return AppTheme.fileTypeScript
        case "py":
            return AppTheme.filePython
        case "java", "kt":
            return AppTheme.fileSwift // Orange like Swift
        case "go":
            return AppTheme.fileTypeScript // Blue
        case "rs":
            return AppTheme.fileSwift // Orange
        case "rb":
            return AppTheme.filePython // Red/Blue
        case "php":
            return AppTheme.filePython // Blue
        case "html", "htm":
            return AppTheme.fileHTML
        case "css", "scss", "sass", "less":
            return AppTheme.fileCSS
        case "json":
            return AppTheme.fileJSON
        case "xml", "yaml", "yml", "toml", "ini":
            return AppTheme.fileConfig
        case "md", "markdown":
            return AppTheme.fileMarkdown
        case "png", "jpg", "jpeg", "gif", "svg", "webp":
            return AppTheme.fileImage
        case "sql", "db", "sqlite":
            return AppTheme.fileTypeScript // Blue
        case "zip", "tar", "gz", "rar", "7z":
            return AppTheme.fileArchive
        default:
            return AppTheme.fileDefault
        }
    }
}

// MARK: - Preview

#if DEBUG
struct FileTypeIcon_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            // Code files
            HStack(spacing: 12) {
                VStack {
                    FileTypeIcon(fileName: "App.swift")
                    Text("Swift")
                        .font(.caption2)
                }
                VStack {
                    FileTypeIcon(fileName: "main.js")
                    Text("JS")
                        .font(.caption2)
                }
                VStack {
                    FileTypeIcon(fileName: "index.ts")
                    Text("TS")
                        .font(.caption2)
                }
                VStack {
                    FileTypeIcon(fileName: "app.py")
                    Text("Python")
                        .font(.caption2)
                }
            }

            // Web files
            HStack(spacing: 12) {
                VStack {
                    FileTypeIcon(fileName: "index.html")
                    Text("HTML")
                        .font(.caption2)
                }
                VStack {
                    FileTypeIcon(fileName: "styles.css")
                    Text("CSS")
                        .font(.caption2)
                }
                VStack {
                    FileTypeIcon(fileName: "data.json")
                    Text("JSON")
                        .font(.caption2)
                }
            }

            // Documents
            HStack(spacing: 12) {
                VStack {
                    FileTypeIcon(fileName: "README.md")
                    Text("Markdown")
                        .font(.caption2)
                }
                VStack {
                    FileTypeIcon(fileName: "doc.txt")
                    Text("Text")
                        .font(.caption2)
                }
                VStack {
                    FileTypeIcon(fileName: "image.png")
                    Text("Image")
                        .font(.caption2)
                }
            }

            // Sizes
            HStack(spacing: 12) {
                FileTypeIcon(fileName: "test.swift", size: .small)
                FileTypeIcon(fileName: "test.swift", size: .medium)
                FileTypeIcon(fileName: "test.swift", size: .large)
            }
        }
        .padding()
    }
}
#endif
