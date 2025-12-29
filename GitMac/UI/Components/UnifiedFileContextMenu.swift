import SwiftUI
import AppKit

// MARK: - Unified File Context Menu

/// A unified, reusable context menu component for all file operations in GitMac.
/// Advanced's comprehensive context menu with additional improvements.
/// Use this instead of defining context menus inline to ensure consistency.
struct UnifiedFileContextMenu: View {
    // MARK: - File Info
    let filePath: String
    let fileState: FileState
    let repositoryPath: String
    
    // MARK: - Callbacks (all optional - menu items only show if callback is provided)
    var onStage: (() -> Void)? = nil
    var onUnstage: (() -> Void)? = nil
    var onDiscard: (() -> Void)? = nil
    var onDiscardStaged: (() -> Void)? = nil
    var onPreview: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onIgnore: (() -> Void)? = nil
    var onStopTracking: (() -> Void)? = nil
    var onAssumeUnchanged: (() -> Void)? = nil
    var onOpenInEditor: (() -> Void)? = nil
    var onShowHistory: (() -> Void)? = nil
    var onBlame: (() -> Void)? = nil
    
    // MARK: - File State Enum
    enum FileState: Equatable {
        case untracked       // New file, not in git
        case modified        // Tracked file with unstaged changes
        case staged          // File staged for commit
        case stagedModified  // Staged file with additional unstaged changes
        case conflicted      // File with merge conflicts
        case deleted         // Deleted file
        case renamed         // Renamed file
    }
    
    // MARK: - Computed Properties
    private var filename: String {
        URL(fileURLWithPath: filePath).lastPathComponent
    }
    
    private var fileExtension: String {
        URL(fileURLWithPath: filePath).pathExtension
    }
    
    private var directory: String {
        let dir = URL(fileURLWithPath: filePath).deletingLastPathComponent().path
        // Get relative path from repo
        if let range = dir.range(of: repositoryPath) {
            let relative = String(dir[range.upperBound...]).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return relative.isEmpty ? "." : relative
        }
        return dir
    }
    
