import Foundation
import SwiftUI

/// Git operation undo/redo manager
@MainActor
class GitUndoManager: ObservableObject {
    static let shared = GitUndoManager()

    @Published var undoStack: [GitOperation] = []
    @Published var redoStack: [GitOperation] = []
    @Published var isProcessing = false
    @Published var lastError: String?

    private let shell = ShellExecutor()
    private var repositoryPath: String = ""

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    private init() {}

    func setRepository(path: String) {
        repositoryPath = path
        // Clear stacks when switching repos
        undoStack.removeAll()
        redoStack.removeAll()
    }

    // MARK: - Record Operations

    func recordCommit(sha: String, message: String) {
        let operation = GitOperation(
            type: .commit,
            description: "Commit: \(message.prefix(50))",
            undoCommand: ["git", "reset", "--soft", "HEAD~1"],
            redoData: ["sha": sha, "message": message],
            timestamp: Date()
        )
        pushUndo(operation)
    }

    func recordStage(files: [String]) {
        let operation = GitOperation(
            type: .stage,
            description: "Stage \(files.count) file(s)",
            undoCommand: ["git", "reset", "HEAD", "--"] + files,
            redoData: ["files": files],
            timestamp: Date()
        )
        pushUndo(operation)
    }

    func recordUnstage(files: [String]) {
        let operation = GitOperation(
            type: .unstage,
            description: "Unstage \(files.count) file(s)",
            undoCommand: ["git", "add"] + files,
            redoData: ["files": files],
            timestamp: Date()
        )
        pushUndo(operation)
    }

    func recordCheckout(fromBranch: String, toBranch: String) {
        let operation = GitOperation(
            type: .checkout,
            description: "Checkout \(toBranch)",
            undoCommand: ["git", "checkout", fromBranch],
            redoData: ["from": fromBranch, "to": toBranch],
            timestamp: Date()
        )
        pushUndo(operation)
    }

    func recordBranchCreate(name: String, sha: String) {
        let operation = GitOperation(
            type: .branchCreate,
            description: "Create branch \(name)",
            undoCommand: ["git", "branch", "-D", name],
            redoData: ["name": name, "sha": sha],
            timestamp: Date()
        )
        pushUndo(operation)
    }

    func recordBranchDelete(name: String, sha: String) {
        let operation = GitOperation(
            type: .branchDelete,
            description: "Delete branch \(name)",
            undoCommand: ["git", "branch", name, sha],
            redoData: ["name": name, "sha": sha],
            timestamp: Date()
        )
        pushUndo(operation)
    }

    func recordMerge(branch: String, resultSha: String) {
        let operation = GitOperation(
            type: .merge,
            description: "Merge \(branch)",
            undoCommand: ["git", "reset", "--hard", "HEAD~1"],
            redoData: ["branch": branch, "sha": resultSha],
            timestamp: Date()
        )
        pushUndo(operation)
    }

    func recordStashCreate(message: String, sha: String) {
        let operation = GitOperation(
            type: .stashCreate,
            description: "Stash: \(message.prefix(30))",
            undoCommand: ["git", "stash", "pop"],
            redoData: ["message": message, "sha": sha],
            timestamp: Date()
        )
        pushUndo(operation)
    }

    func recordStashPop(sha: String) {
        let operation = GitOperation(
            type: .stashPop,
            description: "Pop stash",
            undoCommand: ["git", "stash"],
            redoData: ["sha": sha],
            timestamp: Date()
        )
        pushUndo(operation)
    }

    func recordReset(fromSha: String, toSha: String, mode: ResetMode) {
        let operation = GitOperation(
            type: .reset,
            description: "Reset to \(toSha.prefix(7))",
            undoCommand: ["git", "reset", "--\(mode.rawValue)", fromSha],
            redoData: ["from": fromSha, "to": toSha, "mode": mode.rawValue],
            timestamp: Date()
        )
        pushUndo(operation)
    }

    func recordRevert(sha: String, revertSha: String) {
        let operation = GitOperation(
            type: .revert,
            description: "Revert \(sha.prefix(7))",
            undoCommand: ["git", "reset", "--hard", "HEAD~1"],
            redoData: ["sha": sha, "revertSha": revertSha],
            timestamp: Date()
        )
        pushUndo(operation)
    }

