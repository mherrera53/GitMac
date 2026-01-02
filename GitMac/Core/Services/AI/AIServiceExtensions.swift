//
//  AIServiceExtensions.swift
//  GitMac
//
//  Extended AI capabilities for commits, PRs, code analysis
//

import Foundation

// MARK: - AI Service Extensions

extension AIService {
    
    // MARK: - Smart Commit Message Generation
    
    /// Generate a semantic commit message from staged diff
    func generateSmartCommitMessage(
        diff: String,
        includeBody: Bool = false
    ) async throws -> SmartCommitSuggestion {
        
        let prompt = """
        Analyze this git diff and generate a conventional commit message.
        
        Rules:
        - Subject line max 50 characters
        - Use imperative mood ("Add" not "Added")
        - Be specific about what changed
        - Format: type(scope): description
        \(includeBody ? "- Include a body explaining WHY the change was made" : "- Subject line only, no body")
        
        Diff:
        ```
        \(diff.prefix(4000))
        ```
        
        Respond with a single commit message, no JSON, just the message.
        """
        
        let response = try await generateCommitMessage(diff: diff, style: .conventional)
        return SmartCommitSuggestion(
            type: extractCommitType(from: response),
            subject: response,
            body: nil
        )
    }
    
    /// Generate multiple commit message options
    func generateCommitOptions(diff: String, count: Int = 3) async throws -> [SmartCommitSuggestion] {
        var options: [SmartCommitSuggestion] = []
        
        for style in [CommitStyle.conventional, .simple, .detailed].prefix(count) {
            let message = try await generateCommitMessage(diff: diff, style: style)
            options.append(SmartCommitSuggestion(
                type: extractCommitType(from: message),
                subject: message,
                body: nil
            ))
        }
        
        return options
    }
    
    private func extractCommitType(from message: String) -> String {
        let types = ["feat", "fix", "docs", "style", "refactor", "test", "chore"]
        for type in types {
            if message.lowercased().hasPrefix(type) {
                return type
            }
        }
        return "chore"
    }
    
    // MARK: - PR Summary Generation
    
    /// Generate a pull request summary from commits and diff
    func generatePRSummary(
        commits: [String],
        diff: String,
        template: PRSummaryTemplate = .default
    ) async throws -> PRSummaryResult {
        
        let commitsList = commits.prefix(20).joined(separator: "\n")
        let diffPreview = String(diff.prefix(3000))
        
        // Use the existing commit message generation with a custom prompt
        let prompt = """
        Generate a pull request description.
        
        Commits:
        \(commitsList)
        
        Diff preview:
        \(diffPreview)
        
        Provide a title and summary.
        """
        
        // For now, use the commit message as a basis
        let response = try await generateCommitMessage(diff: diff, style: .detailed)
        
        return PRSummaryResult(
            title: response.components(separatedBy: "\n").first ?? "Pull Request",
            summary: response,
            changes: commits.map { String($0.prefix(70)) },
            breakingChanges: [],
            testingNotes: nil
        )
    }
    
    // MARK: - Code Explanation
    
    /// Explain selected code with context
    func explainCode(
        selection: String,
        filePath: String,
        language: String
    ) async throws -> CodeExplanationResult {
        
        // Use a modified prompt based on the code
        let simplePrompt = "Explain: \(String(selection.prefix(500)))"
        let response = try await generateCommitMessage(diff: simplePrompt, style: .detailed)
        
        return CodeExplanationResult(
            summary: response,
            concepts: [],
            issues: [],
            improvements: [],
            complexity: "medium"
        )
    }
    
    // MARK: - Diff Analysis
    
    /// Analyze diff for potential issues
    func analyzeDiffForIssues(diff: String) async throws -> [CodeIssueResult] {
        // Simple analysis - could be enhanced with AI
        var issues: [CodeIssueResult] = []
        
        // Check for common patterns
        if diff.contains("TODO") || diff.contains("FIXME") {
            issues.append(CodeIssueResult(
                severity: .info,
                type: "todo",
                file: nil,
                line: nil,
                message: "Contains TODO/FIXME comments",
                suggestion: "Consider addressing before merging"
            ))
        }
        
        if diff.contains("console.log") || diff.contains("print(") {
            issues.append(CodeIssueResult(
                severity: .warning,
                type: "debug",
                file: nil,
                line: nil,
                message: "Contains debug statements",
                suggestion: "Remove debug output before production"
            ))
        }
        
        return issues
    }
    
