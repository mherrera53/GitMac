import SwiftUI

/// Three-way merge conflict resolver
struct ConflictResolverView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager

    @Environment(AppState.self) var appState
    @StateObject private var viewModel = ConflictResolverViewModel()
    @State private var selectedFile: ConflictFile?
    @State private var showAbortConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // Header with conflict count
            ConflictHeader(
                conflictCount: viewModel.conflictFiles.count,
                resolvedCount: viewModel.resolvedCount,
                operation: viewModel.operation,
                canContinue: viewModel.allResolved,
                isBusy: viewModel.isLoading || viewModel.isPerformingOperation,
                onAbort: { showAbortConfirmation = true },
                onContinue: {
                    let path = appState.currentRepository?.path
                    Task {
                        if await viewModel.continueMerge(), let repo = appState.currentRepository, repo.path == path {
                            try? await appState.gitService.refresh()
                            await viewModel.loadConflicts(from: repo)
                        }
                    }
                }
            )

            HStack {
                Text("Current = index stage 2 · Incoming = stage 3. During rebase, current is the checked-out base and incoming is the replayed commit.")
                    .font(.caption).foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Button("Reload") {
                    if let repo = appState.currentRepository { Task { await viewModel.loadConflicts(from: repo) } }
                }
                .disabled(viewModel.isLoading || viewModel.isPerformingOperation)
                if let recovery = viewModel.recoveryURL {
                    Button("Recovery copies") {
                        NSWorkspace.shared.activateFileViewerSelecting([recovery.deletingLastPathComponent()])
                    }.accessibilityIdentifier("conflict-recovery-history")
                }
                Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("conflict-close")
            }
            .padding(.horizontal).padding(.vertical, 8)

            if !viewModel.commitMessagePreview.isEmpty && viewModel.allResolved {
                DisclosureGroup("Prepared Git message") {
                    Text(viewModel.commitMessagePreview).font(.caption.monospaced()).textSelection(.enabled)
                }.padding(.horizontal)
            }

            if let error = viewModel.error {
                VStack(alignment: .leading, spacing: 6) {
                    Text(error).font(.callout).foregroundStyle(AppTheme.error).textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding()
                .accessibilityIdentifier("conflict-operation-error")
            }

            Divider()

            HSplitView {
                // Left: File list
                ConflictFileList(
                    files: viewModel.conflictFiles,
                    selectedFile: $selectedFile
                )
                .frame(minWidth: 200, maxWidth: 300)

                // Right: Resolution View
                if let file = selectedFile {
                    // Use InlineConflictResolver for better UX (VS Code style)
                    InlineConflictResolver(
                        filePath: file.path,
                        repositoryPath: appState.currentRepository?.path ?? "",
                        isAlreadyResolved: file.isResolved,
                        savedRecoveryURL: viewModel.recoveryByPath[file.path],
                        onRecoveryCreated: { viewModel.rememberRecovery($0, for: file) },
                        onResolved: {
                            Task {
                                await viewModel.noteStagedResolution(file)
                            }
                        }
                    )
                    .id(file.snapshot?.id ?? file.id)
                } else if viewModel.isLoading {
                    ProgressView("Reading conflicts from Git…").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.error != nil {
                    Text("Conflict status needs review. Reload from Git before continuing.")
                        .foregroundStyle(AppTheme.textSecondary).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    EmptyConflictView()
                }
            }
        }
        .background(AppTheme.background)
        .tint(AppTheme.accent)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("conflict-resolver")
        .task(id: appState.currentRepository?.path) {
            selectedFile = nil
            if let repo = appState.currentRepository {
                await viewModel.loadConflicts(from: repo)
                if selectedFile == nil {
                    selectedFile = viewModel.conflictFiles.first
                }
            }
        }
        .onReceive(viewModel.$conflictFiles) { files in
            selectedFile = files.first(where: { $0.id == selectedFile?.id }) ?? files.first
        }
        .confirmationDialog("Abort \(viewModel.operation.title)?", isPresented: $showAbortConfirmation, titleVisibility: .visible) {
            Button("Preserve conflict copies and abort", role: .destructive) {
                let path = appState.currentRepository?.path
                Task {
                    if await viewModel.abortMerge(), appState.currentRepository?.path == path { try? await appState.gitService.refresh() }
                }
            }
            Button("Keep resolving", role: .cancel) {}
        } message: {
            Text("GitMac saves supported conflict files and index versions first. Additional local changes block this action until they have separate recovery support. This does not delete saved recovery copies.")
        }
    }
}

// MARK: - View Model

import Darwin
import CryptoKit

enum GitConflictOperation: String, Sendable {
    case merge, rebase, cherryPick, revert, none

    static func detect(_ locations: RepositoryFileLocations) -> Self {
        let fm = FileManager.default
        func exists(_ name: String) -> Bool { fm.fileExists(atPath: locations.gitDirectory.appendingPathComponent(name).path) }
        if exists("rebase-merge") || (exists("rebase-apply") && !exists("rebase-apply/applying")) { return .rebase }
        if exists("MERGE_HEAD") { return .merge }
        if exists("CHERRY_PICK_HEAD") { return .cherryPick }
        if exists("REVERT_HEAD") { return .revert }
        return .none
    }

    var title: String {
        switch self { case .cherryPick: return "cherry-pick"; default: return rawValue }
    }
    var continueArguments: [String]? {
        switch self {
        case .merge: return ["commit", "--no-edit"]
        case .none: return nil
        default: return [title, "--continue"]
        }
    }
    var abortArguments: [String]? { self == .none ? nil : [title, "--abort"] }
}

struct ConflictResolutionFailure: LocalizedError {
    let message: String
    var recoveryURL: URL? = nil
    var errorDescription: String? {
        message + (recoveryURL.map { "\nOriginal and proposal retained at: \($0.path)" } ?? "")
    }
}

/// Immutable evidence from the index and working copy used for a resolution.
/// Binary/deletion/symlink UI remains explicit; this writer accepts regular files.
struct ConflictResolutionSnapshot: Sendable {
    struct Fingerprint: Equatable, Sendable {
        let path: String
        let worktreeID: String
        let headOID: String
        let permissions: Int
        let workingDigest: Data
        let indexDigest: Data
    }
    let id = UUID()
    let locations: RepositoryFileLocations
    let path: String
    let workingData: Data
    let permissions: Int
    let unmergedIndex: Data
    let headOID: String
    let stages: [Int: Data]
    static let maximumFileBytes = 8 * 1024 * 1024

    static func inlineText(from bytes: Data) throws -> String {
        guard bytes.count <= 2 * 1024 * 1024, !bytes.contains(0), let text = String(data: bytes, encoding: .utf8) else {
            throw ConflictResolutionFailure(message: "The inline editor supports UTF-8 text previews up to 2 MB. No file was changed; use an external resolver for binary or larger content.")
        }
        var lines = 1, columns = 0
        for byte in bytes {
            if byte == 10 { lines += 1; columns = 0 } else { columns += 1 }
            guard lines <= 20_000, columns <= 16_384 else {
                throw ConflictResolutionFailure(message: "This file exceeds the inline editor's line limits. No file was changed; use an external resolver for this content.")
            }
        }
        return text
    }

    var fileURL: URL { locations.workingDirectory.appendingPathComponent(path) }
    var fingerprint: Fingerprint {
        Fingerprint(path: path, worktreeID: locations.worktreeID, headOID: headOID, permissions: permissions,
            workingDigest: Data(SHA256.hash(data: workingData)), indexDigest: Data(SHA256.hash(data: unmergedIndex)))
    }

