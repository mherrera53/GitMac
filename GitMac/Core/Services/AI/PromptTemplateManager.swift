//
//  PromptTemplateManager.swift
//  GitMac
//
//  Configurable AI prompt templates for commits, PRs, and code analysis
//

import SwiftUI
import Combine

// MARK: - Prompt Template Types

enum PromptTemplateType: String, CaseIterable, Identifiable, Codable {
    case commitMessage = "commit_message"
    case prSummary = "pr_summary"
    case codeReview = "code_review"
    case codeExplanation = "code_explanation"
    case releaseNotes = "release_notes"
    case bugAnalysis = "bug_analysis"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .commitMessage: return "Commit Message"
        case .prSummary: return "PR Summary"
        case .codeReview: return "Code Review"
        case .codeExplanation: return "Code Explanation"
        case .releaseNotes: return "Release Notes"
        case .bugAnalysis: return "Bug Analysis"
        }
    }
    
    var icon: String {
        switch self {
        case .commitMessage: return "text.badge.checkmark"
        case .prSummary: return "arrow.triangle.pull"
        case .codeReview: return "eye.fill"
        case .codeExplanation: return "questionmark.circle"
        case .releaseNotes: return "doc.text.fill"
        case .bugAnalysis: return "ladybug.fill"
        }
    }
    
    var description: String {
        switch self {
        case .commitMessage:
            return "Template for generating semantic commit messages from staged changes"
        case .prSummary:
            return "Template for creating pull request descriptions and change summaries"
        case .codeReview:
            return "Template for analyzing code changes and providing review feedback"
        case .codeExplanation:
            return "Template for explaining selected code with context"
        case .releaseNotes:
            return "Template for generating release notes from commits"
        case .bugAnalysis:
            return "Template for detecting potential bugs and security issues"
        }
    }
    
    @MainActor var defaultTemplate: String {
        switch self {
        case .commitMessage:
            return PromptTemplateManager.defaultCommitTemplate
        case .prSummary:
            return PromptTemplateManager.defaultPRTemplate
        case .codeReview:
            return PromptTemplateManager.defaultCodeReviewTemplate
        case .codeExplanation:
            return PromptTemplateManager.defaultExplanationTemplate
        case .releaseNotes:
            return PromptTemplateManager.defaultReleaseNotesTemplate
        case .bugAnalysis:
            return PromptTemplateManager.defaultBugAnalysisTemplate
        }
    }
    
    var availableVariables: [PromptVariable] {
        switch self {
        case .commitMessage:
            return [.diff, .stagedFiles, .branchName, .repoName]
        case .prSummary:
            return [.diff, .commits, .branchName, .targetBranch, .repoName]
        case .codeReview:
            return [.diff, .filePath, .language, .branchName]
        case .codeExplanation:
            return [.selectedCode, .filePath, .language, .context]
        case .releaseNotes:
            return [.commits, .version, .previousVersion, .repoName]
        case .bugAnalysis:
            return [.diff, .filePath, .language]
        }
    }
}

// MARK: - Prompt Variables

enum PromptVariable: String, CaseIterable, Codable {
    case diff = "{{DIFF}}"
    case stagedFiles = "{{STAGED_FILES}}"
    case commits = "{{COMMITS}}"
    case branchName = "{{BRANCH_NAME}}"
    case targetBranch = "{{TARGET_BRANCH}}"
    case repoName = "{{REPO_NAME}}"
    case filePath = "{{FILE_PATH}}"
    case language = "{{LANGUAGE}}"
    case selectedCode = "{{SELECTED_CODE}}"
    case context = "{{CONTEXT}}"
    case version = "{{VERSION}}"
    case previousVersion = "{{PREVIOUS_VERSION}}"
    
    var displayName: String {
        switch self {
        case .diff: return "Diff Content"
        case .stagedFiles: return "Staged Files List"
        case .commits: return "Commit Messages"
        case .branchName: return "Current Branch"
        case .targetBranch: return "Target Branch"
        case .repoName: return "Repository Name"
        case .filePath: return "File Path"
        case .language: return "Programming Language"
        case .selectedCode: return "Selected Code"
        case .context: return "Surrounding Context"
        case .version: return "Version Number"
        case .previousVersion: return "Previous Version"
        }
    }
    
