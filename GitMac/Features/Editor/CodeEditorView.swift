import SwiftUI
import AppKit
import CodeEditSourceEditor
import CodeEditLanguages

// MARK: - Editor Theme Factory

/// Creates EditorTheme using AppTheme semantic colors
@MainActor
enum EditorThemeFactory {
    /// Converts a catalog/dynamic NSColor to a concrete sRGB color
    /// This is required because CodeEditSourceEditor calls brightnessComponent
    /// which doesn't work on catalog colors
    private static func concreteColor(_ color: NSColor) -> NSColor {
        guard let rgb = color.usingColorSpace(.sRGB) else {
            // Fallback: extract components manually
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
            if let deviceColor = color.usingColorSpace(.deviceRGB) {
                deviceColor.getRed(&r, green: &g, blue: &b, alpha: &a)
            }
            return NSColor(srgbRed: r, green: g, blue: b, alpha: a)
        }
        return rgb
    }

    /// Creates theme from current app theme settings
    static func makeTheme() -> EditorTheme {
        EditorTheme(
            text: .init(color: concreteColor(.labelColor)),
            insertionPoint: concreteColor(.textColor),
            invisibles: .init(color: concreteColor(.tertiaryLabelColor)),
            background: concreteColor(.textBackgroundColor),
            lineHighlight: concreteColor(.selectedContentBackgroundColor.withAlphaComponent(0.15)),
            selection: concreteColor(.selectedTextBackgroundColor),
            keywords: .init(color: concreteColor(.systemPink)),        // AppTheme.syntaxKeyword
            commands: .init(color: concreteColor(.systemTeal)),        // commands/functions
            types: .init(color: concreteColor(.systemCyan)),           // AppTheme.syntaxType equivalent
            attributes: .init(color: concreteColor(.systemOrange)),    // decorators/attributes
            variables: .init(color: concreteColor(.systemBlue)),       // variable names
            values: .init(color: concreteColor(.systemPurple)),        // constants/values
            numbers: .init(color: concreteColor(.systemCyan)),         // AppTheme.syntaxNumber
            strings: .init(color: concreteColor(.systemGreen)),        // AppTheme.syntaxString
            characters: .init(color: concreteColor(.systemYellow)),    // character literals
            comments: .init(color: concreteColor(.secondaryLabelColor)) // AppTheme.syntaxComment
        )
    }
}

// MARK: - Code Editor View (using CodeEditSourceEditor)

/// Native code editor with syntax highlighting using CodeEditSourceEditor
struct CodeEditorView: View {
    @Binding var text: String
    let language: CodeLanguage
    let isEditable: Bool

    @State private var editorState = SourceEditorState()

    init(
        text: Binding<String>,
        language: CodeLanguage = .default,
        isEditable: Bool = true
    ) {
        self._text = text
        self.language = language
        self.isEditable = isEditable
    }

    private var configuration: SourceEditorConfiguration {
        SourceEditorConfiguration(
            appearance: .init(
                theme: EditorThemeFactory.makeTheme(),
                font: .monospacedSystemFont(ofSize: 13, weight: .regular),
                lineHeightMultiple: 1.4,
                wrapLines: true,
                bracketPairEmphasis: .flash
            ),
            behavior: .init(
                isEditable: isEditable,
                indentOption: .spaces(count: 4)
            )
        )
    }

    var body: some View {
        SourceEditor(
            $text,
            language: language,
            configuration: configuration,
            state: $editorState
        )
    }
}

// MARK: - File Code Editor

/// Code editor for editing files with automatic language detection
struct FileCodeEditorView: View {
    let filePath: String
    var onContentChange: ((String) -> Void)? = nil
    var onFileSaved: (() -> Void)? = nil  // Called after successful save

    @State private var content: String = ""
    @State private var isLoading = true
    @State private var error: String?
    @State private var hasChanges = false
    @State private var isSaving = false

    private var language: CodeLanguage {
        CodeLanguage.detectLanguageFrom(url: URL(fileURLWithPath: filePath))
    }

    private var filename: String {
        (filePath as NSString).lastPathComponent
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            editorToolbar

            Divider()

            // Editor
            if isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = error {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    Text(error)
                        .foregroundColor(.secondary)
                    Button("Retry") {
                        Task { await loadFile() }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                CodeEditorView(
                    text: $content,
                    language: language,
                    isEditable: true
                )
                .onChange(of: content) { _, newValue in
                    hasChanges = true
                    onContentChange?(newValue)
                }
            }
        }
        .task {
            await loadFile()
        }
    }