    func recordCherryPick(sha: String, resultSha: String) {
        let operation = GitOperation(
            type: .cherryPick,
            description: "Cherry-pick \(sha.prefix(7))",
            undoCommand: ["git", "reset", "--hard", "HEAD~1"],
            redoData: ["sha": sha, "resultSha": resultSha],
            timestamp: Date()
        )
        pushUndo(operation)
    }

    func recordAmend(previousSha: String, newSha: String) {
        let operation = GitOperation(
            type: .amend,
            description: "Amend commit",
            undoCommand: ["git", "reset", "--soft", previousSha],
            redoData: ["previousSha": previousSha, "newSha": newSha],
            timestamp: Date()
        )
        pushUndo(operation)
    }

    func recordTagCreate(name: String, sha: String) {
        let operation = GitOperation(
            type: .tagCreate,
            description: "Create tag \(name)",
            undoCommand: ["git", "tag", "-d", name],
            redoData: ["name": name, "sha": sha],
            timestamp: Date()
        )
        pushUndo(operation)
    }

    func recordTagDelete(name: String, sha: String) {
        let operation = GitOperation(
            type: .tagDelete,
            description: "Delete tag \(name)",
            undoCommand: ["git", "tag", name, sha],
            redoData: ["name": name, "sha": sha],
            timestamp: Date()
        )
        pushUndo(operation)
    }

    // MARK: - Undo/Redo

    func undo() async {
        guard let operation = undoStack.popLast() else { return }

        isProcessing = true
        lastError = nil

        // Execute undo command
        let result = await shell.execute(
            operation.undoCommand[0],
            arguments: Array(operation.undoCommand.dropFirst()),
            workingDirectory: repositoryPath
        )

        if result.exitCode == 0 {
            // Move to redo stack
            redoStack.append(operation)
        } else {
            // Failed, put back on undo stack
            undoStack.append(operation)
            lastError = "Undo failed: \(result.stderr)"
        }

        isProcessing = false
    }

    func redo() async {
        guard let operation = redoStack.popLast() else { return }

        isProcessing = true
        lastError = nil

        // Execute redo based on operation type
        let success = await executeRedo(for: operation)

        if success {
            undoStack.append(operation)
        } else {
            // Failed, put back on redo stack
            redoStack.append(operation)
        }

        isProcessing = false
    }

    private func executeRedo(for operation: GitOperation) async -> Bool {
        switch operation.type {
        case .commit:
            // Can't easily redo a commit without the files
            return false

        case .stage:
            if let files = operation.redoData["files"] as? [String] {
                let result = await shell.execute(
                    "git",
                    arguments: ["add"] + files,
                    workingDirectory: repositoryPath
                )
                return result.exitCode == 0
            }

        case .unstage:
            if let files = operation.redoData["files"] as? [String] {
                let result = await shell.execute(
                    "git",
                    arguments: ["reset", "HEAD", "--"] + files,
                    workingDirectory: repositoryPath
                )
                return result.exitCode == 0
            }

        case .checkout:
            if let toBranch = operation.redoData["to"] as? String {
                let result = await shell.execute(
                    "git",
                    arguments: ["checkout", toBranch],
                    workingDirectory: repositoryPath
                )
                return result.exitCode == 0
            }

        case .branchCreate:
            if let name = operation.redoData["name"] as? String,
               let sha = operation.redoData["sha"] as? String {
                let result = await shell.execute(
                    "git",
                    arguments: ["branch", name, sha],
                    workingDirectory: repositoryPath
                )
                return result.exitCode == 0
            }

        case .branchDelete:
            if let name = operation.redoData["name"] as? String {
                let result = await shell.execute(
                    "git",
                    arguments: ["branch", "-D", name],
                    workingDirectory: repositoryPath
                )
                return result.exitCode == 0
            }

        case .tagCreate:
            if let name = operation.redoData["name"] as? String,
               let sha = operation.redoData["sha"] as? String {
                let result = await shell.execute(
                    "git",
                    arguments: ["tag", name, sha],
                    workingDirectory: repositoryPath
                )
                return result.exitCode == 0
            }

        case .tagDelete:
            if let name = operation.redoData["name"] as? String {
                let result = await shell.execute(
                    "git",
                    arguments: ["tag", "-d", name],
                    workingDirectory: repositoryPath
                )
                return result.exitCode == 0
            }

        default:
            lastError = "Redo not supported for this operation"
            return false
        }

        return false
    }

