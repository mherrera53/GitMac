//
//  TerminalAIService.swift
//  GitMac
//
//  AI command suggestion service with Ollama integration and OpenAI fallback
//

import Foundation

// MARK: - AI Command Suggestion (shared model)

struct AICommandSuggestion: Identifiable {
    let id = UUID()
    let command: String
    let description: String
    let confidence: Double
    let isFromAI: Bool
    let category: String?

    init(command: String, description: String, confidence: Double, isFromAI: Bool, category: String? = nil) {
        self.command = command
        self.description = description
        self.confidence = confidence
        self.isFromAI = isFromAI
        self.category = category
    }
}

// MARK: - Ollama API Models

struct OllamaRequest: Codable {
    let model: String
    let prompt: String
    let stream: Bool
    let options: OllamaOptions?

    struct OllamaOptions: Codable {
        let temperature: Double
        let num_predict: Int
        let top_p: Double?

        enum CodingKeys: String, CodingKey {
            case temperature
            case num_predict
            case top_p
        }
    }
}

struct OllamaResponse: Codable {
    let model: String
    let created_at: String
    let response: String
    let done: Bool
}

// MARK: - AI Service Configuration

enum AIProvider: String {
    case ollama = "ollama"
    case openai = "openai"
}

// MARK: - AI Service

@MainActor
class TerminalAIService {
    static let shared = TerminalAIService()

    // Configuration
    private let ollamaEndpoint = "http://localhost:11434"
    private let defaultModel = "deepseek-coder:6.7b"
    private let timeout: TimeInterval = 10.0

    // State
    private var isOllamaAvailable: Bool?
    private var lastOllamaCheck: Date?
    private let checkInterval: TimeInterval = 60.0 // Re-check every minute

    private init() {}

    // MARK: - Ollama Availability Check

    private func checkOllamaAvailability() async -> Bool {
        // Use cached result if recent
        if let lastCheck = lastOllamaCheck,
           let available = isOllamaAvailable,
           Date().timeIntervalSince(lastCheck) < checkInterval {
            return available
        }

        // Check if Ollama is running
        guard let url = URL(string: "\(ollamaEndpoint)/api/tags") else {
            isOllamaAvailable = false
            return false
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 2.0 // Quick check

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                let available = httpResponse.statusCode == 200
                isOllamaAvailable = available
                lastOllamaCheck = Date()

                if available {
                    print("✅ Ollama is available at \(ollamaEndpoint)")
                } else {
                    print("⚠️ Ollama returned status \(httpResponse.statusCode)")
                }

                return available
            }
        } catch {
            print("⚠️ Ollama not available: \(error.localizedDescription)")
            isOllamaAvailable = false
            lastOllamaCheck = Date()
        }