    private var relativePath: String {
        if let range = filePath.range(of: repositoryPath) {
            return String(filePath[range.upperBound...]).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        return filePath
    }
    
    private var canPreview: Bool {
        let previewableExtensions = ["swift", "py", "js", "ts", "tsx", "jsx", "json", "xml", "md", "txt", "yml", "yaml", "html", "css", "scss", "less", "sh", "bash", "zsh", "rb", "go", "rs", "c", "h", "cpp", "hpp", "java", "kt", "php", "vue", "svelte", "sql", "graphql", "toml", "ini", "cfg", "conf", "env", "gitignore", "dockerfile", "makefile"]
        return previewableExtensions.contains(fileExtension.lowercased())
    }
    
    private var isTextFile: Bool {
        canPreview
    }
    
    private var statusIcon: String {
        switch fileState {
        case .untracked: return "?"
        case .modified: return "M"
        case .staged: return "S"
        case .stagedModified: return "SM"
        case .conflicted: return "!"
        case .deleted: return "D"
        case .renamed: return "R"
        }
    }
    
    // MARK: - Body
    var body: some View {
        Group {
            // MARK: Primary Actions (Stage/Unstage)
            primaryActionsSection
            
            // MARK: Discard/Revert Section
            discardSection
            
            // MARK: View & Edit Section
            viewEditSection
            
            // MARK: Copy & Reveal Section
            copyRevealSection
            
            // MARK: Git History Section
            gitHistorySection
            
            // MARK: Advanced Git Options
            advancedGitSection
            
            // MARK: Ignore & Tracking Section
            ignoreTrackingSection
            
            // MARK: Danger Zone (Delete)
            dangerSection
        }
    }
    
    // MARK: - Primary Actions Section
    @ViewBuilder
    private var primaryActionsSection: some View {
        switch fileState {
        case .untracked, .modified, .stagedModified:
            if let stage = onStage {
                Button {
                    stage()
                } label: {
                    Label("Stage File", systemImage: "plus.circle.fill")
                }
                .keyboardShortcut("s", modifiers: [.command])
            }
            
        case .staged:
            if let unstage = onUnstage {
                Button {
                    unstage()
                } label: {
                    Label("Unstage File", systemImage: "minus.circle.fill")
                }
                .keyboardShortcut("u", modifiers: [.command])
            }
            
        case .conflicted:
            Button {
                // Open merge tool or conflict resolution
            } label: {
                Label("Resolve Conflict...", systemImage: "wand.and.stars")
            }
            
        case .deleted:
            if let stage = onStage {
                Button {
                    stage()
                } label: {
                    Label("Stage Deletion", systemImage: "trash.circle.fill")
                }
            }
            
        case .renamed:
            if let stage = onStage {
                Button {
                    stage()
                } label: {
                    Label("Stage Rename", systemImage: "pencil.circle.fill")
                }
            }
        }
    }
    
    // MARK: - Discard Section
    @ViewBuilder
    private var discardSection: some View {
        let showDiscard = (fileState == .modified || fileState == .stagedModified) && onDiscard != nil
        let showDiscardStaged = (fileState == .staged || fileState == .stagedModified) && onDiscardStaged != nil
        
        if showDiscard || showDiscardStaged {
            Divider()
            
            if showDiscard, let discard = onDiscard {
                Button(role: .destructive) {
                    discard()
                } label: {
                    Label("Discard Changes", systemImage: "arrow.uturn.backward")
                }
            }
            
            if showDiscardStaged, let discardStaged = onDiscardStaged {
                Button(role: .destructive) {
                    discardStaged()
                } label: {
                    Label("Unstage & Discard", systemImage: "trash")
                }
            }
        }
    }
    
    // MARK: - View & Edit Section
    @ViewBuilder
    private var viewEditSection: some View {
        Divider()
        
        // Preview file (for text files)
        if canPreview, let preview = onPreview {
            Button {
                preview()
            } label: {
                Label("Preview File", systemImage: "eye")
            }
        }
        
        // Open with default app
        Button {
            NSWorkspace.shared.open(URL(fileURLWithPath: filePath))
        } label: {
            Label("Open with Default App", systemImage: "arrow.up.forward.app")
        }
        
        // Open in External Editor
        if let openInEditor = onOpenInEditor {
            Button {
                openInEditor()
            } label: {
                Label("Open in External Editor", systemImage: "square.and.pencil")
            }
        } else {
            // Default: open with VS Code if available
            Button {
                openInVSCode()
            } label: {
                Label("Open in VS Code", systemImage: "chevron.left.forwardslash.chevron.right")
            }
        }
    }
    
    // MARK: - Copy & Reveal Section
    @ViewBuilder
    private var copyRevealSection: some View {
        Divider()
        
        Menu {
            Button {
                copyToClipboard(filePath)
            } label: {
                Label("Full Path", systemImage: "doc.on.doc")
            }
            
            Button {
                copyToClipboard(relativePath)
            } label: {
                Label("Relative Path", systemImage: "doc.text")
            }
            
            Button {
                copyToClipboard(filename)
            } label: {
                Label("Filename Only", systemImage: "textformat")
            }
            
            if isTextFile {
                Divider()
                Button {
                    copyFileContent()
                } label: {
                    Label("File Content", systemImage: "doc.plaintext")
                }
            }
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }
        
        Button {
            NSWorkspace.shared.selectFile(filePath, inFileViewerRootedAtPath: "")
        } label: {
            Label("Reveal in Finder", systemImage: "folder")
        }
        
        Button {
            openInTerminal()
        } label: {
            Label("Open in Terminal", systemImage: "terminal")
        }
    }
    
    // MARK: - Git History Section
    @ViewBuilder
    private var gitHistorySection: some View {
        if fileState != .untracked {
            Divider()
            
            if let showHistory = onShowHistory {
                Button {
                    showHistory()
                } label: {
                    Label("Show File History", systemImage: "clock.arrow.circlepath")
                }
            }
            
            if let blame = onBlame {
                Button {
                    blame()
                } label: {
                    Label("Blame", systemImage: "person.text.rectangle")
                }
            }
        }
    }
    
    // MARK: - Advanced Git Section
    @ViewBuilder
    private var advancedGitSection: some View {
        if fileState != .untracked {
            Divider()
            
            if let assumeUnchanged = onAssumeUnchanged {
                Button {
                    assumeUnchanged()
                } label: {
                    Label("Assume Unchanged", systemImage: "eye.slash")
                }
            }
            
            if let stopTracking = onStopTracking {
                Button {
                    stopTracking()
                } label: {
                    Label("Stop Tracking", systemImage: "stop.circle")
                }
            }
        }
    }
    
    // MARK: - Ignore & Tracking Section
    @ViewBuilder
    private var ignoreTrackingSection: some View {
        if onIgnore != nil {
            Divider()
            
            Menu {
                // Ignore specific file
                Button {
                    addToGitignore(pattern: relativePath)
                } label: {
                    Label("Ignore '\(filename)'", systemImage: "doc")
                }
                
                // Ignore by extension
                if !fileExtension.isEmpty {
                    Button {
                        addToGitignore(pattern: "*.\(fileExtension)")
                    } label: {
                        Label("Ignore all '.\(fileExtension)' files", systemImage: "doc.badge.ellipsis")
                    }
                }
                
                // Ignore directory
                if !directory.isEmpty && directory != "." {
                    Button {
                        addToGitignore(pattern: "\(directory)/")
                    } label: {
                        Label("Ignore '\(directory)/' directory", systemImage: "folder.badge.minus")
                    }
                }
                
                Divider()
                
                // For tracked files: ignore AND stop tracking
                if fileState != .untracked, let stopTracking = onStopTracking {
                    Button {
                        addToGitignore(pattern: relativePath)
                        stopTracking()
                    } label: {
                        Label("Ignore & Stop Tracking", systemImage: "eye.slash.circle")
                    }
                }
            } label: {
                Label("Ignore", systemImage: "eye.slash")
            }
        }
    }
    
    // MARK: - Danger Section (Delete)
    @ViewBuilder
    private var dangerSection: some View {
        if fileState == .untracked, let delete = onDelete {
            Divider()
            Button(role: .destructive) {
                delete()
            } label: {
                Label("Delete File", systemImage: "trash.fill")
            }
        }
    }
    
    // MARK: - Helper Functions
    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
    
    private func copyFileContent() {
        if let content = try? String(contentsOfFile: filePath, encoding: .utf8) {
            copyToClipboard(content)
        }
    }
    
    private func openInVSCode() {
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = ["code", filePath]
        try? task.run()
    }
    
    private func openInTerminal() {
        let directory = URL(fileURLWithPath: filePath).deletingLastPathComponent().path
        let script = "tell application \"Terminal\" to do script \"cd '\(directory)'\""
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }
    
    private func addToGitignore(pattern: String) {
        NotificationCenter.default.post(
            name: .ignoreFile,
            object: ["pattern": pattern, "path": filePath, "repoPath": repositoryPath]
        )
        onIgnore?()
    }
}

// MARK: - Convenience Initializers

extension UnifiedFileContextMenu {
    /// Creates a context menu for an untracked file
    static func forUntracked(
        path: String,
        repoPath: String = "",
        onStage: @escaping () -> Void,
        onDelete: (() -> Void)? = nil,
        onIgnore: (() -> Void)? = nil,
        onPreview: (() -> Void)? = nil
    ) -> UnifiedFileContextMenu {
        UnifiedFileContextMenu(
            filePath: path,
            fileState: .untracked,
            repositoryPath: repoPath,
            onStage: onStage,
            onPreview: onPreview,
            onDelete: onDelete,
            onIgnore: onIgnore
        )
    }
    
