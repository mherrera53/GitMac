import SwiftUI
import AppKit

// MARK: - Staging Section with Tree Support
struct StagingSectionWithTree: View {
    let title: String
    let count: Int
    let totalCount: Int  // Total count (may differ from count when paginated)
    let actionIcon: String
    let actionColor: Color
    let onAction: () -> Void
    let viewMode: StagingViewMode
    let files: [StagingFile]
    let isStaged: Bool
    let selectedFilePath: String?
    let extensionFilter: String?
    let onSelect: (StagingFile) -> Void
    let onStage: (StagingFile) -> Void
    let onStageFolder: (String) -> Void
    var onDiscard: ((StagingFile) -> Void)? = nil
    var onDelete: ((StagingFile) -> Void)? = nil
    var onDiscardFolder: ((String) -> Void)? = nil
    var onDeleteFolder: ((String) -> Void)? = nil
    var hasMore: Bool = false
    var onLoadMore: (() -> Void)? = nil

    @State private var isExpanded = true

    /// Files filtered by extension (for flat view and empty check)
    private var filteredFiles: [StagingFile] {
        guard let ext = extensionFilter else { return files }
        return files.filter { ($0.path as NSString).pathExtension.lowercased() == ext.lowercased() }
    }

    private var isPaginated: Bool {
        count < totalCount
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header - compact for 14" Retina
            HStack(spacing: 6) {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(AppTheme.textMuted)
                }
                .buttonStyle(.plain)

                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.textMuted)
                    .lineLimit(1)

