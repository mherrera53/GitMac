import SwiftUI

/// Global search view - Search commits, files, and content
struct SearchView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = SearchViewModel()
    @State private var searchText = ""
    @State private var searchType: SearchType = .commits
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Search header
            VStack(spacing: 12) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    TextField("Search \(searchType.placeholder)...", text: $searchText)
                        .textFieldStyle(.plain)
                        .focused($isSearchFocused)
                        .onSubmit {
                            performSearch()
                        }

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            viewModel.clearResults()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Button("Search") {
                        performSearch()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(searchText.isEmpty)
                }
                .padding(10)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(8)

                // Search type picker
                Picker("Search Type", selection: $searchType) {
                    ForEach(SearchType.allCases) { type in
                        Label(type.rawValue, systemImage: type.icon).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Results
            if viewModel.isSearching {
                VStack {
                    ProgressView("Searching...")
                    Text("Looking through \(searchType.rawValue.lowercased())...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.hasResults {
                SearchResultsView(viewModel: viewModel, searchType: searchType)
            } else if viewModel.hasSearched {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text("No results found")
                        .font(.headline)

                    Text("Try a different search term or type")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                SearchPlaceholderView()
            }
        }
        .onAppear {
            isSearchFocused = true
        }
    }

    private func performSearch() {
        guard !searchText.isEmpty else { return }

        Task {
            if let repo = appState.currentRepository {
                await viewModel.search(
                    query: searchText,
                    type: searchType,
                    in: repo
                )
            }
        }
    }
}

// MARK: - View Model

enum SearchType: String, CaseIterable, Identifiable {
    case commits = "Commits"
    case files = "Files"
    case content = "Content"
    case branches = "Branches"
    case tags = "Tags"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .commits: return "clock"
        case .files: return "doc"
        case .content: return "doc.text.magnifyingglass"
        case .branches: return "arrow.triangle.branch"
        case .tags: return "tag"
        }
    }

    var placeholder: String {
        switch self {
        case .commits: return "commit messages or SHA"
        case .files: return "file names"
        case .content: return "file content"
        case .branches: return "branch names"
        case .tags: return "tag names"
        }
    }
}

@MainActor
class SearchViewModel: ObservableObject {
    @Published var commitResults: [Commit] = []
    @Published var fileResults: [FileSearchResult] = []
    @Published var contentResults: [ContentSearchResult] = []
    @Published var branchResults: [Branch] = []
    @Published var tagResults: [Tag] = []
    @Published var isSearching = false
    @Published var hasSearched = false

    private let shell = ShellExecutor()

    var hasResults: Bool {
        !commitResults.isEmpty ||
        !fileResults.isEmpty ||
        !contentResults.isEmpty ||
        !branchResults.isEmpty ||
        !tagResults.isEmpty
    }

    func search(query: String, type: SearchType, in repo: Repository) async {
        isSearching = true
        hasSearched = true
        clearResults()

        switch type {
        case .commits:
            await searchCommits(query: query, in: repo)
        case .files:
            await searchFiles(query: query, in: repo)
        case .content:
            await searchContent(query: query, in: repo)
        case .branches:
            searchBranches(query: query, in: repo)
        case .tags:
            searchTags(query: query, in: repo)
        }

        isSearching = false
    }

    func clearResults() {
        commitResults = []
        fileResults = []
        contentResults = []
        branchResults = []
        tagResults = []
    }

    private func searchCommits(query: String, in repo: Repository) async {
        // Search by message and SHA
        let result = await shell.execute(
            "git",
            arguments: ["log", "--all", "--format=%H|%an|%ae|%ai|%s", "--grep=\(query)", "-i", "-n", "50"],
            workingDirectory: repo.path
        )

        if result.exitCode == 0 {
            commitResults = result.stdout
                .components(separatedBy: .newlines)
                .filter { !$0.isEmpty }
                .compactMap { parseCommitLine($0) }
        }

        // Also search by SHA prefix
        if commitResults.isEmpty && query.count >= 4 {
            let shaResult = await shell.execute(
                "git",
                arguments: ["log", "--all", "--format=%H|%an|%ae|%ai|%s", query, "-n", "1"],
                workingDirectory: repo.path
            )

            if shaResult.exitCode == 0 {
                commitResults = shaResult.stdout
                    .components(separatedBy: .newlines)
                    .filter { !$0.isEmpty }
                    .compactMap { parseCommitLine($0) }
            }
        }
    }

    private func parseCommitLine(_ line: String) -> Commit? {
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

    private func searchFiles(query: String, in repo: Repository) async {
        let result = await shell.execute(
            "git",
            arguments: ["ls-files", "*\(query)*"],
            workingDirectory: repo.path
        )

        if result.exitCode == 0 {
            fileResults = result.stdout
                .components(separatedBy: .newlines)
                .filter { !$0.isEmpty }
                .map { FileSearchResult(path: $0) }
        }
    }

    private func searchContent(query: String, in repo: Repository) async {
        let result = await shell.execute(
            "git",
            arguments: ["grep", "-n", "-i", "--heading", query],
            workingDirectory: repo.path
        )

        if result.exitCode == 0 {
            contentResults = parseGrepOutput(result.stdout)
        }
    }

    private func parseGrepOutput(_ output: String) -> [ContentSearchResult] {
        var results: [ContentSearchResult] = []
        var currentFile = ""
        var currentMatches: [(Int, String)] = []

        for line in output.components(separatedBy: .newlines) {
            if line.isEmpty {
                if !currentFile.isEmpty && !currentMatches.isEmpty {
                    results.append(ContentSearchResult(
                        path: currentFile,
                        matches: currentMatches
                    ))
                    currentMatches = []
                }
            } else if line.contains(":") {
                // This is a match line
                if let colonIndex = line.firstIndex(of: ":") {
                    let lineNumStr = String(line[..<colonIndex])
                    if let lineNum = Int(lineNumStr) {
                        let content = String(line[line.index(after: colonIndex)...])
                        currentMatches.append((lineNum, content))
                    }
                }
            } else {
                // This is a filename
                currentFile = line
            }
        }

        // Don't forget the last file
        if !currentFile.isEmpty && !currentMatches.isEmpty {
            results.append(ContentSearchResult(
                path: currentFile,
                matches: currentMatches
            ))
        }

        return results
    }

    private func searchBranches(query: String, in repo: Repository) {
        branchResults = repo.branches.filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
    }

    private func searchTags(query: String, in repo: Repository) {
        tagResults = repo.tags.filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
    }
}

// MARK: - Models

struct FileSearchResult: Identifiable {
    let id = UUID()
    let path: String

