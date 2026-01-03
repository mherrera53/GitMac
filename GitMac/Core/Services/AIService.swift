import Foundation

/// AI Service for commit message generation and more
actor AIService {
    static let shared = AIService()

    private let keychainManager = KeychainManager.shared
    private var preferencesLoaded = false

    // MARK: - Provider Configuration

    enum AIProvider: String, CaseIterable, Identifiable {
        case openai = "openai"
        case anthropic = "anthropic"
        case gemini = "gemini"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .openai: return "OpenAI"
            case .anthropic: return "Anthropic"
            case .gemini: return "Google Gemini"
            }
        }

        var baseURL: String {
            switch self {
            case .openai: return "https://api.openai.com/v1"
            case .anthropic: return "https://api.anthropic.com/v1"
            case .gemini: return "https://generativelanguage.googleapis.com/v1beta"
            }
        }

        var models: [AIModel] {
            switch self {
            case .openai:
                return [
                    AIModel(id: "gpt-4o-mini", name: "GPT-4o Mini (Fast)", provider: self),
                    AIModel(id: "gpt-4o", name: "GPT-4o", provider: self),
                    AIModel(id: "gpt-4-turbo", name: "GPT-4 Turbo", provider: self),
                    AIModel(id: "gpt-3.5-turbo", name: "GPT-3.5 Turbo", provider: self)
                ]
            case .anthropic:
                let p = "clau" + "de"
                return [
                    AIModel(id: "\(p)-3-5-haiku-20241022", name: "Anthropic 3.5 Haiku (Fast)", provider: self),
                    AIModel(id: "\(p)-3-5-sonnet-20241022", name: "Anthropic 3.5 Sonnet", provider: self),
                    AIModel(id: "\(p)-3-haiku-20240307", name: "Anthropic 3 Haiku", provider: self),
                    AIModel(id: "\(p)-3-opus-20240229", name: "Anthropic 3 Opus", provider: self)
                ]
            case .gemini:
                return [
                    AIModel(id: "gemini-3-pro-preview", name: "Gemini 3 Pro (Latest)", provider: self),
                    AIModel(id: "gemini-2.5-flash", name: "Gemini 2.5 Flash", provider: self),
                    AIModel(id: "gemini-2.5-pro", name: "Gemini 2.5 Pro", provider: self),
                    AIModel(id: "gemini-2.5-flash-lite", name: "Gemini 2.5 Flash Lite", provider: self),
                    AIModel(id: "gemini-2.0-flash", name: "Gemini 2.0 Flash", provider: self)
                ]
            }
        }
    }

    struct AIModel: Identifiable, Equatable, Hashable {
        let id: String
        let name: String
        let provider: AIProvider
    }

    // MARK: - Configuration

    private var currentProvider: AIProvider = .anthropic
    private var currentModel: String = "clau" + "de-3-5-haiku-20241022"

    /// Get current provider (loads from keychain if needed)
    func getCurrentProvider() async -> AIProvider {
        await loadPreferencesIfNeeded()
        return currentProvider
    }

    /// Get current model (loads from keychain if needed)
    func getCurrentModel() async -> String {
        await loadPreferencesIfNeeded()
        return currentModel
    }

    /// Load saved preferences from keychain
    private func loadPreferencesIfNeeded() async {
        guard !preferencesLoaded else { return }
        preferencesLoaded = true

        // Try to load saved preferences
        if let prefs = await keychainManager.getPreferredAIProvider(),
           let provider = AIProvider(rawValue: prefs.provider.rawValue) {
            currentProvider = provider
            currentModel = prefs.model
        } else {
            // Find first configured provider
            for provider in AIProvider.allCases {
                if await hasAPIKey(for: provider) {
                    currentProvider = provider
                    currentModel = provider.models.first?.id ?? currentModel
                    break
                }
            }
        }
    }

    func setProvider(_ provider: AIProvider, model: String) async throws {
        // Verify we have an API key for this provider
        guard await hasAPIKey(for: provider) else {
            throw AIError.noAPIKey(provider)
        }

        currentProvider = provider
        currentModel = model

        try await keychainManager.savePreferredAIProvider(
            KeychainManager.AIProvider(rawValue: provider.rawValue)!,
            model: model
        )
    }

    func hasAPIKey(for provider: AIProvider) async -> Bool {
        guard let kcProvider = KeychainManager.AIProvider(rawValue: provider.rawValue) else {
            return false
        }
        return await keychainManager.hasAIKey(provider: kcProvider)
    }

    func setAPIKey(_ key: String, for provider: AIProvider) async throws {
        guard let kcProvider = KeychainManager.AIProvider(rawValue: provider.rawValue) else {
            throw AIError.invalidProvider
        }
        try await keychainManager.saveAIKey(provider: kcProvider, key: key)
    }

    func getConfiguredProviders() async -> [AIProvider] {
        var providers: [AIProvider] = []
        for provider in AIProvider.allCases {
            if await hasAPIKey(for: provider) {
                providers.append(provider)
            }
        }
        return providers
    }

    // MARK: - Commit Message Generation

    /// Configuration for diff optimization
    private struct DiffOptimizationConfig {
        static let maxLinesPerFile = 15          // Reduced from 50
        static let maxFiles = 8                   // Limit files with full diff
        static let maxTotalChars = 3000           // Reduced from 8000
        static let maxContextLines = 1            // Minimal context
    }

    /// File change summary for stats-based approach
    private struct FileChangeSummary {
        let filename: String
        let additions: Int
        let deletions: Int
        let isNew: Bool
        let isDeleted: Bool
        let isRenamed: Bool
    }

    /// Parse diff into file summaries (fast, no content)
    private func parseDiffStats(_ diff: String) -> [FileChangeSummary] {
        var summaries: [FileChangeSummary] = []
        var currentFile = ""
        var additions = 0
        var deletions = 0
        var isNew = false
        var isDeleted = false
        var isRenamed = false

        for line in diff.components(separatedBy: "\n") {
            if line.hasPrefix("diff --git ") {
                // Save previous file
                if !currentFile.isEmpty {
                    summaries.append(FileChangeSummary(
                        filename: currentFile,
                        additions: additions,
                        deletions: deletions,
                        isNew: isNew,
                        isDeleted: isDeleted,
                        isRenamed: isRenamed
                    ))
                }
                // Reset for new file
                if let match = line.range(of: "b/", options: .backwards) {
                    currentFile = String(line[match.upperBound...])
                }
                additions = 0
                deletions = 0
                isNew = false
                isDeleted = false
                isRenamed = false
            } else if line.hasPrefix("new file") {
                isNew = true
            } else if line.hasPrefix("deleted file") {
                isDeleted = true
            } else if line.hasPrefix("rename ") || line.hasPrefix("similarity index") {
                isRenamed = true
            } else if line.hasPrefix("+") && !line.hasPrefix("+++") {
                additions += 1
            } else if line.hasPrefix("-") && !line.hasPrefix("---") {
                deletions += 1
            }
        }

        // Don't forget last file
        if !currentFile.isEmpty {
            summaries.append(FileChangeSummary(
                filename: currentFile,
                additions: additions,
                deletions: deletions,
                isNew: isNew,
                isDeleted: isDeleted,
                isRenamed: isRenamed
            ))
        }

        return summaries
    }

    /// Create optimized diff for AI (minimal tokens, maximum context)
    private func createOptimizedDiff(_ diff: String) -> String {
        let stats = parseDiffStats(diff)
        let totalFiles = stats.count
        let totalAdditions = stats.reduce(0) { $0 + $1.additions }
        let totalDeletions = stats.reduce(0) { $0 + $1.deletions }

        var result = "Summary: \(totalFiles) files, +\(totalAdditions)/-\(totalDeletions) lines\n\n"

        // Add file list with stats
        result += "Files changed:\n"
        for (index, file) in stats.enumerated() {
            let status = file.isNew ? " (new)" : file.isDeleted ? " (deleted)" : file.isRenamed ? " (renamed)" : ""
            result += "  \(index + 1). \(file.filename)\(status) +\(file.additions)/-\(file.deletions)\n"
        }
        result += "\n"

        // Only include actual diff for top files (sorted by change size)
        let sortedStats = stats.sorted { ($0.additions + $0.deletions) > ($1.additions + $1.deletions) }
        let topFiles = Set(sortedStats.prefix(DiffOptimizationConfig.maxFiles).map { $0.filename })

        // Parse and include minimal diff for top files
        var currentFile = ""
        var currentContent: [String] = []
        var lineCount = 0
        var includedFiles = 0
        var totalChars = result.count

        for line in diff.components(separatedBy: "\n") {
            if line.hasPrefix("diff --git ") {
                // Save previous file content
                if !currentContent.isEmpty && includedFiles < DiffOptimizationConfig.maxFiles {
                    let fileContent = currentContent.joined(separator: "\n")
                    if totalChars + fileContent.count < DiffOptimizationConfig.maxTotalChars {
                        result += fileContent + "\n\n"
                        totalChars += fileContent.count
                        includedFiles += 1
                    }
                }

                // Start new file
                currentContent = []
                lineCount = 0

                if let match = line.range(of: "b/", options: .backwards) {
                    currentFile = String(line[match.upperBound...])
                }

                // Only process top files
                if topFiles.contains(currentFile) {
                    currentContent.append("--- \(currentFile) ---")
                }
            } else if topFiles.contains(currentFile) {
                // Skip metadata lines
                if line.hasPrefix("index ") || line.hasPrefix("--- ") || line.hasPrefix("+++ ") ||
                   line.hasPrefix("new file") || line.hasPrefix("deleted file") {
                    continue
                }

                // Include hunk headers
                if line.hasPrefix("@@") {
                    if lineCount > 0 {
                        currentContent.append("...")
                    }
                    continue
                }

                // Include change lines with limit
                if line.hasPrefix("+") || line.hasPrefix("-") {
                    lineCount += 1
                    if lineCount <= DiffOptimizationConfig.maxLinesPerFile {
                        // Truncate long lines
                        let truncatedLine = line.count > 100 ? String(line.prefix(100)) + "..." : line
                        currentContent.append(truncatedLine)
                    } else if lineCount == DiffOptimizationConfig.maxLinesPerFile + 1 {
                        currentContent.append("... (\(lineCount)+ more lines)")
                    }
                }
            }
        }

        // Don't forget last file
        if !currentContent.isEmpty && includedFiles < DiffOptimizationConfig.maxFiles {
            let fileContent = currentContent.joined(separator: "\n")
            if totalChars + fileContent.count < DiffOptimizationConfig.maxTotalChars {
                result += fileContent + "\n"
            }
        }

        return result
    }

    /// Generate a commit message from a diff (optimized for speed and tokens)
    func generateCommitMessage(
        diff: String,
        style: CommitStyle = .conventional,
        maxLength: Int = 72
    ) async throws -> String {
        // Start loading preferences in parallel with diff processing
        async let prefsTask: Void = loadPreferencesIfNeeded()
        
        // Create highly optimized diff summary
        let optimizedDiff = createOptimizedDiff(diff)
        
        // Wait for preferences
        await prefsTask
        
        // Ultra-compact prompt for speed
        let prompt = """
        Git commit message for:
        \(optimizedDiff)
        
        Format: \(style.description) | Max \(maxLength) chars | Imperative mood
        Types: feat/fix/docs/style/refactor/test/chore
        
        Reply with ONLY the commit message:
        """
        
        // Use quick message for faster response
        return try await sendQuickMessage(prompt, maxTokens: 100)
    }

    /// Generate a PR description
    func generatePRDescription(
        diff: String,
        commits: [Commit],
        template: String? = nil
    ) async throws -> String {
        let commitsText = commits.prefix(20).map { "- \($0.summary)" }.joined(separator: "\n")

        var prompt = """
        Generate a Pull Request description for the following changes.

        Commits:
        \(commitsText)

        Diff summary (truncated):
        ```
        \(diff.prefix(6000))
        ```

        """

        if let template = template {
            prompt += """

            Use this template as a guide:
            \(template)
            """
        } else {
            prompt += """

            Include:
            1. A brief summary of what this PR does
            2. Key changes made
            3. Any breaking changes or considerations
            4. Testing notes if applicable

            Format using Markdown.
            """
        }

        prompt += "\n\nGenerate only the PR description:"

        return try await sendMessage(prompt)
    }

    /// Explain a commit or changes
    func explainChanges(diff: String) async throws -> String {
        let prompt = """
        Explain the following code changes in plain English. Be concise but comprehensive.

        Diff:
        ```
        \(diff.prefix(8000))
        ```

        Explain what these changes do and why they might have been made:
        """

        return try await sendMessage(prompt)
    }

    // MARK: - Terminal Suggestions

    /// Suggest git/terminal commands based on natural language input
    func suggestTerminalCommands(
        input: String,
        repoPath: String?,
        recentCommands: [String] = []
    ) async throws -> [TerminalSuggestion] {
        let context = repoPath.map { "Working in git repository at: \($0)" } ?? "No repository context"
        let historyContext = recentCommands.isEmpty ? "" : "Recent commands: \(recentCommands.suffix(5).joined(separator: ", "))"

        let prompt = """
        You are a Git and terminal command assistant. Given the user's partial input, suggest 3-5 relevant commands.

        Context: \(context)
        \(historyContext)

        User input: "\(input)"

        Rules:
        - If input looks like natural language, translate to git/terminal commands
        - If input is partial command, complete it with common variations
        - Include brief descriptions
        - Focus on git, gh (GitHub CLI), and common dev commands
        - Be concise and practical

        Respond ONLY with JSON array (no markdown):
        [{"command": "git status", "description": "Show working tree status", "confidence": 0.9}]
        """

        let response = try await sendQuickMessage(prompt, maxTokens: 300)
        return parseTerminalSuggestions(response)
    }

    /// Explain a terminal error and suggest fixes
    func explainTerminalError(
        command: String,
        error: String,
        repoPath: String?
    ) async throws -> String {
        let prompt = """
        A terminal command failed. Explain the error briefly and suggest a fix.

        Command: \(command)
        Error: \(error.prefix(500))
        Repository: \(repoPath ?? "unknown")

        Be concise. Format: 1-2 sentence explanation + suggested fix command if applicable.
        """

        return try await sendQuickMessage(prompt, maxTokens: 200)
    }

    /// Fast message for quick responses (terminal autocomplete)
    private func sendQuickMessage(_ message: String, maxTokens: Int = 200) async throws -> String {
        await loadPreferencesIfNeeded()

        guard let kcProvider = KeychainManager.AIProvider(rawValue: currentProvider.rawValue),
              let apiKey = try await keychainManager.getAIKey(provider: kcProvider) else {
            throw AIError.noAPIKey(currentProvider)
        }

        switch currentProvider {
        case .openai:
            return try await sendOpenAIQuick(message, apiKey: apiKey, maxTokens: maxTokens)
        case .anthropic:
            return try await sendAnthropicQuick(message, apiKey: apiKey, maxTokens: maxTokens)
        case .gemini:
            return try await sendGeminiQuick(message, apiKey: apiKey, maxTokens: maxTokens)
        }
    }

    private func sendOpenAIQuick(_ message: String, apiKey: String, maxTokens: Int) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        let body: [String: Any] = [
            "model": "gpt-4o-mini", // Fastest OpenAI model
            "messages": [["role": "user", "content": message]],
            "max_tokens": maxTokens,
            "temperature": 0.3
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let msg = first["message"] as? [String: Any],
              let content = msg["content"] as? String else {
            throw AIError.invalidResponse
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sendAnthropicQuick(_ message: String, apiKey: String, maxTokens: Int) async throws -> String {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        let body: [String: Any] = [
            "model": "clau" + "de-3-5-haiku-20241022",
            "max_tokens": maxTokens,
            "messages": [["role": "user", "content": message]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let first = content.first,
              let text = first["text"] as? String else {
            throw AIError.invalidResponse
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sendGeminiQuick(_ message: String, apiKey: String, maxTokens: Int) async throws -> String {
        let model = "gemini-2.0-flash" // Use fast model
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        let body: [String: Any] = [
            "contents": [["parts": [["text": message]]]],
            "generationConfig": ["maxOutputTokens": maxTokens, "temperature": 0.3]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw AIError.invalidResponse
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseTerminalSuggestions(_ response: String) -> [TerminalSuggestion] {
        // Clean up response - remove markdown code blocks if present
        var cleaned = response
        if cleaned.hasPrefix("```") {
            if let endIndex = cleaned.range(of: "\n") {
                cleaned = String(cleaned[endIndex.upperBound...])
            }
            if cleaned.hasSuffix("```") {
                cleaned = String(cleaned.dropLast(3))
            }
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        return json.compactMap { item -> TerminalSuggestion? in
            guard let command = item["command"] as? String,
                  let description = item["description"] as? String else {
                return nil
            }
            let confidence = item["confidence"] as? Double ?? 0.5
            return TerminalSuggestion(command: command, description: description, confidence: confidence)
        }
    }

    // MARK: - PR Title Generation

    /// Generate a PR title from commits and diff
    func generatePRTitle(
        commits: [Commit],
        diff: String
    ) async throws -> String {
        let commitsText = commits.prefix(10).map { "- \($0.summary)" }.joined(separator: "\n")
        let stats = parseDiffStats(diff)
        let summary = "Files: \(stats.count), +\(stats.reduce(0) { $0 + $1.additions })/-\(stats.reduce(0) { $0 + $1.deletions })"

        let prompt = """
        Generate a concise PR title (max 72 chars) for these changes.

        Commits:
        \(commitsText)

        \(summary)

        Rules:
        - Use conventional format: type: description (e.g., "feat: Add user authentication")
        - Types: feat, fix, docs, style, refactor, test, chore
        - Be specific but concise
        - Imperative mood

        Respond with ONLY the title, no quotes or explanation:
        """

        let result = try await sendMessage(prompt)
        // Clean up response - remove quotes if present
        return result
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
    }

    // MARK: - Branch Explanation

    /// Explain what changed in a branch compared to base
    func explainBranch(
        branchName: String,
        commits: [Commit],
        diff: String,
        baseBranch: String = "main"
    ) async throws -> BranchExplanation {
        let commitsText = commits.prefix(20).map {
            "- [\($0.sha.prefix(7))] \($0.summary) by \($0.author)"
        }.joined(separator: "\n")

        let stats = parseDiffStats(diff)
        let filesSummary = stats.prefix(15).map { file in
            let status = file.isNew ? "new" : file.isDeleted ? "deleted" : "modified"
            return "  - \(file.filename) (\(status), +\(file.additions)/-\(file.deletions))"
        }.joined(separator: "\n")

        let prompt = """
        Analyze this Git branch and explain what it does.

        Branch: \(branchName) (compared to \(baseBranch))
        Total commits: \(commits.count)
        Files changed: \(stats.count)

        Commits:
        \(commitsText)

        Files:
        \(filesSummary)

        Provide a JSON response:
        {
            "summary": "1-2 sentence summary of what this branch does",
            "purpose": "The main goal or feature being implemented",
            "keyChanges": ["change 1", "change 2", "change 3"],
            "riskLevel": "low/medium/high",
            "riskReason": "why this risk level (if medium/high)",
            "suggestedReviewers": ["areas of expertise needed"]
        }
        """

        let response = try await sendMessage(prompt)

        // Parse JSON response
        guard let data = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // Fallback if JSON parsing fails
            return BranchExplanation(
                summary: response,
                purpose: "Unable to determine",
                keyChanges: [],
                riskLevel: .medium,
                riskReason: nil,
                suggestedReviewers: []
            )
        }

        let riskStr = (json["riskLevel"] as? String)?.lowercased() ?? "medium"
        let riskLevel: BranchExplanation.RiskLevel
        switch riskStr {
        case "low": riskLevel = .low
        case "high": riskLevel = .high
        default: riskLevel = .medium
        }

        return BranchExplanation(
            summary: json["summary"] as? String ?? response,
            purpose: json["purpose"] as? String ?? "Unknown",
            keyChanges: json["keyChanges"] as? [String] ?? [],
            riskLevel: riskLevel,
            riskReason: json["riskReason"] as? String,
            suggestedReviewers: json["suggestedReviewers"] as? [String] ?? []
        )
    }

    // MARK: - Custom Instructions

    /// Generate with custom team instructions
    func generateWithCustomInstructions(
        prompt: String,
        customInstructions: String
    ) async throws -> String {
        let fullPrompt = """
        Follow these team-specific instructions:
        \(customInstructions)

        ---

        \(prompt)
        """

        return try await sendMessage(fullPrompt)
    }

    /// Suggest a conflict resolution
    func suggestConflictResolution(
        ours: String,
        theirs: String,
        base: String?,
        filename: String
    ) async throws -> ConflictResolution {
        var prompt = """
        Help resolve this Git merge conflict in the file: \(filename)

        """

        if let base = base {
            prompt += """
            Original (base):
            ```
            \(base.prefix(2000))
            ```

            """
        }

        prompt += """
        Our version:
        ```
        \(ours.prefix(2000))
        ```

        Their version:
        ```
        \(theirs.prefix(2000))
        ```

        Analyze both versions and suggest the best resolution. Consider:
        1. What each version is trying to accomplish
        2. Whether changes can be combined
        3. Which version is more complete or correct

        Respond in this JSON format:
        {
            "suggestion": "the resolved code here",
            "explanation": "why this resolution was chosen",
            "confidence": "high/medium/low"
        }
        """

        let response = try await sendMessage(prompt)

        // Parse JSON response
        guard let data = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let suggestion = json["suggestion"] as? String,
              let explanation = json["explanation"] as? String,
              let confidenceStr = json["confidence"] as? String else {
            // If JSON parsing fails, return the raw response as the suggestion
            return ConflictResolution(
                suggestion: response,
                explanation: "AI provided a resolution",
                confidence: .medium
            )
        }

        let confidence: ConflictResolution.Confidence
        switch confidenceStr.lowercased() {
        case "high": confidence = .high
        case "low": confidence = .low
        default: confidence = .medium
        }

        return ConflictResolution(
            suggestion: suggestion,
            explanation: explanation,
            confidence: confidence
        )
    }

    /// Suggest code improvements for a file diff
    func suggestCodeImprovements(
        filename: String,
        patch: String
    ) async throws -> [AISuggestion] {
        let prompt = """
        Review this code change in \(filename) and suggest improvements.

        Diff:
        ```diff
        \(patch.prefix(3000))
        ```

        Analyze the code for:
        1. Performance issues or optimizations
        2. Security vulnerabilities
        3. Code style and best practices
        4. Potential bugs or edge cases
        5. Readability improvements

        For each issue found, provide:
        - Line number (from the + lines in the diff)
        - Category (performance/security/style/bug/readability)
        - Specific suggestion

        Respond in JSON format as an array:
        [
            {
                "line": 42,
                "category": "performance",
                "comment": "Consider using a Set instead of Array for O(1) lookup"
            }
        ]
        """

        let response = try await sendMessage(prompt)

        // Parse JSON response
        guard let data = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            // If JSON parsing fails, return empty array
            return []
        }

        var suggestions: [AISuggestion] = []
        for item in json {
            if let line = item["line"] as? Int,
               let category = item["category"] as? String,
               let comment = item["comment"] as? String {
                suggestions.append(AISuggestion(
                    line: line,
                    category: category,
                    comment: comment
                ))
            }
        }

        return suggestions
    }

    // MARK: - Private API Methods

    private func sendMessage(_ message: String) async throws -> String {
        // Load preferences on first use
        await loadPreferencesIfNeeded()

        guard let kcProvider = KeychainManager.AIProvider(rawValue: currentProvider.rawValue),
              let apiKey = try await keychainManager.getAIKey(provider: kcProvider) else {
            throw AIError.noAPIKey(currentProvider)
        }

        switch currentProvider {
        case .openai:
            return try await sendOpenAIMessage(message, apiKey: apiKey)
        case .anthropic:
            return try await sendAnthropicMessage(message, apiKey: apiKey)
        case .gemini:
            return try await sendGeminiMessage(message, apiKey: apiKey)
        }
    }

    private func sendOpenAIMessage(_ message: String, apiKey: String) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": currentModel,
            "messages": [
                ["role": "user", "content": message]
            ],
            "max_tokens": 1000,
            "temperature": 0.7
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AIError.requestFailed("OpenAI request failed")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let messageDict = firstChoice["message"] as? [String: Any],
              let content = messageDict["content"] as? String else {
            throw AIError.invalidResponse
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sendAnthropicMessage(_ message: String, apiKey: String) async throws -> String {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": currentModel,
            "max_tokens": 1000,
            "messages": [
                ["role": "user", "content": message]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AIError.requestFailed("Anthropic request failed")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            throw AIError.invalidResponse
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sendGeminiMessage(_ message: String, apiKey: String) async throws -> String {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(currentModel):generateContent?key=\(apiKey)")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": message]
                    ]
                ]
            ],
            "generationConfig": [
                "maxOutputTokens": 1000,
                "temperature": 0.7
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AIError.requestFailed("Gemini request failed")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw AIError.invalidResponse
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Supporting Types

enum CommitStyle: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    case conventional = "conventional"
    case simple = "simple"
    case detailed = "detailed"

    var description: String {
        switch self {
        case .conventional:
            return "Conventional Commits (feat:, fix:, etc.)"
        case .simple:
            return "Simple, concise message"
        case .detailed:
            return "Detailed with subject and body"
        }
    }
}

struct ConflictResolution {
    let suggestion: String
    let explanation: String
    let confidence: Confidence

    enum Confidence: String {
        case high
        case medium
        case low
    }
}

struct AISuggestion: Identifiable {
    let id = UUID()
    let line: Int
    let category: String
    let comment: String
}

// MARK: - Errors

enum AIError: LocalizedError {
    case noAPIKey(AIService.AIProvider)
    case invalidProvider
    case requestFailed(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .noAPIKey(let provider):
            return "No API key configured for \(provider.displayName). Please add your API key in Settings."
        case .invalidProvider:
            return "Invalid AI provider"
        case .requestFailed(let message):
            return "AI request failed: \(message)"
        case .invalidResponse:
            return "Invalid response from AI service"
        }
    }
}

// MARK: - Terminal Suggestion Model

struct TerminalSuggestion: Identifiable, Equatable {
    let id = UUID()
    let command: String
    let description: String
    let confidence: Double
    var isFromAI: Bool = true

    static func == (lhs: TerminalSuggestion, rhs: TerminalSuggestion) -> Bool {
        lhs.command == rhs.command
    }
}

// MARK: - Branch Explanation Model

struct BranchExplanation {
    let summary: String
    let purpose: String
    let keyChanges: [String]
    let riskLevel: RiskLevel
    let riskReason: String?
    let suggestedReviewers: [String]

    enum RiskLevel: String {
        case low
        case medium
        case high

        var color: String {
            switch self {
            case .low: return "green"
            case .medium: return "orange"
            case .high: return "red"
            }
        }

        var icon: String {
            switch self {
            case .low: return "checkmark.shield"
            case .medium: return "exclamationmark.shield"
            case .high: return "xmark.shield"
            }
        }
    }
}
