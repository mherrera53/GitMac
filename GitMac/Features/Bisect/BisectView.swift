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
        case .good: return .green
        case .bad: return .red
        case .unknown: return .gray
        case .current: return .blue
        case .skipped: return .orange
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
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = BisectViewModel()
    @State private var showStartSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("GIT BISECT")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                if viewModel.state.isActive {
                    Text("In Progress")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))

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
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text("Find bugs with binary search")
                    .font(.system(size: 14, weight: .medium))

                Text("Git bisect helps you find which commit introduced a bug by performing a binary search through your history.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
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
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Circle().fill(Color.green).frame(width: 8, height: 8)
                            Text("Good: \(String(good.prefix(7)))")
                                .font(.system(size: 11, design: .monospaced))
                        }
                        HStack(spacing: 4) {
                            Circle().fill(Color.red).frame(width: 8, height: 8)
                            Text("Bad: \(String(bad.prefix(7)))")
                                .font(.system(size: 11, design: .monospaced))
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("~\(steps) steps remaining")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text("Testing: \(String(current.prefix(7)))")
                            .font(.system(size: 11, design: .monospaced, weight: .bold))
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(12)
            .background(Color.blue.opacity(0.1))

            // Current commit info
            if let commit = viewModel.currentCommit {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Commit")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(commit.message)
                            .font(.system(size: 13))
                            .lineLimit(2)

                        HStack {
                            Text(commit.author)
                                .font(.system(size: 11))
                            Text("•")
                            Text(commit.formattedDate)
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding(12)
            }

            Spacer()

            // Timeline
            if !viewModel.history.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Bisect History")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)

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
            VStack(spacing: 8) {
                Text("Is this commit good or bad?")
                    .font(.system(size: 12, weight: .medium))

                HStack(spacing: 12) {
                    Button {
                        Task { await viewModel.markGood(at: appState.currentRepository?.path) }
                    } label: {
                        Label("Good", systemImage: "checkmark.circle")
                    }
                    .buttonStyle(.bordered)
                    .tint(.green)

                    Button {
                        Task { await viewModel.markBad(at: appState.currentRepository?.path) }
                    } label: {
                        Label("Bad", systemImage: "xmark.circle")
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)

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
                .font(.system(size: 11))
                .foregroundColor(.red)
            }
            .padding(12)
            .background(Color.gray.opacity(0.05))
        }
    }

    // MARK: - Found View

    private func foundView(commit: String) -> some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)

            Text("Bug Found!")
                .font(.system(size: 18, weight: .bold))

            if let commit = viewModel.currentCommit {
                VStack(spacing: 8) {
                    Text(commit.shortSHA)
                        .font(.system(size: 16, design: .monospaced, weight: .bold))
                        .foregroundColor(.blue)

                    Text(commit.message)
                        .font(.system(size: 13))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)

                    HStack {
                        Text(commit.author)
                        Text("•")
                        Text(commit.formattedDate)
                    }
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }

            HStack(spacing: 12) {
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
        HStack(spacing: 8) {
            Image(systemName: commit.status.icon)
                .foregroundColor(commit.status.color)
                .font(.system(size: 12))

            Text(commit.shortSHA)
                .font(.system(size: 11, design: .monospaced))

            Text(commit.message)
                .font(.system(size: 11))
                .lineLimit(1)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
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
        VStack(spacing: 20) {
            Text("Start Git Bisect")
                .font(.headline)

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bad commit (has the bug)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    HStack {
                        TextField("HEAD, commit SHA, or tag", text: $badRef)
                            .textFieldStyle(.roundedBorder)
                        Button("HEAD") { badRef = "HEAD" }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Good commit (before the bug)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    TextField("Commit SHA, tag, or branch", text: $goodRef)
                        .textFieldStyle(.roundedBorder)

                    if !recentCommits.isEmpty {
                        Text("Recent commits:")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(recentCommits.prefix(10)) { commit in
                                    Button {
                                        goodRef = commit.sha
                                    } label: {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(commit.shortSHA)
                                                .font(.system(size: 10, design: .monospaced))
                                            Text(commit.message)
                                                .font(.system(size: 9))
                                                .lineLimit(1)
                                        }
                                        .padding(6)
                                        .background(goodRef == commit.sha ? Color.blue : Color.gray.opacity(0.2))
                                        .foregroundColor(goodRef == commit.sha ? .white : .primary)
                                        .cornerRadius(4)
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
        .padding(24)
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