    var filename: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    var directory: String {
        URL(fileURLWithPath: path).deletingLastPathComponent().path
    }
}

struct ContentSearchResult: Identifiable {
    let id = UUID()
    let path: String
    let matches: [(lineNumber: Int, content: String)]

    var filename: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    var matchCount: Int {
        matches.count
    }
}

// MARK: - Subviews

struct SearchResultsView: View {
    @ObservedObject var viewModel: SearchViewModel
    let searchType: SearchType

    var body: some View {
        switch searchType {
        case .commits:
            CommitSearchResults(commits: viewModel.commitResults)
        case .files:
            FileSearchResults(files: viewModel.fileResults)
        case .content:
            ContentSearchResults(results: viewModel.contentResults)
        case .branches:
            BranchSearchResults(branches: viewModel.branchResults)
        case .tags:
            TagSearchResults(tags: viewModel.tagResults)
        }
    }
}

struct CommitSearchResults: View {
    let commits: [Commit]
    @EnvironmentObject var appState: AppState

    var body: some View {
        List {
            Section {
                Text("\(commits.count) commits found")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ForEach(commits) { commit in
                CommitSearchRow(commit: commit)
                    .onTapGesture {
                        appState.selectedCommit = commit
                    }
            }
        }
        .listStyle(.plain)
    }
}

struct CommitSearchRow: View {
    let commit: Commit

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(commit.shortSHA)
                    .font(.caption.monospaced())
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

struct FileSearchResults: View {
    let files: [FileSearchResult]

    var body: some View {
        List {
            Section {
                Text("\(files.count) files found")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ForEach(files) { file in
                HStack(spacing: 8) {
                    Image(systemName: FileTypeIcon.systemIcon(for: file.filename))
                        .foregroundColor(FileTypeIcon.color(for: file.filename))

                    VStack(alignment: .leading) {
                        Text(file.filename)
                            .fontWeight(.medium)

                        if !file.directory.isEmpty && file.directory != "." {
                            Text(file.directory)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .listStyle(.plain)
    }
}

struct ContentSearchResults: View {
    let results: [ContentSearchResult]

    var body: some View {
        List {
            Section {
                Text("\(results.count) files with matches")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ForEach(results) { result in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: FileTypeIcon.systemIcon(for: result.filename))
                            .foregroundColor(FileTypeIcon.color(for: result.filename))

                        Text(result.path)
                            .fontWeight(.medium)

                        Spacer()

                        Text("\(result.matchCount) matches")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(4)
                    }

                    // Show first few matches
                    ForEach(Array(result.matches.prefix(3).enumerated()), id: \.offset) { _, match in
                        HStack(spacing: 8) {
                            Text("\(match.lineNumber)")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                                .frame(width: 40, alignment: .trailing)

                            Text(match.content.trimmingCharacters(in: .whitespaces))
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(1)
                        }
                        .padding(.leading, 20)
                    }

                    if result.matches.count > 3 {
                        Text("+ \(result.matches.count - 3) more matches")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 68)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.plain)
    }
}

struct BranchSearchResults: View {
    let branches: [Branch]

    var body: some View {
        List {
            Section {
                Text("\(branches.count) branches found")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ForEach(branches) { branch in
                HStack {
                    Image(systemName: "arrow.triangle.branch")
                        .foregroundColor(branch.isCurrent ? .green : .blue)

                    Text(branch.name)
                        .fontWeight(branch.isCurrent ? .semibold : .regular)

                    if branch.isCurrent {
                        Text("current")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }

                    Spacer()

                    if branch.isRemote {
                        Text("remote")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

struct TagSearchResults: View {
    let tags: [Tag]

    var body: some View {
        List {
            Section {
                Text("\(tags.count) tags found")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ForEach(tags) { tag in
                HStack {
                    Image(systemName: tag.isAnnotated ? "tag.fill" : "tag")
                        .foregroundColor(.orange)

                    Text(tag.name)

                    Spacer()

                    Text(tag.shortSHA)
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                }
            }
        }
        .listStyle(.plain)
    }
}

struct SearchPlaceholderView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("Search Your Repository")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                SearchTip(icon: "clock", text: "Search commits by message or SHA")
                SearchTip(icon: "doc", text: "Find files by name")
                SearchTip(icon: "doc.text.magnifyingglass", text: "Search file content")
                SearchTip(icon: "arrow.triangle.branch", text: "Find branches")
                SearchTip(icon: "tag", text: "Search tags")
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SearchTip: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 20)

            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// #Preview {
//     SearchView()
//         .environmentObject(AppState())
//         .frame(width: 600, height: 500)
// }
