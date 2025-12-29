import SwiftUI

// MARK: - Bisect State

enum BisectState: Equatable {
    case inactive
    case inProgress(good: String, bad: String, current: String, stepsRemaining: Int)
    case found(commit: String)

    var isActive: Bool {
        switch self {
        case .inactive: return false
        default: return true
        }
    }
}

struct BisectCommit: Identifiable {
    let id: UUID
    let sha: String
    let message: String
    let author: String
    let date: Date
    let status: BisectCommitStatus

    var shortSHA: String {
        String(sha.prefix(7))
    }

    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    init(id: UUID = UUID(), sha: String, message: String, author: String, date: Date, status: BisectCommitStatus = .unknown) {
        self.id = id
        self.sha = sha
        self.message = message
        self.author = author
        self.date = date
        self.status = status
    }
}

enum BisectCommitStatus {
    case good
    case bad
    case unknown
    case current
    case skipped

    var color: Color {
        switch self {
        case .good: return AppTheme.success
        case .bad: return AppTheme.error
        case .unknown: return AppTheme.textPrimary
        case .current: return AppTheme.accent
        case .skipped: return AppTheme.warning
        }
    }

    var icon: String {
        switch self {
        case .good: return "checkmark.circle.fill"
        case .bad: return "xmark.circle.fill"
        case .unknown: return "questionmark.circle"
        case .current: return "arrowtriangle.right.circle.fill"
        case .skipped: return "forward.circle.fill"
        }
    }
}

// MARK: - Bisect View

struct BisectView: View {
    @StateObject private var themeManager = ThemeManager.shared

    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = BisectViewModel()
    @State private var showStartSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("GIT BISECT")
                    .font(DesignTokens.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()

                if viewModel.state.isActive {
                    Text("In Progress")
                        .font(DesignTokens.Typography.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.warning)
                        .padding(.horizontal, DesignTokens.Spacing.md - 6)
                        .padding(.vertical, DesignTokens.Spacing.xxs)
                        .background(AppTheme.warning.opacity(0.2))
                        .cornerRadius(DesignTokens.CornerRadius.sm)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(AppTheme.textMuted.opacity(0.1))

            switch viewModel.state {
            case .inactive:
                inactiveView

            case .inProgress(let good, let bad, let current, let steps):
                inProgressView(good: good, bad: bad, current: current, steps: steps)

            case .found(let commit):
                foundView(commit: commit)
            }
        }
        .task {
            await viewModel.checkStatus(at: appState.currentRepository?.path)
        }
        .onChange(of: appState.currentRepository?.path) { _, newPath in
            Task { await viewModel.checkStatus(at: newPath) }
        }
        .sheet(isPresented: $showStartSheet) {
            BisectStartSheet(viewModel: viewModel)
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") { viewModel.error = nil }
        } message: {
            Text(viewModel.error ?? "")
        }
    }

    // MARK: - Inactive View

    private var inactiveView: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Spacer()

            Image(systemName: "magnifyingglass.circle")
                // TODO: Replace with appropriate Typography token when available for large icons
                .font(.system(size: DesignTokens.Size.iconXL * 2))
                .foregroundColor(AppTheme.textPrimary)

            VStack(spacing: DesignTokens.Spacing.sm) {
                Text("Find bugs with binary search")
                    .font(DesignTokens.Typography.headline)

                Text("Git bisect helps you find which commit introduced a bug by performing a binary search through your history.")
                    .font(DesignTokens.Typography.callout)
                    .foregroundColor(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignTokens.Spacing.lg + 4)
            }

