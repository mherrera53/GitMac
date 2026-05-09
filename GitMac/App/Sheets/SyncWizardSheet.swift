import SwiftUI

// MARK: - Branch Sync Issue

struct BranchSyncIssue: Identifiable {
    let id = UUID()
    let branch: String
    let issueType: IssueType
    var isSelected: Bool = true

    enum IssueType {
        case behind(Int)
        case ahead(Int)
        case aheadAndBehind(ahead: Int, behind: Int)
        case staleMerged
        case noRemote
        case remoteOnly
        case diverged

        var icon: String {
            switch self {
            case .behind: return "arrow.down.circle.fill"
            case .ahead: return "arrow.up.circle.fill"
            case .aheadAndBehind: return "arrow.up.arrow.down.circle.fill"
            case .staleMerged: return "trash.circle.fill"
            case .noRemote: return "icloud.slash"
            case .remoteOnly: return "cloud.fill"
            case .diverged: return "exclamationmark.triangle.fill"
            }
        }

        var color: Color {
            switch self {
            case .behind: return .yellow
            case .ahead: return .green
            case .aheadAndBehind, .diverged: return .orange
            case .staleMerged: return .gray
            case .noRemote: return .blue
            case .remoteOnly: return .cyan
            }
        }

        var description: String {
            switch self {
            case .behind(let n): return "Behind origin by \(n) commit(s) -- needs pull"
            case .ahead(let n): return "Ahead of origin by \(n) commit(s) -- needs push"
            case .aheadAndBehind(let a, let b): return "^\(a) v\(b) -- needs rebase + push"
            case .staleMerged: return "Already merged into main -- safe to delete"
            case .noRemote: return "No remote tracking branch -- needs push"
            case .remoteOnly: return "Exists only on remote -- checkout to track"
            case .diverged: return "Diverged from remote -- needs rebase"
            }
        }

        var actionLabel: String {
            switch self {
            case .behind: return "Pull"
            case .ahead: return "Push"
            case .aheadAndBehind, .diverged: return "Rebase & Push"
            case .staleMerged: return "Delete"
            case .noRemote: return "Push"
            case .remoteOnly: return "Checkout"
            }
        }
    }
}

// MARK: - Sync Wizard Sheet

