import SwiftUI

/// File history and blame view
struct HistoryView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = HistoryViewModel()
    @State private var selectedFile: String?
    @State private var viewMode: HistoryViewMode = .history

    // Layout constants
    private enum Layout {
        static let viewPickerWidth: CGFloat = 160  // Width for "History" / "Blame" segmented picker
    }

    var body: some View {
        VStack(spacing: 0) {
            // File picker
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(AppTheme.textSecondary)

                TextField("Enter file path...", text: Binding(
                    get: { selectedFile ?? "" },
                    set: { selectedFile = $0 }
                ))

                Picker("View", selection: $viewMode) {
                    Text("History").tag(HistoryViewMode.history)
                    Text("Blame").tag(HistoryViewMode.blame)
                }
                .frame(width: Layout.viewPickerWidth)
            }
            .padding(DesignTokens.Spacing.md)
            .padding(DesignTokens.Spacing.md)
            .background(AppTheme.backgroundSecondary)

            Divider()

            // Content
            if let file = selectedFile, !file.isEmpty {
                switch viewMode {
                case .history:
                    FileHistoryView(path: file, viewModel: viewModel)
                case .blame:
                    BlameView(path: file, viewModel: viewModel)
                }
            } else {
                EmptyHistoryView()
            }
        }
        .task {
            if let repo = appState.currentRepository {
                viewModel.repositoryPath = repo.path
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .repositoryDidRefresh)) { notification in
            // Refresh file history when repository changes (new commits, etc.)
            if let path = notification.object as? String,
               path == appState.currentRepository?.path,
               let file = selectedFile, !file.isEmpty {
                Task {
                    await viewModel.loadFileHistory(for: file)
                }
            }
        }
    }
}

enum HistoryViewMode {
    case history
    case blame
}

// MARK: - View Model

@MainActor
class HistoryViewModel: ObservableObject {
    @Published var fileHistory: [Commit] = []
    @Published var blameLines: [BlameLine] = []
    @Published var isLoading = false
    @Published var error: String?

    var repositoryPath: String = ""

    func loadFileHistory(for path: String) async {
        isLoading = true

        let shell = ShellExecutor()
        let result = await shell.execute(
            "git",
            arguments: ["log", "--format=%H|%an|%ae|%ai|%s", "--follow", "--", path],
            workingDirectory: repositoryPath
        )

        if result.exitCode == 0 {
            fileHistory = result.stdout
                .components(separatedBy: .newlines)
                .filter { !$0.isEmpty }
                .compactMap { line -> Commit? in
                    let parts = line.components(separatedBy: "|")
                    guard parts.count >= 5 else { return nil }

                    let sha = parts[0]
                    let author = parts[1]
                    let email = parts[2]
                    let dateStr = parts[3]
                    let message = parts[4...].joined(separator: "|")

                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
                    let date = formatter.date(from: dateStr) ?? Date()

                    return Commit(
                        sha: sha,
                        message: message,
                        author: author,
                        authorEmail: email,
                        authorDate: date,
                        committer: author,
                        committerEmail: email,
                        committerDate: date,
                        parentSHAs: []
                    )
                }
        }

        isLoading = false
    }

    func loadBlame(for path: String) async {
        isLoading = true

        let shell = ShellExecutor()
        let result = await shell.execute(
            "git",
            arguments: ["blame", "--line-porcelain", path],
            workingDirectory: repositoryPath
        )

        if result.exitCode == 0 {
            blameLines = parseBlameOutput(result.stdout)
        }

        isLoading = false
    }

    private func parseBlameOutput(_ output: String) -> [BlameLine] {
        var lines: [BlameLine] = []
        var currentSha = ""
        var currentAuthor = ""
        var currentDate = Date()
        var lineNumber = 0

        let outputLines = output.components(separatedBy: .newlines)

        for line in outputLines {
            if line.hasPrefix("\t") {
                // Content line
                let content = String(line.dropFirst())
                lineNumber += 1
                lines.append(BlameLine(
                    lineNumber: lineNumber,
                    sha: currentSha,
                    author: currentAuthor,
                    date: currentDate,
                    content: content
                ))
            } else if line.count >= 40 && !line.contains(" ") {
                // SHA line
                currentSha = String(line.prefix(40))
            } else if line.hasPrefix("author ") {
                currentAuthor = String(line.dropFirst(7))
            } else if line.hasPrefix("author-time ") {
                if let timestamp = TimeInterval(line.dropFirst(12)) {
                    currentDate = Date(timeIntervalSince1970: timestamp)
                }
            }
        }

        return lines
    }
}