            Button("Start Bisect") {
                showStartSheet = true
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - In Progress View

    private func inProgressView(good: String, bad: String, current: String, steps: Int) -> some View {
        VStack(spacing: 0) {
            // Status bar
            VStack(spacing: DesignTokens.Spacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        HStack(spacing: DesignTokens.Spacing.xs) {
                            Circle().fill(AppTheme.success).frame(width: DesignTokens.Spacing.sm, height: DesignTokens.Spacing.sm)
                            Text("Good: \(String(good.prefix(7)))")
                                .font(DesignTokens.Typography.caption)
                                .fontDesign(.monospaced)
                        }
                        HStack(spacing: DesignTokens.Spacing.xs) {
                            Circle().fill(AppTheme.error).frame(width: DesignTokens.Spacing.sm, height: DesignTokens.Spacing.sm)
                            Text("Bad: \(String(bad.prefix(7)))")
                                .font(DesignTokens.Typography.caption)
                                .fontDesign(.monospaced)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: DesignTokens.Spacing.xs) {
                        Text("~\(steps) steps remaining")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(AppTheme.textPrimary)
                        Text("Testing: \(String(current.prefix(7)))")
                            .font(DesignTokens.Typography.caption)
                            .fontDesign(.monospaced)
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.accent)
                    }
                }
            }
            .padding(DesignTokens.Spacing.md)
            .background(AppTheme.info.opacity(0.1))

            // Current commit info
            if let commit = viewModel.currentCommit {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Current Commit")
                        .font(DesignTokens.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.textPrimary)

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text(commit.message)
                            .font(DesignTokens.Typography.body)
                            .lineLimit(2)

                        HStack {
                            Text(commit.author)
                                .font(DesignTokens.Typography.caption)
                            Text("•")
                            Text(commit.formattedDate)
                                .font(DesignTokens.Typography.caption)
                        }
                        .foregroundColor(AppTheme.textPrimary)
                    }
                    .padding(DesignTokens.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.textMuted.opacity(0.1))
                    .cornerRadius(DesignTokens.CornerRadius.lg)
                }
                .padding(DesignTokens.Spacing.md)
            }

            Spacer()

            // Timeline
            if !viewModel.history.isEmpty {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Bisect History")
                        .font(DesignTokens.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.textPrimary)
                        .padding(.horizontal, DesignTokens.Spacing.md)

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.history) { commit in
                                BisectHistoryRow(commit: commit)
                            }
                        }
                    }
                    .frame(maxHeight: 150)
                }
            }

            // Action buttons
            VStack(spacing: DesignTokens.Spacing.sm) {
                Text("Is this commit good or bad?")
                    .font(DesignTokens.Typography.callout)
                    .fontWeight(.medium)

                HStack(spacing: DesignTokens.Spacing.md) {
                    Button {
                        Task { await viewModel.markGood(at: appState.currentRepository?.path) }
                    } label: {
                        Label("Good", systemImage: "checkmark.circle")
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.success)

                    Button {
                        Task { await viewModel.markBad(at: appState.currentRepository?.path) }
                    } label: {
                        Label("Bad", systemImage: "xmark.circle")
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.error)

                    Button {
                        Task { await viewModel.skip(at: appState.currentRepository?.path) }
                    } label: {
                        Label("Skip", systemImage: "forward.circle")
                    }
                    .buttonStyle(.bordered)
                }

                Button("Abort Bisect") {
                    Task { await viewModel.abort(at: appState.currentRepository?.path) }
                }
                .font(DesignTokens.Typography.caption)
                .foregroundColor(AppTheme.error)
            }
            .padding(DesignTokens.Spacing.md)
            .background(AppTheme.textMuted.opacity(0.05))
        }
    }

    // MARK: - Found View

    private func foundView(commit: String) -> some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                // TODO: Replace with appropriate Typography token when available for large icons
                .font(.system(size: DesignTokens.Size.iconXL * 2))
                .foregroundColor(AppTheme.success)

            Text("Bug Found!")
                .font(DesignTokens.Typography.title3)

            if let commit = viewModel.currentCommit {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    Text(commit.shortSHA)
                        .font(.system(size: 16, design: .monospaced, weight: .bold))
                        .foregroundColor(AppTheme.accent)

                    Text(commit.message)
                        .font(DesignTokens.Typography.body)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)

                    HStack {
                        Text(commit.author)
                        Text("•")
                        Text(commit.formattedDate)
                    }
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.textPrimary)
                }
                .padding()
                .background(AppTheme.textMuted.opacity(0.1))
                .cornerRadius(DesignTokens.CornerRadius.lg)
            }

            HStack(spacing: DesignTokens.Spacing.md) {
                Button("View Commit") {
                    // TODO: Navigate to commit details
                }
                .buttonStyle(.bordered)

                Button("Reset Bisect") {
                    Task { await viewModel.reset(at: appState.currentRepository?.path) }
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Bisect History Row

struct BisectHistoryRow: View {
    let commit: BisectCommit

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: commit.status.icon)
                .foregroundColor(commit.status.color)
                .font(DesignTokens.Typography.callout)

            Text(commit.shortSHA)
                .font(DesignTokens.Typography.caption)
                .fontDesign(.monospaced)

            Text(commit.message)
                .font(DesignTokens.Typography.caption)
                .lineLimit(1)
                .foregroundColor(AppTheme.textPrimary)

            Spacer()
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.md - 6)
    }
}