struct SyncWizardSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) var appState

    @State private var issues: [BranchSyncIssue] = []
    @State private var isScanning = true
    @State private var isFixing = false
    @State private var currentAction = ""
    @State private var completedCount = 0
    @State private var errorMessages: [String] = []

    private var repoPath: String {
        appState.currentRepository?.path ?? ""
    }

    private var selectedIssues: [BranchSyncIssue] {
        issues.filter { $0.isSelected }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if isScanning {
                scanningView
            } else if issues.isEmpty {
                allGoodView
            } else if isFixing {
                fixingView
            } else {
                issueListView
            }

            Divider()
            footer
        }
        .frame(width: 600, height: 500)
        .task { await scan() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                .font(.title2)
                .foregroundStyle(AppTheme.accent)
            VStack(alignment: .leading) {
                Text("Sync Wizard")
                    .font(DesignTokens.Typography.title2)
                    .fontWeight(.semibold)
                Text(repoPath.components(separatedBy: "/").last ?? "Repository")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            if !isScanning && !issues.isEmpty && !isFixing {
                Text("\(selectedIssues.count)/\(issues.count) selected")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(AppTheme.textMuted)
            }
        }
        .padding()
    }

    // MARK: - Scanning

    private var scanningView: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Scanning branches...")
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - All Good

    private var allGoodView: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("Everything is in sync!")
                .font(DesignTokens.Typography.title3)
                .fontWeight(.semibold)
            Text("All branches are up to date with their remotes.")
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Fixing

    private var fixingView: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            ProgressView(value: Double(completedCount), total: Double(selectedIssues.count))
                .progressViewStyle(.linear)
                .padding(.horizontal)

            Text(currentAction)
                .font(DesignTokens.Typography.callout)
                .foregroundStyle(AppTheme.textSecondary)

            Text("\(completedCount)/\(selectedIssues.count)")
                .font(DesignTokens.Typography.headline)
                .monospacedDigit()

            if !errorMessages.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(errorMessages, id: \.self) { msg in
                            HStack(alignment: .top) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                                    .font(.caption)
                                Text(msg)
                                    .font(DesignTokens.Typography.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(maxHeight: 80)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Issue List

    private var issueListView: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.xs) {
                ForEach(Array(issues.enumerated()), id: \.element.id) { index, issue in
                    HStack(spacing: DesignTokens.Spacing.md) {
                        Toggle("", isOn: $issues[index].isSelected)
                            .labelsHidden()

                        Image(systemName: issue.issueType.icon)
                            .foregroundStyle(issue.issueType.color)
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(issue.branch)
                                .font(DesignTokens.Typography.headline)
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(issue.issueType.description)
                                .font(DesignTokens.Typography.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }

                        Spacer()

                        Text(issue.issueType.actionLabel)
                            .font(DesignTokens.Typography.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(issue.issueType.color.opacity(0.15))
                            .foregroundStyle(issue.issueType.color)
                            .clipShape(.rect(cornerRadius: 4))
                    }
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .background(AppTheme.backgroundSecondary.opacity(0.3))
                    .clipShape(.rect(cornerRadius: 6))
                }
            }
            .padding(.horizontal)
            .padding(.vertical, DesignTokens.Spacing.sm)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Close") { dismiss() }
                .keyboardShortcut(.cancelAction)

            if !isScanning && !issues.isEmpty && !isFixing {
                Button("Select All") {
                    for i in issues.indices { issues[i].isSelected = true }
                }
                .font(DesignTokens.Typography.caption)
                Button("Select None") {
                    for i in issues.indices { issues[i].isSelected = false }
                }
                .font(DesignTokens.Typography.caption)
            }

            Spacer()

            if !isScanning && !issues.isEmpty && !isFixing {
                Button("Fix Selected (\(selectedIssues.count))") {
                    Task { await fixSelected() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedIssues.isEmpty)
            }

            if !isScanning && !isFixing {
                Button {
                    Task {
                        isScanning = true
                        issues = []
                        await scan()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Rescan")
            }
        }
        .padding()
    }

    // MARK: - Scan

    private func scan() async {
        let shell = ShellExecutor.shared
        guard !repoPath.isEmpty else { isScanning = false; return }

        _ = await shell.execute("git", arguments: ["fetch", "--all", "--prune", "--quiet"], workingDirectory: repoPath)

        let mainBranch = WorkspaceSettingsManager.shared.getMainBranch(for: repoPath)
        var found: [BranchSyncIssue] = []

        let localResult = await shell.execute(
            "git", arguments: ["for-each-ref", "--format=%(refname:short)%00%(upstream:short)%00%(upstream:track)", "refs/heads/"],
            workingDirectory: repoPath
        )

        for line in localResult.stdout.components(separatedBy: "\n") where !line.isEmpty {
            let parts = line.components(separatedBy: "\0")
            let name = parts[0]
            let upstream = parts.count > 1 ? parts[1] : ""
            let track = parts.count > 2 ? parts[2] : ""

            if name == mainBranch { continue }

            if upstream.isEmpty {
                found.append(BranchSyncIssue(branch: name, issueType: .noRemote))
                continue
            }

            let ahead = extractCount(track, pattern: "ahead (\\d+)")
            let behind = extractCount(track, pattern: "behind (\\d+)")

            if ahead > 0 && behind > 0 {
                found.append(BranchSyncIssue(branch: name, issueType: .aheadAndBehind(ahead: ahead, behind: behind)))
            } else if ahead > 0 {
                found.append(BranchSyncIssue(branch: name, issueType: .ahead(ahead)))
            } else if behind > 0 {
                found.append(BranchSyncIssue(branch: name, issueType: .behind(behind)))
            }
        }

        let mergedResult = await shell.execute(
            "git", arguments: ["branch", "--merged", "origin/\(mainBranch)", "--format=%(refname:short)"],
            workingDirectory: repoPath
        )
        for name in mergedResult.stdout.components(separatedBy: "\n") where !name.isEmpty {
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            if trimmed == mainBranch || trimmed.isEmpty { continue }
            if found.contains(where: { $0.branch == trimmed }) { continue }
            found.append(BranchSyncIssue(branch: trimmed, issueType: .staleMerged))
        }

        let remoteResult = await shell.execute(
            "git", arguments: ["for-each-ref", "--format=%(refname:short)", "refs/remotes/origin/"],
            workingDirectory: repoPath
        )
        let localNames = Set(localResult.stdout.components(separatedBy: "\n")
            .compactMap { $0.components(separatedBy: "\0").first }
            .filter { !$0.isEmpty })

        for remoteBranch in remoteResult.stdout.components(separatedBy: "\n") where !remoteBranch.isEmpty {
            let short = remoteBranch.replacingOccurrences(of: "origin/", with: "")
            if short == mainBranch || short == "HEAD" { continue }
            if localNames.contains(short) { continue }
            found.append(BranchSyncIssue(branch: short, issueType: .remoteOnly, isSelected: false))
        }

        issues = found
        isScanning = false
    }

    private func extractCount(_ text: String, pattern: String) -> Int {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return 0 }
        return Int(text[range]) ?? 0
    }

    // MARK: - Fix

    private func fixSelected() async {
        isFixing = true
        defer { isFixing = false }
        completedCount = 0
        errorMessages = []
        let shell = ShellExecutor.shared
        let mainBranch = WorkspaceSettingsManager.shared.getMainBranch(for: repoPath)
        let toFix = selectedIssues

        for issue in toFix {
            currentAction = "\(issue.issueType.actionLabel): \(issue.branch)"

            switch issue.issueType {
            case .behind:
                let r = await shell.execute("git", arguments: ["checkout", issue.branch], workingDirectory: repoPath)
                if r.isSuccess {
                    let pull = await shell.execute("git", arguments: ["pull", "--rebase", "--quiet"], workingDirectory: repoPath)
                    if !pull.isSuccess { errorMessages.append("\(issue.branch): pull failed") }
                }

            case .ahead:
                let r = await shell.execute("git", arguments: ["push", "origin", issue.branch, "--quiet"], workingDirectory: repoPath)
                if !r.isSuccess { errorMessages.append("\(issue.branch): push failed") }

            case .aheadAndBehind, .diverged:
                let r = await shell.execute("git", arguments: ["checkout", issue.branch], workingDirectory: repoPath)
                if r.isSuccess {
                    let rebase = await shell.execute("git", arguments: ["rebase", "origin/\(mainBranch)"], workingDirectory: repoPath)
                    if rebase.isSuccess {
                        let push = await shell.execute("git", arguments: ["push", "--force-with-lease", "--quiet"], workingDirectory: repoPath)
                        if !push.isSuccess { errorMessages.append("\(issue.branch): push failed after rebase") }
                    } else {
                        _ = await shell.execute("git", arguments: ["rebase", "--abort"], workingDirectory: repoPath)
                        errorMessages.append("\(issue.branch): rebase conflicts, skipped")
                    }
                }

            case .staleMerged:
                let r = await shell.execute("git", arguments: ["branch", "-d", issue.branch], workingDirectory: repoPath)
                if r.isSuccess {
                    _ = await shell.execute("git", arguments: ["push", "origin", "--delete", issue.branch, "--quiet"], workingDirectory: repoPath)
                } else {
                    errorMessages.append("\(issue.branch): delete failed")
                }

            case .noRemote:
                let r = await shell.execute("git", arguments: ["push", "-u", "origin", issue.branch, "--quiet"], workingDirectory: repoPath)
                if !r.isSuccess { errorMessages.append("\(issue.branch): push failed") }

            case .remoteOnly:
                let r = await shell.execute("git", arguments: ["checkout", "--track", "origin/\(issue.branch)"], workingDirectory: repoPath)
                if !r.isSuccess { errorMessages.append("\(issue.branch): checkout failed") }
            }

            completedCount += 1
        }

        let headBranch = appState.currentRepository?.currentBranch?.name ?? mainBranch
        _ = await shell.execute("git", arguments: ["checkout", headBranch], workingDirectory: repoPath)

        NotificationCenter.default.post(name: .repositoryDidRefresh, object: repoPath)
        currentAction = errorMessages.isEmpty ? "All done!" : "Completed with \(errorMessages.count) error(s)"
    }
}
