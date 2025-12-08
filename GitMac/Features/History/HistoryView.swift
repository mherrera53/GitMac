import SwiftUI

/// File history and blame view
struct HistoryView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = HistoryViewModel()
    @State private var selectedFile: String?
    @State private var viewMode: HistoryViewMode = .history

    var body: some View {
        VStack(spacing: 0) {
            // File picker
            HStack {
                Image(systemName: "doc.text")

                TextField("Enter file path...", text: Binding(
                    get: { selectedFile ?? "" },
                    set: { selectedFile = $0 }
                ))
                .textFieldStyle(.roundedBorder)

                Picker("View", selection: $viewMode) {
                    Text("History").tag(HistoryViewMode.history)
                    Text("Blame").tag(HistoryViewMode.blame)
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

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
                        .font(.headline)
                    Text("(\(viewModel.fileHistory.count) commits)")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))

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
                }
            }
            .frame(minWidth: 300)

            // Diff for selected commit
            if let commit = selectedCommit {
                CommitFileDiffView(commit: commit, path: path, repositoryPath: viewModel.repositoryPath)
            } else {
                VStack {
                    Spacer()
                    Text("Select a commit to view changes")
                        .foregroundColor(.secondary)
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
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(commit.shortSHA)
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)

                Text(commit.summary)
                    .lineLimit(1)
            }

            HStack {
                Text(commit.author)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(commit.relativeDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
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
            HStack {
                Text(commit.shortSHA)
                    .font(.headline.monospaced())
                Text(commit.summary)
                    .lineLimit(1)
                Spacer()
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView([.vertical, .horizontal]) {
                    Text(diff)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .task(id: commit.sha) {
            await loadDiff()
        }
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

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Blame")
                    .font(.headline)
                Spacer()

                Text("\(viewModel.blameLines.count) lines")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

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

    var body: some View {
        HStack(spacing: 0) {
            // Blame info
            HStack(spacing: 8) {
                Rectangle()
                    .fill(color)
                    .frame(width: 3)

                Text(line.shortSHA)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .leading)

                Text(line.author)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 100, alignment: .leading)
                    .lineLimit(1)

                Text(line.relativeDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .trailing)
            }
            .frame(width: 240)
            .padding(.vertical, 1)
            .background(isHovered ? Color.secondary.opacity(0.1) : Color.clear)

            Divider()

            // Line number
            Text("\(line.lineNumber)")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .trailing)
                .padding(.horizontal, 4)

            // Content
            Text(line.content)
                .font(.system(.caption, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(isHovered ? Color.secondary.opacity(0.05) : Color.clear)
    }
}

struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("Enter a file path")
                .font(.headline)

            Text("View the commit history or blame for any file")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// #Preview {
//     HistoryView()
//         .environmentObject(AppState())
//         .frame(width: 900, height: 600)
// }