    var description: String {
        switch self {
        case .diff: return "The git diff output showing changes"
        case .stagedFiles: return "List of files that are staged for commit"
        case .commits: return "List of commit messages"
        case .branchName: return "Name of the current branch"
        case .targetBranch: return "Target branch for PR (usually main)"
        case .repoName: return "Name of the repository"
        case .filePath: return "Path to the current file"
        case .language: return "Detected programming language"
        case .selectedCode: return "The code that was selected by the user"
        case .context: return "Code surrounding the selection"
        case .version: return "Current version being released"
        case .previousVersion: return "Previous release version"
        }
    }
}

// MARK: - Prompt Template

struct PromptTemplate: Identifiable, Codable, Equatable {
    var id: String { type.rawValue + "_" + (name ?? "default") }
    let type: PromptTemplateType
    var name: String?
    var template: String
    var isDefault: Bool
    var createdAt: Date
    var modifiedAt: Date
    
    @MainActor
    init(type: PromptTemplateType, name: String? = nil, template: String? = nil) {
        self.type = type
        self.name = name
        self.template = template ?? type.defaultTemplate
        self.isDefault = template == nil
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
    
    mutating func updateTemplate(_ newTemplate: String) {
        self.template = newTemplate
        self.isDefault = false
        self.modifiedAt = Date()
    }
    
    func render(with variables: [PromptVariable: String]) -> String {
        var result = template
        for (variable, value) in variables {
            result = result.replacingOccurrences(of: variable.rawValue, with: value)
        }
        return result
    }
}

// MARK: - Prompt Template Manager

@MainActor
class PromptTemplateManager: ObservableObject {
    static let shared = PromptTemplateManager()
    
    @Published var templates: [PromptTemplate] = []
    
    private let userDefaultsKey = "com.gitmac.promptTemplates"
    
    private init() {
        loadTemplates()
    }
    
    // MARK: - CRUD Operations
    
    func getTemplate(for type: PromptTemplateType) -> PromptTemplate {
        if let template = templates.first(where: { $0.type == type }) {
            return template
        }
        // Return default if not customized
        return PromptTemplate(type: type)
    }
    
    func saveTemplate(_ template: PromptTemplate) {
        if let index = templates.firstIndex(where: { $0.type == template.type }) {
            templates[index] = template
        } else {
            templates.append(template)
        }
        persistTemplates()
    }
    
    func resetToDefault(type: PromptTemplateType) {
        if let index = templates.firstIndex(where: { $0.type == type }) {
            templates.remove(at: index)
        }
        persistTemplates()
    }
    
    func resetAllToDefault() {
        templates.removeAll()
        persistTemplates()
    }
    
    // MARK: - Persistence
    
    private func loadTemplates() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode([PromptTemplate].self, from: data) else {
            return
        }
        templates = decoded
    }
    
    private func persistTemplates() {
        guard let data = try? JSONEncoder().encode(templates) else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }
    
    // MARK: - Template Rendering
    
    func renderCommitPrompt(diff: String, stagedFiles: [String], branch: String, repo: String) -> String {
        let template = getTemplate(for: .commitMessage)
        return template.render(with: [
            .diff: String(diff.prefix(4000)),
            .stagedFiles: stagedFiles.joined(separator: "\n"),
            .branchName: branch,
            .repoName: repo
        ])
    }
    
    func renderPRPrompt(diff: String, commits: [String], branch: String, target: String, repo: String) -> String {
        let template = getTemplate(for: .prSummary)
        return template.render(with: [
            .diff: String(diff.prefix(3000)),
            .commits: commits.joined(separator: "\n"),
            .branchName: branch,
            .targetBranch: target,
            .repoName: repo
        ])
    }
    
    func renderCodeReviewPrompt(diff: String, file: String, language: String, branch: String) -> String {
        let template = getTemplate(for: .codeReview)
        return template.render(with: [
            .diff: String(diff.prefix(4000)),
            .filePath: file,
            .language: language,
            .branchName: branch
        ])
    }
    
    func renderExplanationPrompt(code: String, file: String, language: String, context: String) -> String {
        let template = getTemplate(for: .codeExplanation)
        return template.render(with: [
            .selectedCode: String(code.prefix(2000)),
            .filePath: file,
            .language: language,
            .context: String(context.prefix(1000))
        ])
    }
    