    // MARK: - Release Notes Generation
    
    /// Generate release notes from commit range
    func generateReleaseNotes(
        commits: [String],
        version: String
    ) async throws -> ReleaseNotesResult {
        
        var features: [String] = []
        var fixes: [String] = []
        var improvements: [String] = []
        
        for commit in commits {
            let lower = commit.lowercased()
            if lower.contains("feat") || lower.contains("add") {
                features.append(commit)
            } else if lower.contains("fix") || lower.contains("bug") {
                fixes.append(commit)
            } else {
                improvements.append(commit)
            }
        }
        
        return ReleaseNotesResult(
            version: version,
            highlights: features.prefix(3).map { String($0) },
            features: features,
            fixes: fixes,
            improvements: improvements,
            breakingChanges: [],
            documentation: []
        )
    }
}

// MARK: - Supporting Types

struct SmartCommitSuggestion: Identifiable {
    let id = UUID()
    let type: String
    let subject: String
    let body: String?
    
    var formattedMessage: String {
        subject
    }
    
    var fullMessage: String {
        if let body = body {
            return "\(subject)\n\n\(body)"
        }
        return subject
    }
}

enum PRSummaryTemplate: String {
    case `default` = "default"
    case minimal = "minimal"
    case detailed = "detailed"
}

struct PRSummaryResult {
    let title: String
    let summary: String
    let changes: [String]
    let breakingChanges: [String]
    let testingNotes: String?
    
    var markdownDescription: String {
        var md = "## Summary\n\n\(summary)\n\n"
        
        if !changes.isEmpty {
            md += "## Changes\n\n"
            for change in changes {
                md += "- \(change)\n"
            }
            md += "\n"
        }
        
        if !breakingChanges.isEmpty {
            md += "## ⚠️ Breaking Changes\n\n"
            for breaking in breakingChanges {
                md += "- \(breaking)\n"
            }
            md += "\n"
        }
        
        if let notes = testingNotes {
            md += "## Testing\n\n\(notes)\n"
        }
        
        return md
    }
}

struct CodeExplanationResult {
    let summary: String
    let concepts: [String]
    let issues: [String]
    let improvements: [String]
    let complexity: String
}

struct CodeIssueResult: Identifiable {
    let id = UUID()
    let severity: Severity
    let type: String
    let file: String?
    let line: Int?
    let message: String
    let suggestion: String?
    
    enum Severity: String {
        case critical = "critical"
        case warning = "warning"
        case info = "info"
    }
}

struct ReleaseNotesResult {
    let version: String
    let highlights: [String]
    let features: [String]
    let fixes: [String]
    let improvements: [String]
    let breakingChanges: [String]
    let documentation: [String]
    
    var markdown: String {
        var md = "# Release Notes - v\(version)\n\n"
        
        if !highlights.isEmpty {
            md += "## 🎯 Highlights\n\n"
            for item in highlights { md += "- \(item)\n" }
            md += "\n"
        }
        
        if !features.isEmpty {
            md += "## ✨ Features\n\n"
            for item in features { md += "- \(item)\n" }
            md += "\n"
        }
        
        if !fixes.isEmpty {
            md += "## 🐛 Bug Fixes\n\n"
            for item in fixes { md += "- \(item)\n" }
            md += "\n"
        }
        
        if !improvements.isEmpty {
            md += "## 🔧 Improvements\n\n"
            for item in improvements { md += "- \(item)\n" }
            md += "\n"
        }
        
        if !breakingChanges.isEmpty {
            md += "## ⚠️ Breaking Changes\n\n"
            for item in breakingChanges { md += "- \(item)\n" }
            md += "\n"
        }
        
        return md
    }
}
