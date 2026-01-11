//
//  GhosttyEnhancedViewModel.swift
//  GitMac
//
//  Enhanced terminal features - Warp-like AI and command tracking
//

import Foundation
import SwiftUI

// NLCommandRequest, NLContext, NLCommandResponse, and CommandCategory are
// defined in TerminalNLTranslationService.swift - do not redefine here

// MARK: - Tracked Command Model (Rich History)

struct TrackedCommand: Identifiable, Codable {
    let id: UUID
    let command: String
    let timestamp: Date
    var output: String = ""
    var exitCode: Int? = nil
    var isComplete: Bool = false
    var error: String? = nil
    var aiSuggestion: String? = nil

    // Rich History fields
    var startTime: Date
    var endTime: Date?
    var duration: TimeInterval? {
        guard let endTime = endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }
    var gitBranch: String?
    var workingDirectory: String?
    var processId: Int32?

    init(command: String, timestamp: Date = Date(), gitBranch: String? = nil, workingDirectory: String? = nil) {
        self.id = UUID()
        self.command = command
        self.timestamp = timestamp
        self.startTime = timestamp
        self.gitBranch = gitBranch
        self.workingDirectory = workingDirectory
    }

    var durationFormatted: String {
        guard let duration = duration else { return "Running..." }
        if duration < 1 {
            return String(format: "%.0fms", duration * 1000)
        } else if duration < 60 {
            return String(format: "%.1fs", duration)
        } else {
            let minutes = Int(duration / 60)
            let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
            return "\(minutes)m \(seconds)s"
        }
    }

    var statusIcon: String {
        if !isComplete { return "circle.fill" }
        if let code = exitCode {
            return code == 0 ? "checkmark.circle.fill" : "xmark.circle.fill"
        }
        return "circle.fill"
    }

    var statusColor: String {
        if !isComplete { return "info" }
        if let code = exitCode {
            return code == 0 ? "success" : "error"
        }
        return "textSecondary"
    }
}

// MARK: - Workflow

struct TerminalWorkflow: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let command: String
    let parameters: [TerminalWorkflowParameter]
    let category: String
    let tags: [String]
}

struct TerminalWorkflowParameter {
    let name: String
    let description: String
    let placeholder: String
    let required: Bool
    let defaultValue: String?
}

// MARK: - Enhanced ViewModel

@MainActor
class GhosttyEnhancedViewModel: ObservableObject {
    // Command tracking
    @Published var trackedCommands: [TrackedCommand] = []
    @Published var currentInput: String = ""

    // AI Features
    @Published var aiSuggestions: [AICommandSuggestion] = []
    @Published var selectedSuggestionIndex: Int = 0
    @Published var isLoadingAI: Bool = false

    // NL Translation State
    @Published var showNLInput = false
    @Published var nlInputText = ""
    @Published var nlTranslationResult: NLCommandResponse? = nil
    @Published var selectedNLCommand: String? = nil

    // Workflows
    @Published var workflows: [TerminalWorkflow] = []

    // Context
    @Published var currentRepoPath: String?
    @Published var currentDirectory: String = ""

    // AI debounce
    private var aiSuggestionTask: Task<Void, Never>?
    private var aiCache: [String: [AICommandSuggestion]] = [:]

    init() {
        loadDefaultWorkflows()
    }

    // MARK: - Command Tracking (Rich History)

    func trackCommand(_ command: String) {
        // Get current git branch if in a repo
        var gitBranch: String?
        if let repoPath = currentRepoPath {
            gitBranch = getCurrentGitBranch(at: repoPath)
        }

        let tracked = TrackedCommand(
            command: command,
            timestamp: Date(),
            gitBranch: gitBranch,
            workingDirectory: currentDirectory.isEmpty ? nil : currentDirectory
        )
        trackedCommands.append(tracked)

        // Limit to last 100 commands
        if trackedCommands.count > 100 {
            trackedCommands.removeFirst()
        }

        // Persist history
        saveCommandHistory()
    }

    func updateCommandOutput(_ commandId: UUID, output: String) {
        if let index = trackedCommands.firstIndex(where: { $0.id == commandId }) {
            trackedCommands[index].output = output
        }
    }

    func completeCommand(_ commandId: UUID, exitCode: Int) {
        if let index = trackedCommands.firstIndex(where: { $0.id == commandId }) {
            trackedCommands[index].exitCode = exitCode
            trackedCommands[index].isComplete = true
            trackedCommands[index].endTime = Date()

            // Trigger Active AI if command failed
            if exitCode != 0 {
                suggestErrorFix(for: trackedCommands[index])
            }

            // Persist history
            saveCommandHistory()
        }
    }

