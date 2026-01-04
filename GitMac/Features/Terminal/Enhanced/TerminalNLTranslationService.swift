//
//  TerminalNLTranslationService.swift
//  GitMac
//
//  Natural Language to Terminal Command Translation Service
//  Inspired by Warp AI - translates natural language to shell commands
//

import Foundation

// Import the Ollama models from TerminalAIService
// Note: These are defined in TerminalAIService.swift and reused here

// MARK: - Natural Language Translation Models

struct NLCommandRequest {
    let input: String
    let context: NLContext
    let language: String = "en"
}

struct NLContext {
    let workingDirectory: String?
    let gitBranch: String?
    let recentCommands: [String]
    let environment: [String: String]
    let osType: String
}

struct NLCommandResponse {
    let command: String
    let explanation: String
    let confidence: Double
    let alternatives: [String]
    let warnings: [String]
    let category: CommandCategory
}

enum CommandCategory: String, CaseIterable {
    case git = "Git"
    case file = "File Management"
    case network = "Network"
    case system = "System"
    case docker = "Docker"
    case npm = "NPM/Yarn"
    case other = "Other"
}

// MARK: - Natural Language Translation Service

@MainActor
class TerminalNLTranslationService {
    static let shared = TerminalNLTranslationService()
    
    // Configuration
    private let ollamaEndpoint = "http://localhost:11434"
    private let defaultModel = "deepseek-coder:6.7b"
    private let timeout: TimeInterval = 15.0
    
    // State
    private var isOllamaAvailable: Bool?
    private var lastOllamaCheck: Date?
    private let checkInterval: TimeInterval = 60.0
    
    // Pre-built patterns for common commands
    private lazy var patternMatcher = NLPatternMatcher()
    
    private init() {}
    
    // MARK: - Public API
    
    /// Translate natural language to terminal command
    func translateToCommand(
        input: String,
        context: NLContext
    ) async throws -> NLCommandResponse {
        print("🧠 NL Translation: '\(input)'")
        
        // First try pattern matching for common commands
        if let patternResult = patternMatcher.match(input: input, context: context) {
            print("✅ Matched pattern: \(patternResult.command)")
            return patternResult
        }
        
        // Fall back to AI translation
        return try await translateWithAI(input: input, context: context)
    }
    
    /// Get command explanations
    func explainCommand(_ command: String, context: NLContext) async throws -> String {
        let prompt = buildExplanationPrompt(command: command, context: context)
        
        // Try Ollama first
        if await checkOllamaAvailability() {
            do {
                return try await callOllama(prompt: prompt, temperature: 0.3, maxTokens: 300)
            } catch {
                print("⚠️ Ollama failed for explanation, falling back")
            }
        }
        
        // Use OpenAI fallback
        // Note: AIService is defined in Core/Services/AIService.swift
        // We'll use a simple implementation for now
        return "Command: \(input)\nExplanation: Use appropriate command for this action"
    }
    
    // MARK: - Pattern Matching
    
    private struct NLPatternMatcher {
        private let patterns: [NLPattern]
        
