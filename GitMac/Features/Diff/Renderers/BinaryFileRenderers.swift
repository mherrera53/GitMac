import SwiftUI
import AppKit

// MARK: - Binary File Renderers

struct BinaryFileView: View {
    let filename: String
    var repoPath: String? = nil

    private var isImage: Bool {
        let ext = (filename as NSString).pathExtension.lowercased()
        return ["png", "jpg", "jpeg", "gif", "webp", "bmp", "tiff", "ico", "svg"].contains(ext)
    }

    private var isPDF: Bool {
        let ext = (filename as NSString).pathExtension.lowercased()
        return ext == "pdf"
    }

    private var fullPath: URL? {
        guard let repoPath = repoPath else { return nil }
        return URL(fileURLWithPath: repoPath).appendingPathComponent(filename)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.lg) {
                if isImage, let repo = repoPath {
                    // Image diff view with old/new comparison
                    ImageDiffView(filename: filename, repoPath: repo)
                } else if isPDF, let path = fullPath {
                    PDFPreviewView(pdfURL: path, filename: filename)
                } else {
                    GenericBinaryView(filename: filename)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(DesignTokens.Spacing.lg)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}

// MARK: - Image Diff View

enum ImageDiffMode: String, CaseIterable {
    case sideBySide = "Side by Side"
    case onionSkin = "Onion Skin"
    case swipe = "Swipe"
}

struct ImageDiffView: View {
    let filename: String
    let repoPath: String

    @State private var diffMode: ImageDiffMode = .sideBySide
    @State private var opacity: Double = 0.5
    @State private var swipePosition: CGFloat = 0.5
    @State private var oldImage: NSImage?
    @State private var newImage: NSImage?
    @State private var oldSize: CGSize = .zero
    @State private var newSize: CGSize = .zero
    @State private var oldFileSize: Int64 = 0
    @State private var newFileSize: Int64 = 0
    @State private var isLoading = true

    private var fullPath: URL {
        URL(fileURLWithPath: repoPath).appendingPathComponent(filename)
    }

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            // Header
            HStack {
                Image(systemName: "photo.on.rectangle.angled")
                    .foregroundStyle(AppTheme.accent)
                Text(filename)
                    .font(DesignTokens.Typography.headline)
                Spacer()
                Picker("", selection: $diffMode) {
                    ForEach(ImageDiffMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 280)
            }

            if isLoading {
                ProgressView("Loading images...")
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else if oldImage == nil && newImage != nil {
                // New file
                VStack(spacing: DesignTokens.Spacing.sm) {
                    Label("New image", systemImage: "plus.circle.fill")
                        .foregroundStyle(AppTheme.diffAddition)
                        .font(DesignTokens.Typography.callout)
                    imageView(newImage, label: "New")
                    imageSizeInfo(size: newSize, fileSize: newFileSize)
                }
            } else if oldImage != nil && newImage == nil {
                // Deleted file
                VStack(spacing: DesignTokens.Spacing.sm) {
                    Label("Deleted image", systemImage: "minus.circle.fill")
                        .foregroundStyle(AppTheme.diffDeletion)
                        .font(DesignTokens.Typography.callout)
                    imageView(oldImage, label: "Old")
                    imageSizeInfo(size: oldSize, fileSize: oldFileSize)
                }
            } else if let old = oldImage, let new = newImage {
                // Modified - show comparison
                switch diffMode {
                case .sideBySide:
                    sideBySideView(old: old, new: new)
                case .onionSkin:
                    onionSkinView(old: old, new: new)
                case .swipe:
                    swipeView(old: old, new: new)
                }

                // Size delta
                sizeDeltaInfo
            } else {
                GenericBinaryView(filename: filename)
            }
        }
        .task {
            await loadImages()
        }
    }

    // MARK: - Side by Side

    private func sideBySideView(old: NSImage, new: NSImage) -> some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            VStack(spacing: DesignTokens.Spacing.xs) {
                Text("Before")
                    .font(DesignTokens.Typography.caption.weight(.medium))
                    .foregroundStyle(AppTheme.diffDeletion)
                imageView(old, label: "Old")
                imageSizeInfo(size: oldSize, fileSize: oldFileSize)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: DesignTokens.Spacing.xs) {
                Text("After")
                    .font(DesignTokens.Typography.caption.weight(.medium))
                    .foregroundStyle(AppTheme.diffAddition)
                imageView(new, label: "New")
                imageSizeInfo(size: newSize, fileSize: newFileSize)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Onion Skin

    private func onionSkinView(old: NSImage, new: NSImage) -> some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            ZStack {
                Image(nsImage: old)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .opacity(1 - opacity)

                Image(nsImage: new)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .opacity(opacity)
            }
            .frame(maxWidth: 700, maxHeight: 500)
            .background(CheckerboardPattern())
            .clipShape(.rect(cornerRadius: DesignTokens.CornerRadius.md))

            HStack(spacing: DesignTokens.Spacing.sm) {
                Text("Old")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(AppTheme.diffDeletion)
                Slider(value: $opacity, in: 0...1)
                    .frame(width: 200)
                Text("New")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(AppTheme.diffAddition)
            }
        }
    }

    // MARK: - Swipe

    private func swipeView(old: NSImage, new: NSImage) -> some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            GeometryReader { geo in
                ZStack {
                    Image(nsImage: new)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geo.size.width)

                    Image(nsImage: old)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geo.size.width)
                        .clipShape(
                            Rectangle()
                                .offset(x: 0)
                                .size(width: geo.size.width * swipePosition, height: geo.size.height)
                        )

                    // Divider line
                    Rectangle()
                        .fill(AppTheme.accent)
                        .frame(width: 2)
                        .offset(x: geo.size.width * swipePosition - geo.size.width / 2)
                }
                .background(CheckerboardPattern())
                .clipShape(.rect(cornerRadius: DesignTokens.CornerRadius.md))
            }
            .frame(maxWidth: 700, maxHeight: 500)

            Slider(value: $swipePosition, in: 0...1)
                .frame(width: 300)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func imageView(_ image: NSImage?, label: String) -> some View {
        if let img = image {
            Image(nsImage: img)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 400, maxHeight: 400)
                .background(CheckerboardPattern())
                .clipShape(.rect(cornerRadius: DesignTokens.CornerRadius.md))
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        }
    }

    private func imageSizeInfo(size: CGSize, fileSize: Int64) -> some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            if size != .zero {
                Text("\(Int(size.width)) × \(Int(size.height))")
                    .font(DesignTokens.Typography.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            if fileSize > 0 {
                Text(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))
                    .font(DesignTokens.Typography.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    private var sizeDeltaInfo: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            if oldSize != .zero && newSize != .zero {
                if oldSize != newSize {
                    Text("Dimensions: \(Int(oldSize.width))×\(Int(oldSize.height)) → \(Int(newSize.width))×\(Int(newSize.height))")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            if oldFileSize > 0 && newFileSize > 0 {
                let delta = newFileSize - oldFileSize
                let sign = delta >= 0 ? "+" : ""
                Text("Size: \(sign)\(ByteCountFormatter.string(fromByteCount: delta, countStyle: .file))")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(delta > 0 ? AppTheme.diffDeletion : AppTheme.diffAddition)
            }
        }
    }

    private func loadImages() async {
        isLoading = true
        defer { isLoading = false }

        // Load new image from working copy
        let newURL = fullPath
        if FileManager.default.fileExists(atPath: newURL.path) {
            if let img = NSImage(contentsOf: newURL) {
                newImage = img
                newSize = img.size
            }
            if let attrs = try? FileManager.default.attributesOfItem(atPath: newURL.path),
               let size = attrs[.size] as? Int64 {
                newFileSize = size
            }
        }

        // Load old image from git HEAD via temp file (binary-safe)
        let tempPath = NSTemporaryDirectory() + "gitmac_imgdiff_\(UUID().uuidString).\((filename as NSString).pathExtension)"
        defer { try? FileManager.default.removeItem(atPath: tempPath) }
        let shell = ShellExecutor()
        let result = await shell.execute(
            "bash",
            arguments: ["-c", "git show HEAD:\(filename) > \(tempPath)"],
            workingDirectory: repoPath
        )
        if result.exitCode == 0, FileManager.default.fileExists(atPath: tempPath) {
            let tempURL = URL(fileURLWithPath: tempPath)
            if let data = try? Data(contentsOf: tempURL), let img = NSImage(data: data) {
                oldImage = img
                oldSize = img.size
                oldFileSize = Int64(data.count)
            }
        }
    }
}

// MARK: - Image Preview

struct ImagePreviewView: View {
    let imageURL: URL
    let filename: String
    @State private var imageSize: CGSize = .zero

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            // Header
            HStack {
                Image(systemName: "photo")
                    .foregroundColor(AppTheme.accent)
                Text(filename)
                    .font(DesignTokens.Typography.headline)
                Spacer()
                if imageSize != .zero {
                    Text("\(Int(imageSize.width)) × \(Int(imageSize.height))")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(AppTheme.textPrimary)
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .padding(.vertical, DesignTokens.Spacing.xs)
                        .background(AppTheme.textSecondary.opacity(0.2))
                        .cornerRadius(DesignTokens.CornerRadius.sm)
                }
            }

            // Image preview with max size
            if let nsImage = NSImage(contentsOf: imageURL) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 800, maxHeight: 600)
                    .background(
                        // Checkerboard pattern for transparent images
                        CheckerboardPattern()
                    )
                    .cornerRadius(DesignTokens.CornerRadius.md)
                    .shadow(color: .black.opacity(0.2), radius: DesignTokens.Spacing.xs, x: 0, y: DesignTokens.Spacing.xxs)
                    .onAppear {
                        imageSize = nsImage.size
                    }
            } else {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(DesignTokens.Typography.largeTitle)
                        .foregroundColor(AppTheme.warning)
                    Text("Could not load image")
                        .foregroundColor(AppTheme.textPrimary)
                }
                .frame(height: 200)
            }

            // File info
            if let attrs = try? FileManager.default.attributesOfItem(atPath: imageURL.path),
               let fileSize = attrs[.size] as? Int64 {
                Text(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.textPrimary)
            }
        }
    }
}