    static func readRegularFile(_ url: URL, root: URL, maximumBytes: Int = maximumFileBytes) throws -> (Data, Int) {
        let normalized = url.standardizedFileURL
        guard normalized.path.hasPrefix(root.path + "/"),
              normalized.resolvingSymlinksInPath().path == normalized.path else {
            throw ConflictResolutionFailure(message: "The conflict path traverses a symbolic link or leaves the worktree. No file was changed.")
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: normalized.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular else {
            throw ConflictResolutionFailure(message: "The conflict is not a regular file. No file was changed; use a file-level external resolution.")
        }
        let descriptor = Darwin.open(normalized.path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK)
        guard descriptor >= 0 else { throw CocoaError(.fileReadNoPermission) }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        var info = stat()
        guard fstat(descriptor, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG,
              info.st_size >= 0, info.st_size <= maximumBytes else {
            throw ConflictResolutionFailure(message: "This resolver requires a regular file within the preview limit. The file was not modified; resolve this file with an external tool.")
        }
        let bytes = try handle.read(upToCount: maximumBytes + 1) ?? Data()
        guard bytes.count <= maximumBytes, bytes.count == Int(info.st_size) else {
            throw ConflictResolutionFailure(message: "The file grew beyond the resolver limit. Reload before continuing.")
        }
        return (bytes, Int(info.st_mode & 0o777))
    }

    static func capture(repositoryPath: String, path: String, maximumBytes: Int = maximumFileBytes) async throws -> Self {
        let limit = min(maximumFileBytes, max(1, maximumBytes))
        guard !path.isEmpty, !path.hasPrefix("/"), !path.contains("\0"),
              !path.split(separator: "/", omittingEmptySubsequences: false).contains(where: { $0 == ".." || $0 == "." || $0.isEmpty }) else {
            throw ConflictResolutionFailure(message: "Invalid conflict path. No file was changed.")
        }
        let locations = try RepositoryFileLocations(repositoryPath: repositoryPath)
        let file = locations.workingDirectory.appendingPathComponent(path)
        let (workingData, permissions) = try readRegularFile(file, root: locations.workingDirectory, maximumBytes: limit)
        let index = await ShellExecutor.shared.executeData("git", arguments: ["ls-files", "--unmerged", "-z", "--", path],
            workingDirectory: locations.workingDirectory.path, maxOutputBytes: 1024 * 1024)
        guard index.isSuccess, let records = index.stdoutData, !records.isEmpty,
              let text = String(data: records, encoding: .utf8) else {
            throw ConflictResolutionFailure(message: "Git could not confirm unmerged index entries for this file. Reload its status before resolving.")
        }
        var stages: [Int: Data] = [:]
        for record in text.split(separator: "\0") {
            guard let tab = record.firstIndex(of: "\t"),
                  let value = record[..<tab].split(separator: " ").last,
                  let stage = Int(value), (1...3).contains(stage) else {
                throw ConflictResolutionFailure(message: "Git returned an unsupported unmerged index record.")
            }
            let blob = await ShellExecutor.shared.executeData("git", arguments: ["show", "--no-ext-diff", "--no-textconv", ":\(stage):\(path)"],
                workingDirectory: locations.workingDirectory.path, maxOutputBytes: limit)
            guard blob.isSuccess, let data = blob.stdoutData else {
                throw ConflictResolutionFailure(message: "Could not read index stage \(stage). No file was changed. " + blob.stderr)
            }
            stages[stage] = data
        }
        let snapshot = Self(locations: locations, path: path, workingData: workingData,
            permissions: permissions, unmergedIndex: records,
            headOID: try await currentHead(at: locations.workingDirectory.path), stages: stages)
        try await snapshot.validate()
        return snapshot
    }

    static func currentFingerprint(locations: RepositoryFileLocations, path: String) async throws -> Fingerprint {
        let (bytes, mode) = try readRegularFile(locations.workingDirectory.appendingPathComponent(path), root: locations.workingDirectory)
        let index = await ShellExecutor.shared.executeData("git", arguments: ["ls-files", "--unmerged", "-z", "--", path],
            workingDirectory: locations.workingDirectory.path, maxOutputBytes: 1024 * 1024)
        guard index.isSuccess, let data = index.stdoutData else { throw ConflictResolutionFailure(message: "Could not revalidate the conflict index before aborting.") }
        let head = try await currentHead(at: locations.workingDirectory.path)
        guard try RepositoryFileLocations(repositoryPath: locations.workingDirectory.path).worktreeID == locations.worktreeID else {
            throw ConflictResolutionFailure(message: "The worktree identity changed. No abort was executed.")
        }
        return Fingerprint(path: path, worktreeID: locations.worktreeID, headOID: head, permissions: mode,
            workingDigest: Data(SHA256.hash(data: bytes)), indexDigest: Data(SHA256.hash(data: data)))
    }

    func validateWorkingCopy() throws {
        guard try RepositoryFileLocations(repositoryPath: locations.workingDirectory.path).worktreeID == locations.worktreeID else {
            throw ConflictResolutionFailure(message: "The worktree identity changed. Reopen the resolver.")
        }
        let (data, mode) = try Self.readRegularFile(fileURL, root: locations.workingDirectory)
        guard data == workingData, mode == permissions else {
            throw ConflictResolutionFailure(message: "The local file changed after this preview opened. Your newer content was kept. Reload and review the resolution again.")
        }
        guard !FileManager.default.fileExists(atPath: locations.gitDirectory.appendingPathComponent("index.lock").path) else {
            throw ConflictResolutionFailure(message: "Another Git operation holds the index lock. No file was changed. Wait for it to finish, then retry.")
        }
    }

    func validate() async throws {
        try Task.checkCancellation()
        guard try await Self.currentHead(at: locations.workingDirectory.path) == headOID else {
            throw ConflictResolutionFailure(message: "HEAD changed after this conflict opened. No file was changed. Reload the resolver.")
        }
        let index = await ShellExecutor.shared.executeData("git", arguments: ["ls-files", "--unmerged", "-z", "--", path],
            workingDirectory: locations.workingDirectory.path, maxOutputBytes: 1024 * 1024)
        guard index.isSuccess, index.stdoutData == unmergedIndex else {
            throw ConflictResolutionFailure(message: "The index changed after this conflict opened. No file was changed. Reload and review its current state.")
        }
        try validateWorkingCopy()
    }

    private static func currentHead(at path: String) async throws -> String {
        let result = await ShellExecutor.shared.execute("git", arguments: ["rev-parse", "--verify", "HEAD"], workingDirectory: path)
        guard result.isSuccess else { throw ConflictResolutionFailure(message: "Git could not verify the current HEAD. " + result.stderr) }
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Serializes GitMac resolution writes per worktree, preserving recovery data.
actor ConflictResolutionStore {
    static let shared = ConflictResolutionStore()
    private var activeWorktrees: Set<String> = []

    func save(_ content: Data, snapshot: ConflictResolutionSnapshot) async throws -> URL {
        let identity = snapshot.locations.worktreeID
        guard activeWorktrees.insert(identity).inserted else {
            throw ConflictResolutionFailure(message: "Another resolution is saving in this worktree. Wait, then reload its status.")
        }
        defer { activeWorktrees.remove(identity) }
        guard content.count <= ConflictResolutionSnapshot.maximumFileBytes else {
            throw ConflictResolutionFailure(message: "The proposed resolution exceeds 8 MB. No file was changed.")
        }
        if let text = String(data: content, encoding: .utf8), !content.contains(0), ConflictParser.containsMarkers(in: text) {
            throw ConflictResolutionFailure(message: "Conflict markers remain in the proposed text. No file was changed. Review every block before saving.")
        }
        try await snapshot.validate()
        let recovery = try makeRecovery(content, snapshot: snapshot, purpose: "resolution")
        do {
            try await snapshot.validate()
            try Task.checkCancellation()
            try snapshot.validateWorkingCopy()
            try content.write(to: snapshot.fileURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: snapshot.permissions], ofItemAtPath: snapshot.fileURL.path)
            let staged = await ShellExecutor.shared.execute("git", arguments: ["add", "--", snapshot.path],
                workingDirectory: snapshot.locations.workingDirectory.path)
            guard staged.isSuccess else {
                throw ConflictResolutionFailure(message: "The resolution was written but Git could not stage it. " + staged.stderr)
            }
            return recovery
        } catch {
            // Never blindly restore over a possible newer editor change.
            throw ConflictResolutionFailure(message: error.localizedDescription, recoveryURL: recovery)
        }
    }

    /// Abort only after preserving every supported conflict and verifying that
    /// no additional local files would need a broader recovery archive.
    func abort(paths: [String], locations: RepositoryFileLocations,
               operation: GitConflictOperation) async throws -> URL? {
        guard let arguments = operation.abortArguments,
              GitConflictOperation.detect(locations) == operation else {
            throw ConflictResolutionFailure(message: "The Git operation changed. Refresh before aborting.")
        }
        let identity = locations.worktreeID
        guard activeWorktrees.insert(identity).inserted else {
            throw ConflictResolutionFailure(message: "Another resolution is saving. Wait before aborting.")
        }
        defer { activeWorktrees.remove(identity) }
        let allowedPaths = Set(paths)
        var fingerprints: [ConflictResolutionSnapshot.Fingerprint] = []
        var recovery: URL?
        do {
            for path in allowedPaths.sorted() {
                let archived = try await archiveAbortFile(path, locations: locations)
                fingerprints.append(archived.0)
                recovery = archived.1
            }
            for query in [["diff", "--name-only", "-z"], ["diff", "--cached", "--name-only", "-z"],
                          ["ls-files", "--others", "--exclude-standard", "-z"]] {
                let result = await ShellExecutor.shared.executeData("git", arguments: query,
                    workingDirectory: locations.workingDirectory.path, maxOutputBytes: 1024 * 1024)
                guard result.isSuccess, let data = result.stdoutData, let text = String(data: data, encoding: .utf8) else {
                    throw ConflictResolutionFailure(message: "Could not verify local changes before aborting. No abort was executed.")
                }
                guard text.split(separator: "\0").allSatisfy({ allowedPaths.contains(String($0)) }) else {
                    throw ConflictResolutionFailure(message: "Additional local changes need a separate recovery archive before aborting. No abort was executed; your files remain in place.")
                }
            }
            for fingerprint in fingerprints {
                guard try await ConflictResolutionSnapshot.currentFingerprint(locations: locations, path: fingerprint.path) == fingerprint else {
                    throw ConflictResolutionFailure(message: "A local conflict changed during backup. No abort was executed; reload and review it.")
                }
            }
            guard GitConflictOperation.detect(locations) == operation else {
                throw ConflictResolutionFailure(message: "The operation changed during backup. No abort was executed.")
            }
            try Task.checkCancellation()
            let result = await ShellExecutor.shared.execute("git", arguments: arguments, workingDirectory: locations.workingDirectory.path)
            guard result.isSuccess else { throw ConflictResolutionFailure(message: "Git could not finish the abort. " + result.stderr) }
            return recovery
        } catch {
            throw ConflictResolutionFailure(message: error.localizedDescription, recoveryURL: recovery)
        }
    }

    private func archiveAbortFile(_ path: String, locations: RepositoryFileLocations) async throws -> (ConflictResolutionSnapshot.Fingerprint, URL) {
        // This function's raw blobs leave scope before the next file is loaded.
        let snapshot = try await ConflictResolutionSnapshot.capture(repositoryPath: locations.workingDirectory.path, path: path)
        guard snapshot.locations.worktreeID == locations.worktreeID else {
            throw ConflictResolutionFailure(message: "The worktree identity changed. No abort was executed.")
        }
        let recovery = try makeRecovery(snapshot.workingData, snapshot: snapshot, purpose: "before-abort")
        return (snapshot.fingerprint, recovery)
    }

    func continueOperation(locations: RepositoryFileLocations, operation: GitConflictOperation) async throws {
        let identity = locations.worktreeID
        guard activeWorktrees.insert(identity).inserted else {
            throw ConflictResolutionFailure(message: "A resolution is still saving. Wait before continuing.")
        }
        defer { activeWorktrees.remove(identity) }
        guard GitConflictOperation.detect(locations) == operation, let arguments = operation.continueArguments else {
            throw ConflictResolutionFailure(message: "No matching Git operation is active. Refresh before continuing.")
        }
        let path = locations.workingDirectory.path
        let index = await ShellExecutor.shared.executeData("git", arguments: ["ls-files", "--unmerged", "-z"], workingDirectory: path)
        guard index.isSuccess, index.stdoutData?.isEmpty == true else {
            throw ConflictResolutionFailure(message: "Git still has unresolved index entries. Resolve and stage them before continuing.")
        }
        let changed = await ShellExecutor.shared.executeData("git", arguments: ["diff", "--cached", "--name-only", "--diff-filter=ACMRT", "-z"],
            workingDirectory: path, maxOutputBytes: 1024 * 1024)
        guard changed.isSuccess, let data = changed.stdoutData, let names = String(data: data, encoding: .utf8) else {
            throw ConflictResolutionFailure(message: "Could not verify the staged files before continuing.")
        }
        for name in names.split(separator: "\0") {
            let blob = await ShellExecutor.shared.executeData("git", arguments: ["show", "--no-ext-diff", "--no-textconv", ":\(name)"],
                workingDirectory: path, maxOutputBytes: ConflictResolutionSnapshot.maximumFileBytes)
            guard blob.isSuccess, let bytes = blob.stdoutData else {
                throw ConflictResolutionFailure(message: "Could not verify a staged file within the resolver limits. Review it externally before continuing. " + blob.stderr)
            }
            if !bytes.contains(0), let text = String(data: bytes, encoding: .utf8), ConflictParser.containsMarkers(in: text) {
                throw ConflictResolutionFailure(message: "Staged conflict markers remain in \(name). No continuation was executed.")
            }
        }
        guard GitConflictOperation.detect(locations) == operation else {
            throw ConflictResolutionFailure(message: "The Git operation changed. Refresh before continuing.")
        }
        try Task.checkCancellation()
        let result = await ShellExecutor.shared.execute("git", arguments: arguments, workingDirectory: path,
            environment: ["GIT_EDITOR": "/usr/bin/true"], timeout: 600)
        guard result.isSuccess else { throw ConflictResolutionFailure(message: "Git could not continue \(operation.title). " + result.stderr) }
    }

    private func makeRecovery(_ content: Data, snapshot: ConflictResolutionSnapshot, purpose: String) throws -> URL {
        let fm = FileManager.default
        let parent = snapshot.locations.gitDirectory.appendingPathComponent("gitmac-recovery", isDirectory: true)
        if !fm.fileExists(atPath: parent.path) {
            try fm.createDirectory(at: parent, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        }
        let attributes = try fm.attributesOfItem(atPath: parent.path)
        guard attributes[.type] as? FileAttributeType == .typeDirectory,
              parent.resolvingSymlinksInPath().path == parent.standardizedFileURL.path else {
            throw ConflictResolutionFailure(message: "The recovery location is unsafe. No file was changed.")
        }
        let recovery = parent.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: recovery, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        do {
            func preserve(_ data: Data, _ name: String) throws {
                let url = recovery.appendingPathComponent(name)
                try data.write(to: url, options: .withoutOverwriting)
                try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            }
            try preserve(snapshot.workingData, "working-copy.original")
            try preserve(content, "resolution.proposed")
            try preserve(snapshot.unmergedIndex, "unmerged-index.records")
            for (stage, data) in snapshot.stages { try preserve(data, "stage-\(stage).original") }
            let metadata: [String: Any] = ["version": 1, "path": snapshot.path,
                "worktreeID": snapshot.locations.worktreeID, "headOID": snapshot.headOID,
                "permissions": snapshot.permissions, "purpose": purpose,
                "createdAt": ISO8601DateFormatter().string(from: Date()),
                "scope": "Original, index stages and proposed file; not a full repository backup or automatic undo"]
            try preserve(JSONSerialization.data(withJSONObject: metadata, options: [.sortedKeys, .prettyPrinted]), "metadata.json")
            return recovery
        } catch {
            // Never blindly restore over a possible newer editor change.
            throw ConflictResolutionFailure(message: error.localizedDescription, recoveryURL: recovery)
        }
    }
}

@MainActor
class ConflictResolverViewModel: ObservableObject {
    @Published var conflictFiles: [ConflictFile] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published private(set) var recoveryURL: URL?
    @Published private(set) var recoveryByPath: [String: URL] = [:]
    @Published private(set) var operation = GitConflictOperation.none
    @Published private(set) var isPerformingOperation = false
    @Published private(set) var commitMessagePreview = ""

    private let aiService = AIService()
    private var repositoryPath: String = ""
    private var loadGeneration = UUID()

    var resolvedCount: Int {
        conflictFiles.filter { $0.isResolved }.count
    }

    var allResolved: Bool {
        operation != .none && conflictFiles.allSatisfy { $0.isResolved }
    }

    func loadConflicts(from repo: Repository) async {
        loadGeneration = UUID()
        let generation = loadGeneration
        if repositoryPath != repo.path { recoveryByPath = [:]; recoveryURL = nil }
        repositoryPath = repo.path
        isLoading = true
        conflictFiles = []
        error = nil
        defer { if loadGeneration == generation { isLoading = false } }
        do {
            let locations = try RepositoryFileLocations(repositoryPath: repo.path)
            operation = GitConflictOperation.detect(locations)
            commitMessagePreview = (try? String(contentsOf: locations.gitDirectory.appendingPathComponent("MERGE_MSG"), encoding: .utf8)) ?? ""
        } catch { self.error = error.localizedDescription; operation = .none; return }

        var files: [ConflictFile] = []
        let result = await ShellExecutor.shared.executeData("git", arguments: ["diff", "--name-only", "--diff-filter=U", "-z"],
            workingDirectory: repo.path, maxOutputBytes: 1024 * 1024)
        guard !Task.isCancelled, loadGeneration == generation else { return }
        guard result.isSuccess, let data = result.stdoutData, let names = String(data: data, encoding: .utf8) else {
            error = "Could not read current conflicts from Git. " + result.stderr
            return
        }
        for name in names.split(separator: "\0") {
            let path = String(name)
            if !files.isEmpty {
                // The native inline editor loads the selected file on demand.
                // Keep the complete list without retaining all versions of it.
                files.append(ConflictFile(path: path, oursContent: "", theirsContent: "", baseContent: nil))
                continue
            }
            do {
                let snapshot = try await ConflictResolutionSnapshot.capture(repositoryPath: repo.path, path: path, maximumBytes: 2 * 1024 * 1024)
                guard !Task.isCancelled, loadGeneration == generation else { return }
                _ = try ConflictResolutionSnapshot.inlineText(from: snapshot.workingData)
                let ours = try snapshot.stages[2].map { try ConflictResolutionSnapshot.inlineText(from: $0) }
                let theirs = try snapshot.stages[3].map { try ConflictResolutionSnapshot.inlineText(from: $0) }
                files.append(ConflictFile(path: path, oursContent: ours ?? "", theirsContent: theirs ?? "",
                    baseContent: try snapshot.stages[1].map { try ConflictResolutionSnapshot.inlineText(from: $0) }, snapshot: snapshot))
            } catch {
                guard !Task.isCancelled, loadGeneration == generation else { return }
                files.append(ConflictFile(path: path, oursContent: "", theirsContent: "", baseContent: nil,
                    unsupportedReason: error.localizedDescription))
            }
        }
        guard !Task.isCancelled, loadGeneration == generation else { return }
        conflictFiles = files
    }

    func loadConflictContent(for path: String) async -> (ours: String, theirs: String, base: String?) {
        do {
            let snapshot = try await ConflictResolutionSnapshot.capture(repositoryPath: repositoryPath, path: path)
            return (snapshot.stages[2].flatMap { String(data: $0, encoding: .utf8) } ?? "",
                    snapshot.stages[3].flatMap { String(data: $0, encoding: .utf8) } ?? "",
                    snapshot.stages[1].flatMap { String(data: $0, encoding: .utf8) })
        } catch { self.error = error.localizedDescription; return ("", "", nil) }
    }

    func rememberRecovery(_ url: URL, for file: ConflictFile) {
        guard conflictFiles.contains(where: { $0.id == file.id }) else { return }
        recoveryByPath[file.path] = url
        recoveryURL = url
    }

    func resolveWithOurs(_ file: ConflictFile) async {
        guard file.snapshot?.stages[2] != nil else {
            error = "The current index side is absent. A deletion requires an explicit file-level resolution; no file was changed."
            return
        }
        await resolveFile(file, with: file.oursContent)
    }

    func resolveWithTheirs(_ file: ConflictFile) async {
        guard file.snapshot?.stages[3] != nil else {
            error = "The incoming index side is absent. A deletion requires an explicit file-level resolution; no file was changed."
            return
        }
        await resolveFile(file, with: file.theirsContent)
    }

    func resolveWithCustom(_ file: ConflictFile, content: String) async {
        await resolveFile(file, with: content)
    }

    func resolveWithAI(_ file: ConflictFile) async -> AIConflictResolution? {
        do {
            return try await aiService.suggestConflictResolution(
                ours: file.oursContent,
                theirs: file.theirsContent,
                base: file.baseContent,
                filename: file.path
            )
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    private func resolveFile(_ file: ConflictFile, with content: String) async {
        guard let snapshot = file.snapshot,
              snapshot.locations.workingDirectory.path == URL(fileURLWithPath: repositoryPath).standardizedFileURL.resolvingSymlinksInPath().path else {
            error = file.unsupportedReason ?? "This resolution belongs to an old or unsupported preview. Reload before saving."
            return
        }
        guard !snapshot.workingData.contains(0), String(data: snapshot.workingData, encoding: .utf8) != nil,
              snapshot.stages.values.allSatisfy({ !$0.contains(0) && String(data: $0, encoding: .utf8) != nil }) else {
            error = "This is not a supported UTF-8 text conflict. No file was changed. Use an external resolver for binary content."
            return
        }
        let generation = loadGeneration
        error = nil
        do {
            let recovery = try await ConflictResolutionStore.shared.save(Data(content.utf8), snapshot: snapshot)
            guard generation == loadGeneration else { return }
            recoveryURL = recovery
            recoveryByPath[file.path] = recovery
            if let index = conflictFiles.firstIndex(where: { $0.id == file.id }) {
                conflictFiles[index].isResolved = true
                conflictFiles[index].resolvedContent = content
            }
        } catch {
            guard generation == loadGeneration else { return }
            self.error = error.localizedDescription
            recoveryURL = (error as? ConflictResolutionFailure)?.recoveryURL
        }
    }

    func markResolved(_ file: ConflictFile) async {
        guard let snapshot = file.snapshot,
              snapshot.locations.workingDirectory.path == URL(fileURLWithPath: repositoryPath).standardizedFileURL.resolvingSymlinksInPath().path else {
            error = "Reload this conflict before staging."; return
        }
        let generation = loadGeneration
        do { try await snapshot.validate() }
        catch { self.error = error.localizedDescription; return }
        guard generation == loadGeneration else { return }
        guard let text = String(data: snapshot.workingData, encoding: .utf8), !snapshot.workingData.contains(0),
              !ConflictParser.containsMarkers(in: text) else {
            error = "Unresolved text markers remain. Review the file before staging it."
            return
        }
        // Stage the file
        let result = await ShellExecutor.shared.execute(
            "git", arguments: ["add", "--", file.path],
            workingDirectory: repositoryPath
        )
        guard generation == loadGeneration else { return }
        guard result.isSuccess else {
            self.error = result.stderr.isEmpty ? "Git could not stage the resolved file." : result.stderr
            return
        }
        if let index = conflictFiles.firstIndex(where: { $0.id == file.id }) {
            conflictFiles[index].isResolved = true
        }
    }

    /// The inline resolver already staged its verified snapshot. Never stage a
    /// second time and accidentally include a newer edit made after that save.
    func noteStagedResolution(_ file: ConflictFile) async {
        let generation = loadGeneration
        let result = await ShellExecutor.shared.execute("git", arguments: ["ls-files", "--unmerged", "-z", "--", file.path],
            workingDirectory: repositoryPath)
        guard generation == loadGeneration else { return }
        guard result.isSuccess, result.stdout.isEmpty else { error = "Git still reports a conflict. Reload its status."; return }
        if let index = conflictFiles.firstIndex(where: { $0.id == file.id }) { conflictFiles[index].isResolved = true }
    }

    @discardableResult
    func abortMerge() async -> Bool {
        guard !isLoading, !isPerformingOperation else { return false }
        isPerformingOperation = true
        defer { isPerformingOperation = false }
        let generation = loadGeneration
        do {
            let locations = try RepositoryFileLocations(repositoryPath: repositoryPath)
            let active = GitConflictOperation.detect(locations)
            guard active == operation, active != .none else {
                throw ConflictResolutionFailure(message: "No matching merge, rebase, cherry-pick or revert is active. Refresh before aborting.")
            }
            let recovery = try await ConflictResolutionStore.shared.abort(paths: conflictFiles.map(\.path), locations: locations, operation: active)
            guard generation == loadGeneration else { return true }
            recoveryURL = recovery
            conflictFiles = []
            operation = .none
            error = nil
            NotificationManager.shared.success("\(active.title.capitalized) aborted", detail: "Conflict copies were preserved before aborting.")
            return true
        } catch {
            guard generation == loadGeneration else { return false }
            self.error = error.localizedDescription
            recoveryURL = (error as? ConflictResolutionFailure)?.recoveryURL
            return false
        }
    }

    @discardableResult
    func continueMerge() async -> Bool {
        guard !isLoading, !isPerformingOperation else { return false }
        isPerformingOperation = true
        defer { isPerformingOperation = false }
        let generation = loadGeneration
        let path = repositoryPath
        do {
            let locations = try RepositoryFileLocations(repositoryPath: path)
            let active = GitConflictOperation.detect(locations)
            guard active == operation, active.continueArguments != nil else {
                throw ConflictResolutionFailure(message: "No matching operation is active. A stash resolution is staged for a normal commit; it must not create a merge commit automatically.")
            }
            // The GUI shows the prepared message; the user's Continue action
            // authorizes it. Hooks/signatures remain active; no global config.
            try await ConflictResolutionStore.shared.continueOperation(locations: locations, operation: active)
            guard generation == loadGeneration else { return true }
            operation = GitConflictOperation.detect(locations)
            error = nil
            NotificationManager.shared.success("\(active.title.capitalized) continued")
            return true
        } catch {
            guard generation == loadGeneration else { return false }
            self.error = error.localizedDescription
            return false
        }
    }
}

// MARK: - Models

struct ConflictFile: Identifiable, Hashable {
    let id = UUID()
    let path: String
    let oursContent: String
    let theirsContent: String
    let baseContent: String?
    var snapshot: ConflictResolutionSnapshot? = nil
    var unsupportedReason: String? = nil
    var isResolved = false
    var resolvedContent: String?

    var filename: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    static func == (lhs: ConflictFile, rhs: ConflictFile) -> Bool {
        lhs.id == rhs.id && lhs.isResolved == rhs.isResolved && lhs.resolvedContent == rhs.resolvedContent
            && lhs.unsupportedReason == rhs.unsupportedReason && lhs.snapshot?.id == rhs.snapshot?.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Represents a single conflict chunk within a file
struct ConflictChunk: Identifiable {
    let id = UUID()
    let startLine: Int
    let endLine: Int
    let oursLines: [String]
    let theirsLines: [String]
    let baseLines: [String]?
    var resolution: ChunkResolution = .unresolved

    enum ChunkResolution: Equatable {
        case unresolved
        case ours
        case theirs
        case both
        case custom(String)

        static func == (lhs: ChunkResolution, rhs: ChunkResolution) -> Bool {
            switch (lhs, rhs) {
            case (.unresolved, .unresolved): return true
            case (.ours, .ours): return true
            case (.theirs, .theirs): return true
            case (.both, .both): return true
            case (.custom(let a), .custom(let b)): return a == b
            default: return false
            }
        }
    }

    var isResolved: Bool {
        if case .unresolved = resolution { return false }
        return true
    }

    var resolvedContent: String {
        switch resolution {
        case .unresolved:
            return ""
        case .ours:
            return oursLines.joined(separator: "\n")
        case .theirs:
            return theirsLines.joined(separator: "\n")
        case .both:
            return (oursLines + theirsLines).joined(separator: "\n")
        case .custom(let content):
            return content
        }
    }
}

/// Parses conflict markers from file content
struct ConflictParser {
    /// Conservative guard used before writing/staging or continuing Git. A
    /// malformed opener/closer is still unresolved even if no chunk can parse.
    static func containsMarkers(in content: String) -> Bool {
        content.components(separatedBy: "\n").contains { raw in
            let line = raw.hasSuffix("\r") ? String(raw.dropLast()) : raw
            guard let character = line.first, [Character("<"), ">", "|"].contains(character) else { return false }
            let count = line.prefix(while: { $0 == character }).count
            let tail = line.dropFirst(count)
            return count >= 7 && (tail.isEmpty || tail.first == " ")
        }
    }

    static func parseConflicts(from content: String) -> [ConflictChunk] {
        let lines = content.components(separatedBy: "\n").map { line in
            line.hasSuffix("\r") ? String(line.dropLast()) : line
        }
        var chunks: [ConflictChunk] = []
        func marker(_ line: String, _ character: Character) -> (width: Int, tail: Substring)? {
            let prefix = line.prefix(while: { $0 == character })
            guard prefix.count >= 7 else { return nil }
            let tail = line.dropFirst(prefix.count)
            guard tail.isEmpty || tail.first == " " else { return nil }
            return (prefix.count, tail)
        }
        var i = 0
        while i < lines.count {
            if let opening = marker(lines[i], "<") {
                let startLine = i
                var oursLines: [String] = []
                var theirsLines: [String] = []
                var baseLines: [String]? = nil
                enum Section { case ours, base, theirs }
                var section = Section.ours
                var closed = false

                i += 1
                while i < lines.count {
                    // Ambiguous/nested blocks require manual review, rather
                    // than partially replacing an incorrectly parsed region.
                    if marker(lines[i], "<") != nil { return [] }
                    if let base = marker(lines[i], "|") {
                        guard base.width == opening.width, section == .ours, baseLines == nil else { return [] }
                        section = .base
                        baseLines = []
                        i += 1
                        continue
                    } else if let separator = marker(lines[i], "=") {
                        guard separator.width == opening.width, separator.tail.isEmpty, section != .theirs else { return [] }
                        section = .theirs
                        i += 1
                        continue
                    } else if let closing = marker(lines[i], ">") {
                        guard closing.width == opening.width, section == .theirs else { return [] }
                        chunks.append(ConflictChunk(
                            startLine: startLine,
                            endLine: i,
                            oursLines: oursLines,
                            theirsLines: theirsLines,
                            baseLines: baseLines
                        ))
                        closed = true
                        break
                    }

                    if section == .ours {
                        oursLines.append(lines[i])
                    } else if section == .base {
                        baseLines?.append(lines[i])
                    } else {
                        theirsLines.append(lines[i])
                    }
                    i += 1
                }
                guard closed else { return [] }
                i += 1  // move past >>>>>>>
                continue  // skip the outer i += 1
            }
            i += 1
        }

        return chunks
    }

    /// Applies resolutions to original content
    static func applyResolutions(to content: String, chunks: [ConflictChunk]) -> String {
        let resolved = chunks.filter(\.isResolved).sorted { $0.startLine < $1.startLine }
        guard !resolved.isEmpty else { return content }
        let lines = content.split(omittingEmptySubsequences: false) { $0 == "\n" || $0 == "\r\n" }
        var output = ""
        var cursor = content.startIndex
        // Copy untouched byte ranges exactly; do not normalize an entire file
        // merely because one conflict block changed.
        for chunk in resolved {
            guard chunk.startLine >= 0, chunk.endLine >= chunk.startLine,
                  chunk.endLine < lines.count else { continue }
            let start = lines[chunk.startLine].startIndex
            let last = lines[chunk.endLine]
            let end = last.endIndex
            guard start >= cursor else { continue }
            let newline = content[lines[chunk.startLine].endIndex...].hasPrefix("\r\n") ? "\r\n" : "\n"
            let replacement = chunk.resolvedContent.replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\n", with: newline)
            let terminator = content[end...].hasPrefix("\r\n") ? "\r\n" : (content[end...].hasPrefix("\n") ? "\n" : "")
            let keepsLine: Bool
            switch chunk.resolution {
            case .ours: keepsLine = !chunk.oursLines.isEmpty
            case .theirs: keepsLine = !chunk.theirsLines.isEmpty
            case .both: keepsLine = !chunk.oursLines.isEmpty || !chunk.theirsLines.isEmpty
            case .custom: keepsLine = !replacement.isEmpty && !replacement.hasSuffix(newline)
            case .unresolved: keepsLine = false
            }
            output += content[cursor..<start]
            output += replacement
            if keepsLine { output += terminator }
            cursor = terminator.isEmpty ? end : content.index(after: end)
        }
        output += content[cursor...]
        return output
    }
}

// MARK: - Subviews

struct ConflictHeader: View {
    let conflictCount: Int
    let resolvedCount: Int
    let operation: GitConflictOperation
    let canContinue: Bool
    let isBusy: Bool
    var onAbort: () -> Void = {}
    var onContinue: () -> Void = {}

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppTheme.warning)

            Text("Resolve Git Conflicts")
                .font(.headline)

            Text("\(resolvedCount)/\(conflictCount) resolved")
                .font(DesignTokens.Typography.caption)
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.vertical, DesignTokens.Spacing.xxs)
                .background(resolvedCount == conflictCount ? AppTheme.success.opacity(0.2) : AppTheme.warning.opacity(0.2))
                .foregroundStyle(resolvedCount == conflictCount ? AppTheme.success : AppTheme.warning)
                .clipShape(.rect(cornerRadius: DesignTokens.CornerRadius.lg))

            Spacer()

            Button("Abort \(operation == .none ? "operation" : operation.title)") {
                onAbort()
            }
            .foregroundStyle(AppTheme.error)
            .disabled(operation == .none || isBusy)
            .help("Preserve supported conflict copies before aborting; additional local changes prevent an unsafe abort")

            Button(operation == .none ? "Continue" : "Continue \(operation.title)") {
                onContinue()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canContinue || isBusy)
            .help("Continue the active Git operation using its prepared message, hooks and signatures")
            .accessibilityIdentifier("conflict-continue")
        }
        .padding()
        .background(AppTheme.warning.opacity(0.1))
    }
}

struct ConflictFileList: View {
    let files: [ConflictFile]
    @Binding var selectedFile: ConflictFile?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Conflicted Files")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(AppTheme.backgroundSecondary)

            Divider()

            List(files, selection: $selectedFile) { file in
                ConflictFileRow(file: file, isSelected: selectedFile?.id == file.id)
                    .tag(file)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AppTheme.backgroundSecondary)
        }
    }
}

struct ConflictFileRow: View {
    let file: ConflictFile
    let isSelected: Bool

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: file.isResolved ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(file.isResolved ? AppTheme.success : AppTheme.error)

            Image(systemName: "doc.fill")
                .foregroundStyle(AppTheme.accent)

            VStack(alignment: .leading) {
                Text(file.filename)
                    .lineLimit(1)

                let dir = URL(fileURLWithPath: file.path).deletingLastPathComponent().path
                if !dir.isEmpty && dir != "." {
                    Text(dir)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if file.isResolved {
                Text("Resolved")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(AppTheme.success)
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("conflict-file-\(file.path)")
    }
}

struct ThreeWayMergeView: View {
    let file: ConflictFile
    @ObservedObject var viewModel: ConflictResolverViewModel
    @State private var outputContent: String = ""
    @State private var aiResolution: AIConflictResolution?
    @State private var isGeneratingAI = false

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text(file.path)
                    .font(.headline)

                Spacer()

                Button {
                    Task {
                        isGeneratingAI = true
                        aiResolution = await viewModel.resolveWithAI(file)
                        if let resolution = aiResolution {
                            outputContent = resolution.suggestion
                        }
                        isGeneratingAI = false
                    }
                } label: {
                    if isGeneratingAI {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Label("AI Resolve", systemImage: "sparkles")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isGeneratingAI)

                Button("Use Ours") {
                    Task { await viewModel.resolveWithOurs(file) }
                }
                .buttonStyle(.bordered)

                Button("Use Theirs") {
                    Task { await viewModel.resolveWithTheirs(file) }
                }
                .buttonStyle(.bordered)

                Button("Save Resolution") {
                    Task { await viewModel.resolveWithCustom(file, content: outputContent) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(outputContent.isEmpty)
            }
            .padding()
            .background(AppTheme.backgroundSecondary)

            Divider()

            // AI resolution info
            if let resolution = aiResolution {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundStyle(AppTheme.accentPurple)

                    Text("AI Suggestion")
                        .fontWeight(.medium)

                    ConfidenceBadge(confidence: resolution.confidence)

                    Spacer()

                    Text(resolution.explanation)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                }
                .padding(DesignTokens.Spacing.sm)
                .background(AppTheme.accentPurple.opacity(0.1))

                Divider()
            }

            // Three panels
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // Ours (left)
                    MergePanel(
                        title: "Ours (Current)",
                        content: file.oursContent,
                        color: .blue,
                        onSelect: { selected in
                            outputContent += selected + "\n"
                        }
                    )
                    .frame(width: geometry.size.width / 3)

                    Divider()

                    // Output (center)
                    OutputPanel(
                        content: $outputContent
                    )
                    .frame(width: geometry.size.width / 3)

                    Divider()

                    // Theirs (right)
                    MergePanel(
                        title: "Theirs (Incoming)",
                        content: file.theirsContent,
                        color: .green,
                        onSelect: { selected in
                            outputContent += selected + "\n"
                        }
                    )
                    .frame(width: geometry.size.width / 3)
                }
            }
        }
        .onAppear {
            // Initialize output with base content or empty
            outputContent = file.baseContent ?? ""
        }
    }
}

struct MergePanel: View {
    let title: String
    let content: String
    let color: Color
    var onSelect: (String) -> Void = { _ in }

