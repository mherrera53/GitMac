import SwiftUI

struct AIQuickReviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) var appState

    let pr: GitHubPullRequest
    @ObservedObject var viewModel: PRListViewModel

    @State private var isAnalyzing = false
    @State private var reviewResult = ""
    @State private var issues: [ReviewIssue] = []
    @State private var isPostingComment = false
    @State private var commentPosted = false

    struct ReviewIssue: Identifiable {
        let id = UUID()
        let severity: String
        let file: String
        let description: String
        var selected: Bool = true
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(AppTheme.accent)
                VStack(alignment: .leading) {
                    Text("AI Review: #\(pr.number)")
                        .font(DesignTokens.Typography.title3)
                        .fontWeight(.semibold)
                    Text(pr.title)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding()

            Divider()

            if isAnalyzing {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Analyzing \(pr.changedFiles) file(s)...")
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if issues.isEmpty && reviewResult.isEmpty {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                    Text("No issues found")
                        .font(DesignTokens.Typography.title3)
                    Text("The PR looks good based on AI analysis.")
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                        if !reviewResult.isEmpty {
                            Text("Summary")
                                .font(DesignTokens.Typography.headline)
                                .padding(.horizontal)
                            Text(reviewResult)
                                .font(DesignTokens.Typography.callout)
                                .foregroundStyle(AppTheme.textSecondary)
                                .padding(.horizontal)
                                .padding(.bottom, DesignTokens.Spacing.sm)
                        }

                        if !issues.isEmpty {
                            Text("Issues (\(issues.count))")
                                .font(DesignTokens.Typography.headline)
                                .padding(.horizontal)

                            ForEach(Array(issues.enumerated()), id: \.element.id) { index, issue in
                                HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
                                    Toggle("", isOn: $issues[index].selected)
                                        .labelsHidden()

                                    Image(systemName: severityIcon(issue.severity))
                                        .foregroundStyle(severityColor(issue.severity))
                                        .frame(width: 16)

                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack {
                                            Text(issue.severity.uppercased())
                                                .font(.caption2.bold())
                                                .foregroundStyle(severityColor(issue.severity))
                                            Text(issue.file)
                                                .font(DesignTokens.Typography.caption)
                                                .foregroundStyle(AppTheme.textMuted)
                                        }
                                        Text(issue.description)
                                            .font(DesignTokens.Typography.callout)
                                            .foregroundStyle(AppTheme.textPrimary)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, DesignTokens.Spacing.xs)
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }

            Divider()

            HStack {
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                if commentPosted {
                    Label("Comment posted", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(DesignTokens.Typography.caption)
                }

                if !issues.isEmpty && !commentPosted {
                    Button {
                        Task { await postReviewComment() }
                    } label: {
                        HStack(spacing: 4) {
                            if isPostingComment {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text("Post as PR Comment")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isPostingComment || issues.filter(\.selected).isEmpty)
                }

                if issues.isEmpty && reviewResult.isEmpty && !isAnalyzing {
                    Button("Analyze") {
                        Task { await analyze() }
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
        isAnalyzing = true
        defer { isAnalyzing = false }

        do {
            guard let repo = appState.currentRepository,
                  let remote = repo.remotes.first(where: { $0.isGitHub }),
                  let ownerRepo = remote.ownerAndRepo else { return }

            let files = try await appState.gitHubService.getPullRequestFiles(
                owner: ownerRepo.owner, repo: ownerRepo.repo, number: pr.number
            )

            var allPatches = ""
            for file in files.prefix(10) {
                if let patch = file.patch {
                    allPatches += "### \(file.filename)\n\(patch.prefix(2000))\n\n"
                }
            }

            let prompt = """
            Review this Pull Request diff for a team codebase. Check for:
            1. Business logic errors or regressions
            2. Security vulnerabilities (SQL injection, XSS, auth bypass)
            3. Performance issues (N+1 queries, missing indexes, memory leaks)
            4. Missing error handling or edge cases
            5. Code style violations or anti-patterns

            PR: #\(pr.number) - \(pr.title)
            Branch: \(pr.head.ref) -> \(pr.base.ref)

            Diff:
            \(allPatches.prefix(8000))

            Respond in this exact JSON format:
            {
                "summary": "Brief overall assessment",
                "issues": [
                    {"severity": "critical|warning|suggestion", "file": "filename", "description": "what's wrong and how to fix"}
                ]
            }
            If no issues found, return empty issues array.
            """

            let result = try await AIService.shared.generateText(prompt: prompt)
            let cleaned = AIService.cleanAIResponse(result)

            if let data = cleaned.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                reviewResult = json["summary"] as? String ?? ""
                if let jsonIssues = json["issues"] as? [[String: Any]] {
                    issues = jsonIssues.map { item in
                        ReviewIssue(
                            severity: item["severity"] as? String ?? "suggestion",
                            file: item["file"] as? String ?? "",
                            description: item["description"] as? String ?? ""
                        )
                    }
                }
            } else {
                reviewResult = cleaned
            }
        } catch {
            reviewResult = "Analysis failed: \(error.localizedDescription)"
        }
    }

    private func postReviewComment() async {
        isPostingComment = true
        defer { isPostingComment = false }

        guard let repo = appState.currentRepository,
              let remote = repo.remotes.first(where: { $0.isGitHub }),
              let ownerRepo = remote.ownerAndRepo else { return }

        let selected = issues.filter(\.selected)
        var body = "## AI Review\n\n"
        if !reviewResult.isEmpty {
            body += "\(reviewResult)\n\n"
        }
        for issue in selected {
            let icon = issue.severity == "critical" ? "" : issue.severity == "warning" ? "" : "[idea]"
            body += "- \(icon) **\(issue.file)**: \(issue.description)\n"
        }

        do {
            try await appState.gitHubService.addPullRequestComment(
                owner: ownerRepo.owner, repo: ownerRepo.repo, number: pr.number, body: body
            )
            commentPosted = true
        } catch {
            NotificationManager.shared.error("Failed to post comment", detail: error.localizedDescription)
        }
    }

    private func severityIcon(_ severity: String) -> String {
        switch severity {
        case "critical": return "xmark.octagon.fill"
        case "warning": return "exclamationmark.triangle.fill"
        default: return "lightbulb.fill"
        }
    }

    private func severityColor(_ severity: String) -> Color {
        switch severity {
        case "critical": return .red
        case "warning": return .orange
        default: return .blue
        }
    }
}