// MARK: - Checkerboard Pattern (for transparent images)

struct CheckerboardPattern: View {
    var body: some View {
        Canvas { context, size in
            let squareSize: CGFloat = 10
            let light = AppTheme.textMuted.opacity(0.2)
            let dark = AppTheme.textMuted.opacity(0.3)

            for row in 0..<Int(size.height / squareSize) + 1 {
                for col in 0..<Int(size.width / squareSize) + 1 {
                    let isLight = (row + col) % 2 == 0
                    let rect = CGRect(
                        x: CGFloat(col) * squareSize,
                        y: CGFloat(row) * squareSize,
                        width: squareSize,
                        height: squareSize
                    )
                    context.fill(Rectangle().path(in: rect), with: .color(isLight ? light : dark))
                }
            }
        }
    }
}

// MARK: - PDF Preview

struct PDFPreviewView: View {
    let pdfURL: URL
    let filename: String

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            HStack {
                Image(systemName: "doc.richtext")
                    .foregroundColor(AppTheme.error)
                Text(filename)
                    .font(DesignTokens.Typography.headline)
                Spacer()
            }

            // Quick Look preview or fallback
            if let pdfData = try? Data(contentsOf: pdfURL),
               let pdfDoc = NSPDFImageRep(data: pdfData) {
                VStack {
                    Image(nsImage: pdfDoc.pdfImage ?? NSImage())
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 600, maxHeight: 800)
                        .background(AppTheme.textPrimary)
                        .cornerRadius(DesignTokens.CornerRadius.md)
                        .shadow(color: .black.opacity(0.2), radius: DesignTokens.Spacing.xs, x: 0, y: DesignTokens.Spacing.xxs)

                    Text("\(pdfDoc.pageCount) page(s)")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(AppTheme.textPrimary)
                }
            } else {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "doc.richtext")
                        .font(DesignTokens.Typography.iconXXXXL)
                        .foregroundColor(AppTheme.error)
                    Text("PDF Document")
                        .font(DesignTokens.Typography.headline)
                    Button("Open in Preview") {
                        NSWorkspace.shared.open(pdfURL)
                    }
                }
                .frame(height: 200)
            }
        }
    }
}