    @State private var selectedLines: Set<Int> = []

    var lines: [String] {
        content.components(separatedBy: .newlines)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.caption.weight(.semibold))
                Spacer()

                if !selectedLines.isEmpty {
                    Button("Add Selected") {
                        let selected = selectedLines.sorted().map { lines[$0] }.joined(separator: "\n")
                        onSelect(selected)
                        selectedLines.removeAll()
                    }
                    .buttonStyle(.borderless)
                    .font(DesignTokens.Typography.caption)
                }
            }
            .padding(DesignTokens.Spacing.sm)
            .background(color.opacity(0.1))

            // Content
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        HStack(spacing: 0) {
                            Text("\(index + 1)")
                                .font(DesignTokens.Typography.caption.monospaced())
                                .foregroundStyle(AppTheme.textPrimary)
                                .frame(width: 30, alignment: .trailing)
                                .padding(.trailing, 8)

                            Text(line.isEmpty ? " " : line)
                                .font(DesignTokens.Typography.caption.monospaced())
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 1)
                        .padding(.horizontal, DesignTokens.Spacing.xs)
                        .background(selectedLines.contains(index) ? color.opacity(0.2) : Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedLines.contains(index) {
                                selectedLines.remove(index)
                            } else {
                                selectedLines.insert(index)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct OutputPanel: View {
    @Binding var content: String

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "doc.text")
                    .foregroundStyle(AppTheme.textSecondary)
                Text("Output")
                    .font(.caption.weight(.semibold))
                Spacer()

                Button {
                    content = ""
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(AppTheme.error)
                }
                .buttonStyle(.borderless)
            }
            .padding(DesignTokens.Spacing.sm)
            .background(AppTheme.textSecondary.opacity(0.1))

            // Editable content
            DSTextEditor(placeholder: "Edit content...", text: $content)
        }
    }
}