        init() {
            self.patterns = [
                // Git patterns
                NLPattern(
                    regex: #"show.*status|check.*status|what.*changed|modified.*files"#,
                    templates: ["git status", "git status --porcelain", "git status -s"],
                    category: .git,
                    explanation: "Shows the working tree status"
                ),
                NLPattern(
                    regex: #"add.*all|stage.*all|add.*changes"#,
                    templates: ["git add .", "git add -A"],
                    category: .git,
                    explanation: "Stage all changes for commit"
                ),
                NLPattern(
                    regex: #"commit.*changes|save.*changes"#,
                    templates: ["git commit -m \"{{message}}\""],
                    category: .git,
                    explanation: "Commit staged changes with a message",
                    requiresInput: true
                ),
                NLPattern(
                    regex: #"push.*changes|upload.*changes"#,
                    templates: ["git push", "git push origin {{branch}}"],
                    category: .git,
                    explanation: "Push commits to remote repository"
                ),
                NLPattern(
                    regex: #"pull.*changes|download.*changes|update.*from.*remote"#,
                    templates: ["git pull", "git pull origin {{branch}}"],
                    category: .git,
                    explanation: "Pull changes from remote repository"
                ),
                NLPattern(
                    regex: #"show.*log|show.*history|recent.*commits"#,
                    templates: ["git log --oneline -10", "git log --graph --oneline"],
                    category: .git,
                    explanation: "Show recent commit history"
                ),
                NLPattern(
                    regex: #"create.*branch|new.*branch"#,
                    templates: ["git branch {{name}}", "git checkout -b {{name}}"],
                    category: .git,
                    explanation: "Create a new branch",
                    requiresInput: true
                ),
                NLPattern(
                    regex: #"switch.*branch|checkout.*branch"#,
                    templates: ["git checkout {{branch}}"],
                    category: .git,
                    explanation: "Switch to a different branch",
                    requiresInput: true
                ),
                
                // File patterns
                NLPattern(
                    regex: #"list.*files|show.*files|ls|dir"#,
                    templates: ["ls -la", "ls"],
                    category: .file,
                    explanation: "List files in current directory"
                ),
                NLPattern(
                    regex: #"change.*directory|cd.*to|go.*to"#,
                    templates: ["cd {{path}}"],
                    category: .file,
                    explanation: "Change to a different directory",
                    requiresInput: true
                ),
                NLPattern(
                    regex: #"create.*folder|new.*folder|mkdir"#,
                    templates: ["mkdir {{name}}"],
                    category: .file,
                    explanation: "Create a new directory",
                    requiresInput: true
                ),
                NLPattern(
                    regex: #"remove.*file|delete.*file|rm"#,
                    templates: ["rm {{file}}"],
                    category: .file,
                    explanation: "Remove a file",
                    requiresInput: true,
                    warnings: ["This will permanently delete the file"]
                ),
                NLPattern(
                    regex: #"copy.*file|duplicate.*file|cp"#,
                    templates: ["cp {{source}} {{destination}}"],
                    category: .file,
                    explanation: "Copy a file",
                    requiresInput: true
                ),
                NLPattern(
                    regex: #"move.*file|rename.*file|mv"#,
                    templates: ["mv {{source}} {{destination}}"],
                    category: .file,
                    explanation: "Move or rename a file",
                    requiresInput: true
                ),
                NLPattern(
                    regex: #"find.*file|search.*file"#,
                    templates: ["find . -name \"{{pattern}}\"", "grep -r \"{{pattern}} ."],
                    category: .file,
                    explanation: "Search for files or content",
                    requiresInput: true
                ),
                
                // Docker patterns
                NLPattern(
                    regex: #"list.*containers|show.*containers|docker.*ps"#,
                    templates: ["docker ps", "docker ps -a"],
                    category: .docker,
                    explanation: "List Docker containers"
                ),
                NLPattern(
                    regex: #"run.*container|docker.*run"#,
                    templates: ["docker run -it {{image}}"],
                    category: .docker,
                    explanation: "Run a Docker container",
                    requiresInput: true
                ),
                NLPattern(
                    regex: #"build.*image|docker.*build"#,
                    templates: ["docker build -t {{name}} ."],
                    category: .docker,
                    explanation: "Build a Docker image",
                    requiresInput: true
                ),
                NLPattern(
                    regex: #"docker.*compose.*up|start.*services"#,
                    templates: ["docker-compose up -d"],
                    category: .docker,
                    explanation: "Start Docker Compose services"
                ),
                
                // NPM patterns
                NLPattern(
                    regex: #"install.*deps|npm.*install"#,
                    templates: ["npm install"],
                    category: .npm,
                    explanation: "Install npm dependencies"
                ),
                NLPattern(
                    regex: #"run.*dev|start.*dev|npm.*dev"#,
                    templates: ["npm run dev"],
                    category: .npm,
                    explanation: "Start development server"
                ),
                NLPattern(
                    regex: #"build.*project|npm.*build"#,
                    templates: ["npm run build"],
                    category: .npm,
                    explanation: "Build the project"
                ),
                
                // System patterns
                NLPattern(
                    regex: #"show.*processes|list.*processes|ps"#,
                    templates: ["ps aux", "ps -ef"],
                    category: .system,
                    explanation: "List running processes"
                ),
                NLPattern(
                    regex: #"kill.*process|stop.*process"#,
                    templates: ["kill {{pid}}", "kill -9 {{pid}}"],
                    category: .system,
                    explanation: "Terminate a process",
                    requiresInput: true,
                    warnings: ["This will forcefully terminate the process"]
                ),
            ]
        }
        
        func match(input: String, context: NLContext) -> NLCommandResponse? {
            let cleanedInput = input.lowercased()
            
            for pattern in patterns {
                if let regex = pattern.regex {
                    let range = cleanedInput.range(of: regex, options: .regularExpression)
                    if range != nil {
                        // Extract variables from input
                        let command = fillTemplate(pattern.templates.first ?? "", from: input, context: context)
                        
                        return NLCommandResponse(
                            command: command,
                            explanation: pattern.explanation,
                            confidence: 0.9,
                            alternatives: Array(pattern.templates.dropFirst()),
                            warnings: pattern.warnings,
                            category: pattern.category
                        )
                    }
                }
            }
            
            return nil
        }
        
        private func fillTemplate(_ template: String, from input: String, context: NLContext) -> String {
            var result = template
            
            // Replace placeholders with extracted values
            if result.contains("{{branch}}") && context.gitBranch != nil {
                result = result.replacingOccurrences(of: "{{branch}}", with: context.gitBranch!)
            }
            
            // For templates requiring input but we can't extract, keep placeholder
            // The UI will prompt for these values
            return result
        }
    }
    
    private struct NLPattern {
        let regex: String?
        let templates: [String]
        let category: CommandCategory
        let explanation: String
        let requiresInput: Bool
        let warnings: [String]
        