    private var editorToolbar: some View {
        HStack(spacing: 12) {
            // File info
            HStack(spacing: 6) {
                Image(systemName: "doc.fill")
                    .foregroundColor(.accentColor)
                Text(filename)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
            }

            // Language badge
            Text(language.id.rawValue.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.accentColor.opacity(0.2))
                .cornerRadius(4)

            // Unsaved indicator
            if hasChanges {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                    Text("Unsaved")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            // Save button
            Button {
                Task { await saveFile() }
            } label: {
                HStack(spacing: 4) {
                    if isSaving {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "square.and.arrow.down")
                    }
                    Text("Save")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(hasChanges ? Color.accentColor : Color.gray.opacity(0.3))
                .foregroundColor(hasChanges ? .white : .gray)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(!hasChanges || isSaving)
            .keyboardShortcut("s", modifiers: .command)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func loadFile() async {
        isLoading = true
        error = nil

        do {
            content = try String(contentsOfFile: filePath, encoding: .utf8)
            hasChanges = false
        } catch {
            self.error = "Failed to load file: \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func saveFile() async {
        isSaving = true

        do {
            try content.write(toFile: filePath, atomically: true, encoding: .utf8)
            hasChanges = false
            onFileSaved?()  // Notify parent that file was saved

            // Post notification to refresh diff and staging
            NotificationCenter.default.post(
                name: .fileSavedInEditor,
                object: nil,
                userInfo: ["filePath": filePath]
            )
        } catch {
            self.error = "Failed to save: \(error.localizedDescription)"
        }

        isSaving = false
    }
}

// MARK: - Editor Sheet

/// Sheet wrapper for the code editor with optional preview for Markdown
struct EditorSheet: View {
    let filePath: String
    var onFileSaved: (() -> Void)? = nil  // Called after successful save

    @Environment(\.dismiss) private var dismiss
    @State private var showPreview = false
    @State private var content: String = ""

    private var filename: String {
        (filePath as NSString).lastPathComponent
    }

    private var isMarkdown: Bool {
        let ext = (filePath as NSString).pathExtension.lowercased()
        return ext == "md" || ext == "markdown"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit: \(filename)")
                    .font(.headline)

                if isMarkdown {
                    // Language badge
                    Text("MARKDOWN")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.2))
                        .cornerRadius(4)
                }

                Spacer()

                // Preview toggle for Markdown files
                if isMarkdown {
                    Picker("", selection: $showPreview) {
                        Label("Edit", systemImage: "pencil")
                            .tag(false)
                        Label("Preview", systemImage: "eye")
                            .tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                }

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Content area
            if isMarkdown && showPreview {
                MarkdownView(content: content, fileName: filename)
            } else {
                FileCodeEditorView(
                    filePath: filePath,
                    onContentChange: { newContent in content = newContent },
                    onFileSaved: onFileSaved
                )
            }
        }
        .frame(minWidth: 900, minHeight: 700)
        .task {
            // Load initial content for preview
            if let text = try? String(contentsOfFile: filePath, encoding: .utf8) {
                content = text
            }
        }
    }
}

// MARK: - Markdown Preview Sheet

/// Standalone preview sheet for Markdown files with Mermaid support
struct MarkdownPreviewSheet: View {
    let filePath: String
    @Environment(\.dismiss) private var dismiss
    @State private var content: String = ""
    @State private var isLoading = true

    private var filename: String {
        (filePath as NSString).lastPathComponent
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "eye")
                    .foregroundColor(.accentColor)
                Text("Preview: \(filename)")
                    .font(.headline)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Preview content
            if isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                MarkdownView(content: content, fileName: filename)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .task {
            do {
                content = try String(contentsOfFile: filePath, encoding: .utf8)
            } catch {
                content = "Error loading file: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
}

// MARK: - Preview

#if DEBUG
struct CodeEditorView_Previews: PreviewProvider {
    @State static var code = """
    import SwiftUI

    struct ContentView: View {
        @State private var count = 0

        var body: some View {
            VStack {
                Text("Count: \\(count)")
                Button("Increment") {
                    count += 1
                }
            }
        }
    }
    """

    static var previews: some View {
        VStack(spacing: 0) {
            CodeEditorView(
                text: $code,
                language: .swift,
                isEditable: true
            )
        }
        .frame(width: 600, height: 400)
    }
}
#endif