    func renderReleaseNotesPrompt(commits: [String], version: String, previousVersion: String, repo: String) -> String {
        let template = getTemplate(for: .releaseNotes)
        return template.render(with: [
            .commits: commits.joined(separator: "\n"),
            .version: version,
            .previousVersion: previousVersion,
            .repoName: repo
        ])
    }
    
    func renderBugAnalysisPrompt(diff: String, file: String, language: String) -> String {
        let template = getTemplate(for: .bugAnalysis)
        return template.render(with: [
            .diff: String(diff.prefix(4000)),
            .filePath: file,
            .language: language
        ])
    }
    
    // MARK: - Default Templates
    
    static let defaultCommitTemplate = """
    Analyze this git diff and generate a semantic commit message.
    
    Repository: {{REPO_NAME}}
    Branch: {{BRANCH_NAME}}
    
    Staged files:
    {{STAGED_FILES}}
    
    Rules:
    - Use conventional commits format: type(scope): description
    - Types: feat, fix, docs, style, refactor, test, chore
    - Subject line max 50 characters
    - Use imperative mood ("Add" not "Added")
    - Be specific about what changed
    
    Diff:
    ```
    {{DIFF}}
    ```
    
    Respond in JSON format:
    {
        "type": "feat|fix|docs|style|refactor|test|chore",
        "scope": "optional scope",
        "subject": "commit subject",
        "body": "optional body explaining the change"
    }
    """
    
    static let defaultPRTemplate = """
    Generate a pull request description for these changes.
    
    Repository: {{REPO_NAME}}
    Branch: {{BRANCH_NAME}} → {{TARGET_BRANCH}}
    
    Commits:
    {{COMMITS}}
    
    Diff:
    ```
    {{DIFF}}
    ```
    
    Generate:
    1. A clear, descriptive title
    2. A summary of what this PR accomplishes
    3. List of key changes (bullet points)
    4. Any breaking changes or migration notes
    5. Testing considerations
    
    Respond in JSON:
    {
        "title": "PR title",
        "summary": "What this PR does",
        "changes": ["change 1", "change 2"],
        "breaking_changes": ["if any"],
        "testing_notes": "How to test"
    }
    """
    
    static let defaultCodeReviewTemplate = """
    Review this code change for potential issues.
    
    File: {{FILE_PATH}}
    Language: {{LANGUAGE}}
    Branch: {{BRANCH_NAME}}
    
    Diff:
    ```{{LANGUAGE}}
    {{DIFF}}
    ```
    
    Analyze for:
    - Code quality issues
    - Potential bugs
    - Performance concerns
    - Security vulnerabilities
    - Best practices violations
    - Readability improvements
    
    Respond in JSON:
    {
        "overall_rating": "approve|request_changes|comment",
        "summary": "Brief review summary",
        "issues": [
            {
                "severity": "critical|warning|suggestion",
                "line": 0,
                "message": "Issue description",
                "suggestion": "How to fix"
            }
        ],
        "positive": ["Good things about the code"]
    }
    """
    
    static let defaultExplanationTemplate = """
    Explain this {{LANGUAGE}} code from {{FILE_PATH}}:
    
    ```{{LANGUAGE}}
    {{SELECTED_CODE}}
    ```
    
    Context:
    {{CONTEXT}}
    
    Provide:
    1. A brief summary of what this code does
    2. Key concepts used
    3. Potential issues or improvements
    4. Related documentation or resources
    
    Respond in JSON:
    {
        "summary": "What the code does",
        "concepts": ["concept1", "concept2"],
        "issues": ["potential issue"],
        "improvements": ["suggested improvement"],
        "complexity": "low|medium|high"
    }
    """
    
    static let defaultReleaseNotesTemplate = """
    Generate release notes for version {{VERSION}} of {{REPO_NAME}}.
    Previous version: {{PREVIOUS_VERSION}}
    
    Commits:
    {{COMMITS}}
    
    Group changes by:
    - ✨ Features (new functionality)
    - 🐛 Bug Fixes (corrected issues)
    - 🔧 Improvements (enhancements)
    - 📚 Documentation (doc updates)
    - ⚠️ Breaking Changes (incompatible changes)
    
    Respond in JSON:
    {
        "version": "{{VERSION}}",
        "highlights": ["key highlight"],
        "features": ["new feature"],
        "fixes": ["bug fix"],
        "improvements": ["improvement"],
        "breaking": ["breaking change"],
        "documentation": ["doc update"]
    }
    """
    