// MARK: - Start Sheet

struct BisectStartSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: BisectViewModel

    @State private var goodRef = ""
    @State private var badRef = "HEAD"
    @State private var recentCommits: [BisectCommit] = []

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg + 4) {
            Text("Start Git Bisect")
                .font(.headline)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Bad commit (has the bug)")
                        .font(DesignTokens.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.textPrimary)
                    HStack {
                        DSTextField(placeholder: "HEAD, commit SHA, or tag", text: $badRef)
                        Button("HEAD") { badRef = "HEAD" }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Good commit (before the bug)")
                        .font(DesignTokens.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.textPrimary)
                    DSTextField(placeholder: "Commit SHA, tag, or branch", text: $goodRef)

                    if !recentCommits.isEmpty {
                        Text("Recent commits:")
                            .font(DesignTokens.Typography.caption2)
                            .foregroundColor(AppTheme.textPrimary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: DesignTokens.Spacing.sm) {
                                ForEach(recentCommits.prefix(10)) { commit in
                                    Button {
                                        goodRef = commit.sha
                                    } label: {
                                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                                            Text(commit.shortSHA)
                                                .font(DesignTokens.Typography.caption2)
                                                .fontDesign(.monospaced)
                                            Text(commit.message)
                                                .font(.system(size: 9)) // Commit message in button - intentionally small
                                                .lineLimit(1)
                                        }
                                        .padding(DesignTokens.Spacing.md - 6)
                                        .background(goodRef == commit.sha ? AppTheme.info : AppTheme.textMuted.opacity(0.2))
                                        .foregroundColor(goodRef == commit.sha ? .white : .primary)
                                        .cornerRadius(DesignTokens.CornerRadius.sm)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)

                Spacer()

                Button("Start") {
                    Task {
                        await viewModel.start(good: goodRef, bad: badRef, at: appState.currentRepository?.path)
                        if viewModel.error == nil { dismiss() }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(goodRef.isEmpty || badRef.isEmpty)
            }
        }
        .padding(DesignTokens.Spacing.xl)
        .frame(width: 450)
        .task {
            await loadRecentCommits()
        }
    }

    private func loadRecentCommits() async {
        guard let path = appState.currentRepository?.path else { return }

        let shell = ShellExecutor()
        let result = await shell.execute(
            "git",
            arguments: ["log", "--oneline", "-30", "--format=%H|%s|%an|%at"],
            workingDirectory: path
        )

        guard result.isSuccess else { return }

        recentCommits = result.stdout.components(separatedBy: .newlines).compactMap { line in
            let parts = line.components(separatedBy: "|")
            guard parts.count >= 4 else { return nil }

            let timestamp = Double(parts[3]) ?? 0
            return BisectCommit(
                sha: parts[0],
                message: parts[1],
                author: parts[2],
                date: Date(timeIntervalSince1970: timestamp)
            )
        }
    }
}

// MARK: - View Model

@MainActor
class BisectViewModel: ObservableObject {
    @Published var state: BisectState = .inactive
    @Published var currentCommit: BisectCommit?
    @Published var history: [BisectCommit] = []
    @Published var isLoading = false
    @Published var error: String?

    private let shell = ShellExecutor()

    func checkStatus(at path: String?) async {
        guard let path = path else {
            state = .inactive
            return
        }

        // Check if bisect is in progress
        let bisectLogResult = await shell.execute(
            "git",
            arguments: ["bisect", "log"],
            workingDirectory: path
        )

        if bisectLogResult.isSuccess && !bisectLogResult.stdout.isEmpty {
            await parseStatus(at: path)
        } else {
            state = .inactive
            history = []
            currentCommit = nil
        }
    }

    private func parseStatus(at path: String) async {
        // Get current HEAD
        let headResult = await shell.execute(
            "git",
            arguments: ["rev-parse", "HEAD"],
            workingDirectory: path
        )

        guard headResult.isSuccess else { return }
        let current = headResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)

        // Get bisect info
        let logResult = await shell.execute(
            "git",
            arguments: ["bisect", "log"],
            workingDirectory: path
        )

        var good = ""
        var bad = ""

        for line in logResult.stdout.components(separatedBy: .newlines) {
            if line.contains("git bisect good") {
                let parts = line.components(separatedBy: " ")
                if let sha = parts.last { good = sha }
            } else if line.contains("git bisect bad") {
                let parts = line.components(separatedBy: " ")
                if let sha = parts.last { bad = sha }
            }
        }

        // Estimate remaining steps
        let stepsResult = await shell.execute(
            "git",
            arguments: ["rev-list", "--count", "\(good)..\(bad)"],
            workingDirectory: path
        )

        let count = Int(stepsResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let steps = max(1, Int(log2(Double(max(1, count)))))

        state = .inProgress(good: good, bad: bad, current: current, stepsRemaining: steps)

        // Load current commit details
        await loadCommitDetails(sha: current, at: path)
    }

    private func loadCommitDetails(sha: String, at path: String) async {
        let result = await shell.execute(
            "git",
            arguments: ["log", "-1", "--format=%H|%s|%an|%at", sha],
            workingDirectory: path
        )

        guard result.isSuccess else { return }

        let parts = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "|")
        guard parts.count >= 4 else { return }

        let timestamp = Double(parts[3]) ?? 0
        currentCommit = BisectCommit(
            sha: parts[0],
            message: parts[1],
            author: parts[2],
            date: Date(timeIntervalSince1970: timestamp),
            status: .current
        )
    }

    func start(good: String, bad: String, at path: String?) async {
        guard let path = path else { return }

        isLoading = true

        // Start bisect
        var result = await shell.execute("git", arguments: ["bisect", "start"], workingDirectory: path)
        guard result.isSuccess else {
            error = result.stderr
            isLoading = false
            return
        }

        // Mark bad
        result = await shell.execute("git", arguments: ["bisect", "bad", bad], workingDirectory: path)
        guard result.isSuccess else {
            error = result.stderr
            await abort(at: path)
            isLoading = false
            return
        }

        // Mark good
        result = await shell.execute("git", arguments: ["bisect", "good", good], workingDirectory: path)

        if result.stdout.contains("is the first bad commit") {
            // Found immediately
            let sha = parseFoundCommit(from: result.stdout)
            state = .found(commit: sha)
            await loadCommitDetails(sha: sha, at: path)
        } else {
            await checkStatus(at: path)
        }

        isLoading = false
    }

    func markGood(at path: String?) async {
        guard let path = path else { return }

        let result = await shell.execute("git", arguments: ["bisect", "good"], workingDirectory: path)

        if result.stdout.contains("is the first bad commit") {
            let sha = parseFoundCommit(from: result.stdout)
            state = .found(commit: sha)
            await loadCommitDetails(sha: sha, at: path)
        } else {
            // Add to history
            if let commit = currentCommit {
                history.insert(BisectCommit(
                    sha: commit.sha,
                    message: commit.message,
                    author: commit.author,
                    date: commit.date,
                    status: .good
                ), at: 0)
            }
            await checkStatus(at: path)
        }
    }

    func markBad(at path: String?) async {
        guard let path = path else { return }

        let result = await shell.execute("git", arguments: ["bisect", "bad"], workingDirectory: path)

        if result.stdout.contains("is the first bad commit") {
            let sha = parseFoundCommit(from: result.stdout)
            state = .found(commit: sha)
            await loadCommitDetails(sha: sha, at: path)
        } else {
            if let commit = currentCommit {
                history.insert(BisectCommit(
                    sha: commit.sha,
                    message: commit.message,
                    author: commit.author,
                    date: commit.date,
                    status: .bad
                ), at: 0)
            }
            await checkStatus(at: path)
        }
    }

    func skip(at path: String?) async {
        guard let path = path else { return }

        _ = await shell.execute("git", arguments: ["bisect", "skip"], workingDirectory: path)

        if let commit = currentCommit {
            history.insert(BisectCommit(
                sha: commit.sha,
                message: commit.message,
                author: commit.author,
                date: commit.date,
                status: .skipped
            ), at: 0)
        }

        await checkStatus(at: path)
    }

    func abort(at path: String?) async {
        guard let path = path else { return }

        _ = await shell.execute("git", arguments: ["bisect", "reset"], workingDirectory: path)

        state = .inactive
        history = []
        currentCommit = nil
    }

    func reset(at path: String?) async {
        await abort(at: path)
    }

    private func parseFoundCommit(from output: String) -> String {
        // Parse "abc1234 is the first bad commit"
        let parts = output.components(separatedBy: " ")
        return parts.first ?? ""
    }
}