struct ConfidenceBadge: View {
    let confidence: AIConflictResolution.Confidence

    var body: some View {
        Text(confidence.rawValue.capitalized)
            .font(DesignTokens.Typography.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, DesignTokens.Spacing.xs + 2)
            .padding(.vertical, DesignTokens.Spacing.xxs)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(.rect(cornerRadius: DesignTokens.CornerRadius.sm))
    }

    var color: Color {
        switch confidence {
        case .high: return AppTheme.success
        case .medium: return AppTheme.warning
        case .low: return AppTheme.error
        }
    }
}

struct EmptyConflictView: View {
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "checkmark.circle")
                .font(DesignTokens.Typography.iconXXXXL)
                .foregroundStyle(AppTheme.success)

            Text("No conflicts to resolve")
                .font(.headline)

            Text("Review Git status and any remaining local changes before publishing.")
                .foregroundStyle(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Inline Conflict Resolver (VS Code style)

struct InlineConflictResolver: View {
    let filePath: String
    let repositoryPath: String
    var isAlreadyResolved = false
    var savedRecoveryURL: URL? = nil
    var onRecoveryCreated: ((URL) -> Void)? = nil
    var onResolved: () -> Void = {}

    @State private var fileContent: String = ""
    @State private var chunks: [ConflictChunk] = []
    @State private var isLoading = true
    @State private var isLoaded = false
    @State private var error: String?
    @State private var isSaving = false
    @State private var didStageResolution = false
    @State private var snapshot: ConflictResolutionSnapshot?
    @State private var recoveryURL: URL?
    @State private var saveTask: Task<Void, Never>?
    @Namespace private var animation

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "doc.text")
                    .foregroundStyle(AppTheme.textPrimary)
                
                Text(URL(fileURLWithPath: filePath).lastPathComponent)
                    .font(.headline)

                Spacer()

                let resolvedCount = chunks.filter(\.isResolved).count
                if !chunks.isEmpty {
                Text("\(resolvedCount)/\(chunks.count) conflicts resolved")
                    .font(DesignTokens.Typography.caption)
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                    .background(resolvedCount == chunks.count ? AppTheme.success.opacity(0.2) : AppTheme.warning.opacity(0.2))
                    .foregroundStyle(resolvedCount == chunks.count ? AppTheme.success : AppTheme.warning)
                    .clipShape(.rect(cornerRadius: DesignTokens.CornerRadius.lg))
                    .animation(.spring(), value: resolvedCount)
                }

                if didStageResolution {
                    Text("Saved and staged").font(.caption).foregroundStyle(AppTheme.success)
                } else if isLoaded && !isLoading && !chunks.isEmpty && chunks.allSatisfy(\.isResolved) {
                    Button("Save & Stage") {
                        saveResolution()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSaving)
                    .accessibilityIdentifier("conflict-save-stage")
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding()
            .background(AppTheme.backgroundSecondary)

            Divider()

            if isLoading {
                ProgressView("Loading conflicts...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = error {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(AppTheme.error)
                    Text(error).textSelection(.enabled)
                        .foregroundStyle(AppTheme.textPrimary)
                    Button("Reload conflict from disk") { Task { await loadFile() } }
                        .disabled(isSaving)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(renderContent().enumerated()), id: \.offset) { _, item in
                            switch item {
                            case .normal(let line, let lineNumber):
                                NormalLineView(line: line, lineNumber: lineNumber)
                            case .conflict(let chunkIndex):
                                if chunkIndex < chunks.count {
                                    ConflictChunkView(
                                        chunk: chunks[chunkIndex],
                                        namespace: animation,
                                        isReadOnly: didStageResolution,
                                        onResolve: { resolution in
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                chunks[chunkIndex].resolution = resolution
                                            }
                                        }
                                    )
                                    .padding(.vertical, DesignTokens.Spacing.sm)
                                    .id("chunk-\(chunks[chunkIndex].id)")
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            if let recoveryURL {
                HStack {
                    Text("Original and proposed versions are kept in a private recovery folder.")
                        .font(.caption).foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    Button("Show recovery copies") { NSWorkspace.shared.activateFileViewerSelecting([recoveryURL]) }
                        .accessibilityIdentifier("conflict-recovery-copies")
                }.padding(8)
            }
        }
        .task(id: [repositoryPath, filePath]) {
            await loadFile()
        }
        .onDisappear { saveTask?.cancel() }
    }

    @MainActor
    private func loadFile() async {
        guard !isSaving else { return }
        isLoading = true
        isLoaded = false
        snapshot = nil
        didStageResolution = false
        chunks = []
        fileContent = ""
        recoveryURL = savedRecoveryURL
        error = nil

        do {
            if isAlreadyResolved {
                let locations = try RepositoryFileLocations(repositoryPath: repositoryPath)
                let (bytes, _) = try ConflictResolutionSnapshot.readRegularFile(locations.workingDirectory.appendingPathComponent(filePath),
                    root: locations.workingDirectory, maximumBytes: 2 * 1024 * 1024)
                fileContent = try ConflictResolutionSnapshot.inlineText(from: bytes)
                didStageResolution = true
                isLoaded = true
                isLoading = false
                return
            }
            let loaded = try await ConflictResolutionSnapshot.capture(repositoryPath: repositoryPath, path: filePath, maximumBytes: 2 * 1024 * 1024)
            guard !Task.isCancelled else { return }
            let text = try ConflictResolutionSnapshot.inlineText(from: loaded.workingData)
            for stage in loaded.stages.values { _ = try ConflictResolutionSnapshot.inlineText(from: stage) }
            fileContent = text
            chunks = ConflictParser.parseConflicts(from: fileContent)
            guard !chunks.isEmpty else {
                throw ConflictResolutionFailure(message: "Git reports an unmerged file without supported text markers. Review file-level deletion, rename or external resolutions before staging. No file was changed.")
            }
            snapshot = loaded
            isLoaded = true
            isLoading = false
        } catch {
            guard !Task.isCancelled else { return }
            self.error = error.localizedDescription
            isLoading = false
        }
    }

    @MainActor
    private func saveResolution() {
        guard !isSaving, !didStageResolution, !isLoading, isLoaded, !chunks.isEmpty,
              chunks.allSatisfy(\.isResolved), let snapshot,
              snapshot.path == filePath,
              snapshot.locations.workingDirectory.path == URL(fileURLWithPath: repositoryPath).standardizedFileURL.resolvingSymlinksInPath().path else { return }
        isSaving = true
        error = nil
        let resolvedContent = ConflictParser.applyResolutions(to: fileContent, chunks: chunks)
        saveTask = Task { @MainActor in
            defer { isSaving = false }
            do {
                let recovery = try await ConflictResolutionStore.shared.save(Data(resolvedContent.utf8), snapshot: snapshot)
                guard !Task.isCancelled, self.snapshot?.id == snapshot.id else { return }
                recoveryURL = recovery
                didStageResolution = true
                onRecoveryCreated?(recovery)
                onResolved()
            } catch {
                guard self.snapshot?.id == snapshot.id else { return }
                recoveryURL = (error as? ConflictResolutionFailure)?.recoveryURL
                self.error = error.localizedDescription
            }
        }
    }

    enum RenderItem {
        case normal(line: String, lineNumber: Int)
        case conflict(chunkIndex: Int)
    }

    private func renderContent() -> [RenderItem] {
        let lines = fileContent.components(separatedBy: .newlines)
        var items: [RenderItem] = []
        var lineIndex = 0
        var chunkIndex = 0

        while lineIndex < lines.count {
            if chunkIndex < chunks.count && lineIndex == chunks[chunkIndex].startLine {
                items.append(.conflict(chunkIndex: chunkIndex))
                lineIndex = chunks[chunkIndex].endLine + 1
                chunkIndex += 1
            } else {
                items.append(.normal(line: lines[lineIndex], lineNumber: lineIndex + 1))
                lineIndex += 1
            }
        }

        return items
    }
}

struct NormalLineView: View {
    let line: String
    let lineNumber: Int

    var body: some View {
        HStack(spacing: 0) {
            Text("\(lineNumber)")
                .font(DesignTokens.Typography.caption.monospaced())
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 40, alignment: .trailing)
                .padding(.trailing, 8)

            Text(line.isEmpty ? " " : line)
                .font(DesignTokens.Typography.caption.monospaced())
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 1)
    }
}

struct ConflictChunkView: View {
    let chunk: ConflictChunk
    var namespace: Namespace.ID? = nil
    var isReadOnly = false
    var onResolve: (ConflictChunk.ChunkResolution) -> Void = { _ in }

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if chunk.isResolved {
                // Resolved state
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.success)
                    Text("Resolved")
                        .fontWeight(.medium)
                        .foregroundStyle(AppTheme.success)
                    
                    Spacer()
                    
                    if !isReadOnly {
                        Button("Change choice") {
                            onResolve(.unresolved)
                        }
                        .buttonStyle(.borderless)
                        .font(DesignTokens.Typography.caption)
                        .help("Change this preview before saving; this does not undo a Git operation")
                    }
                }
                .padding(DesignTokens.Spacing.sm)
                .background(AppTheme.success.opacity(0.1))

                // Show resolved content
                Text(chunk.resolvedContent)
                    .font(DesignTokens.Typography.caption.monospaced())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(AppTheme.success.opacity(0.05))
            } else {
                // Unresolved state
                VStack(spacing: 0) {
                    ConflictActionBar(chunk: chunk, onResolve: onResolve)
                    OursSection(chunk: chunk)
                    SeparatorSection()
                    TheirsSection(chunk: chunk)
                }
            }
        }
        .background(AppTheme.warning.opacity(chunk.isResolved ? 0 : 0.05))
        .clipShape(.rect(cornerRadius: DesignTokens.CornerRadius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                .stroke(chunk.isResolved ? AppTheme.success : AppTheme.warning, lineWidth: 1)
        )
        .shadow(color: isHovered ? AppTheme.background.opacity(0.1) : Color.clear, radius: 4, x: 0, y: 2)
        .scaleEffect(isHovered && !chunk.isResolved ? 1.01 : 1.0)
        .onHover { isHovered = $0 }
    }
}