    /// Creates a context menu for a modified (unstaged) file
    static func forModified(
        path: String,
        repoPath: String = "",
        onStage: @escaping () -> Void,
        onDiscard: @escaping () -> Void,
        onIgnore: (() -> Void)? = nil,
        onPreview: (() -> Void)? = nil,
        onShowHistory: (() -> Void)? = nil,
        onBlame: (() -> Void)? = nil
    ) -> UnifiedFileContextMenu {
        UnifiedFileContextMenu(
            filePath: path,
            fileState: .modified,
            repositoryPath: repoPath,
            onStage: onStage,
            onDiscard: onDiscard,
            onPreview: onPreview,
            onIgnore: onIgnore,
            onShowHistory: onShowHistory,
            onBlame: onBlame
        )
    }
    
    /// Creates a context menu for a staged file
    static func forStaged(
        path: String,
        repoPath: String = "",
        onUnstage: @escaping () -> Void,
        onDiscardStaged: (() -> Void)? = nil,
        onPreview: (() -> Void)? = nil,
        onShowHistory: (() -> Void)? = nil
    ) -> UnifiedFileContextMenu {
        UnifiedFileContextMenu(
            filePath: path,
            fileState: .staged,
            repositoryPath: repoPath,
            onUnstage: onUnstage,
            onDiscardStaged: onDiscardStaged,
            onPreview: onPreview,
            onShowHistory: onShowHistory
        )
    }
    