                // Show loaded/total when paginated
                if isPaginated {
                    Text("\(count)/\(totalCount)")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.warning)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(AppTheme.warning.opacity(0.15))
                        .clipShape(.rect(cornerRadius: 3))
                } else {
                    Text("\(totalCount)")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textMuted)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(AppTheme.backgroundTertiary)
                        .clipShape(.rect(cornerRadius: 3))
                }

                Spacer(minLength: 4)

                Button(action: onAction) {
                    Image(systemName: actionIcon)
                        .font(.system(size: 13))
                        .foregroundStyle(actionColor)
                }
                .buttonStyle(.plain)
                .help(isStaged ? "Unstage All" : "Stage All")
                .accessibilityLabel(isStaged ? "Unstage all \(totalCount) files" : "Stage all \(totalCount) files")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.thinMaterial)

            // Content
            if isExpanded {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if filteredFiles.isEmpty {
                            Text(isStaged ? "No staged changes" : "No unstaged changes")
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.textMuted)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        } else if viewMode == .tree {
                            StagingTreeView(
                                files: files,  // Pass loaded files to build tree
                                isStaged: isStaged,
                                selectedFilePath: selectedFilePath,
                                extensionFilter: extensionFilter,  // Filter applied in tree
                                onSelect: onSelect,
                                onStage: onStage,
                                onStageFolder: onStageFolder,
                                onDiscard: onDiscard,
                                onDelete: onDelete,
                                onDiscardFolder: onDiscardFolder,
                                onDeleteFolder: onDeleteFolder
                            )
                        } else {
                            ForEach(filteredFiles) { file in
                                ClickableFileRow(
                                    file: file,
                                    isStaged: isStaged,
                                    isSelected: file.path == selectedFilePath,
                                    onSelect: { onSelect(file) },
                                    onStage: { onStage(file) },
                                    onDiscard: onDiscard.map { cb in { cb(file) } },
                                    onDelete: onDelete.map { cb in { cb(file) } }
                                )
                            }
                        }

                        // Load More button when paginated
                        if hasMore {
                            Button {
                                onLoadMore?()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.down.circle")
                                        .font(.system(size: 12))
                                    Text("Load more (\(totalCount - count) remaining)")
                                        .font(.system(size: 11))
                                }
                                .foregroundStyle(AppTheme.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(AppTheme.accent.opacity(0.08))
                                .clipShape(.rect(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Staging Tree View (Memory Optimized)
struct StagingTreeView: View {
    let files: [StagingFile]
    let isStaged: Bool
    let selectedFilePath: String?
    let extensionFilter: String?
    let onSelect: (StagingFile) -> Void
    let onStage: (StagingFile) -> Void
    let onStageFolder: (String) -> Void
    var onDiscard: ((StagingFile) -> Void)? = nil
    var onDelete: ((StagingFile) -> Void)? = nil
    var onDiscardFolder: ((String) -> Void)? = nil
    var onDeleteFolder: ((String) -> Void)? = nil

    var body: some View {
        GenericFileTreeView<StagingFile, StagingRowContent>.forStagingFiles(
            files: files,
            selectedPath: .constant(selectedFilePath),
            section: isStaged ? "staged" : "unstaged",
            extensionFilter: extensionFilter,
            pathExtractor: { $0.path }
        ) { path, file, isFolder, isSelected, _ in
            StagingRowContent(
                path: path,
                file: file,
                isFolder: isFolder,
                isStaged: isStaged,
                isSelected: isSelected,
                onSelect: onSelect,
                onStage: onStage,
                onStageFolder: onStageFolder,
                onDiscard: onDiscard,
                onDelete: onDelete,
                onDiscardFolder: onDiscardFolder,
                onDeleteFolder: onDeleteFolder
            )
        }
    }
}

// MARK: - Staging Row Content (Memory Optimized - no GenericTreeNode dependency)
struct StagingRowContent: View {
    let path: String
    let file: StagingFile?
    let isFolder: Bool
    let isStaged: Bool
    let isSelected: Bool
    let onSelect: (StagingFile) -> Void
    let onStage: (StagingFile) -> Void
    let onStageFolder: (String) -> Void
    var onDiscard: ((StagingFile) -> Void)? = nil
    var onDelete: ((StagingFile) -> Void)? = nil
    var onDiscardFolder: ((String) -> Void)? = nil
    var onDeleteFolder: ((String) -> Void)? = nil

    @State private var isHovered = false

    private var fileName: String {
        (path as NSString).lastPathComponent
    }

    var body: some View {
        if isFolder {
            folderContent
        } else {
            fileContent
        }
    }

    private var folderContent: some View {
        HStack(spacing: 5) {
            Image(systemName: "folder.fill")
                .font(.system(size: 12))
                .foregroundColor(AppTheme.warning)
            Text(fileName)
                .font(.system(size: 11))
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 2)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .contextMenu {
            Button { onStageFolder(path) } label: {
                Label(isStaged ? "Unstage Folder" : "Stage Folder",
                      systemImage: isStaged ? "minus.circle" : "plus.circle")
            }
            if !isStaged {
                if let onDiscardFolder {
                    Divider()
                    Button(role: .destructive) { onDiscardFolder(path) } label: {
                        Label("Revert Folder Changes", systemImage: "arrow.uturn.backward")
                    }
                }
                if let onDeleteFolder {
                    if onDiscardFolder == nil { Divider() }
                    Button(role: .destructive) { onDeleteFolder(path) } label: {
                        Label("Delete Untracked in Folder", systemImage: "trash")
                    }
                }
            }
        }
    }

    private var fileContent: some View {
        Button { if let f = file { onSelect(f) } } label: {
            HStack(spacing: 4) {
                if let f = file {
                    StatusIcon(stagingStatus: f.status, size: .small)
                }
                FileTypeIcon(fileName: fileName, size: .small)
                Text(fileName)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 2)

                if let f = file, f.hasChanges, f.status != .deleted {
                    DiffStatsView(additions: f.additions, deletions: f.deletions, size: .small, style: .compact)
                        .fixedSize()
                }

                if (isHovered || isSelected), let f = file {
                    Button { onStage(f) } label: {
                        Image(systemName: isStaged ? "minus.circle.fill" : "plus.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(isStaged ? AppTheme.error : AppTheme.success)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? AppTheme.accent.opacity(0.3) : (isHovered ? AppTheme.hover : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .contextMenu { fileContextMenu }
    }

    @ViewBuilder
    private var fileContextMenu: some View {
        if let f = file {
            Button { onStage(f) } label: {
                Label(isStaged ? "Unstage" : "Stage", systemImage: isStaged ? "minus.circle" : "plus.circle")
            }
            if !isStaged, onDiscard != nil, f.status != .untracked {
                Divider()
                Button(role: .destructive) { onDiscard?(f) } label: {
                    Label("Revert Changes", systemImage: "arrow.uturn.backward")
                }
            }
            if !isStaged, f.status == .untracked {
                Divider()
                Button(role: .destructive) { onDelete?(f) } label: {
                    Label("Delete File", systemImage: "trash")
                }
            }
            Divider()
            Button {
                onSelect(f)
                NotificationCenter.default.post(name: .showFileHistory, object: f.path)
            } label: {
                Label("Show File History", systemImage: "clock.arrow.circlepath")
            }
            Divider()
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(f.path, forType: .string)
            } label: {
                Label("Copy Path", systemImage: "doc.on.doc")
            }
        }
    }
}

// MARK: - Clickable File Row
struct ClickableFileRow: View {
    let file: StagingFile
    let isStaged: Bool
    var isSelected: Bool = false
    let onSelect: () -> Void
    let onStage: () -> Void
    var onDiscard: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 5) {
                // Status icon
                Image(systemName: file.status.icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(file.status.color)
                    .frame(width: 12)

                // File path
                Text(file.path)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 2)

                if isHovered || isSelected {
                    Button(action: onStage) {
                        Image(systemName: isStaged ? "minus.circle" : "plus.circle")
                            .font(.system(size: 12))
                            .foregroundStyle(isStaged ? AppTheme.error : AppTheme.success)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? AppTheme.accent.opacity(0.3) : (isHovered ? AppTheme.hover : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(isStaged ? "Staged" : "Unstaged") file \((file.path as NSString).lastPathComponent), \(file.status.accessibilityDescription)")
        .accessibilityHint(isStaged ? "Double-click to view diff, hover to unstage" : "Double-click to view diff, hover to stage")
        .onHover { isHovered = $0 }
        .contextMenu {
            Button {
                onStage()
            } label: {
                Label(isStaged ? "Unstage File" : "Stage File",
                      systemImage: isStaged ? "minus.circle" : "plus.circle")
            }
            if !isStaged, let onDiscard, file.status != .untracked {
                Divider()
                Button(role: .destructive) { onDiscard() } label: {
                    Label("Revert Changes", systemImage: "arrow.uturn.backward")
                }
            }
            if !isStaged, let onDelete, file.status == .untracked {
                Divider()
                Button(role: .destructive) { onDelete() } label: {
                    Label("Delete File", systemImage: "trash")
                }
            }
            Divider()
            Button {
                onSelect()
                NotificationCenter.default.post(name: .showFileHistory, object: file.path)
            } label: {
                Label("Show File History", systemImage: "clock.arrow.circlepath")
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
}

// MARK: - Staging ViewModel
@MainActor
class LegacyStagingViewModel: ObservableObject {
    @Published var unstagedFiles: [StagingFile] = []
    @Published var stagedFiles: [StagingFile] = []

    private let engine = GitEngine()
    private var currentPath: String?

    func loadStatus(at path: String) async {
        currentPath = path
        do {
            let status = try await engine.getStatus(at: path)
            unstagedFiles = status.unstaged.map { StagingFile(from: $0, staged: false) } +
                           status.untracked.map { StagingFile(path: $0, status: .untracked, isStaged: false) }
            stagedFiles = status.staged.map { StagingFile(from: $0, staged: true) }
        } catch {
            print("Error loading status: \(error)")
        }
    }

    func stage(file: StagingFile) {
        guard let path = currentPath else { return }
        Task {
            do {
                try await engine.stage(files: [file.path], at: path)
                await loadStatus(at: path)
            } catch {
                print("Error staging: \(error)")
            }
        }
    }

    func unstage(file: StagingFile) {
        guard let path = currentPath else { return }
        Task {
            do {
                try await engine.unstage(files: [file.path], at: path)
                await loadStatus(at: path)
            } catch {
                print("Error unstaging: \(error)")
            }
        }
    }

    func stageAll() {
        guard let path = currentPath else { return }
        Task {
            do {
                try await engine.stageAll(at: path)
                await loadStatus(at: path)
            } catch {
                print("Error staging all: \(error)")
            }
        }
    }

    func unstageAll() {
        guard let path = currentPath else { return }
        Task {
            do {
                let files = stagedFiles.map { $0.path }
                try await engine.unstage(files: files, at: path)
                await loadStatus(at: path)
            } catch {
                print("Error unstaging all: \(error)")
            }
        }
    }

    func stageFolder(_ folder: String) {
        guard let path = currentPath else { return }
        Task {
            do {
                let filesToStage = unstagedFiles.filter {
                    $0.path.hasPrefix(folder + "/") || $0.path == folder
                }.map { $0.path }
                if !filesToStage.isEmpty {
                    try await engine.stage(files: filesToStage, at: path)
                    await loadStatus(at: path)
                }
            } catch {
                print("Error staging folder: \(error)")
            }
        }
    }

    func unstageFolder(_ folder: String) {
        guard let path = currentPath else { return }
        Task {
            do {
                let filesToUnstage = stagedFiles.filter {
                    $0.path.hasPrefix(folder + "/") || $0.path == folder
                }.map { $0.path }
                if !filesToUnstage.isEmpty {
                    try await engine.unstage(files: filesToUnstage, at: path)
                    await loadStatus(at: path)
                }
            } catch {
                print("Error unstaging folder: \(error)")
            }
        }
    }

    func discard(file: StagingFile) {
        guard let path = currentPath else { return }
        Task {
            do {
                try await engine.discardChanges(files: [file.path], at: path)
                await loadStatus(at: path)
            } catch {
                print("Error discarding changes: \(error)")
            }
        }
    }

    func deleteFile(_ file: StagingFile) {
        guard let repoPath = currentPath else { return }
        let absolutePath = URL(fileURLWithPath: repoPath).appendingPathComponent(file.path).path
        Task {
            do {
                try FileManager.default.removeItem(atPath: absolutePath)
                await loadStatus(at: repoPath)
            } catch {
                print("Error deleting file: \(error)")
            }
        }
    }

    func commit(message: String, onSuccess: @escaping () -> Void) {
        guard let path = currentPath, !message.isEmpty else { return }
        Task {
            do {
                let commit = try await engine.commit(message: message, at: path)
                let shortSHA = String(commit.sha.prefix(7))
                await loadStatus(at: path)
                onSuccess()
                NotificationManager.shared.success("Commit completed", detail: "SHA: \(shortSHA)")
            } catch {
                NotificationManager.shared.error("Commit failed", detail: error.localizedDescription)
            }
        }
    }

    /// Image file extensions
    private static let imageExtensions = Set(["png", "jpg", "jpeg", "gif", "webp", "bmp", "tiff", "ico", "svg", "heic", "heif"])

    /// Check if file is an image based on extension
    private func isImageFile(_ path: String) -> Bool {
        let ext = (path as NSString).pathExtension.lowercased()
        return Self.imageExtensions.contains(ext)
    }

    func getDiff(for file: StagingFile, at path: String) async -> FileDiff? {
        // For untracked files, show file content as new additions
        if file.status == .untracked {
            return await getUntrackedFileDiff(for: file, at: path)
        }

        // Check if file is an image - return binary FileDiff for image preview
        if isImageFile(file.path) {
            return FileDiff(
                oldPath: file.path,
                newPath: file.path,
                status: file.status == .deleted ? .deleted : .modified,
                hunks: [],
                isBinary: true,
                additions: 0,
                deletions: 0
            )
        }

        do {
            let diffString = try await engine.getDiff(for: file.path, staged: file.isStaged, at: path)

            // Check if git reports this as a binary file (exact pattern: "Binary files ... differ")
            // Git outputs: "Binary files a/path and b/path differ"
            if diffString.hasPrefix("Binary files ") && diffString.contains(" differ\n") {
                return FileDiff(
                    oldPath: file.path,
                    newPath: file.path,
                    status: file.status == .deleted ? .deleted : .modified,
                    hunks: [],
                    isBinary: true,
                    additions: 0,
                    deletions: 0
                )
            }

            // Use async parser to avoid UI freeze on large files
            let diffs = await DiffParser.parseAsync(diffString)
            return diffs.first
        } catch {
            print("Error getting diff: \(error)")
            return nil
        }
    }

    private func getUntrackedFileDiff(for file: StagingFile, at repoPath: String) async -> FileDiff? {
        let fullPath = (repoPath as NSString).appendingPathComponent(file.path)

        // Check if file is an image - return binary FileDiff for image preview
        if isImageFile(file.path) {
            return FileDiff(
                oldPath: "/dev/null",
                newPath: file.path,
                status: .untracked,
                hunks: [],
                isBinary: true,
                additions: 0,
                deletions: 0
            )
        }

        // Read file content
        guard let content = try? String(contentsOfFile: fullPath, encoding: .utf8) else {
            // Try to read as binary/image indicator
            if FileManager.default.fileExists(atPath: fullPath) {
                return FileDiff(
                    oldPath: "/dev/null",
                    newPath: file.path,
                    status: .untracked,
                    hunks: [DiffHunk(
                        header: "@@ -0,0 +1 @@",
                        oldStart: 0,
                        oldLines: 0,
                        newStart: 1,
                        newLines: 1,
                        lines: [DiffLine(type: .context, content: "[Binary or unreadable file]", oldLineNumber: nil, newLineNumber: 1)]
                    )],
                    isBinary: true,
                    additions: 0,
                    deletions: 0
                )
            }
            return nil
        }

        // Create diff lines showing all content as additions
        let lines = content.components(separatedBy: .newlines)
        var diffLines: [DiffLine] = []

        for (index, line) in lines.enumerated() {
            diffLines.append(DiffLine(
                type: .addition,
                content: line,
                oldLineNumber: nil,
                newLineNumber: index + 1
            ))
        }

        let hunk = DiffHunk(
            header: "@@ -0,0 +1,\(lines.count) @@",
            oldStart: 0,
            oldLines: 0,
            newStart: 1,
            newLines: lines.count,
            lines: diffLines
        )

        return FileDiff(
            oldPath: "/dev/null",
            newPath: file.path,
            status: .untracked,
            hunks: [hunk],
            isBinary: false,
            additions: lines.count,
            deletions: 0
        )
    }
}

// StagingFile and StagingFileStatus are defined in App/Models/StagingFile.swift
// Do not redefine here

// MARK: - Staging Section
struct StagingSection<Content: View>: View {
    let title: String
    let count: Int
    let actionIcon: String
    let actionColor: Color
    let onAction: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.textMuted)
                Spacer()
                Text("\(count)")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textMuted)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppTheme.backgroundTertiary)
                    .cornerRadius(4)
                Button(action: onAction) {
                    Image(systemName: actionIcon)
                        .foregroundColor(actionColor)
                }
                .buttonStyle(.plain)
                .disabled(count == 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppTheme.backgroundSecondary)

            ScrollView {
                LazyVStack(spacing: 0) {
                    content
                }
            }
            .frame(minHeight: 80, maxHeight: 200)
        }
    }
}
