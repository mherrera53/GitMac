import Foundation

@MainActor
final class BranchNamingSuggestionService {
    private let aiService = AIService.shared
    
    func suggestBranchNames(context: BranchContext) async -> [BranchSuggestion] {
        var suggestions: [BranchSuggestion] = []
        
        let detectedType = detectBranchType(context: context)
        
        if await aiService.isAvailable() {
            suggestions = await generateAISuggestions(context: context, detectedType: detectedType)
        }
        
        if suggestions.isEmpty {
            suggestions = generateHeuristicSuggestions(context: context, detectedType: detectedType)
        }
        
        return Array(suggestions.prefix(5))
    }
    
    private func generateAISuggestions(context: BranchContext, detectedType: BranchType) async -> [BranchSuggestion] {
        do {
            let commitMessages = context.recentCommits.map { $0.message }.joined(separator: "\n")
            let filesContext = context.modifiedFiles.prefix(10).joined(separator: ", ")
            
            let prompt = """
            Generate 5 git branch names based on this context:
            
            Current branch: \(context.currentBranchName ?? "main")
            Base branch: \(context.baseBranch)
            Recent commits:
            \(commitMessages)
            
            Modified files: \(filesContext)
            
            Team conventions: \(context.teamConventions.joined(separator: ", "))
            
            Rules:
            1. Follow team conventions (use prefixes like \(context.teamConventions.joined(separator: ", ")))
            2. Use lowercase with hyphens (kebab-case)
            3. Be concise but descriptive (2-4 words)
            4. Focus on the MAIN change/feature being worked on
            5. Avoid generic names like "fix-bug" or "update-code"
            
            Return ONLY the branch names, one per line, without explanations.
            """
            
            let response = try await aiService.generateText(prompt: prompt)
            
            return parseBranchNamesFromAI(response: response, detectedType: detectedType, context: context)
        } catch {
            Logger.debug("❌ AI suggestion failed: \(error)")
            return []
        }
    }
    
    private func parseBranchNamesFromAI(response: String, detectedType: BranchType, context: BranchContext) -> [BranchSuggestion] {
        let lines = response.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        return lines.enumerated().compactMap { index, line in
            var branchName = line
                .replacingOccurrences(of: "^[0-9]+\\.\\s*", with: "", options: .regularExpression)
                .replacingOccurrences(of: "^-\\s*", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            
            if !branchName.contains("/") {
                branchName = "\(detectedType.prefix)\(branchName)"
            }
            
            let confidence: Float = 0.9 - (Float(index) * 0.1)
            
            return BranchSuggestion(
                name: branchName,
                type: detectedType,
                reasoning: "AI-generated based on recent commits and file changes",
                confidence: max(confidence, 0.5)
            )
        }
    }
    
    private func generateHeuristicSuggestions(context: BranchContext, detectedType: BranchType) -> [BranchSuggestion] {
        var suggestions: [BranchSuggestion] = []
        
        let keywords = extractKeywords(context: context)
        
        for (index, keyword) in keywords.prefix(3).enumerated() {
            let branchName = "\(detectedType.prefix)\(keyword)"
            let confidence: Float = 0.7 - (Float(index) * 0.15)
            
            suggestions.append(BranchSuggestion(
                name: branchName,
                type: detectedType,
                reasoning: "Based on commit keywords",
                confidence: max(confidence, 0.4)
            ))
        }
        
        if suggestions.isEmpty {
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .none)
            suggestions.append(BranchSuggestion(
                name: "\(detectedType.prefix)new-changes",
                type: detectedType,
                reasoning: "Generic branch name",
                confidence: 0.3
            ))
        }
        
        return suggestions
    }
    
    private func detectBranchType(context: BranchContext) -> BranchType {
        let commitMessages = context.recentCommits.map { $0.message.lowercased() }.joined(separator: " ")
        let files = context.modifiedFiles.map { $0.lowercased() }.joined(separator: " ")
        let combined = commitMessages + " " + files
        
        if combined.contains("fix") || combined.contains("bug") || combined.contains("issue") {
            return .bugfix
        }
        
        if combined.contains("hotfix") || combined.contains("critical") || combined.contains("urgent") {
            return .hotfix
        }
        
        if combined.contains("release") || combined.contains("version") {
            return .release
        }
        
        if combined.contains("test") || combined.contains("spec") {
            return .test
        }
        
        if combined.contains("refactor") || combined.contains("cleanup") {
            return .refactor
        }
        
        if combined.contains("docs") || combined.contains("documentation") {
            return .docs
        }
        
        if context.currentBranchName == "main" || context.currentBranchName == "master" {
            return .feature
        }
        
        return .feature
    }
    
    private func extractKeywords(context: BranchContext) -> [String] {
        var keywords: [String] = []
        
        let stopWords = Set(["the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by", "from", "up", "about", "into", "through", "add", "update", "remove", "fix", "change"])
        
        for commit in context.recentCommits.prefix(5) {
            let words = commit.message
                .lowercased()
                .components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .punctuationCharacters) }
                .filter { !$0.isEmpty && $0.count > 2 && !stopWords.contains($0) }
            
            keywords.append(contentsOf: words)
        }
        
        let fileKeywords = context.modifiedFiles.compactMap { file -> String? in
            let components = file.components(separatedBy: "/")
            return components.last?.components(separatedBy: ".").first
        }
        
        keywords.append(contentsOf: fileKeywords)
        
        let frequency = keywords.reduce(into: [:]) { counts, word in
            counts[word, default: 0] += 1
        }
        
        return frequency.sorted { $0.value > $1.value }
            .prefix(10)
            .map { $0.key.replacingOccurrences(of: "_", with: "-") }
    }
}

struct BranchContext {
    let repoPath: String
    let baseBranch: String
    let recentCommits: [Commit]
    let modifiedFiles: [String]
    let currentBranchName: String?
    let teamConventions: [String]
    
    init(
        repoPath: String,
        baseBranch: String,
        recentCommits: [Commit] = [],
        modifiedFiles: [String] = [],
        currentBranchName: String? = nil,
        teamConventions: [String] = ["feature/", "bugfix/", "hotfix/"]
    ) {
        self.repoPath = repoPath
        self.baseBranch = baseBranch
        self.recentCommits = recentCommits
        self.modifiedFiles = modifiedFiles
        self.currentBranchName = currentBranchName
        self.teamConventions = teamConventions
    }
}

struct BranchSuggestion: Identifiable {
    let id = UUID()
    let name: String
    let type: BranchType
    let reasoning: String
    let confidence: Float
    
    var icon: String {
        type.icon
    }
    
    var color: String {
        type.color
    }
}

enum BranchType {
    case feature
    case bugfix
    case hotfix
    case release
    case test
    case refactor
    case docs
    
    var prefix: String {
        switch self {
        case .feature: return "feature/"
        case .bugfix: return "bugfix/"
        case .hotfix: return "hotfix/"
        case .release: return "release/"
        case .test: return "test/"
        case .refactor: return "refactor/"
        case .docs: return "docs/"
        }
    }
    
    var icon: String {
        switch self {
        case .feature: return "sparkles"
        case .bugfix: return "ladybug"
        case .hotfix: return "flame"
        case .release: return "tag"
        case .test: return "testtube.2"
        case .refactor: return "arrow.triangle.2.circlepath"
        case .docs: return "doc.text"
        }
    }
    
    var color: String {
        switch self {
        case .feature: return "blue"
        case .bugfix: return "orange"
        case .hotfix: return "red"
        case .release: return "green"
        case .test: return "purple"
        case .refactor: return "cyan"
        case .docs: return "gray"
        }
    }
}