    /// Creates a context menu for a conflicted file
    static func forConflicted(
        path: String,
        repoPath: String = "",
        onPreview: (() -> Void)? = nil
    ) -> UnifiedFileContextMenu {
        UnifiedFileContextMenu(
            filePath: path,
            fileState: .conflicted,
            repositoryPath: repoPath,
            onPreview: onPreview
        )
    }
}

// MARK: - Hunk Context Menu

/// Context menu specifically for diff hunks
struct HunkContextMenu: View {
    let hunkIndex: Int
    let isStaged: Bool
    
    var onStageHunk: ((Int) -> Void)? = nil
    var onUnstageHunk: ((Int) -> Void)? = nil
    var onDiscardHunk: ((Int) -> Void)? = nil
    var onCopyHunk: ((Int) -> Void)? = nil
    
    var body: some View {
        Group {
            if !isStaged {
                if let stageHunk = onStageHunk {
                    Button {
                        stageHunk(hunkIndex)
                    } label: {
                        Label("Stage Hunk", systemImage: "plus.circle.fill")
                    }
                }
                
                if let discardHunk = onDiscardHunk {
                    Divider()
                    Button(role: .destructive) {
                        discardHunk(hunkIndex)
                    } label: {
                        Label("Discard Hunk", systemImage: "trash")
                    }
                }
            } else {
                if let unstageHunk = onUnstageHunk {
                    Button {
                        unstageHunk(hunkIndex)
                    } label: {
                        Label("Unstage Hunk", systemImage: "minus.circle.fill")
                    }
                }
            }
            
            if let copyHunk = onCopyHunk {
                Divider()
                Button {
                    copyHunk(hunkIndex)
                } label: {
                    Label("Copy Hunk", systemImage: "doc.on.doc")
                }
            }
        }
    }
}

// MARK: - Line Selection Context Menu

/// Context menu for selected lines in diff view
struct LineSelectionContextMenu: View {
    let selectedLines: [Int]
    let isStaged: Bool
    
    var onStageLines: (([Int]) -> Void)? = nil
    var onUnstageLines: (([Int]) -> Void)? = nil
    var onDiscardLines: (([Int]) -> Void)? = nil
    var onCopyLines: (([Int]) -> Void)? = nil
    
    var lineCountText: String {
        selectedLines.count == 1 ? "Line" : "\(selectedLines.count) Lines"
    }
    
