import SwiftUI

/// Advanced Search View - Search commits, files, authors, and content
/// Like GitHub/GitLab search but faster
struct AdvancedSearchView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = SearchViewModel()
    
    @State private var searchText = ""
    @State private var searchMode: SearchMode = .commits
    @State private var selectedResult: SearchResult?
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar and filters
            searchHeader
            
            Divider()
            
            // Results
            HSplitView {
                // Results list
                searchResults
                    .frame(minWidth: 300)
                
                // Result detail
                if let result = selectedResult {
                    resultDetail(result)
                } else {
                    emptyDetail
                }
            }
        }
        .task {
            viewModel.configure(appState: appState)
        }
    }
    
    // MARK: - Search Header
    
    private var searchHeader: some View {
        VStack(spacing: 12) {
            // Search field
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppTheme.textPrimary)
                
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .onSubmit {
                        Task { await performSearch() }
                    }
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        viewModel.clearResults()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppTheme.textPrimary)
                    }
                    .buttonStyle(.plain)
                }
                
                Button("Search") {
                    Task { await performSearch() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(searchText.isEmpty)
                .keyboardShortcut(.return)
            }
            
            // Search modes
            Picker("Search in", selection: $searchMode) {
                ForEach(SearchMode.allCases) { mode in
                    Label(mode.displayName, systemImage: mode.icon)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            
            // Filters
            if searchMode == .commits {
                commitFilters
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    private var commitFilters: some View {
        HStack(spacing: 12) {
            // Author filter
            Menu {
                Button("All Authors") {
                    viewModel.filterAuthor = nil
                }
                
                Divider()
                
                ForEach(viewModel.authors, id: \.self) { author in
                    Button(author) {
                        viewModel.filterAuthor = author
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "person")
                        .foregroundColor(AppTheme.textSecondary)
                    Text(viewModel.filterAuthor ?? "All Authors")
                        .lineLimit(1)
                }
            }
            .menuStyle(.borderlessButton)
            .frame(maxWidth: 150)
            
            // Date range
            Menu {
                Button("Any Time") {
                    viewModel.filterDateRange = nil
                }
                
                Divider()
                
                Button("Last 24 Hours") {
                    viewModel.filterDateRange = .lastDay
                }
                
                Button("Last Week") {
                    viewModel.filterDateRange = .lastWeek
                }
                
                Button("Last Month") {
                    viewModel.filterDateRange = .lastMonth
                }
                
                Button("Last Year") {
                    viewModel.filterDateRange = .lastYear
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .foregroundColor(AppTheme.textSecondary)
                    Text(viewModel.filterDateRange?.displayName ?? "Any Time")
                }
            }
            .menuStyle(.borderlessButton)
            
            Spacer()
            
            // Regex toggle
            Toggle("Regex", isOn: $viewModel.useRegex)
                .toggleStyle(.checkbox)
            
            // Case sensitive toggle
            Toggle("Case Sensitive", isOn: $viewModel.caseSensitive)
                .toggleStyle(.checkbox)
        }
    }
    
    // MARK: - Search Results
    
    private var searchResults: some View {
        VStack(spacing: 0) {
            // Results header
            HStack {
                Text("\(viewModel.results.count) results")
                    .font(.caption)
                    .foregroundColor(AppTheme.textPrimary)
                
                Spacer()
                
                if viewModel.isSearching {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Results list
            if viewModel.isSearching && viewModel.results.isEmpty {
                loadingView
            } else if viewModel.results.isEmpty && !searchText.isEmpty {
                noResultsView
            } else {
                resultsList
            }
        }
    }
    
    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(viewModel.results) { result in
                    SearchResultRow(
                        result: result,
                        searchText: searchText,
                        isSelected: selectedResult?.id == result.id
                    )
                    .onTapGesture {
                        selectedResult = result
                    }
                }
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Searching...")
                .foregroundColor(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var noResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.textPrimary)
            
            Text("No results found")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)
            
            Text("Try a different search term or filters")
                .font(.caption)
                .foregroundColor(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Result Detail
    
    @ViewBuilder
    private func resultDetail(_ result: SearchResult) -> some View {
        switch result.type {
        case .commit(let commit):
            CommitDetailView(commit: commit)
        case .file(let path, let matches):
            FileMatchDetailView(path: path, matches: matches)
        case .content(let path, let line, let content):
            ContentMatchDetailView(path: path, line: line, content: content)
        }
    }
    
    private var emptyDetail: some View {
        VStack {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.textPrimary)
            Text("Select a result to view details")
                .foregroundColor(AppTheme.textPrimary)
            Spacer()
        }
    }
    
    // MARK: - Actions
    
    private func performSearch() async {
        await viewModel.search(query: searchText, mode: searchMode)
    }
}

// MARK: - Search Mode

enum SearchMode: String, CaseIterable, Identifiable {
    case commits
    case files
    case content
    case authors
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .commits: return "Commits"
        case .files: return "Files"
        case .content: return "Content"
        case .authors: return "Authors"
        }
    }
    
    var icon: String {
        switch self {
        case .commits: return "clock"
        case .files: return "doc.text"
        case .content: return "text.magnifyingglass"
        case .authors: return "person"
        }
    }
}

// MARK: - Date Range Filter

enum DateRangeFilter: String, CaseIterable {
    case lastDay
    case lastWeek
    case lastMonth
    case lastYear
    
    var displayName: String {
        switch self {
        case .lastDay: return "Last 24 Hours"
        case .lastWeek: return "Last Week"
        case .lastMonth: return "Last Month"
        case .lastYear: return "Last Year"
        }
    }
    
    var date: Date {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .lastDay:
            return calendar.date(byAdding: .day, value: -1, to: now)!
        case .lastWeek:
            return calendar.date(byAdding: .weekOfYear, value: -1, to: now)!
        case .lastMonth:
            return calendar.date(byAdding: .month, value: -1, to: now)!
        case .lastYear:
            return calendar.date(byAdding: .year, value: -1, to: now)!
        }
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let result: SearchResult
    let searchText: String
    let isSelected: Bool
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: result.icon)
                .font(.system(size: 16))
                .foregroundColor(result.iconColor)
                .frame(width: 24)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(highlightedTitle)
                    .lineLimit(1)
                
                Text(result.subtitle)
                    .font(.caption)
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Metadata
            if let metadata = result.metadata {
                Text(metadata)
                    .font(.caption)
                    .foregroundColor(AppTheme.textPrimary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? AppTheme.accent.opacity(0.2) : (isHovered ? AppTheme.textSecondary.opacity(0.05) : Color.clear))
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
    
    private var highlightedTitle: AttributedString {
        var attributed = AttributedString(result.title)
        
        // Highlight search text
        if let range = result.title.range(of: searchText, options: .caseInsensitive) {
            let nsRange = NSRange(range, in: result.title)
            if let attrRange = Range<AttributedString.Index>(nsRange, in: attributed) {
                attributed[attrRange].foregroundColor = .accentColor
                attributed[attrRange].font = .body.bold()
            }
        }
        
        return attributed
    }
}

// MARK: - Search Result Model

struct SearchResult: Identifiable {
    let id: UUID
    let type: SearchResultType
    let title: String
    let subtitle: String
    let metadata: String?
    
    var icon: String {
        switch type {
        case .commit: return "clock"
        case .file: return "doc.text"
        case .content: return "text.magnifyingglass"
        }
    }
    
    var iconColor: Color {
        switch type {
        case .commit: return .blue
        case .file: return .purple
        case .content: return .orange
        }
    }
    
    init(id: UUID = UUID(), type: SearchResultType, title: String, subtitle: String, metadata: String? = nil) {
        self.id = id
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.metadata = metadata
    }
}

enum SearchResultType {
    case commit(Commit)
    case file(path: String, matches: Int)
    case content(path: String, line: Int, content: String)
}

// MARK: - View Model

@MainActor
class SearchViewModel: ObservableObject {
    @Published var results: [SearchResult] = []
    @Published var authors: [String] = []
    @Published var isSearching = false
    
    // Filters
    @Published var filterAuthor: String?
    @Published var filterDateRange: DateRangeFilter?
    @Published var useRegex = false
    @Published var caseSensitive = false
    
    private var appState: AppState?
    private var searchTask: Task<Void, Never>?
    
    func configure(appState: AppState) {
        self.appState = appState
        loadAuthors()
    }
    
    func search(query: String, mode: SearchMode) async {
        // Cancel previous search
        searchTask?.cancel()
        
        searchTask = Task {
            isSearching = true
            results = []
            
            guard let repoPath = appState?.currentRepository?.path else {
                isSearching = false
                return
            }
            
            switch mode {
            case .commits:
                await searchCommits(query: query, repoPath: repoPath)
            case .files:
                await searchFiles(query: query, repoPath: repoPath)
            case .content:
                await searchContent(query: query, repoPath: repoPath)
            case .authors:
                await searchAuthors(query: query, repoPath: repoPath)
            }
            
            isSearching = false
        }
    }
    
    func clearResults() {
        searchTask?.cancel()
        results = []
    }
    
    // MARK: - Search Implementations
    
    private func searchCommits(query: String, repoPath: String) async {
        let shell = ShellExecutor()
        
        var args = ["log", "--format=%H|%an|%ae|%ai|%s"]
        
        // Apply filters
        if let author = filterAuthor {
            args.append("--author=\(author)")
        }
        
        if let dateRange = filterDateRange {
            let formatter = ISO8601DateFormatter()
            args.append("--since=\(formatter.string(from: dateRange.date))")
        }
        
        // Search in message
        if useRegex {
            args.append("--grep=\(query)")
        } else {
            args.append("--grep=\(query)")
        }
        
        if !caseSensitive {
            args.append("-i")
        }
        
        let result = await shell.execute(
            "git",
            arguments: args,
            workingDirectory: repoPath
        )
        
        if result.exitCode == 0 {
            results = parseCommitResults(result.stdout)
        }
    }
    
    private func searchFiles(query: String, repoPath: String) async {
        let shell = ShellExecutor()
        let result = await shell.execute(
            "git",
            arguments: ["ls-files"],
            workingDirectory: repoPath
        )
        
        if result.exitCode == 0 {
            let files = result.stdout
                .components(separatedBy: .newlines)
                .filter { !$0.isEmpty }
            
            // Filter by query
            let filtered = files.filter { file in
                if caseSensitive {
                    return file.contains(query)
                } else {
                    return file.localizedCaseInsensitiveContains(query)
                }
            }
            
            results = filtered.map { path in
                SearchResult(
                    type: .file(path: path, matches: 1),
                    title: URL(fileURLWithPath: path).lastPathComponent,
                    subtitle: path
                )
            }
        }
    }
    
    private func searchContent(query: String, repoPath: String) async {
        let shell = ShellExecutor()
        
        var args = ["grep", "-n"]
        
        if !caseSensitive {
            args.append("-i")
        }
        
        if useRegex {
            args.append("-E")
        }
        
        args.append(query)
        
        let result = await shell.execute(
            "git",
            arguments: args,
            workingDirectory: repoPath
        )
        
        if result.exitCode == 0 {
            results = parseContentResults(result.stdout)
        }
    }
    
    private func searchAuthors(query: String, repoPath: String) async {
        let shell = ShellExecutor()
        let result = await shell.execute(
            "git",
            arguments: ["log", "--format=%an|%ae", "--all"],
            workingDirectory: repoPath
        )
        
        if result.exitCode == 0 {
            let allAuthors = Set(result.stdout
                .components(separatedBy: .newlines)
                .filter { !$0.isEmpty }
                .map { $0.components(separatedBy: "|")[0] }
            )
            
            let filtered = allAuthors.filter { author in
                if caseSensitive {
                    return author.contains(query)
                } else {
                    return author.localizedCaseInsensitiveContains(query)
                }
            }
            
            results = filtered.map { author in
                SearchResult(
                    type: .commit(Commit(
                        sha: "",
                        message: "",
                        author: author,
                        authorEmail: "",
                        authorDate: Date(),
                        committer: author,
                        committerEmail: "",
                        committerDate: Date(),
                        parentSHAs: []
                    )),
                    title: author,
                    subtitle: "Author"
                )
            }
        }
    }
    
    // MARK: - Parsing
    
    private func parseCommitResults(_ output: String) -> [SearchResult] {
        output
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .compactMap { line in
                let parts = line.components(separatedBy: "|")
                guard parts.count >= 5 else { return nil }
                
                let parsedDate = ISO8601DateFormatter().date(from: parts[3]) ?? Date()
                let commit = Commit(
                    sha: parts[0],
                    message: parts[4],
                    author: parts[1],
                    authorEmail: parts[2],
                    authorDate: parsedDate,
                    committer: parts[1],
                    committerEmail: parts[2],
                    committerDate: parsedDate,
                    parentSHAs: []
                )
                
                return SearchResult(
                    type: .commit(commit),
                    title: commit.message,
                    subtitle: commit.author,
                    metadata: commit.date.formatted(.relative(presentation: .named))
                )
            }
    }
    
    private func parseContentResults(_ output: String) -> [SearchResult] {
        output
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .compactMap { line in
                // Format: path:lineNumber:content
                let parts = line.split(separator: ":", maxSplits: 2)
                guard parts.count >= 3 else { return nil }
                
                let path = String(parts[0])
                let lineNumber = Int(parts[1]) ?? 0
                let content = String(parts[2])
                
                return SearchResult(
                    type: .content(path: path, line: lineNumber, content: content),
                    title: content.trimmingCharacters(in: .whitespaces),
                    subtitle: "\(path):\(lineNumber)",
                    metadata: "Line \(lineNumber)"
                )
            }
    }
    
    private func loadAuthors() {
        guard let repoPath = appState?.currentRepository?.path else { return }
        
        Task {
            let shell = ShellExecutor()
            let result = await shell.execute(
                "git",
                arguments: ["log", "--format=%an", "--all"],
                workingDirectory: repoPath
            )
            
            if result.exitCode == 0 {
                authors = Array(Set(result.stdout
                    .components(separatedBy: .newlines)
                    .filter { !$0.isEmpty }
                )).sorted()
            }
        }
    }
}

// MARK: - Detail Views

struct CommitDetailView: View {
    let commit: Commit
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(commit.message)
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 12) {
                        Label(commit.author, systemImage: "person")
                        Label(commit.shortSHA, systemImage: "number")
                        Label(commit.date.formatted(.relative(presentation: .named)), systemImage: "clock")
                    }
                    .font(.caption)
                    .foregroundColor(AppTheme.textPrimary)
                }
                .padding()
                
                Divider()
                
                // Actions
                HStack {
                    Button("View Commit") {
                        // TODO: Navigate to commit
                    }
                    
                    Button("Copy SHA") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(commit.sha, forType: .string)
                    }
                }
                .padding()
            }
        }
    }
}

struct FileMatchDetailView: View {
    let path: String
    let matches: Int
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.textPrimary)
            
            Text(path)
                .font(.headline)
            
            Text("\(matches) matches")
                .foregroundColor(AppTheme.textPrimary)
            
            Button("Open File") {
                NSWorkspace.shared.open(URL(fileURLWithPath: path))
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ContentMatchDetailView: View {
    let path: String
    let line: Int
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(path):\(line)")
                .font(.headline)
            
            Text(content)
                .font(.system(.body, design: .monospaced))
                .padding()
                .background(AppTheme.textSecondary.opacity(0.1))
                .cornerRadius(8)
            
            Button("Open in Editor") {
                NSWorkspace.shared.open(URL(fileURLWithPath: path))
            }
        }
        .padding()
    }
}
