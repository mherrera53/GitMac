import SwiftUI

/// Staging area view - manage staged and unstaged changes
struct StagingAreaView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = StagingAreaViewModel()
    @State private var commitMessage = ""
    @State private var isAmending = false
    @State private var selectedFile: String?
    @State private var showAICommitSheet = false
    @State private var showConflictResolver = false
    @State private var conflictFileToResolve: FileStatus?

    var body: some View {
        HSplitView {
            // Left: File lists
            VStack(spacing: 0) {
                // Conflicted files (if any)
                if !viewModel.conflictedFiles.isEmpty {
                    FileListSection(
                        title: "Conflicts",
                        count: viewModel.conflictedFiles.count,
                        icon: "exclamationmark.triangle.fill",
                        headerColor: .red
                    ) {
                        EmptyView()
                    } content: {
                        ForEach(viewModel.conflictedFiles) { file in
                            ConflictedFileRow(
                                file: file,
                                isSelected: selectedFile == file.path,
                                onSelect: { selectedFile = file.path },
                                onResolve: {
                                    conflictFileToResolve = file
                                    showConflictResolver = true
                                }
                            )
                        }
                    }

                    Divider()
                }

                // Unstaged changes
                FileListSection(
                    title: "Unstaged Changes",
                    count: viewModel.unstagedFiles.count + viewModel.untrackedFiles.count,
                    icon: "square",
                    headerColor: .orange
                ) {
                    HStack {
                        Button("Stage All") {
                            Task { await viewModel.stageAll() }
                        }
                        .buttonStyle(.borderless)

                        Button("Discard All") {
                            Task { await viewModel.discardAll() }
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.red)
                    }
                } content: {
                    if viewModel.unstagedFiles.isEmpty && viewModel.untrackedFiles.isEmpty {
                        Text("No unstaged changes")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        ForEach(viewModel.unstagedFiles) { file in
                            FileRow(
                                file: file,
                                isSelected: selectedFile == file.path,
                                onSelect: { selectedFile = file.path },
                                onStage: { Task { await viewModel.stage(file: file.path) } },
                                onDiscard: { Task { await viewModel.discardChanges(file: file.path) } }
                            )
                        }

                        ForEach(viewModel.untrackedFiles, id: \.self) { path in
                            UntrackedFileRow(
                                path: path,
                                isSelected: selectedFile == path,
                                onSelect: { selectedFile = path },
                                onStage: { Task { await viewModel.stage(file: path) } }
                            )
                        }
                    }
                }

                Divider()

                // Staged changes
                FileListSection(
                    title: "Staged Changes",
                    count: viewModel.stagedFiles.count,
                    icon: "checkmark.square.fill",
                    headerColor: .green
                ) {
                    Button("Unstage All") {
                        Task { await viewModel.unstageAll() }
                    }
                    .buttonStyle(.borderless)
                } content: {
                    if viewModel.stagedFiles.isEmpty {
                        Text("No staged changes")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        ForEach(viewModel.stagedFiles) { file in
                            FileRow(
                                file: file,
                                isSelected: selectedFile == file.path,
                                onSelect: { selectedFile = file.path },
                                onUnstage: { Task { await viewModel.unstage(file: file.path) } }
                            )
                        }
                    }
                }

                Divider()

                // Commit message area
                CommitMessageArea(
                    message: $commitMessage,
                    isAmending: $isAmending,
                    canCommit: viewModel.canCommit(message: commitMessage, amend: isAmending),
                    validationError: viewModel.commitError,
                    hasConflicts: !viewModel.conflictedFiles.isEmpty,
                    onCommit: {
                        Task {
                            let success = await viewModel.commit(message: commitMessage, amend: isAmending)
                            if success {
                                commitMessage = ""
                                isAmending = false
                            }
                        }
                    },
                    onGenerateAI: { showAICommitSheet = true }
                )
            }
            .frame(minWidth: 300)
            .alert("Commit Error", isPresented: $viewModel.showError) {
                Button("OK") { viewModel.showError = false }
            } message: {
                if let error = viewModel.commitError {
                    Text(error.localizedDescription)
                    if let recovery = error.recoverySuggestion {
                        Text(recovery)
                    }
                }
            }

            // Right: Diff viewer
            if let file = selectedFile {
                DiffPreviewView(path: file, staged: viewModel.stagedFiles.contains { $0.path == file })
            } else {
                VStack {
                    Spacer()
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Select a file to view changes")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .sheet(isPresented: $showAICommitSheet) {
            AICommitMessageSheet(message: $commitMessage, diff: viewModel.currentDiff)
        }
        .sheet(isPresented: $showConflictResolver) {
            if let file = conflictFileToResolve, let repoPath = appState.currentRepository?.path {
                InlineConflictResolverView(
                    filePath: file.path,
                    repositoryPath: repoPath,
                    isPresented: $showConflictResolver,
                    onResolved: {
                        // Refresh status after resolving
                        if let repo = appState.currentRepository {
                            Task {
                                await viewModel.loadStatus(for: repo)
                                // Stage the resolved file
                                await viewModel.stage(file: file.path)
                            }
                        }
                    }
                )
            }
        }
        .task {
            if let repo = appState.currentRepository {
                await viewModel.loadStatus(for: repo)
            }
        }
        .onChange(of: appState.currentRepository?.status) { _, _ in
            if let repo = appState.currentRepository {
                Task {
                    await viewModel.loadStatus(for: repo)
                }
            }
        }
    }
}

// MARK: - View Model

// MARK: - Commit Validation Error
enum CommitValidationError: LocalizedError {
    case noStagedFiles
    case emptyMessage
    case messageTooShort
    case noRepository
    case conflictsExist

    var errorDescription: String? {
        switch self {
        case .noStagedFiles:
            return "No files staged for commit"
        case .emptyMessage:
            return "Commit message cannot be empty"
        case .messageTooShort:
            return "Commit message should be at least 3 characters"
        case .noRepository:
            return "No repository selected"
        case .conflictsExist:
            return "Resolve merge conflicts before committing"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .noStagedFiles:
            return "Stage at least one file before committing"
        case .emptyMessage:
            return "Enter a descriptive commit message"
        case .messageTooShort:
            return "Write a more descriptive message"
        case .noRepository:
            return "Open a repository first"
        case .conflictsExist:
            return "Use the conflict resolver to fix merge conflicts"
        }
    }
}

@MainActor
class StagingAreaViewModel: ObservableObject {
    @Published var stagedFiles: [FileStatus] = []
    @Published var unstagedFiles: [FileStatus] = []
    @Published var untrackedFiles: [String] = []
    @Published var conflictedFiles: [FileStatus] = []
    @Published var isLoading = false
    @Published var currentDiff = ""
    @Published var commitError: CommitValidationError?
    @Published var showError = false

    private var currentPath: String?
    private let gitService = GitService()

    func loadStatus(for repo: Repository) async {
        currentPath = repo.path
        stagedFiles = repo.status.staged
        unstagedFiles = repo.status.unstaged
        untrackedFiles = repo.status.untracked
        conflictedFiles = repo.status.conflicted

        // Load diff for all staged files
        currentDiff = (try? await gitService.getDiff(staged: true)) ?? ""

        // Clear any previous error when status updates
        commitError = nil
        showError = false
    }

    func stage(file: String) async {
        guard let _ = currentPath else { return }
        try? await gitService.stage(files: [file])
    }

    func stageAll() async {
        guard let _ = currentPath else { return }
        try? await gitService.stageAll()
    }

    func unstage(file: String) async {
        guard let _ = currentPath else { return }
        try? await gitService.unstage(files: [file])
    }

    func unstageAll() async {
        let allStaged = stagedFiles.map { $0.path }
        try? await gitService.unstage(files: allStaged)
    }

    func discardChanges(file: String) async {
        guard let _ = currentPath else { return }
        try? await gitService.discardChanges(files: [file])
    }

    func discardAll() async {
        let allUnstaged = unstagedFiles.map { $0.path }
        try? await gitService.discardChanges(files: allUnstaged)
    }

    /// Validate commit before executing
    func validateCommit(message: String, amend: Bool = false) -> CommitValidationError? {
        // Check repository
        guard currentPath != nil else {
            return .noRepository
        }

        // Check for conflicts
        if !conflictedFiles.isEmpty {
            return .conflictsExist
        }

        // Check for staged files (unless amending)
        if !amend && stagedFiles.isEmpty {
            return .noStagedFiles
        }

        // Validate message
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedMessage.isEmpty {
            return .emptyMessage
        }

        if trimmedMessage.count < 3 {
            return .messageTooShort
        }

        return nil
    }

    /// Commit with validation
    func commit(message: String, amend: Bool = false) async -> Bool {
        // Validate first
        if let error = validateCommit(message: message, amend: amend) {
            commitError = error
            showError = true
            return false
        }

        guard let _ = currentPath else { return false }

        do {
            _ = try await gitService.commit(message: message, amend: amend)
            commitError = nil
            showError = false
            return true
        } catch {
            // Handle git errors
            return false
        }
    }

    /// Check if can commit (for UI enabling/disabling)
    func canCommit(message: String, amend: Bool = false) -> Bool {
        return validateCommit(message: message, amend: amend) == nil
    }
}

// MARK: - Subviews

struct FileListSection<HeaderActions: View, Content: View>: View {
    let title: String
    let count: Int
    let icon: String
    let headerColor: Color
    @ViewBuilder let headerActions: () -> HeaderActions
    @ViewBuilder let content: () -> Content

    @State private var isExpanded = true

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    withAnimation { isExpanded.toggle() }
                } label: {
                    HStack {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Image(systemName: icon)
                            .foregroundColor(headerColor)

                        Text(title)
                            .fontWeight(.medium)

                        Text("(\(count))")
                            .foregroundColor(.secondary)

                        Spacer()
                    }
                }
                .buttonStyle(.plain)

                headerActions()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))

            // Content
            if isExpanded {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        content()
                    }
                }
            }
        }
    }
}