    var body: some View {
        Group {
            if !isStaged {
                if let stageLines = onStageLines {
                    Button {
                        stageLines(selectedLines)
                    } label: {
                        Label("Stage Selected \(lineCountText)", systemImage: "plus.circle.fill")
                    }
                }
                
                if let discardLines = onDiscardLines {
                    Divider()
                    Button(role: .destructive) {
                        discardLines(selectedLines)
                    } label: {
                        Label("Discard Selected \(lineCountText)", systemImage: "trash")
                    }
                }
            } else {
                if let unstageLines = onUnstageLines {
                    Button {
                        unstageLines(selectedLines)
                    } label: {
                        Label("Unstage Selected \(lineCountText)", systemImage: "minus.circle.fill")
                    }
                }
            }
            
            if let copyLines = onCopyLines {
                Divider()
                Button {
                    copyLines(selectedLines)
                } label: {
                    Label("Copy Selected \(lineCountText)", systemImage: "doc.on.doc")
                }
            }
        }
    }
}

// MARK: - Folder Context Menu

/// Context menu for folders in tree view
struct FolderContextMenu: View {
    let folderPath: String
    let isStaged: Bool
    let fileCount: Int
    
    var onStageFolder: ((String) -> Void)? = nil
    var onUnstageFolder: ((String) -> Void)? = nil
    var onDiscardFolder: ((String) -> Void)? = nil
    var onIgnoreFolder: ((String) -> Void)? = nil
    
    private var folderName: String {
        URL(fileURLWithPath: folderPath).lastPathComponent
    }
    
    var body: some View {
        Group {
            if !isStaged {
                if let stageFolder = onStageFolder {
                    Button {
                        stageFolder(folderPath)
                    } label: {
                        Label("Stage Folder (\(fileCount) files)", systemImage: "plus.circle.fill")
                    }
                }
                
                if let discardFolder = onDiscardFolder {
                    Divider()
                    Button(role: .destructive) {
                        discardFolder(folderPath)
                    } label: {
                        Label("Discard All Changes", systemImage: "trash")
                    }
                }
            } else {
                if let unstageFolder = onUnstageFolder {
                    Button {
                        unstageFolder(folderPath)
                    } label: {
                        Label("Unstage Folder (\(fileCount) files)", systemImage: "minus.circle.fill")
                    }
                }
            }
            
            Divider()
            
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(folderPath, forType: .string)
            } label: {
                Label("Copy Path", systemImage: "doc.on.doc")
            }
            
            Button {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: folderPath)
            } label: {
                Label("Reveal in Finder", systemImage: "folder")
            }
            
            if let ignoreFolder = onIgnoreFolder {
                Divider()
                Button {
                    ignoreFolder(folderPath)
                } label: {
                    Label("Ignore '\(folderName)/'", systemImage: "eye.slash")
                }
            }
        }
    }
}

// MARK: - Preview
#if DEBUG
struct UnifiedFileContextMenu_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Text("Right-click: Modified file")
                .contextMenu {
                    UnifiedFileContextMenu.forModified(
                        path: "/path/to/file.swift",
                        repoPath: "/path/to",
                        onStage: { print("Stage") },
                        onDiscard: { print("Discard") }
                    )
                }
            
            Text("Right-click: Untracked file")
                .contextMenu {
                    UnifiedFileContextMenu.forUntracked(
                        path: "/path/to/newfile.swift",
                        repoPath: "/path/to",
                        onStage: { print("Stage") },
                        onDelete: { print("Delete") }
                    )
                }
            
            Text("Right-click: Hunk")
                .contextMenu {
                    HunkContextMenu(
                        hunkIndex: 0,
                        isStaged: false,
                        onStageHunk: { _ in print("Stage hunk") },
                        onDiscardHunk: { _ in print("Discard hunk") }
                    )
                }
        }
        .padding()
    }
}
#endif
