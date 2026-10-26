import Foundation
import SwiftUI

enum WorkflowError: LocalizedError {
    case stepFailed(String)

    var errorDescription: String? {
        switch self {
        case .stepFailed(let detail): return detail
        }
    }
}

struct WorkflowContext {
    let repoPath: String
    let branchManager: BranchStateManager
    let currentBranch: String
    let commitMessage: String
    let diff: String
    var showPRSheet: Binding<Bool>
    var commitSHAForPR: Binding<String>
}

@MainActor
@Observable
class WorkflowEngine {
    static let shared = WorkflowEngine()

    private(set) var workflows: [GitWorkflow] = []
    var isExecuting = false
    var currentStep: Int = 0
    var totalSteps: Int = 0
    var statusMessage: String = ""
    var pendingConfirmation: String? = nil
    private(set) var pendingConfirmationID: UUID?
    private var confirmationContinuation: CheckedContinuation<Bool, Never>?
    private var executionID: UUID?

    private let userDefaultsKey = "com.gitmac.workflows"

    private init() {
        loadWorkflows()
    }

    // MARK: - Persistence

    func loadWorkflows() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([GitWorkflow].self, from: data) {
            workflows = decoded
        } else {
            workflows = GitWorkflow.defaultWorkflows
        }
    }

    func saveWorkflows() {
        if let data = try? JSONEncoder().encode(workflows) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    func addWorkflow(_ workflow: GitWorkflow) {
        workflows.append(workflow)
        saveWorkflows()
    }

    func updateWorkflow(_ workflow: GitWorkflow) {
        if let index = workflows.firstIndex(where: { $0.id == workflow.id }) {
            workflows[index] = workflow
            saveWorkflows()
        }
    }

    func deleteWorkflow(_ workflow: GitWorkflow) {
        workflows.removeAll { $0.id == workflow.id }
        saveWorkflows()
    }

    func resetToDefaults() {
        workflows = GitWorkflow.defaultWorkflows
        saveWorkflows()
    }

    func confirmPending(id: UUID) {
        guard pendingConfirmationID == id else { return }
        resolvePendingConfirmation(true)
    }

    func cancelPending(id: UUID) {
        guard pendingConfirmationID == id else { return }
        resolvePendingConfirmation(false)
    }

    private func resolvePendingConfirmation(_ confirmed: Bool) {
        guard let continuation = confirmationContinuation else { return }
        confirmationContinuation = nil
        pendingConfirmation = nil
        pendingConfirmationID = nil
        continuation.resume(returning: confirmed)
    }

    // MARK: - Trigger Matching

    func matchingWorkflows(branch: String, hasStaged: Bool) -> [GitWorkflow] {
        workflows.filter { workflow in
            guard workflow.isEnabled else { return false }
            return matchesTrigger(workflow.triggerCondition, branch: branch, hasStaged: hasStaged)
        }
    }

    private func matchesTrigger(_ trigger: WorkflowTrigger, branch: String, hasStaged: Bool) -> Bool {
        switch trigger {
        case .always:
            return true
        case .onBranch(let pattern):
            return branchMatchesPattern(branch, pattern: pattern)
        case .notOnBranch(let pattern):
            return !branchMatchesPattern(branch, pattern: pattern)
        case .hasStaged:
            return hasStaged
        case .manual:
            return false
        }
    }

    private func branchMatchesPattern(_ branch: String, pattern: String) -> Bool {
        let alternatives = pattern.components(separatedBy: "|")
        return alternatives.contains { alt in
            if alt.contains("*") {
                let parts = alt.split(separator: "*", maxSplits: 1, omittingEmptySubsequences: false)
                let prefix = String(parts.first ?? "")
                let suffix = parts.count > 1 ? String(parts[1]) : ""
                return branch.hasPrefix(prefix) && branch.hasSuffix(suffix)
            }
            return branch == alt
        }
    }

    // MARK: - Execution

    func execute(_ workflow: GitWorkflow, context: WorkflowContext) async throws {
        guard !isExecuting else {
            throw WorkflowError.stepFailed("Another workflow is already executing.")
        }
        try Task.checkCancellation()
        let executionID = UUID()
        self.executionID = executionID
        isExecuting = true
        totalSteps = workflow.steps.count
        currentStep = 0
        defer {
            self.executionID = nil
            resolvePendingConfirmation(false)
            isExecuting = false
            statusMessage = ""
            currentStep = 0
        }

        for (index, step) in workflow.steps.enumerated() {
            currentStep = index + 1
            try Task.checkCancellation()

            switch step {
            case .fetch(let remote):
                statusMessage = "Fetching \(remote)..."
                let fetchResult = await ShellExecutor.shared.execute(
                    "git", arguments: ["fetch", remote, "--quiet"],
                    workingDirectory: context.repoPath
                )
                if !fetchResult.isSuccess {
                    throw WorkflowError.stepFailed("Fetch failed: \(fetchResult.stderr)")
                }

            case .createBranch(let strategy):
                statusMessage = "Creating branch..."
                let name = try await resolveBranchName(strategy, context: context)
                try await context.branchManager.createBranch(name: name, from: context.currentBranch, checkout: true)

            case .checkout(let branch):
                statusMessage = "Checking out \(branch)..."
                let checkoutResult = await ShellExecutor.shared.execute(
                    "git", arguments: ["checkout", branch],
                    workingDirectory: context.repoPath
                )
                if !checkoutResult.isSuccess {
                    throw WorkflowError.stepFailed("Checkout failed: \(checkoutResult.stderr)")
                }

            case .checkoutMain:
                let mainBranch = WorkspaceSettingsManager.shared.getMainBranch(for: context.repoPath)
                statusMessage = "Checking out \(mainBranch)..."
                let checkoutResult = await ShellExecutor.shared.execute(
                    "git", arguments: ["checkout", mainBranch],
                    workingDirectory: context.repoPath
                )
                if !checkoutResult.isSuccess {
                    throw WorkflowError.stepFailed("Checkout main failed: \(checkoutResult.stderr)")
                }

            case .pull(let rebase):
                statusMessage = "Pulling..."
                var args = ["pull"]
                if rebase { args.append("--rebase") }
                let pullResult = await ShellExecutor.shared.execute(
                    "git", arguments: args,
                    workingDirectory: context.repoPath
                )
                if !pullResult.isSuccess {
                    throw WorkflowError.stepFailed("Pull failed: \(pullResult.stderr)")
                }

            case .rebaseOnMain:
                let mainBranch = WorkspaceSettingsManager.shared.getMainBranch(for: context.repoPath)
                statusMessage = "Rebasing on \(mainBranch)..."
                let rebaseResult = await ShellExecutor.shared.execute(
                    "git", arguments: ["rebase", "origin/\(mainBranch)"],
                    workingDirectory: context.repoPath
                )
                if !rebaseResult.isSuccess {
                    throw WorkflowError.stepFailed("Rebase on \(mainBranch) failed: \(rebaseResult.stderr). Resolve conflicts, then continue or abort the rebase explicitly.")
                }

            case .createTag(let strategy):
                statusMessage = "Creating tag..."
                let tagName = try await resolveBranchName(strategy, context: context)
                let tagResult = await ShellExecutor.shared.execute(
                    "git", arguments: ["tag", "-a", tagName, "-m", "Release \(tagName)"],
                    workingDirectory: context.repoPath
                )
                if !tagResult.isSuccess {
                    throw WorkflowError.stepFailed("Tag creation failed: \(tagResult.stderr)")
                }

            case .stash:
                statusMessage = "Stashing staged changes..."
                let stashResult = await ShellExecutor.shared.execute(
                    "git", arguments: ["stash", "push", "--staged"],
                    workingDirectory: context.repoPath
                )
                if !stashResult.isSuccess {
                    throw WorkflowError.stepFailed("Stash failed: \(stashResult.stderr)")
                }

            case .stashPop:
                statusMessage = "Restoring changes..."
                let popResult = await ShellExecutor.shared.execute(
                    "git", arguments: ["stash", "pop"],
                    workingDirectory: context.repoPath
                )
                if !popResult.isSuccess {
                    throw WorkflowError.stepFailed("Stash pop failed: \(popResult.stderr)")
                }

            case .stageAll:
                statusMessage = "Staging files..."
                let stageResult = await ShellExecutor.shared.execute(
                    "git", arguments: ["add", "-A"],
                    workingDirectory: context.repoPath
                )
                if !stageResult.isSuccess {
                    throw WorkflowError.stepFailed("Stage all failed: \(stageResult.stderr)")
                }

            case .stageFiles(let patterns):
                statusMessage = "Staging files..."
                for pattern in patterns {
                    try Task.checkCancellation()
                    let stageResult = await ShellExecutor.shared.execute(
                        "git", arguments: ["add", "--", pattern],
                        workingDirectory: context.repoPath
                    )
                    if !stageResult.isSuccess {
                        throw WorkflowError.stepFailed("Stage files failed: \(stageResult.stderr)")
                    }
                }

            case .commit(let strategy):
                statusMessage = "Committing..."
                let message = try await resolveCommitMessage(strategy, context: context)
                let commitResult = await ShellExecutor.shared.execute(
                    "git", arguments: ["commit", "-m", message],
                    workingDirectory: context.repoPath
                )
                if !commitResult.isSuccess {
                    throw WorkflowError.stepFailed("Commit failed: \(commitResult.stderr)")
                }

            case .push(let setUpstream, let force):
                statusMessage = "Pushing..."
                var args = ["push"]
                if setUpstream { args.append("--set-upstream") }
                if force { args.append("--force-with-lease") }
                if setUpstream {
                    let branchResult = await ShellExecutor.shared.execute(
                        "git", arguments: ["rev-parse", "--abbrev-ref", "HEAD"],
                        workingDirectory: context.repoPath
                    )
                    if !branchResult.isSuccess {
                        throw WorkflowError.stepFailed("Cannot determine branch for push: \(branchResult.stderr)")
                    }
                    let branchName = branchResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !branchName.isEmpty, branchName != "HEAD" else {
                        throw WorkflowError.stepFailed("Create or check out a branch before setting its upstream.")
                    }
                    args.append(contentsOf: ["origin", branchName])
                }
                let pushResult = await ShellExecutor.shared.execute(
                    "git", arguments: args,
                    workingDirectory: context.repoPath
                )
                if !pushResult.isSuccess {
                    throw WorkflowError.stepFailed("Push failed: \(pushResult.stderr)")
                }

            case .openPR(_, _):
                statusMessage = "Opening PR..."
                let engine = GitEngine()
                let sha = try await engine.getHeadSHA(at: context.repoPath)
                context.commitSHAForPR.wrappedValue = String(sha.prefix(7))
                context.showPRSheet.wrappedValue = true

            case .runCommand(let command):
                statusMessage = "Running \(command)..."
                let parts = parseShellArgs(command)
                guard let cmd = parts.first else { continue }
                let result = await ShellExecutor.shared.execute(
                    cmd, arguments: Array(parts.dropFirst()),
                    workingDirectory: context.repoPath
                )
                if !result.isSuccess {
                    throw WorkflowError.stepFailed("Command failed: \(result.stderr)")
                }

            case .notify(let message):
                NotificationManager.shared.success(message)

            case .waitForConfirmation(let message):
                statusMessage = message
                let confirmed = await withTaskCancellationHandler {
                    await withCheckedContinuation { continuation in
                        guard !Task.isCancelled else {
                            continuation.resume(returning: false)
                            return
                        }
                        pendingConfirmation = message
                        pendingConfirmationID = UUID()
                        confirmationContinuation = continuation
                    }
                } onCancel: {
                    Task { @MainActor [weak self] in
                        guard let self, self.executionID == executionID else { return }
                        self.resolvePendingConfirmation(false)
                    }
                }
                try Task.checkCancellation()
                if !confirmed {
                    throw WorkflowError.stepFailed("User cancelled at: \(message)")
                }
            }
            try Task.checkCancellation()
        }

        try Task.checkCancellation()
        NotificationManager.shared.success("Workflow '\(workflow.name)' completed")
    }

    // MARK: - Strategy Resolution

    private func resolveBranchName(_ strategy: BranchNameStrategy, context: WorkflowContext) async throws -> String {
        switch strategy {
        case .aiGenerated:
            if await AIService.shared.isAvailable() {
                let raw = try await AIService.shared.generateText(
                    prompt: "Short branch name for this diff (feat/fix/chore prefix, kebab-case, max 40 chars, no explanation): \(context.diff.prefix(1000))"
                )
                let cleaned = AIService.cleanAIResponse(raw)
                    .lowercased()
                    .replacingOccurrences(of: " ", with: "-")
                    .filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "/" }
                return String(cleaned.prefix(40))
            }
            let ts = Int(Date().timeIntervalSince1970) % 100000
            return "feat/changes-\(ts)"

        case .fromCommitMessage:
            let slug = context.commitMessage
                .lowercased()
                .replacingOccurrences(of: " ", with: "-")
                .filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "/" }
            return String("feat/\(slug)".prefix(40))

        case .userInput:
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd-HHmmss"
            return "feature/\(formatter.string(from: Date()))"

        case .template(let tmpl):
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd"
            return tmpl
                .replacingOccurrences(of: "{{date}}", with: dateFormatter.string(from: Date()))
                .replacingOccurrences(of: "{{short_desc}}", with: String(context.commitMessage.prefix(20).lowercased().replacingOccurrences(of: " ", with: "-")))
        }
    }

    private func resolveCommitMessage(_ strategy: CommitMessageStrategy, context: WorkflowContext) async throws -> String {
        switch strategy {
        case .userProvided:
            return context.commitMessage
        case .aiGenerated:
            return try await AIService.shared.generateCommitMessage(diff: context.diff)
        case .template(let tmpl):
            return tmpl
                .replacingOccurrences(of: "{{message}}", with: context.commitMessage)
                .replacingOccurrences(of: "{{branch}}", with: context.currentBranch)
        }
    }

    private func parseShellArgs(_ command: String) -> [String] {
        var args: [String] = []
        var current = ""
        var inQuote: Character? = nil

        for char in command {
            if let q = inQuote {
                if char == q {
                    inQuote = nil
                } else {
                    current.append(char)
                }
            } else if char == "\"" || char == "'" {
                inQuote = char
            } else if char == " " {
                if !current.isEmpty {
                    args.append(current)
                    current = ""
                }
            } else {
                current.append(char)
            }
        }
        if !current.isEmpty { args.append(current) }
        return args
    }
}
