//
//  TerminalSuggestionEngine.swift
//  GitMac
//
//  AI-powered suggestion engine for terminal commands
//

import Foundation

/// AI-powered suggestion engine with Ollama and fallback support
actor TerminalSuggestionEngine {

    static let shared = TerminalSuggestionEngine()

    private init() {}

    // MARK: - Public API

    /// Get suggestions for input using AI
    func getSuggestions(
        for input: String,
        context: TerminalSuggestionContext
    ) async -> [String] {
        // Try Ollama first (local, fast)
        if await AIService.shared.hasAPIKey(for: .ollama) {
            do {
                let result = try await fetchOllamaSuggestion(input: input, context: context)
                if !result.isEmpty {
                    return parseSuggestions(result, prefix: input)
                }
            } catch {
                print("[SuggestionEngine] Ollama failed: \(error)")
            }
        }

        // Fallback to configured AI service
        do {
            let suggestions = try await AIService.shared.suggestTerminalCommands(
                input: input,
                repoPath: context.workingDirectory
            )
            return suggestions.map { $0.command }
        } catch {
            print("[SuggestionEngine] Fallback AI failed: \(error)")
        }

        return []
    }

    // MARK: - Ollama Integration

    private func fetchOllamaSuggestion(
        input: String,
        context: TerminalSuggestionContext
    ) async throws -> String {
        let baseURL = AIService.ollamaBaseURL
        guard let url = URL(string: "\(baseURL)/api/generate") else { return "" }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 3 // Fast timeout for inline suggestions

        let prompt = buildPrompt(for: input, context: context)
        let model = await getOllamaModel()

        let body: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": false,
            "options": [
                "num_predict": 60,
                "temperature": 0.1
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = json["response"] as? String else {
            return ""
        }

        return cleanResponse(text, input: input)
    }

    private func getOllamaModel() async -> String {
        let configured = await AIService.shared.getCurrentModel()
        return configured.isEmpty ? "llama3.2" : configured
    }

    // MARK: - Prompt Building

    private func buildPrompt(for input: String, context: TerminalSuggestionContext) -> String {
        let lower = input.lowercased()
        var contextParts: [String] = []

        // Branch context
        if ["checkout", "switch", "merge", "rebase", "branch"].contains(where: { lower.contains($0) }) {
            if !context.branches.isEmpty {
                contextParts.append("Available branches: \(context.branches.prefix(10).joined(separator: ", "))")
            }
        }

        // File context
        let fileCommands = ["cat", "vim", "nano", "code", "open", "git add", "less", "head", "tail"]
        if fileCommands.contains(where: { lower.hasPrefix($0) }) {
            if !context.files.isEmpty {
                contextParts.append("Files: \(context.files.prefix(15).joined(separator: ", "))")
            }
        }

        // Directory context
        if lower.hasPrefix("cd ") {
            if !context.directories.isEmpty {
                contextParts.append("Directories: \(context.directories.prefix(10).joined(separator: ", "))")
            }
        }

        // Commit message context
        if lower.contains("commit") && lower.contains("-m") {
            contextParts.append("Use conventional commits: \(TerminalCompletions.commitTypes.joined(separator: ", "))")
            if !context.stagedFiles.isEmpty {
                contextParts.append("Staged files: \(context.stagedFiles.prefix(10).joined(separator: ", "))")
                if let suggestedType = context.inferredCommitType {
                    contextParts.append("Suggested type: \(suggestedType)")
                }
            }
        }

        // Build prompt
        if contextParts.isEmpty {
            return """
            Complete this terminal/git command. Reply with ONLY the completed command, nothing else.
            Input: \(input)
            """
        } else {
            return """
            Complete this terminal/git command using the context below.
            Reply with ONLY the completed command, nothing else.

            Context:
            \(contextParts.joined(separator: "\n"))

            Input: \(input)
            """
        }
    }

    // MARK: - Response Processing

    private func cleanResponse(_ text: String, input: String) -> String {
        let cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "\n").first ?? ""
            .replacingOccurrences(of: "`", with: "")
            .trimmingCharacters(in: .whitespaces)

        // Only return if it starts with input
        return cleaned.lowercased().hasPrefix(input.lowercased()) ? cleaned : ""
    }

    private func parseSuggestions(_ text: String, prefix: String) -> [String] {
        return text
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && $0.lowercased().hasPrefix(prefix.lowercased()) }
            .prefix(3)
            .map { String($0) }
    }
}

// MARK: - Context Model

/// Context for terminal suggestions
struct TerminalSuggestionContext {
    let workingDirectory: String
    let branches: [String]
    let files: [String]
    let directories: [String]
    let stagedFiles: [String]
    let modifiedFiles: [String]
    let inferredCommitType: String?

    init(
        workingDirectory: String = "",
        branches: [String] = [],
        files: [String] = [],
        directories: [String] = [],
        stagedFiles: [String] = [],
        modifiedFiles: [String] = [],
        inferredCommitType: String? = nil
    ) {
        self.workingDirectory = workingDirectory
        self.branches = branches
        self.files = files
        self.directories = directories
        self.stagedFiles = stagedFiles
        self.modifiedFiles = modifiedFiles
        self.inferredCommitType = inferredCommitType
    }

