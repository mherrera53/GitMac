import SwiftUI
import AppKit

// MARK: - Stash Detail ViewModel
@MainActor
class StashDetailViewModel: ObservableObject {
    @Published var stashFiles: [StashFile] = []
    @Published var isLoading = false

    private let engine = GitEngine()

    func loadStashFiles(stashRef: String, at path: String) async {
        var log = "DEBUG: Loading stash files for \(stashRef) at \(path)\n"

        isLoading = true
        do {
            let files = try await engine.getStashFiles(stashRef: stashRef, at: path)
            log += "DEBUG: Loaded \(files.count) stash files\n"
            stashFiles = files
        } catch {
            log += "ERROR loading stash files: \(error)\n"
            stashFiles = []
        }
        isLoading = false

        // Write to temp file for debugging
        try? log.write(toFile: "/tmp/gitmac_debug.log", atomically: true, encoding: .utf8)
    }

    func getDiff(for file: StashFile, stash: Stash, at path: String) async -> FileDiff? {
        let shell = ShellExecutor()
        // Use git diff between stash parent and stash for specific file
        // Syntax: git diff stash@{n}^ stash@{n} -- file.path
        let result = await shell.execute(
            "git",
            arguments: ["diff", "\(stash.reference)^", stash.reference, "--", file.path],
            workingDirectory: path
        )

        if result.exitCode == 0 && !result.stdout.isEmpty {
            // Use async parser to avoid UI freeze on large files
            let diffs = await DiffParser.parseAsync(result.stdout)
            return diffs.first
        }
        return nil
    }

    func applyStashFile(stash: Stash, file: StashFile, at path: String) async {
        isLoading = true
        do {
            let shell = ShellExecutor()
            let result = await shell.execute(
                "git",
                arguments: ["checkout", stash.reference, "--", file.path],
                workingDirectory: path
            )

            if result.exitCode != 0 {
                // Handle error if needed (maybe via a published error property)
                print("Error applying file: \(result.stderr)")
            } else {
                NotificationCenter.default.post(name: .repositoryDidRefresh, object: path)
            }
        }
        isLoading = false
    }
}

// MARK: - Stash Detail File Row
struct StashDetailFileRow: View {
    let file: StashFile
    let onSelect: () -> Void
    var onApply: () -> Void = {}
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                // Status icon
                Image(systemName: statusIcon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(file.statusColor)
                    .frame(width: 14)

                // File icon
                Image(systemName: fileIcon(for: file.filename))
                    .font(.system(size: 10))
                    .foregroundColor(AppTheme.textMuted)

                // File path
                Text(file.filename)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                // Directory path
                if file.path != file.filename {
                    Text(String(file.path.dropLast(file.filename.count + 1)))
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textMuted)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isHovered ? AppTheme.hover : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button {
                onApply()
            } label: {
                Label("Apply Stash to File", systemImage: "arrow.uturn.backward")
            }

            Divider()

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(file.path, forType: .string)
            } label: {
                Label("Copy Path", systemImage: "doc.on.doc")
            }
        }
    }

    private var statusIcon: String {
        switch file.status {
        case .added: return "plus"
        case .modified: return "pencil"
        case .deleted: return "minus"
        case .renamed: return "arrow.right"
        default: return "circle"
        }
    }

    private func fileIcon(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "js", "ts", "jsx", "tsx": return "curlybraces"
        case "json": return "curlybraces.square"
        case "md": return "doc.text"
        case "png", "jpg", "jpeg", "gif", "svg": return "photo"
        case "css", "scss": return "paintbrush"
        case "html": return "chevron.left.forwardslash.chevron.right"
        default: return "doc"
        }
    }
}