struct ConflictActionBar: View {
    let chunk: ConflictChunk
    var onResolve: (ConflictChunk.ChunkResolution) -> Void

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.lg) {
            Button { onResolve(.ours) } label: {
                Text("Accept Current").font(DesignTokens.Typography.caption)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(AppTheme.accent)
            .help("Use index stage 2 for this block; during rebase this is the checked-out base")
            .accessibilityIdentifier("conflict-accept-current")

            Text("|").foregroundStyle(AppTheme.textPrimary)

            Button { onResolve(.theirs) } label: {
                Text("Accept Incoming").font(DesignTokens.Typography.caption)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(AppTheme.success)
            .help("Use index stage 3 for this block; during rebase this is the replayed commit")
            .accessibilityIdentifier("conflict-accept-incoming")

            Text("|").foregroundStyle(AppTheme.textPrimary)

            Button { onResolve(.both) } label: {
                Text("Accept Both").font(DesignTokens.Typography.caption)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(AppTheme.accentPurple)
            .help("Keep current lines followed by incoming lines; review their order before saving")
            .accessibilityIdentifier("conflict-accept-both")

            Spacer()

            if chunk.isResolved {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Resolved")
                }
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(AppTheme.success)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(AppTheme.textSecondary.opacity(0.1))
    }
}

struct OursSection: View {
    let chunk: ConflictChunk

    private var isSelected: Bool {
        chunk.resolution == .ours || chunk.resolution == .both
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("<<<<<<< Current (index stage 2)")
                    .font(DesignTokens.Typography.caption.monospaced())
                    .foregroundStyle(AppTheme.accent)
                Spacer()
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xxs)
            .background(AppTheme.info.opacity(0.15))

            ForEach(Array(chunk.oursLines.enumerated()), id: \.offset) { _, line in
                Text(line.isEmpty ? " " : line)
                    .font(DesignTokens.Typography.caption.monospaced())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 48)
                    .padding(.vertical, 1)
                    .background(isSelected ? AppTheme.info.opacity(0.1) : AppTheme.info.opacity(0.05))
            }
        }
        .overlay(
            Rectangle()
                .stroke(AppTheme.info.opacity(0.3), lineWidth: chunk.resolution == .ours ? 2 : 0)
        )
    }
}