    /// Create context from TerminalContext
    @MainActor
    static func from(_ ctx: TerminalContext, workingDirectory: String) -> TerminalSuggestionContext {
        TerminalSuggestionContext(
            workingDirectory: workingDirectory,
            branches: ctx.branches,
            files: ctx.files,
            directories: ctx.directories,
            stagedFiles: ctx.stagedFiles,
            modifiedFiles: ctx.modifiedFiles,
            inferredCommitType: ctx.inferCommitType()
        )
    }
}

// MARK: - Dynamic Completions

/// Find dynamic completions based on context
struct DynamicCompletions {

    static func find(for input: String, context: TerminalSuggestionContext) -> [String] {
        let lower = input.lowercased()
        var results: [String] = []

        // Git branch commands
        results.append(contentsOf: branchCompletions(for: input, lower: lower, branches: context.branches))

        // New branch prefixes
        results.append(contentsOf: newBranchCompletions(for: input, lower: lower))

        // Directory completions
        results.append(contentsOf: directoryCompletions(for: input, lower: lower, directories: context.directories))

        // File completions
        results.append(contentsOf: fileCompletions(for: input, lower: lower, files: context.files))

        // Git add completions
        results.append(contentsOf: gitAddCompletions(for: input, lower: lower, files: context.files))

        // Commit message completions
        results.append(contentsOf: commitMessageCompletions(
            for: input,
            lower: lower,
            stagedFiles: context.stagedFiles,
            inferredType: context.inferredCommitType
        ))

        return results
    }

    private static func branchCompletions(for input: String, lower: String, branches: [String]) -> [String] {
        let branchCommands = ["git checkout ", "git switch ", "git merge ", "git rebase "]
        guard branchCommands.contains(where: { lower.hasPrefix($0) }) else { return [] }

        let prefix = input.components(separatedBy: " ").dropLast().joined(separator: " ") + " "
        let partial = String(input.dropFirst(prefix.count))

        return branches
            .filter { $0.lowercased().hasPrefix(partial.lowercased()) }
            .prefix(3)
            .map { prefix + $0 }
    }

    private static func newBranchCompletions(for input: String, lower: String) -> [String] {
        guard lower.hasPrefix("git checkout -b ") || lower.hasPrefix("git switch -c ") else { return [] }

        let prefix = input.components(separatedBy: " ").dropLast().joined(separator: " ") + " "
        let partial = String(input.dropFirst(prefix.count)).lowercased()

        return TerminalCompletions.branchPrefixes
            .filter { $0.hasPrefix(partial) }
            .prefix(3)
            .map { prefix + $0 }
    }

    private static func directoryCompletions(for input: String, lower: String, directories: [String]) -> [String] {
        guard lower.hasPrefix("cd ") else { return [] }
        let partial = String(input.dropFirst(3))

        return directories
            .filter { $0.lowercased().hasPrefix(partial.lowercased()) }
            .prefix(3)
            .map { "cd " + $0 }
    }

    private static func fileCompletions(for input: String, lower: String, files: [String]) -> [String] {
        let fileCommands = ["cat ", "vim ", "nano ", "code ", "less ", "head ", "tail ", "open "]
        guard let cmd = fileCommands.first(where: { lower.hasPrefix($0) }) else { return [] }

        let partial = String(input.dropFirst(cmd.count))

        return files
            .filter { $0.lowercased().hasPrefix(partial.lowercased()) }
            .prefix(3)
            .map { cmd + $0 }
    }

    private static func gitAddCompletions(for input: String, lower: String, files: [String]) -> [String] {
        guard lower.hasPrefix("git add "),
              !lower.hasSuffix("."),
              !lower.hasSuffix("--all") else { return [] }

        let partial = String(input.dropFirst(8))
        guard !partial.isEmpty, partial != "." else { return [] }

        return files
            .filter { $0.lowercased().hasPrefix(partial.lowercased()) }
            .prefix(3)
            .map { "git add " + $0 }
    }

    private static func commitMessageCompletions(
        for input: String,
        lower: String,
        stagedFiles: [String],
        inferredType: String?
    ) -> [String] {
        guard lower.hasPrefix("git commit -m \""), !input.hasSuffix("\"\"") else { return [] }

        let afterQuote = String(input.dropFirst("git commit -m \"".count))
        let suggestedType = inferredType ?? "feat"

        var types = TerminalCompletions.commitTypes
        if let idx = types.firstIndex(of: suggestedType) {
            types.remove(at: idx)
            types.insert(suggestedType, at: 0)
        }

        var results: [String] = []

        if afterQuote.isEmpty || afterQuote == "\"" {
            // Smart suggestion with file names
            if !stagedFiles.isEmpty {
                let shortFiles = stagedFiles.prefix(3).map { ($0 as NSString).lastPathComponent }
                results.append("git commit -m \"\(suggestedType): update \(shortFiles.joined(separator: ", "))\"")
            }
            // Type suggestions
            for t in types.prefix(3) {
                results.append("git commit -m \"\(t): \"")
            }
        } else {
            // Partial match
            let partialLower = afterQuote.lowercased()
            for t in types where t.hasPrefix(partialLower) {
                results.append("git commit -m \"\(t): \"")
            }
        }

        return results
    }
}