struct BlameLine: Identifiable {
    let id = UUID()
    let lineNumber: Int
    let sha: String
    let author: String
    let date: Date
    let content: String

    var shortSHA: String {
        String(sha.prefix(7))
    }

    var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - File History View

struct FileHistoryView: View {
    let path: String
    @ObservedObject var viewModel: HistoryViewModel
    @State private var selectedCommit: Commit?

    var body: some View {
        HSplitView {
            // Commit list
            VStack(spacing: 0) {
                HStack {
                    Text("History")
                        .font(DesignTokens.Typography.headline)
                    Text("(\(viewModel.fileHistory.count) commits)")
                        .foregroundColor(AppTheme.textPrimary)
                    Spacer()
                }
                .padding(DesignTokens.Spacing.md)
                .background(AppTheme.backgroundSecondary)

                Divider()

                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(viewModel.fileHistory, selection: $selectedCommit) { commit in
                        FileCommitRow(commit: commit)
                            .tag(commit)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(AppTheme.background)
                }
            }
            .background(AppTheme.background)
            .frame(minWidth: 300)

            // Diff for selected commit
            if let commit = selectedCommit {
                CommitFileDiffView(commit: commit, path: path, repositoryPath: viewModel.repositoryPath)
            } else {
                VStack {
                    Spacer()
                    Text("Select a commit to view changes")
                        .foregroundColor(AppTheme.textPrimary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .task(id: path) {
            await viewModel.loadFileHistory(for: path)
        }
    }
}

struct FileCommitRow: View {
    let commit: Commit

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(commit.shortSHA)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(AppTheme.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppTheme.accent.opacity(0.1))
                    .cornerRadius(4)

                Text(commit.summary)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
            }

            HStack {
                Image(systemName: "person.fill")
                    .font(.system(size: 10))
                    .foregroundColor(AppTheme.textSecondary)
                
                Text(commit.author)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)

                Spacer()

                Text(commit.relativeDate)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textMuted)
            }
            .padding(.leading, 2)
        }
        .padding(.vertical, 4)
    }
}

struct CommitFileDiffView: View {
    let commit: Commit
    let path: String
    let repositoryPath: String

    @State private var diff = ""
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(commit.shortSHA)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(AppTheme.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppTheme.accent.opacity(0.1))
                    .cornerRadius(4)

                Text(commit.summary)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(DesignTokens.Spacing.md)
            .padding(DesignTokens.Spacing.md)
            .background(AppTheme.backgroundSecondary)

            Divider()

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView([.vertical, .horizontal]) {
                    Text(diff)
                        .font(DesignTokens.Typography.commitHash)
                        .textSelection(.enabled)
                        .padding(DesignTokens.Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .task(id: commit.sha) {
            await loadDiff()
        }
        .background(AppTheme.background)
    }

    private func loadDiff() async {
        isLoading = true
        let shell = ShellExecutor()
        let result = await shell.execute(
            "git",
            arguments: ["show", commit.sha, "--", path],
            workingDirectory: repositoryPath
        )
        diff = result.stdout
        isLoading = false
    }
}

// MARK: - Blame View

struct BlameView: View {
    let path: String
    @ObservedObject var viewModel: HistoryViewModel
    @State private var hoveredLine: Int?

    private let authorColors: [String: Color] = [:]