struct SeparatorSection: View {
    var body: some View {
        HStack {
            Text("=======")
                .font(DesignTokens.Typography.caption.monospaced())
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xxs)
        .background(AppTheme.textSecondary.opacity(0.1))
    }
}

struct TheirsSection: View {
    let chunk: ConflictChunk

    private var isSelected: Bool {
        chunk.resolution == .theirs || chunk.resolution == .both
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(chunk.theirsLines.enumerated()), id: \.offset) { _, line in
                Text(line.isEmpty ? " " : line)
                    .font(DesignTokens.Typography.caption.monospaced())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 48)
                    .padding(.vertical, 1)
                    .background(isSelected ? AppTheme.success.opacity(0.1) : AppTheme.success.opacity(0.05))
            }

            HStack {
                Text(">>>>>>> Incoming (index stage 3)")
                    .font(DesignTokens.Typography.caption.monospaced())
                    .foregroundStyle(AppTheme.success)
                Spacer()
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xxs)
            .background(AppTheme.success.opacity(0.15))
        }
        .overlay(
            Rectangle()
                .stroke(AppTheme.success.opacity(0.3), lineWidth: chunk.resolution == .theirs ? 2 : 0)
        )
    }
}

// MARK: - Quick Conflict Resolver (for single file)

/// Quick resolver for a single conflicted file - shows as sheet
struct QuickConflictResolverSheet: View {
    let conflictedFile: FileStatus
    let repositoryPath: String
    @Binding var isPresented: Bool
    var onResolved: () -> Void = {}

    var body: some View {
        InlineConflictResolver(
            filePath: conflictedFile.path,
            repositoryPath: repositoryPath,
            onResolved: {
                onResolved()
                isPresented = false
            }
        )
    }
}

// #Preview {
//     ConflictResolverView()
//         .environmentObject(AppState())
//         .frame(width: 1000, height: 600)
// }
