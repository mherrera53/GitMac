import SwiftUI
import AppKit

// MARK: - Code Language

enum CodeLanguage: String, CaseIterable {
    case swift = "Swift"
    case python = "Python"
    case javascript = "JavaScript"
    case typescript = "TypeScript"
    case go = "Go"
    case rust = "Rust"
    case shell = "Shell"
    case markdown = "Markdown"
    case json = "JSON"
    case yaml = "YAML"
    case ruby = "Ruby"
    case kotlin = "Kotlin"
    case unknown = "Text"

    static var `default`: CodeLanguage { .unknown }

    struct LanguageID {
        let rawValue: String
    }
    var id: LanguageID { LanguageID(rawValue: rawValue) }

    static func detectLanguageFrom(url: URL) -> CodeLanguage {
        switch url.pathExtension.lowercased() {
        case "swift":               return .swift
        case "py":                  return .python
        case "js", "jsx", "mjs":   return .javascript
        case "ts", "tsx":           return .typescript
        case "go":                  return .go
        case "rs":                  return .rust
        case "sh", "bash", "zsh":  return .shell
        case "md", "markdown":      return .markdown
        case "json":                return .json
        case "yml", "yaml":         return .yaml
        case "rb":                  return .ruby
        case "kt", "kts":           return .kotlin
        default:                    return .unknown
        }
    }
}

// MARK: - Code Editor View (NSTextView-based)

struct CodeEditorView: NSViewRepresentable {
    @Binding var text: String
    let language: CodeLanguage
    let isEditable: Bool

    init(
        text: Binding<String>,
        language: CodeLanguage = .default,
        isEditable: Bool = true
    ) {
        self._text = text
        self.language = language
        self.isEditable = isEditable
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }

        textView.delegate = context.coordinator
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFindPanel = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false

        applyStyle(to: textView)
        textView.string = text

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        applyStyle(to: textView)
        if textView.string != text {
            let selection = textView.selectedRange()
            textView.string = text
            // Restore cursor position safely
            let safeRange = NSRange(location: min(selection.location, text.utf16.count), length: 0)
            textView.setSelectedRange(safeRange)
        }
        textView.isEditable = isEditable
    }

    private func applyStyle(to textView: NSTextView) {
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = NSColor.labelColor
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor.selectedTextBackgroundColor,
            .foregroundColor: NSColor.selectedTextColor
        ]
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeEditorView

        init(_ parent: CodeEditorView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            if parent.text != textView.string {
                parent.text = textView.string
            }
        }
    }
}

// MARK: - NSColor helper

private extension NSColor {
    func forAppearance(_ appearance: NSAppearance) -> NSColor {
        var result = self
        appearance.performAsCurrentDrawingAppearance {
            result = NSColor(cgColor: self.cgColor) ?? self
        }
        return result
    }
}

// MARK: - File Code Editor

struct FileCodeEditorView: View {
    let filePath: String
    var onContentChange: ((String) -> Void)? = nil
    var onFileSaved: (() -> Void)? = nil

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
            editorToolbar
            Divider()

            if isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = error {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundStyle(.orange)
                    Text(error)
                        .foregroundStyle(.secondary)
                    Button("Retry") { Task { await loadFile() } }
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
        .task { await loadFile() }
    }

    private var editorToolbar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "doc.fill")
                    .foregroundStyle(Color.accentColor)
                Text(filename)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
            }

            Text(language.id.rawValue.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.accentColor.opacity(0.2))
                .clipShape(.rect(cornerRadius: 4))

            if hasChanges {
                HStack(spacing: 4) {
                    Circle().fill(Color.orange).frame(width: 8, height: 8)
                    Text("Unsaved")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            Button {
                Task { await saveFile() }
            } label: {
                HStack(spacing: 4) {
                    if isSaving {
                        ProgressView().scaleEffect(0.7)
                    } else {
                        Image(systemName: "square.and.arrow.down")
                    }
                    Text("Save")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(hasChanges ? Color.accentColor : Color.gray.opacity(0.3))
                .foregroundStyle(hasChanges ? .white : .gray)
                .clipShape(.rect(cornerRadius: 6))
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
            onFileSaved?()
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

struct EditorSheet: View {
    let filePath: String
    var onFileSaved: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var showPreview = false
    @State private var content: String = ""

    private var filename: String { (filePath as NSString).lastPathComponent }
    private var isMarkdown: Bool {
        let ext = (filePath as NSString).pathExtension.lowercased()
        return ext == "md" || ext == "markdown"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Edit: \(filename)").font(.headline)

                if isMarkdown {
                    Text("MARKDOWN")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.2))
                        .clipShape(.rect(cornerRadius: 4))
                }

                Spacer()

                if isMarkdown {
                    Picker("", selection: $showPreview) {
                        Label("Edit", systemImage: "pencil").tag(false)
                        Label("Preview", systemImage: "eye").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                }

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            if isMarkdown && showPreview {
                MarkdownView(content: content, fileName: filename)
            } else {
                FileCodeEditorView(
                    filePath: filePath,
                    onContentChange: { content = $0 },
                    onFileSaved: onFileSaved
                )
            }
        }
        .frame(minWidth: 900, minHeight: 700)
        .task {
            if let text = try? String(contentsOfFile: filePath, encoding: .utf8) {
                content = text
            }
        }
    }
}

// MARK: - Markdown Preview Sheet

struct MarkdownPreviewSheet: View {
    let filePath: String
    @Environment(\.dismiss) private var dismiss
    @State private var content: String = ""
    @State private var isLoading = true

    private var filename: String { (filePath as NSString).lastPathComponent }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "eye").foregroundStyle(Color.accentColor)
                Text("Preview: \(filename)").font(.headline)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

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
                Button("Increment") { count += 1 }
            }
        }
    }
    """

    static var previews: some View {
        CodeEditorView(text: $code, language: .swift, isEditable: true)
            .frame(width: 600, height: 400)
    }
}
#endif