struct FileRow: View {
    let file: FileStatus
    let isSelected: Bool
    var onSelect: () -> Void = {}
    var onStage: (() -> Void)? = nil
    var onUnstage: (() -> Void)? = nil
    var onDiscard: (() -> Void)? = nil

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            // Status indicator
            StatusIcon(status: file.status)

            // File icon
            Image(systemName: FileTypeIcon.systemIcon(for: file.filename))
                .foregroundColor(FileTypeIcon.color(for: file.filename))
                .frame(width: 16)

            // File path
            VStack(alignment: .leading, spacing: 0) {
                Text(file.filename)
                    .lineLimit(1)

                if !file.directory.isEmpty && file.directory != "." {
                    Text(file.directory)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Actions (shown on hover)
            if isHovered {
                HStack(spacing: 4) {
                    if let stage = onStage {
                        Button {
                            stage()
                        } label: {
                            Image(systemName: "plus.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("Stage")
                    }

                    if let unstage = onUnstage {
                        Button {
                            unstage()
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("Unstage")
                    }

                    if let discard = onDiscard {
                        Button {
                            discard()
                        } label: {
                            Image(systemName: "xmark.circle")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.borderless)
                        .help("Discard changes")
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onHover { isHovered = $0 }
        .contextMenu {
            FileContextMenu(
                filePath: file.path,
                isStaged: onUnstage != nil,
                onStage: onStage,
                onUnstage: onUnstage,
                onDiscard: onDiscard
            )
        }
    }
}

// MARK: - Conflicted File Row

struct ConflictedFileRow: View {
    let file: FileStatus
    let isSelected: Bool
    var onSelect: () -> Void = {}
    var onResolve: () -> Void = {}

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            // Conflict indicator
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .frame(width: 16)

            // File icon
            Image(systemName: FileTypeIcon.systemIcon(for: file.filename))
                .foregroundColor(FileTypeIcon.color(for: file.filename))
                .frame(width: 16)

            // File path
            VStack(alignment: .leading, spacing: 0) {
                Text(file.filename)
                    .lineLimit(1)

                if !file.directory.isEmpty && file.directory != "." {
                    Text(file.directory)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Resolve button
            Button {
                onResolve()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "wand.and.stars")
                    Text("Resolve")
                }
                .font(.caption)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.red.opacity(0.05))
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onHover { isHovered = $0 }
        .contextMenu {
            Button {
                onResolve()
            } label: {
                Label("Resolve Conflict...", systemImage: "wand.and.stars")
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

// MARK: - File Context Menu
struct FileContextMenu: View {
    let filePath: String
    let isStaged: Bool
    var onStage: (() -> Void)?
    var onUnstage: (() -> Void)?
    var onDiscard: (() -> Void)?

    var filename: String {
        URL(fileURLWithPath: filePath).lastPathComponent
    }

    var body: some View {
        Group {
            // Stage/Unstage
            if !isStaged, let stage = onStage {
                Button {
                    stage()
                } label: {
                    Label("Stage File", systemImage: "plus.circle")
                }
            }

            if isStaged, let unstage = onUnstage {
                Button {
                    unstage()
                } label: {
                    Label("Unstage File", systemImage: "minus.circle")
                }
            }

            Divider()

            // File operations
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(filePath, forType: .string)
            } label: {
                Label("Copy Path", systemImage: "doc.on.doc")
            }

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(filename, forType: .string)
            } label: {
                Label("Copy Filename", systemImage: "doc.text")
            }

            Divider()

            Button {
                NSWorkspace.shared.selectFile(filePath, inFileViewerRootedAtPath: "")
            } label: {
                Label("Reveal in Finder", systemImage: "folder")
            }

            Button {
                NSWorkspace.shared.open(URL(fileURLWithPath: filePath))
            } label: {
                Label("Open with Default App", systemImage: "arrow.up.forward.app")
            }

            if !isStaged, let discard = onDiscard {
                Divider()

                Button(role: .destructive) {
                    discard()
                } label: {
                    Label("Discard Changes", systemImage: "xmark.circle")
                }
            }
        }
    }
}

struct UntrackedFileRow: View {
    let path: String
    let isSelected: Bool
    var onSelect: () -> Void = {}
    var onStage: (() -> Void)? = nil

    @State private var isHovered = false

    var filename: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    var directory: String {
        URL(fileURLWithPath: path).deletingLastPathComponent().path
    }

    var body: some View {
        HStack(spacing: 8) {
            StatusIcon(status: .untracked)

            Image(systemName: FileTypeIcon.systemIcon(for: filename))
                .foregroundColor(FileTypeIcon.color(for: filename))
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 0) {
                Text(filename)
                    .lineLimit(1)

                if !directory.isEmpty && directory != "." {
                    Text(directory)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if isHovered, let stage = onStage {
                Button {
                    stage()
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.borderless)
                .help("Stage")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onHover { isHovered = $0 }
        .contextMenu {
            if let stage = onStage {
                Button {
                    stage()
                } label: {
                    Label("Stage File", systemImage: "plus.circle")
                }
            }

            Divider()

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(path, forType: .string)
            } label: {
                Label("Copy Path", systemImage: "doc.on.doc")
            }

            Button {
                NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
            } label: {
                Label("Reveal in Finder", systemImage: "folder")
            }

            Divider()

            Button(role: .destructive) {
                try? FileManager.default.removeItem(atPath: path)
            } label: {
                Label("Delete File", systemImage: "trash")
            }
        }
    }
}

struct StatusIcon: View {
    let status: FileStatusType

    var body: some View {
        Text(status.rawValue)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundColor(statusColor)
            .frame(width: 16, height: 16)
            .background(statusColor.opacity(0.2))
            .cornerRadius(3)
    }

    var statusColor: Color {
        switch status {
        case .added: return .green
        case .modified: return .orange
        case .deleted: return .red
        case .renamed: return .blue
        case .copied: return .blue
        case .untracked: return .gray
        case .ignored: return .gray
        case .typeChanged: return .purple
        case .unmerged: return .red
        }
    }
}

struct CommitMessageArea: View {
    @Binding var message: String
    @Binding var isAmending: Bool
    let canCommit: Bool
    var validationError: CommitValidationError? = nil
    var hasConflicts: Bool = false
    let onCommit: () -> Void
    let onGenerateAI: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Commit Message")
                    .font(.headline)

                Spacer()

                Button {
                    onGenerateAI()
                } label: {
                    Label("Generate with AI", systemImage: "sparkles")
                }
                .buttonStyle(.borderless)
            }

            // Conflict warning
            if hasConflicts {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Resolve merge conflicts before committing")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Spacer()
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(4)
            }

            TextEditor(text: $message)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 80, maxHeight: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(borderColor, lineWidth: 1)
                )

            // Validation hint
            if !canCommit && !message.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                    Text(validationHint)
                        .font(.caption)
                    Spacer()
                }
                .foregroundColor(.secondary)
            }

            // Character count
            HStack {
                Text("\(message.count) characters")
                    .font(.caption2)
                    .foregroundColor(message.count < 3 ? .orange : .secondary)

                Spacer()
            }

            HStack {
                Toggle("Amend last commit", isOn: $isAmending)
                    .toggleStyle(.checkbox)

                Spacer()

                Button("Commit") {
                    onCommit()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canCommit)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }

    var borderColor: Color {
        if hasConflicts {
            return .orange
        }
        if !canCommit && !message.isEmpty {
            return .orange.opacity(0.5)
        }
        return Color.secondary.opacity(0.3)
    }

    var validationHint: String {
        if message.trimmingCharacters(in: .whitespacesAndNewlines).count < 3 {
            return "Message should be at least 3 characters"
        }
        if let error = validationError {
            return error.errorDescription ?? "Cannot commit"
        }
        return "Ready to commit"
    }
}

struct DiffPreviewView: View {
    let path: String
    let staged: Bool

    @State private var diff = ""
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: FileTypeIcon.systemIcon(for: path))
                    .foregroundColor(FileTypeIcon.color(for: path))
                Text(path)
                    .fontWeight(.medium)
                Spacer()

                if staged {
                    Text("Staged")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(4)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Diff content
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if diff.isEmpty {
                Text("No changes to display")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView([.vertical, .horizontal]) {
                    Text(diff)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .padding()
                }
            }
        }
        .task(id: path) {
            await loadDiff()
        }
    }

    private func loadDiff() async {
        isLoading = true
        let service = GitService()
        diff = (try? await service.getDiff(for: path, staged: staged)) ?? ""
        isLoading = false
    }
}

// MARK: - AI Commit Message Sheet

struct AICommitMessageSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var message: String
    let diff: String

    @State private var generatedMessage = ""
    @State private var isGenerating = false
    @State private var error: String?
    @State private var selectedStyle: CommitStyle = .conventional

    private let aiService = AIService()

    var body: some View {
        VStack(spacing: 16) {
            Text("Generate Commit Message")
                .font(.title2)
                .fontWeight(.semibold)

            Picker("Style", selection: $selectedStyle) {
                ForEach(CommitStyle.allCases, id: \.self) { style in
                    Text(style.description).tag(style)
                }
            }
            .pickerStyle(.segmented)

            if isGenerating {
                ProgressView("Generating...")
                    .frame(maxHeight: .infinity)
            } else if !generatedMessage.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Generated Message:")
                        .font(.headline)

                    TextEditor(text: $generatedMessage)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                }
            } else if let error = error {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundColor(.orange)
                    Text(error)
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                VStack {
                    Image(systemName: "sparkles")
                        .font(.system(size: 32))
                        .foregroundColor(.accentColor)
                    Text("Click Generate to create a commit message")
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                if generatedMessage.isEmpty || isGenerating {
                    Button("Generate") {
                        Task { await generate() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isGenerating || diff.isEmpty)
                } else {
                    Button("Regenerate") {
                        Task { await generate() }
                    }

                    Button("Use This") {
                        message = generatedMessage
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
        .frame(width: 500, height: 350)
    }

    private func generate() async {
        isGenerating = true
        error = nil

        do {
            generatedMessage = try await aiService.generateCommitMessage(
                diff: diff,
                style: selectedStyle
            )
        } catch {
            self.error = error.localizedDescription
        }

        isGenerating = false
    }
}

// #Preview {
//     StagingAreaView()
//         .environmentObject(AppState())
//         .frame(width: 800, height: 600)
// }