        return false
    }

    // MARK: - Ollama API Call

    private func callOllama(prompt: String, temperature: Double = 0.3, maxTokens: Int = 150) async throws -> String {
        guard let url = URL(string: "\(ollamaEndpoint)/api/generate") else {
            throw NSError(domain: "TerminalAI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid Ollama endpoint"])
        }

        let request = OllamaRequest(
            model: defaultModel,
            prompt: prompt,
            stream: false,
            options: OllamaRequest.OllamaOptions(
                temperature: temperature,
                num_predict: maxTokens,
                top_p: 0.9
            )
        )

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = timeout
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "TerminalAI", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid response from Ollama"])
        }

        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "TerminalAI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Ollama API error: \(httpResponse.statusCode)"])
        }

        let ollamaResponse = try JSONDecoder().decode(OllamaResponse.self, from: data)
        return ollamaResponse.response.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - OpenAI Fallback

    private func callOpenAI(prompt: String) async throws -> String {
        // Import AIService for fallback to cloud providers
        let aiService = AIService()

        // Use the existing AIService which supports OpenAI, Anthropic, and Google
        return try await aiService.generateCommitMessage(diff: prompt)
    }

    // MARK: - Terminal Command Suggestions

    func suggestTerminalCommands(
        input: String,
        repoPath: String?,
        recentCommands: [String]
    ) async throws -> [AICommandSuggestion] {
        print("🔮 TerminalAIService: suggestTerminalCommands called with input: '\(input)'")

        // PRIORITY: Check for directory/file path suggestions first
        let directorySuggestions = getDirectorySuggestions(for: input, repoPath: repoPath)
        if !directorySuggestions.isEmpty {
            print("📁 Returning \(directorySuggestions.count) directory suggestions")
            return directorySuggestions
        }

        // Build context
        let recentContext = recentCommands.isEmpty ? "" : "\nRecent commands: \(recentCommands.suffix(3).joined(separator: ", "))"
        let repoContext = repoPath != nil ? "\nWorking in Git repository: \(repoPath!)" : ""

        let prompt = """
        You are a terminal command assistant. Suggest 3-5 relevant terminal commands based on the user's input.

        User input: "\(input)"
        \(recentContext)\(repoContext)

        Return ONLY a JSON array of suggestions in this exact format:
        [
          {"command": "git status", "description": "Show working tree status", "confidence": 0.95},
          {"command": "git add .", "description": "Stage all changes", "confidence": 0.85}
        ]

        Rules:
        - Focus on Git commands if in a repository
        - Include common terminal commands (ls, cd, grep, etc.)
        - Be concise (descriptions max 50 chars)
        - Order by relevance (highest confidence first)
        - Return ONLY valid JSON, no other text
        """

        // Try Ollama first
        let ollamaAvailable = await checkOllamaAvailability()

        var aiResponse: String?
        var usedProvider = AIProvider.ollama

        if ollamaAvailable {
            do {
                print("📡 Calling Ollama for suggestions...")
                aiResponse = try await callOllama(prompt: prompt, temperature: 0.3, maxTokens: 300)
                print("✅ Got response from Ollama")
            } catch {
                print("⚠️ Ollama failed: \(error.localizedDescription), falling back to OpenAI")
                usedProvider = .openai
            }
        } else {
            print("⚠️ Ollama not available, using OpenAI fallback")
            usedProvider = .openai
        }

        // Fallback to OpenAI if Ollama failed or unavailable
        if aiResponse == nil && usedProvider == .openai {
            do {
                // Use the shared AIService to get structured suggestions directly
                let aiService = AIService.shared
                let aiSuggestions = try await aiService.suggestTerminalCommands(
                    input: input,
                    repoPath: repoPath,
                    recentCommands: recentCommands
                )
                
                // Map to local model
                let mappedSuggestions = aiSuggestions.map { suggestion in
                    AICommandSuggestion(
                        command: suggestion.command,
                        description: suggestion.description,
                        confidence: suggestion.confidence,
                        isFromAI: true,
                        category: "AI"
                    )
                }
                
                print("💡 TerminalAIService: Returning \(mappedSuggestions.count) AI suggestions from cloud provider")
                return mappedSuggestions
            } catch {
                print("❌ Cloud AI provider failed: \(error.localizedDescription)")
                return getStaticSuggestions(for: input)
            }
        }

        // Parse AI response
        guard let response = aiResponse else {
            return getStaticSuggestions(for: input)
        }

        // Extract JSON from response (in case there's extra text)
        let jsonPattern = "\\[\\s*\\{[^\\]]*\\}\\s*\\]"
        guard let regex = try? NSRegularExpression(pattern: jsonPattern, options: [.dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: response, range: NSRange(response.startIndex..., in: response)),
              let range = Range(match.range, in: response) else {
            print("⚠️ Failed to extract JSON from AI response, using static suggestions")
            return getStaticSuggestions(for: input)
        }

        let jsonString = String(response[range])

        do {
            struct SuggestionJSON: Codable {
                let command: String
                let description: String
                let confidence: Double
            }

            let suggestions = try JSONDecoder().decode([SuggestionJSON].self, from: jsonString.data(using: .utf8)!)

            let aiSuggestions = suggestions.map { suggestion in
                AICommandSuggestion(
                    command: suggestion.command,
                    description: suggestion.description,
                    confidence: suggestion.confidence,
                    isFromAI: true,
                    category: nil
                )
            }

            print("💡 TerminalAIService: Returning \(aiSuggestions.count) AI suggestions")
            return aiSuggestions

        } catch {
            print("⚠️ Failed to parse AI JSON: \(error.localizedDescription)")
            return getStaticSuggestions(for: input)
        }
    }

    // MARK: - Static Fallback Suggestions

    private func getStaticSuggestions(for input: String) -> [AICommandSuggestion] {
        let lowercasedInput = input.lowercased().trimmingCharacters(in: .whitespaces)
        var suggestions: [AICommandSuggestion] = []

        // Git command suggestions
        // Check if input is "git" or starts with "git "
        if lowercasedInput == "git" || lowercasedInput.hasPrefix("git ") || lowercasedInput.starts(with: "g") {
            
            // Default suggestions if just "git" or "g"
            if lowercasedInput == "git" || lowercasedInput == "g" {
                suggestions.append(AICommandSuggestion(
                    command: "git status",
                    description: "Show the working tree status",
                    confidence: 0.95,
                    isFromAI: false,
                    category: "Git"
                ))
                suggestions.append(AICommandSuggestion(
                    command: "git add .",
                    description: "Stage all changes",
                    confidence: 0.90,
                    isFromAI: false,
                    category: "Git"
                ))
                suggestions.append(AICommandSuggestion(
                    command: "git commit -m \"\"",
                    description: "Commit changes",
                    confidence: 0.85,
                    isFromAI: false,
                    category: "Git"
                ))
                suggestions.append(AICommandSuggestion(
                    command: "git push",
                    description: "Push to remote",
                    confidence: 0.80,
                    isFromAI: false,
                    category: "Git"
                ))
                suggestions.append(AICommandSuggestion(
                    command: "git pull",
                    description: "Pull from remote",
                    confidence: 0.80,
                    isFromAI: false,
                    category: "Git"
                ))
            }
            
            // Specific sub-commands
            if lowercasedInput.contains("s") || lowercasedInput.contains("stat") {
                suggestions.append(AICommandSuggestion(
                    command: "git status",
                    description: "Show the working tree status",
                    confidence: 0.85,
                    isFromAI: false,
                    category: "Git"
                ))
            }

            if lowercasedInput.contains("a") || lowercasedInput.contains("add") {
                suggestions.append(AICommandSuggestion(
                    command: "git add .",
                    description: "Stage all changes",
                    confidence: 0.80,
                    isFromAI: false,
                    category: "Git"
                ))
            }

            if lowercasedInput.contains("c") || lowercasedInput.contains("commit") {
                suggestions.append(AICommandSuggestion(
                    command: "git commit -m \"\"",
                    description: "Commit staged changes with message",
                    confidence: 0.80,
                    isFromAI: false,
                    category: "Git"
                ))
            }

            if lowercasedInput.contains("pu") || lowercasedInput.contains("push") {
                suggestions.append(AICommandSuggestion(
                    command: "git push",
                    description: "Push commits to remote",
                    confidence: 0.75,
                    isFromAI: false,
                    category: "Git"
                ))
            }
            
            if lowercasedInput.contains("pl") || lowercasedInput.contains("pull") {
                suggestions.append(AICommandSuggestion(
                    command: "git pull",
                    description: "Pull changes from remote",
                    confidence: 0.75,
                    isFromAI: false,
                    category: "Git"
                ))
            }

            if lowercasedInput.contains("l") || lowercasedInput.contains("log") {
                suggestions.append(AICommandSuggestion(
                    command: "git log --oneline -10",
                    description: "Show recent commits",
                    confidence: 0.75,
                    isFromAI: false,
                    category: "Git"
                ))
            }
        }

        // Docker suggestions
        if lowercasedInput.contains("docker") || lowercasedInput.starts(with: "d") {
            // Default docker suggestions
            if lowercasedInput == "docker" || lowercasedInput == "d" {
                suggestions.append(AICommandSuggestion(
                    command: "docker ps",
                    description: "List containers",
                    confidence: 0.90,
                    isFromAI: false,
                    category: "Docker"
                ))
                suggestions.append(AICommandSuggestion(
                    command: "docker-compose up -d",
                    description: "Start services",
                    confidence: 0.85,
                    isFromAI: false,
                    category: "Docker"
                ))
            }
            
            if lowercasedInput.contains("ps") {
                suggestions.append(AICommandSuggestion(
                    command: "docker ps",
                    description: "List running containers",
                    confidence: 0.70,
                    isFromAI: false,
                    category: "Docker"
                ))
            }

            if lowercasedInput.contains("compose") {
                suggestions.append(AICommandSuggestion(
                    command: "docker-compose up -d",
                    description: "Start containers in background",
                    confidence: 0.75,
                    isFromAI: false,
                    category: "Docker"
                ))
            }
        }

        // NPM suggestions
        if lowercasedInput.contains("npm") {
            suggestions.append(AICommandSuggestion(
                command: "npm install",
                description: "Install dependencies",
                confidence: 0.70,
                isFromAI: false,
                category: "Node"
            ))

            suggestions.append(AICommandSuggestion(
                command: "npm run dev",
                description: "Run development server",
                confidence: 0.70,
                isFromAI: false,
                category: "Node"
            ))
        }

        // Deduplicate suggestions by command
        var uniqueSuggestions: [AICommandSuggestion] = []
        var seenCommands = Set<String>()
        
        for suggestion in suggestions {
            if !seenCommands.contains(suggestion.command) {
                seenCommands.insert(suggestion.command)
                uniqueSuggestions.append(suggestion)
            }
        }

        print("💡 TerminalAIService: Returning \(uniqueSuggestions.count) static suggestions")
        return uniqueSuggestions
    }

    // MARK: - Error Explanation

    func explainTerminalError(
        command: String,
        error: String,
        repoPath: String?
    ) async throws -> String {
        let repoContext = repoPath != nil ? "\nWorking directory: \(repoPath!)" : ""

        let prompt = """
        You are a helpful terminal assistant. Explain this error and suggest a fix.

        Command: \(command)
        Error output:
        \(error)
        \(repoContext)

        Provide:
        1. Brief explanation of what went wrong
        2. Suggested fix (command or steps)
        3. Keep it concise (max 200 words)

        Format as plain text, not JSON.
        """

        // Try Ollama first
        let ollamaAvailable = await checkOllamaAvailability()

        if ollamaAvailable {
            do {
                print("📡 Calling Ollama for error explanation...")
                let explanation = try await callOllama(prompt: prompt, temperature: 0.2, maxTokens: 500)
                print("✅ Got error explanation from Ollama")
                return explanation
            } catch {
                print("⚠️ Ollama failed: \(error.localizedDescription)")
            }
        }

        // Fallback to OpenAI
        do {
            print("📡 Calling OpenAI for error explanation...")
            let explanation = try await callOpenAI(prompt: prompt)
            print("✅ Got error explanation from OpenAI")
            return explanation
        } catch {
            print("❌ OpenAI also failed: \(error.localizedDescription)")
            return "Unable to get AI explanation. Error: \(error.localizedDescription)\n\nTry checking the command syntax and ensure you have the necessary permissions."
        }
    }

    // MARK: - Directory & File Path Suggestions

    private func getDirectorySuggestions(for input: String, repoPath: String?) -> [AICommandSuggestion] {
        // Commands that take file/directory paths
        let pathCommands = ["cd", "ls", "cat", "vim", "nano", "open", "code", "rm", "mv", "cp", "mkdir", "touch", "grep", "find"]

        // Parse input to detect command and partial path
        let components = input.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard components.count >= 1 else { return [] }

        let command = String(components[0])
        guard pathCommands.contains(command) else { return [] }

        // Get the partial path (or empty if just the command)
        let partialPath = components.count > 1 ? String(components[1]) : ""

        // Determine the working directory
        let workingDir = repoPath ?? FileManager.default.currentDirectoryPath

        // Parse the partial path
        let (searchDir, searchPrefix) = parsePartialPath(partialPath, workingDir: workingDir)

        // Get matching files/directories
        let matches = getMatchingPaths(in: searchDir, prefix: searchPrefix, forCommand: command)

        // Create suggestions
        var suggestions: [AICommandSuggestion] = []
        for (path, isDir) in matches.prefix(8) { // Limit to 8 suggestions
            let fullCommand = "\(command) \(path)"
            let icon = isDir ? "📁" : "📄"
            let type = isDir ? "directory" : "file"
            suggestions.append(AICommandSuggestion(
                command: fullCommand,
                description: "\(icon) \(type)",
                confidence: 0.95,
                isFromAI: false,
                category: "Path"
            ))
        }

        return suggestions
    }

    private func parsePartialPath(_ partial: String, workingDir: String) -> (searchDir: String, prefix: String) {
        if partial.isEmpty {
            // No path entered yet, show current directory contents
            return (workingDir, "")
        }

        if partial.hasPrefix("/") {
            // Absolute path
            let url = URL(fileURLWithPath: partial)
            let dir = url.deletingLastPathComponent().path
            let prefix = url.lastPathComponent
            return (dir, prefix)
        } else if partial.hasPrefix("~/") {
            // Home directory
            let expandedPath = NSString(string: partial).expandingTildeInPath
            let url = URL(fileURLWithPath: expandedPath)
            let dir = url.deletingLastPathComponent().path
            let prefix = url.lastPathComponent
            return (dir, prefix)
        } else {
            // Relative path
            let url = URL(fileURLWithPath: workingDir).appendingPathComponent(partial)
            let dir = url.deletingLastPathComponent().path
            let prefix = url.lastPathComponent
            return (dir, prefix)
        }
    }

    private func getMatchingPaths(in directory: String, prefix: String, forCommand command: String) -> [(path: String, isDir: Bool)] {
        let fileManager = FileManager.default
        var results: [(path: String, isDir: Bool)] = []

        guard fileManager.fileExists(atPath: directory) else { return [] }

        do {
            let contents = try fileManager.contentsOfDirectory(atPath: directory)
            let filtered = prefix.isEmpty ? contents : contents.filter { $0.hasPrefix(prefix) }

            for item in filtered {
                let fullPath = URL(fileURLWithPath: directory).appendingPathComponent(item).path
                var isDirectory: ObjCBool = false

                if fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory) {
                    // For 'cd', only show directories
                    if command == "cd" && !isDirectory.boolValue {
                        continue
                    }

                    // Skip hidden files unless prefix starts with dot
                    if item.hasPrefix(".") && !prefix.hasPrefix(".") {
                        continue
                    }

                    // Create relative or clean path for display
                    let displayPath = item.contains(" ") ? "\"\(item)\"" : item
                    results.append((displayPath, isDirectory.boolValue))
                }
            }

            // Sort: directories first, then alphabetically
            results.sort { (a, b) in
                if a.isDir != b.isDir {
                    return a.isDir
                }
                return a.path.localizedCaseInsensitiveCompare(b.path) == .orderedAscending
            }

        } catch {
            print("❌ Error reading directory \(directory): \(error)")
        }

        return results
    }
}