    // Blame view layout constants
    private enum Layout {
        static let authorIndicatorWidth: CGFloat = DesignTokens.Spacing.xxs + 1  // 3px color bar
        static let shaColumnWidth: CGFloat = 60      // Width for 7-char SHA
        static let authorColumnWidth: CGFloat = 100  // Typical author name length
        static let dateColumnWidth: CGFloat = 50     // Relative date format ("2h ago")
        static let lineNumberWidth: CGFloat = 40     // Line numbers up to 9999
        static let blameInfoWidth: CGFloat = 240     // Total width of blame metadata section
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Blame")
                    .font(DesignTokens.Typography.headline)
                Spacer()

                Text("\(viewModel.blameLines.count) lines")
                    .foregroundColor(AppTheme.textPrimary)
            }
            .padding(DesignTokens.Spacing.md)
            .padding(DesignTokens.Spacing.md)
            .background(AppTheme.backgroundSecondary)

            Divider()

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView([.vertical, .horizontal]) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(viewModel.blameLines) { line in
                            BlameLineRow(
                                line: line,
                                isHovered: hoveredLine == line.lineNumber,
                                color: colorForAuthor(line.author)
                            )
                            .onHover { isHovered in
                                hoveredLine = isHovered ? line.lineNumber : nil
                            }
                        }
                    }
                }
            }
        }
        .task(id: path) {
            await viewModel.loadBlame(for: path)
        }
        .background(AppTheme.background)
    }

    private func colorForAuthor(_ author: String) -> Color {
        // Generate consistent color from author name
        let hash = author.hash
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.5, brightness: 0.8)
    }
}

struct BlameLineRow: View {
    let line: BlameLine
    let isHovered: Bool
    let color: Color

    // Reuse BlameView layout constants
    private enum Layout {
        static let authorIndicatorWidth: CGFloat = DesignTokens.Spacing.xxs + 1  // 3px color bar
        static let shaColumnWidth: CGFloat = 60      // Width for 7-char SHA
        static let authorColumnWidth: CGFloat = 100  // Typical author name length
        static let dateColumnWidth: CGFloat = 50     // Relative date format ("2h ago")
        static let lineNumberWidth: CGFloat = 40     // Line numbers up to 9999
        static let blameInfoWidth: CGFloat = 240     // Total width of blame metadata section
    }

    var body: some View {
        HStack(spacing: 0) {
            // Blame info
            HStack(spacing: DesignTokens.Spacing.sm) {
                Rectangle()
                    .fill(color)
                    .frame(width: Layout.authorIndicatorWidth)

                Text(line.shortSHA)
                    .font(.system(size: 11, weight: .bold, design: .monospaced)) // Monospaced & Bold
                    .foregroundColor(AppTheme.accent) // Accent color
                    .frame(width: Layout.shaColumnWidth, alignment: .leading)

                Text(line.author)
                    .font(.system(size: 11, weight: .medium)) // Medium weight
                    .foregroundColor(AppTheme.textSecondary) // Secondary text color
                    .frame(width: Layout.authorColumnWidth, alignment: .leading)
                    .lineLimit(1)

                Text(line.relativeDate)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textMuted) // Muted text color
                    .frame(width: Layout.dateColumnWidth, alignment: .trailing)
            }
            .frame(width: Layout.blameInfoWidth)
            .padding(.vertical, 1)  // Precise 1px padding for tight row spacing
            .background(isHovered ? AppTheme.textSecondary.opacity(0.1) : Color.clear)

            Divider()

            // Line number
            Text("\(line.lineNumber)")
                .font(DesignTokens.Typography.commitHash)
                .foregroundColor(AppTheme.textPrimary)
                .frame(width: Layout.lineNumberWidth, alignment: .trailing)
                .padding(.horizontal, DesignTokens.Spacing.xs)

            // Content
            Text(line.content)
                .font(DesignTokens.Typography.commitHash)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(isHovered ? AppTheme.textSecondary.opacity(0.05) : Color.clear)
    }
}

struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "clock")
                .font(.system(size: DesignTokens.Size.iconXL))
                .fontWeight(.regular)
                .foregroundColor(AppTheme.textPrimary)

            Text("Enter a file path")
                .font(DesignTokens.Typography.headline)

            Text("View the commit history or blame for any file")
                .foregroundColor(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// #Preview {
//     HistoryView()
//         .environmentObject(AppState())
//         .frame(width: 900, height: 600)
// }
