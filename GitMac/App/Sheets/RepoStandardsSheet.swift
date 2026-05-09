import SwiftUI

struct RepoStandard: Identifiable {
    let id = UUID()
    let category: String
    let icon: String
    let title: String
    let description: String
    let action: String
    var applied: Bool = false
}

struct RepoStandardsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) var appState

    @State private var isAnalyzing = true
    @State private var standards: [RepoStandard] = []
    @State private var applyingId: UUID?

    private var repoPath: String {
        appState.currentRepository?.path ?? ""
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "wand.and.stars")
                    .foregroundStyle(AppTheme.accent)
                VStack(alignment: .leading) {
                    Text("Repo Standards")
                        .font(DesignTokens.Typography.title2)
                        .fontWeight(.semibold)
                    Text("AI-powered suggestions to keep your repo clean")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
            }
            .padding()

            Divider()

            if isAnalyzing {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Analyzing repository...")
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if standards.isEmpty {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                    Text("Repo looks great!")
                        .font(DesignTokens.Typography.title3)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: DesignTokens.Spacing.sm) {
                        ForEach(standards) { standard in
                            HStack(spacing: DesignTokens.Spacing.md) {
                                Image(systemName: standard.icon)
                                    .foregroundStyle(categoryColor(standard.category))
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(standard.category.uppercased())
                                            .font(.caption2.bold())
                                            .foregroundStyle(categoryColor(standard.category))
                                        Text(standard.title)
                                            .font(DesignTokens.Typography.headline)
                                    }
                                    Text(standard.description)
                                        .font(DesignTokens.Typography.caption)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }

                                Spacer()

                                if standard.applied {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                } else if applyingId == standard.id {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Button(standard.action) {
                                        Task { await applyStandard(standard) }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                            .padding(DesignTokens.Spacing.md)
                            .background(AppTheme.backgroundSecondary.opacity(0.3))
                            .clipShape(.rect(cornerRadius: 8))
                        }
                    }
                    .padding()
                }
            }

            Divider()

            HStack {
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                let remaining = standards.filter { !$0.applied }
                if !remaining.isEmpty {
                    Button("Apply All (\(remaining.count))") {
                        Task { await applyAll() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .frame(width: 600, height: 500)
        .task { await analyze() }
    }

    private func analyze() async {
        guard !repoPath.isEmpty else { isAnalyzing = false; return }
        let shell = ShellExecutor.shared
        var found: [RepoStandard] = []

        let gitignorePath = "\(repoPath)/.gitignore"
        let gitignoreExists = FileManager.default.fileExists(atPath: gitignorePath)
        let gitignoreContent = (try? String(contentsOfFile: gitignorePath, encoding: .utf8)) ?? ""

        if !gitignoreExists {
            found.append(RepoStandard(
                category: "gitignore", icon: "eye.slash.circle.fill",
                title: "Create .gitignore",
                description: "No .gitignore found. AI will generate one based on your project type.",
                action: "Create"
            ))
        }

        let untrackedResult = await shell.execute(
            "git", arguments: ["ls-files", "--others", "--exclude-standard"],
            workingDirectory: repoPath
        )
        let untracked = untrackedResult.stdout.components(separatedBy: "\n").filter { !$0.isEmpty }
        let suspiciousPatterns = [".DS_Store", "node_modules", ".env", "*.log", "Pods/", ".build/", "DerivedData", "*.xcuserstate", "Thumbs.db", "__pycache__"]
        let suspiciousFiles = untracked.filter { file in
            suspiciousPatterns.contains { pattern in
                if pattern.hasPrefix("*") { return file.hasSuffix(String(pattern.dropFirst())) }
                return file.contains(pattern)
            }
        }
        if !suspiciousFiles.isEmpty {
            let preview = suspiciousFiles.prefix(3).joined(separator: ", ")
            found.append(RepoStandard(
                category: "gitignore", icon: "eye.slash",
                title: "Add \(suspiciousFiles.count) pattern(s) to .gitignore",
                description: "Found: \(preview)\(suspiciousFiles.count > 3 ? " (+\(suspiciousFiles.count - 3) more)" : "")",
                action: "Add"
            ))
        }

        let rerereCheck = await shell.execute(
            "git", arguments: ["config", "--local", "rerere.enabled"],
            workingDirectory: repoPath
        )
        if rerereCheck.stdout.trimmingCharacters(in: .whitespacesAndNewlines) != "true" {
            found.append(RepoStandard(
                category: "config", icon: "arrow.triangle.2.circlepath.circle",
                title: "Enable rerere (reuse recorded resolutions)",
                description: "Automatically apply previously resolved merge conflicts.",
                action: "Enable"
            ))
        }

        let autocrlfCheck = await shell.execute(
            "git", arguments: ["config", "--local", "core.autocrlf"],
            workingDirectory: repoPath
        )
        if autocrlfCheck.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            found.append(RepoStandard(
                category: "config", icon: "text.alignleft",
                title: "Set core.autocrlf",
                description: "Normalize line endings to avoid cross-platform diffs.",
                action: "Set"
            ))
        }

        let hookPath = "\(repoPath)/.git/hooks/pre-commit"
        if !FileManager.default.fileExists(atPath: hookPath) {
            found.append(RepoStandard(
                category: "hooks", icon: "bolt.shield",
                title: "Add pre-commit hook",
                description: "Prevent commits to protected branches and enforce commit message format.",
                action: "Create"
            ))
        }

        if !gitignoreContent.contains(".env") && gitignoreExists {
            let envExists = FileManager.default.fileExists(atPath: "\(repoPath)/.env")
            if envExists {
                found.append(RepoStandard(
                    category: "security", icon: "lock.shield",
                    title: "Add .env to .gitignore",
                    description: "Environment files with secrets should never be committed.",
                    action: "Add"
                ))
            }
        }

        let lfsCheck = await shell.execute(
            "git", arguments: ["lfs", "status"],
            workingDirectory: repoPath
        )
        if !lfsCheck.isSuccess {
            let hasLargeFiles = untracked.contains { ext in
                [".zip", ".tar", ".gz", ".mp4", ".mov", ".psd", ".ai"].contains { ext.hasSuffix($0) }
            }
            if hasLargeFiles {
                found.append(RepoStandard(
                    category: "lfs", icon: "externaldrive.badge.plus",
                    title: "Consider Git LFS for large files",
                    description: "Large binary files detected. LFS keeps the repo fast.",
                    action: "Info"
                ))
            }
        }

        standards = found
        isAnalyzing = false
    }

    private func applyStandard(_ standard: RepoStandard) async {
        applyingId = standard.id
        defer { applyingId = nil }
        let shell = ShellExecutor.shared

        switch standard.category {
        case "gitignore":
            if standard.title.contains("Create") {
                await generateGitignore()
            } else {
                await addSuspiciousToGitignore()
            }

        case "config":
            if standard.title.contains("rerere") {
                _ = await shell.execute("git", arguments: ["config", "--local", "rerere.enabled", "true"], workingDirectory: repoPath)
                _ = await shell.execute("git", arguments: ["config", "--local", "rerere.autoupdate", "true"], workingDirectory: repoPath)
            } else if standard.title.contains("autocrlf") {
                _ = await shell.execute("git", arguments: ["config", "--local", "core.autocrlf", "input"], workingDirectory: repoPath)
            }

        case "hooks":
            let hook = """
            #!/bin/sh
            branch=$(git rev-parse --abbrev-ref HEAD)
            if [ "$branch" = "main" ] || [ "$branch" = "master" ]; then
                echo "Direct commits to $branch are blocked. Use a feature branch."
                exit 1
            fi
            """
            let hookPath = "\(repoPath)/.git/hooks/pre-commit"
            try? hook.write(toFile: hookPath, atomically: true, encoding: .utf8)
            _ = await shell.execute("chmod", arguments: ["+x", hookPath], workingDirectory: repoPath)

        case "security":
            appendToGitignore(".env\n.env.*\n")

        default:
            break
        }

        if let index = standards.firstIndex(where: { $0.id == standard.id }) {
            standards[index].applied = true
        }
        NotificationCenter.default.post(name: .repositoryDidRefresh, object: repoPath)
    }

    private func applyAll() async {
        for standard in standards where !standard.applied {
            await applyStandard(standard)
        }
    }

    private func generateGitignore() async {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: repoPath)) ?? []
        var projectType = "general"
        if files.contains(where: { $0.hasSuffix(".xcodeproj") || $0.hasSuffix(".xcworkspace") }) {
            projectType = "swift/xcode"
        } else if files.contains("package.json") {
            projectType = "node/javascript"
        } else if files.contains("composer.json") {
            projectType = "php"
        } else if files.contains("requirements.txt") || files.contains("pyproject.toml") {
            projectType = "python"
        }

        do {
            let prompt = "Generate a comprehensive .gitignore for a \(projectType) project. Only output the file content, no explanations."
            let content = try await AIService.shared.generateText(prompt: prompt)
            let cleaned = AIService.cleanAIResponse(content)
            try cleaned.write(toFile: "\(repoPath)/.gitignore", atomically: true, encoding: .utf8)
        } catch {
            let fallback = ".DS_Store\n*.log\n.env\nnode_modules/\n"
            try? fallback.write(toFile: "\(repoPath)/.gitignore", atomically: true, encoding: .utf8)
        }
    }

    private func addSuspiciousToGitignore() async {
        let shell = ShellExecutor.shared
        let result = await shell.execute(
            "git", arguments: ["ls-files", "--others", "--exclude-standard"],
            workingDirectory: repoPath
        )
        let patterns = [".DS_Store", "*.log", "*.xcuserstate", "Thumbs.db", "__pycache__/", ".build/", "DerivedData/"]
        let toAdd = patterns.filter { pattern in
            result.stdout.contains(pattern.replacingOccurrences(of: "*", with: ""))
        }
        if !toAdd.isEmpty {
            appendToGitignore(toAdd.joined(separator: "\n") + "\n")
        }
    }

    private func appendToGitignore(_ entry: String) {
        let path = "\(repoPath)/.gitignore"
        var content = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
        if !content.hasSuffix("\n") { content += "\n" }
        content += entry
        try? content.write(toFile: path, atomically: true, encoding: .utf8)
    }

    private func categoryColor(_ category: String) -> Color {
        switch category {
        case "gitignore": return .orange
        case "config": return .blue
        case "hooks": return .purple
        case "security": return .red
        case "lfs": return .cyan
        default: return AppTheme.accent
        }
    }
}