    static let defaultBugAnalysisTemplate = """
    Analyze this diff for potential bugs and security issues.
    
    File: {{FILE_PATH}}
    Language: {{LANGUAGE}}
    
    ```diff
    {{DIFF}}
    ```
    
    Look for:
    - Security vulnerabilities (SQL injection, XSS, etc.)
    - Memory leaks
    - Race conditions
    - Null pointer exceptions
    - Resource leaks
    - Missing error handling
    - Logic errors
    
    Respond in JSON:
    {
        "issues": [
            {
                "severity": "critical|warning|info",
                "type": "security|performance|bug|style",
                "line": 0,
                "message": "description",
                "suggestion": "how to fix"
            }
        ]
    }
    """
}

// MARK: - Prompt Template Editor View

struct PromptTemplateEditorView: View {
    @StateObject private var manager = PromptTemplateManager.shared
    @State private var selectedType: PromptTemplateType = .commitMessage
    @State private var editingTemplate: String = ""
    @State private var hasChanges = false
    
    var body: some View {
        HSplitView {
            // Template type list
            VStack(alignment: .leading, spacing: 0) {
                Text("Prompt Templates")
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
                    .padding()
                
                Divider()
                
                List(PromptTemplateType.allCases, selection: $selectedType) { type in
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Image(systemName: type.icon)
                            .foregroundColor(AppTheme.accent)
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(type.displayName)
                                .font(.subheadline)
                                .foregroundColor(AppTheme.textPrimary)
                            
                            if !manager.getTemplate(for: type).isDefault {
                                Text("Customized")
                                    .font(.caption2)
                                    .foregroundColor(AppTheme.accent)
                            }
                        }
                    }
                    .tag(type)
                }
            }
            .frame(width: 220)
            .background(AppTheme.backgroundSecondary)
            
            // Template editor
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedType.displayName)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.textPrimary)
                        
                        Text(selectedType.description)
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    
                    Spacer()
                    
                    if hasChanges {
                        Button("Save") {
                            saveTemplate()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    Button("Reset to Default") {
                        resetTemplate()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                
                Divider()
                
                // Variables reference
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Text("Variables:")
                            .font(.caption)
                            .foregroundColor(AppTheme.textMuted)
                        
                        ForEach(selectedType.availableVariables, id: \.self) { variable in
                            Button {
                                insertVariable(variable)
                            } label: {
                                Text(variable.rawValue)
                                    .font(.caption.monospaced())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(AppTheme.accent.opacity(0.2))
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                            .help(variable.description)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, DesignTokens.Spacing.sm)
                }
                .background(AppTheme.backgroundTertiary)
                
                // Text editor
                TextEditor(text: $editingTemplate)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .background(AppTheme.background)
                    .padding()
            }
            .background(AppTheme.background)
        }
        .frame(minWidth: 800, minHeight: 500)
        .onChange(of: selectedType) { _, newType in
            loadTemplate(for: newType)
        }
        .onChange(of: editingTemplate) { _, _ in
            hasChanges = editingTemplate != manager.getTemplate(for: selectedType).template
        }
        .onAppear {
            loadTemplate(for: selectedType)
        }
    }
    
    private func loadTemplate(for type: PromptTemplateType) {
        editingTemplate = manager.getTemplate(for: type).template
        hasChanges = false
    }
    
    private func saveTemplate() {
        var template = manager.getTemplate(for: selectedType)
        template.updateTemplate(editingTemplate)
        manager.saveTemplate(template)
        hasChanges = false
    }
    
    private func resetTemplate() {
        manager.resetToDefault(type: selectedType)
        loadTemplate(for: selectedType)
    }
    
    private func insertVariable(_ variable: PromptVariable) {
        editingTemplate += variable.rawValue
    }
}

// MARK: - Preview

#Preview("Prompt Template Editor") {
    PromptTemplateEditorView()
        .frame(width: 900, height: 600)
}