extension NSPDFImageRep {
    var pdfImage: NSImage? {
        let image = NSImage(size: bounds.size)
        image.addRepresentation(self)
        return image
    }
}

// MARK: - Generic Binary View

struct GenericBinaryView: View {
    let filename: String

    private var fileExtension: String {
        (filename as NSString).pathExtension.lowercased()
    }

    private var fileIcon: String {
        switch fileExtension {
        case "zip", "tar", "gz", "7z", "rar": return "doc.zipper"
        case "dmg", "iso": return "externaldrive"
        case "app": return "app.badge.checkmark"
        case "ttf", "otf", "woff", "woff2": return "textformat"
        case "mp3", "wav", "aac", "flac", "m4a": return "waveform"
        case "mp4", "mov", "avi", "mkv", "webm": return "film"
        case "sqlite", "db": return "cylinder"
        default: return "doc.fill"
        }
    }

    private var fileTypeName: String {
        switch fileExtension {
        case "zip": return "ZIP Archive"
        case "tar": return "TAR Archive"
        case "gz": return "GZIP Archive"
        case "7z": return "7-Zip Archive"
        case "rar": return "RAR Archive"
        case "dmg": return "Disk Image"
        case "iso": return "ISO Image"
        case "app": return "Application"
        case "ttf", "otf": return "Font File"
        case "woff", "woff2": return "Web Font"
        case "mp3": return "MP3 Audio"
        case "wav": return "WAV Audio"
        case "aac": return "AAC Audio"
        case "flac": return "FLAC Audio"
        case "m4a": return "M4A Audio"
        case "mp4": return "MP4 Video"
        case "mov": return "QuickTime Video"
        case "avi": return "AVI Video"
        case "mkv": return "MKV Video"
        case "webm": return "WebM Video"
        case "sqlite", "db": return "Database"
        default: return "Binary File"
        }
    }

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: fileIcon)
                .font(DesignTokens.Typography.iconXXXXL)
                .foregroundColor(AppTheme.textPrimary)

            Text(fileTypeName)
                .font(DesignTokens.Typography.headline)

            Text(filename)
                .foregroundColor(AppTheme.textPrimary)

            Text("Cannot display diff for binary files")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(AppTheme.textPrimary)
        }
        .frame(maxHeight: 300)
    }
}