    private func getCurrentGitBranch(at path: String) -> String? {
        let task = Process()
        task.launchPath = "/usr/bin/git"
        task.arguments = ["-C", path, "rev-parse", "--abbrev-ref", "HEAD"]
        task.standardOutput = Pipe()
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()

            if task.terminationStatus == 0,
               let data = (task.standardOutput as? Pipe)?.fileHandleForReading.readDataToEndOfFile(),
               let branch = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !branch.isEmpty {
                return branch
            }
        } catch {
            return nil
        }

        return nil
    }

    // MARK: - History Persistence

    private func saveCommandHistory() {
        guard let data = try? JSONEncoder().encode(trackedCommands) else { return }
        UserDefaults.standard.set(data, forKey: "terminal.commandHistory")
    }

    func loadCommandHistory() {
        guard let data = UserDefaults.standard.data(forKey: "terminal.commandHistory"),
              let commands = try? JSONDecoder().decode([TrackedCommand].self, from: data) else {
            return
        }
        trackedCommands = commands
    }

    func clearCommands() {
        trackedCommands.removeAll()
    }

    // MARK: - AI Suggestions (Warp-style)

    func updateInput(_ input: String, repoPath: String?) {
        currentInput = input
        currentRepoPath = repoPath

        print("🔍 Enhanced: updateInput called with: '\(input)' (length: \(input.count))")

        // Cancel previous task
        aiSuggestionTask?.cancel()

        // Clear suggestions if input is too short
        guard input.count >= 2 else {
            print("⚠️ Enhanced: Input too short, clearing suggestions")
            aiSuggestions.removeAll()
            return
        }

        // Check cache
        let cacheKey = input.lowercased()
        if let cached = aiCache[cacheKey] {
            aiSuggestions = filterSuggestions(cached, excluding: input)
            return
        }

        // Debounced AI call
        aiSuggestionTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
            guard !Task.isCancelled else { return }
            await fetchAISuggestions(for: input, repoPath: repoPath)
        }
    }

    private func filterSuggestions(_ suggestions: [AICommandSuggestion], excluding input: String) -> [AICommandSuggestion] {
        let inputLower = input.lowercased().trimmingCharacters(in: .whitespaces)
        guard !inputLower.isEmpty else { return [] }

        return suggestions.filter { suggestion in
            let cmdLower = suggestion.command.lowercased().trimmingCharacters(in: .whitespaces)

            // Skip empty or exact match
            guard !cmdLower.isEmpty, cmdLower != inputLower else { return false }

            // Skip if suggestion is shorter than input (not useful)
            guard cmdLower.count > inputLower.count else { return false }

            // Skip if suggestion doesn't start with or contain the input
            // (prefer completions over unrelated commands)
            let isCompletion = cmdLower.hasPrefix(inputLower)
            let isRelated = cmdLower.contains(inputLower) || inputLower.split(separator: " ").first.map { cmdLower.hasPrefix(String($0)) } ?? false

            return isCompletion || isRelated
        }
    }

    private func fetchAISuggestions(for input: String, repoPath: String?) async {
        isLoadingAI = true

        do {
            let suggestions = try await TerminalAIService.shared.suggestTerminalCommands(
                input: input,
                repoPath: repoPath,
                recentCommands: trackedCommands.suffix(5).map { $0.command }
            )

            // Cache and update, filtering out exact matches
            let filtered = filterSuggestions(suggestions, excluding: input)
            aiCache[input.lowercased()] = filtered
            self.aiSuggestions = filtered
            selectedSuggestionIndex = 0

        } catch {
            // Silent fail
        }

        isLoadingAI = false
    }

    func applySuggestion(_ suggestion: AICommandSuggestion, to viewModel: GhosttyViewModel) {
        let cmd = suggestion.command
        let input = currentInput

        // Smart completion: only add what's missing
        if cmd.lowercased().hasPrefix(input.lowercased()) && !input.isEmpty {
            // Suggestion starts with what user typed - just append the rest
            let startIndex = cmd.index(cmd.startIndex, offsetBy: input.count)
            let completion = String(cmd[startIndex...])
            viewModel.writeInput(completion)
        } else if let range = cmd.lowercased().range(of: input.lowercased()), range.lowerBound == cmd.startIndex {
            // Case-insensitive match at start - append rest
            let startIndex = cmd.index(cmd.startIndex, offsetBy: input.count)
            let completion = String(cmd[startIndex...])
            viewModel.writeInput(completion)
        } else {
            // No prefix match - need to replace
            // Send backspaces to clear current input
            if !input.isEmpty {
                let backspaces = String(repeating: "\u{7F}", count: input.count)
                viewModel.writeInput(backspaces)
            }
            viewModel.writeInput(cmd)
        }

        // Clear suggestions
        aiSuggestions.removeAll()
        currentInput = cmd
    }

    // MARK: - Suggestion Navigation

    func selectNextSuggestion() {
        guard !aiSuggestions.isEmpty else { return }
        selectedSuggestionIndex = min(selectedSuggestionIndex + 1, aiSuggestions.count - 1)
    }

    func selectPreviousSuggestion() {
        guard !aiSuggestions.isEmpty else { return }
        selectedSuggestionIndex = max(selectedSuggestionIndex - 1, 0)
    }

    func applySelectedSuggestion(to viewModel: GhosttyViewModel) {
        guard selectedSuggestionIndex < aiSuggestions.count else { return }
        let suggestion = aiSuggestions[selectedSuggestionIndex]
        applySuggestion(suggestion, to: viewModel)
    }

    // MARK: - Active AI (Warp-style error suggestions)

    private func suggestErrorFix(for command: TrackedCommand) {
        guard let exitCode = command.exitCode, exitCode != 0 else { return }

        Task {
            do {
                let suggestion = try await TerminalAIService.shared.explainTerminalError(
                    command: command.command,
                    error: command.output,
                    repoPath: currentRepoPath
                )

                if let index = trackedCommands.firstIndex(where: { $0.id == command.id }) {
                    trackedCommands[index].aiSuggestion = suggestion
                }
            } catch {
                print("❌ Error getting AI fix suggestion: \(error)")
            }
        }
    }

    // MARK: - Workflows (Warp-style)

    func loadDefaultWorkflows() {
        workflows = [
            TerminalWorkflow(
                name: "Git Status",
                description: "Show git status",
                command: "git status",
                parameters: [],
                category: "Git",
                tags: ["git", "status"]
            ),
            TerminalWorkflow(
                name: "Git Add All",
                description: "Stage all changes",
                command: "git add .",
                parameters: [],
                category: "Git",
                tags: ["git", "add"]
            ),
            TerminalWorkflow(
                name: "Git Commit",
                description: "Commit with message",
                command: "git commit -m \"{{message}}\"",
                parameters: [
                    TerminalWorkflowParameter(
                        name: "message",
                        description: "Commit message",
                        placeholder: "Enter commit message",
                        required: true,
                        defaultValue: nil
                    )
                ],
                category: "Git",
                tags: ["git", "commit"]
            ),
            TerminalWorkflow(
                name: "Docker Compose Up",
                description: "Start docker compose",
                command: "docker-compose up -d",
                parameters: [],
                category: "Docker",
                tags: ["docker", "compose"]
            ),
            TerminalWorkflow(
                name: "NPM Install",
                description: "Install node modules",
                command: "npm install",
                parameters: [],
                category: "Node",
                tags: ["npm", "install"]
            ),
            TerminalWorkflow(
                name: "Find Files",
                description: "Find files by name",
                command: "find . -name \"{{filename}}\"",
                parameters: [
                    TerminalWorkflowParameter(
                        name: "filename",
                        description: "File name pattern",
                        placeholder: "*.js",
                        required: true,
                        defaultValue: nil
                    )
                ],
                category: "Files",
                tags: ["find", "search"]
            )
        ]
    }

    func executeWorkflow(_ workflow: TerminalWorkflow, in viewModel: GhosttyViewModel) {
        // For now, just execute the command directly
        // TODO: Handle parameter substitution
        viewModel.writeInput(workflow.command + "\n")
        trackCommand(workflow.command)
    }

    func searchWorkflows(_ query: String) -> [TerminalWorkflow] {
        guard !query.isEmpty else { return workflows }

        let lowercased = query.lowercased()
        return workflows.filter { workflow in
            workflow.name.lowercased().contains(lowercased) ||
            workflow.description.lowercased().contains(lowercased) ||
            workflow.command.lowercased().contains(lowercased) ||
            workflow.tags.contains(where: { $0.lowercased().contains(lowercased) })
        }
    }

    // MARK: - Context

    func updateContext(repoPath: String?) {
        currentRepoPath = repoPath
        currentDirectory = repoPath ?? NSHomeDirectory()
    }
}
