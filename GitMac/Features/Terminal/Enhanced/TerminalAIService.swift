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
                aiResponse = try await callOpenAI(prompt: prompt)
                print("✅ Got response from OpenAI")
            } catch {
                print("❌ OpenAI also failed: \(error.localizedDescription)")
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
        let lowercasedInput = input.lowercased()
        var suggestions: [AICommandSuggestion] = []

        // Git command suggestions
        if lowercasedInput.starts(with: "g") || lowercasedInput.contains("git") {
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

            if lowercasedInput.contains("p") || lowercasedInput.contains("push") {
                suggestions.append(AICommandSuggestion(
                    command: "git push",
                    description: "Push commits to remote",
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
        if lowercasedInput.contains("docker") {
            suggestions.append(AICommandSuggestion(
                command: "docker ps",
                description: "List running containers",
                confidence: 0.70,
                isFromAI: false,
                category: "Docker"
            ))

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

        print("💡 TerminalAIService: Returning \(suggestions.count) static suggestions")
        return suggestions
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
}
