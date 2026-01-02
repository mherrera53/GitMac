//
//  GhosttyEnhancedViewModel.swift
//  GitMac
//
//  Enhanced terminal features - Warp-like AI and command tracking
//

import Foundation
import SwiftUI

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

    // AI features
    @Published var aiSuggestions: [AICommandSuggestion] = []
    @Published var selectedSuggestionIndex: Int = 0
    @Published var isLoadingAI: Bool = false

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
            print("✅ Enhanced: Found \(cached.count) cached suggestions")
            aiSuggestions = cached
            return
        }

        print("🔄 Enhanced: Starting debounced AI call...")
        // Debounced AI call
        aiSuggestionTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
            guard !Task.isCancelled else {
                print("❌ Enhanced: AI task cancelled")
                return
            }

            await fetchAISuggestions(for: input, repoPath: repoPath)
        }
    }

    private func fetchAISuggestions(for input: String, repoPath: String?) async {
        isLoadingAI = true
        print("🤖 Enhanced: Fetching AI suggestions for '\(input)'...")

        do {
            // Get AI suggestions
            let suggestions = try await TerminalAIService.shared.suggestTerminalCommands(
                input: input,
                repoPath: repoPath,
                recentCommands: trackedCommands.suffix(5).map { $0.command }
            )

            print("✅ Enhanced: Received \(suggestions.count) suggestions from AI service")

            // Cache and update (suggestions are already AICommandSuggestion)
            aiCache[input.lowercased()] = suggestions
            self.aiSuggestions = suggestions
            selectedSuggestionIndex = 0

            print("📝 Enhanced: Updated aiSuggestions array with \(aiSuggestions.count) items")
            print("📊 Enhanced: currentInput = '\(currentInput)', isEmpty = \(currentInput.isEmpty)")

        } catch {
            print("❌ AI suggestion error: \(error)")
        }

        isLoadingAI = false
    }

    func applySuggestion(_ suggestion: AICommandSuggestion, to viewModel: GhosttyViewModel) {
        // Send the command to Ghostty
        viewModel.writeInput(suggestion.command + "\n")

        // Track it
        trackCommand(suggestion.command)

        // Clear suggestions
        aiSuggestions.removeAll()
        currentInput = ""
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
