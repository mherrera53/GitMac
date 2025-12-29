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
                if isImage, let path = fullPath {
                    // Image preview
                    ImagePreviewView(imageURL: path, filename: filename)
                } else if isPDF, let path = fullPath {
                    // PDF preview
                    PDFPreviewView(pdfURL: path, filename: filename)
                } else {
                    // Generic binary file
                    GenericBinaryView(filename: filename)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(DesignTokens.Spacing.lg)
        }
        .background(Color(nsColor: .textBackgroundColor))
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