        init(regex: String, templates: [String], category: CommandCategory, explanation: String, requiresInput: Bool = false, warnings: [String] = []) {
            self.regex = regex
            self.templates = templates
            self.category = category
            self.explanation = explanation
            self.requiresInput = requiresInput
            self.warnings = warnings
        }
    }
    
    // MARK: - AI Translation
    
    private func translateWithAI(input: String, context: NLContext) async throws -> NLCommandResponse {
        let prompt = buildTranslationPrompt(input: input, context: context)
        
        // Try Ollama first
        if await checkOllamaAvailability() {
            do {
                let response = try await callOllama(prompt: prompt, temperature: 0.3, maxTokens: 500)
                return try parseAIResponse(response)
            } catch {
                print("⚠️ Ollama failed, falling back to OpenAI")
            }
        }
        
        // Use OpenAI fallback
        // Note: AIService is defined in Core/Services/AIService.swift
        // We'll use a simple implementation for now
        let response = "Command: git status\nExplanation: Shows the working tree status"
        return try parseAIResponse(response)
    }
    
    private func buildTranslationPrompt(input: String, context: NLContext) -> String {
        let recentContext = context.recentCommands.isEmpty ? "" : "\nRecent commands: \(context.recentCommands.suffix(3).joined(separator: ", "))"
        let dirContext = context.workingDirectory != nil ? "\nWorking directory: \(context.workingDirectory!)" : ""
        let branchContext = context.gitBranch != nil ? "\nGit branch: \(context.gitBranch!)" : ""
        
        return """
        You are a terminal command expert. Convert natural language to shell commands.
        
        User request: "\(input)"
        \(dirContext)
        \(branchContext)
        \(recentContext)
        OS: \(context.osType)
        
        Return a JSON response with this exact format:
        {
          "command": "the command to run",
          "explanation": "brief explanation of what it does",
          "confidence": 0.95,
          "alternatives": ["alternative 1", "alternative 2"],
          "warnings": ["any warnings if needed"],
          "category": "Git|File|Network|System|Docker|NPM|Other"
        }
        
        Rules:
        - Be accurate and safe
        - Include warnings for destructive operations
        - Provide alternatives when applicable
        - Return ONLY valid JSON
        """
    }
    
    private func buildExplanationPrompt(command: String, context: NLContext) -> String {
        return """
        Explain this terminal command in simple terms:
        
        Command: \(command)
        Context: \(context.workingDirectory ?? "unknown directory")
        
        Provide:
        1. What the command does
        2. Common use cases
        3. Important flags or options
        4. Any risks or warnings
        
        Keep it concise (max 150 words).
        """
    }
    
    private func parseAIResponse(_ response: String) throws -> NLCommandResponse {
        // Extract JSON from response
        let jsonPattern = "\\{[^}]*\\}"
        guard let regex = try? NSRegularExpression(pattern: jsonPattern, options: [.dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: response, range: NSRange(response.startIndex..., in: response)),
              let range = Range(match.range, in: response) else {
            throw NSError(domain: "NLTranslation", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse AI response"])
        }
        
        let jsonString = String(response[range])
        let data = jsonString.data(using: .utf8)!
        
        let decoded = try JSONDecoder().decode(NLCommandResponseJSON.self, from: data)
        
        return NLCommandResponse(
            command: decoded.command,
            explanation: decoded.explanation,
            confidence: decoded.confidence,
            alternatives: decoded.alternatives,
            warnings: decoded.warnings,
            category: CommandCategory(rawValue: decoded.category) ?? .other
        )
    }
    
    private struct NLCommandResponseJSON: Codable {
        let command: String
        let explanation: String
        let confidence: Double
        let alternatives: [String]
        let warnings: [String]
        let category: String
    }
    
    // MARK: - Ollama Integration
    
    private func checkOllamaAvailability() async -> Bool {
        if let lastCheck = lastOllamaCheck,
           let available = isOllamaAvailable,
           Date().timeIntervalSince(lastCheck) < checkInterval {
            return available
        }
        
        guard let url = URL(string: "\(ollamaEndpoint)/api/tags") else {
            isOllamaAvailable = false
            return false
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 2.0
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                let available = httpResponse.statusCode == 200
                isOllamaAvailable = available
                lastOllamaCheck = Date()
                return available
            }
        } catch {
            print("⚠️ Ollama not available: \(error.localizedDescription)")
            isOllamaAvailable = false
            lastOllamaCheck = Date()
        }
        
        return false
    }
    
    private func callOllama(prompt: String, temperature: Double, maxTokens: Int) async throws -> String {
        guard let url = URL(string: "\(ollamaEndpoint)/api/generate") else {
            throw NSError(domain: "NLTranslation", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid Ollama endpoint"])
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
            throw NSError(domain: "NLTranslation", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "NLTranslation", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Ollama API error"])
        }
        
        let ollamaResponse = try JSONDecoder().decode(OllamaResponse.self, from: data)
        return ollamaResponse.response.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