    // MARK: - Helpers

    private func pushUndo(_ operation: GitOperation) {
        undoStack.append(operation)
        // Clear redo stack when new operation is performed
        redoStack.removeAll()

        // Limit stack size
        if undoStack.count > 50 {
            undoStack.removeFirst()
        }
    }

    func clearHistory() {
        undoStack.removeAll()
        redoStack.removeAll()
    }
}

// MARK: - Models

struct GitOperation: Identifiable {
    let id = UUID()
    let type: OperationType
    let description: String
    let undoCommand: [String]
    let redoData: [String: Any]
    let timestamp: Date

    enum OperationType: String {
        case commit
        case stage
        case unstage
        case checkout
        case branchCreate
        case branchDelete
        case merge
        case stashCreate
        case stashPop
        case reset
        case revert
        case cherryPick
        case amend
        case tagCreate
        case tagDelete
    }

    var icon: String {
        switch type {
        case .commit: return "checkmark.circle"
        case .stage: return "plus.circle"
        case .unstage: return "minus.circle"
        case .checkout: return "arrow.right.circle"
        case .branchCreate: return "plus.square"
        case .branchDelete: return "minus.square"
        case .merge: return "arrow.triangle.merge"
        case .stashCreate, .stashPop: return "archivebox"
        case .reset: return "arrow.uturn.backward"
        case .revert: return "arrow.counterclockwise"
        case .cherryPick: return "arrow.right.doc.on.clipboard"
        case .amend: return "pencil.circle"
        case .tagCreate, .tagDelete: return "tag"
        }
    }

    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

// ResetMode is defined in ResetView.swift

// MARK: - Undo History View

struct UndoHistoryView: View {
    @ObservedObject var undoManager = GitUndoManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Operation History")
                    .font(.headline)

                Spacer()

                Button {
                    undoManager.clearHistory()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(.borderless)
                .disabled(undoManager.undoStack.isEmpty && undoManager.redoStack.isEmpty)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            if undoManager.undoStack.isEmpty && undoManager.redoStack.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 48))
                        .foregroundColor(AppTheme.textPrimary)

                    Text("No operation history")
                        .font(.headline)

                    Text("Git operations will appear here")
                        .foregroundColor(AppTheme.textPrimary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    if !undoManager.redoStack.isEmpty {
                        Section("Redo Stack") {
                            ForEach(undoManager.redoStack.reversed()) { operation in
                                OperationRow(operation: operation, isRedo: true)
                            }
                        }
                    }

                    Section("Undo Stack") {
                        ForEach(undoManager.undoStack.reversed()) { operation in
                            OperationRow(operation: operation, isRedo: false)
                        }
                    }
                }
                .listStyle(.plain)
            }

            Divider()

            // Undo/Redo buttons
            HStack {
                Button {
                    Task { await undoManager.undo() }
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!undoManager.canUndo || undoManager.isProcessing)

                Button {
                    Task { await undoManager.redo() }
                } label: {
                    Label("Redo", systemImage: "arrow.uturn.forward")
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!undoManager.canRedo || undoManager.isProcessing)

                Spacer()

                if undoManager.isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                }

                if let error = undoManager.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(AppTheme.error)
                        .lineLimit(1)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
        }
    }
}

struct OperationRow: View {
    let operation: GitOperation
    let isRedo: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: operation.icon)
                .foregroundColor(isRedo ? AppTheme.warning : AppTheme.accent)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(operation.description)
                    .lineLimit(1)

                Text(operation.relativeTime)
                    .font(.caption)
                    .foregroundColor(AppTheme.textPrimary)
            }

            Spacer()

            Text(operation.type.rawValue)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(AppTheme.textSecondary.opacity(0.2))
                .cornerRadius(4)
        }
        .padding(.vertical, 2)
        .opacity(isRedo ? 0.6 : 1)
    }
}

// #Preview {
//     UndoHistoryView()
//         .frame(width: 350, height: 400)
// }
