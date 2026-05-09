import SwiftUI

/// Branch Comparison View - Compare any two branches/commits
struct BranchComparisonView: View {
    @Environment(AppState.self) var appState
    @StateObject private var viewModel = BranchComparisonViewModel()
    
    @State private var baseBranch: String = ""
    @State private var compareBranch: String = ""
    @State private var showBasePicker = false
    @State private var showComparePicker = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Comparison selector
            comparisonSelector
            
            Divider()
            
            // Results
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if baseBranch.isEmpty || compareBranch.isEmpty {
                emptyState
            } else {
                comparisonResults
            }
        }
        .task {
            viewModel.configure(appState: appState)
            
            // Set default branches
            if let current = appState.currentRepository?.currentBranch?.name {
                baseBranch = current
            }
        }
    }
    
    // MARK: - Comparison Selector
    
    private var comparisonSelector: some View {
        HStack(spacing: 16) {
            // Base branch
            VStack(alignment: .leading, spacing: 6) {
                Text("Base")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textPrimary)
                
                Button {
                    showBasePicker = true
                } label: {
                    HStack {
                        Image(systemName: "arrow.branch")
                            .foregroundStyle(AppTheme.info)

                        Text(baseBranch.isEmpty ? "Select branch..." : baseBranch)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(.rect(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showBasePicker) {
                    BranchPickerPopover(
                        selectedBranch: $baseBranch,
                        isPresented: $showBasePicker
                    )
                    .environment(appState)
                }
            }
            
            // Comparison arrow
            Image(systemName: "arrow.left.arrow.right")
                .font(.title3)
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.top, 20)
            
            // Compare branch
            VStack(alignment: .leading, spacing: 6) {
                Text("Compare")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textPrimary)
                
                Button {
                    showComparePicker = true
                } label: {
                    HStack {
                        Image(systemName: "arrow.branch")
                            .foregroundStyle(AppTheme.success)

                        Text(compareBranch.isEmpty ? "Select branch..." : compareBranch)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(.rect(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showComparePicker) {
                    BranchPickerPopover(
                        selectedBranch: $compareBranch,
                        isPresented: $showComparePicker
                    )
                    .environment(appState)
                }
            }
            
            Spacer()
            
            // Compare button
            Button {
                Task { await viewModel.compare(base: baseBranch, compare: compareBranch) }
            } label: {
                Label("Compare", systemImage: "arrow.left.arrow.right.circle")
            }
            .buttonStyle(.borderedProminent)
            .disabled(baseBranch.isEmpty || compareBranch.isEmpty || viewModel.isLoading)
            
            // Swap button
            Button {
                swap(&baseBranch, &compareBranch)
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .buttonStyle(.borderless)
            .help("Swap branches")
            .disabled(baseBranch.isEmpty || compareBranch.isEmpty)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    // MARK: - Comparison Results
    
    private var comparisonResults: some View {
        TabView {
            // Commits
            commitsTab
                .tabItem {
                    Label("Commits (\(viewModel.commits.count))", systemImage: "clock")
                }
            
            // Files changed
            filesTab
                .tabItem {
                    Label("Files (\(viewModel.changedFiles.count))", systemImage: "doc.text")
                }
            
            // Diff
            diffTab
                .tabItem {
                    Label("Diff", systemImage: "arrow.left.arrow.right")
                }
            
            // Stats
            statsTab
                .tabItem {
                    Label("Stats", systemImage: "chart.bar")
                }
        }
    }
    
    private var commitsTab: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.commits) { commit in
                    ComparisonCommitRow(commit: commit)
                }
            }
        }
    }
    
    private var filesTab: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.changedFiles) { file in
                    ChangedFileRow(file: file)
                }
            }
        }
    }
    
    private var diffTab: some View {
        ScrollView {
            Text(viewModel.diff)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
    }
    
    private var statsTab: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Overall stats
                HStack(spacing: 40) {
                    ComparisonStatCard(
                        icon: "clock",
                        color: AppTheme.info,
                        value: "\(viewModel.commits.count)",
                        label: "Commits"
                    )

                    ComparisonStatCard(
                        icon: "doc.text",
                        color: AppTheme.accent,
                        value: "\(viewModel.changedFiles.count)",
                        label: "Files Changed"
                    )

                    ComparisonStatCard(
                        icon: "plus.circle",
                        color: AppTheme.success,
                        value: "\(viewModel.totalAdditions)",
                        label: "Lines Added"
                    )

                    ComparisonStatCard(
                        icon: "minus.circle",
                        color: AppTheme.error,
                        value: "\(viewModel.totalDeletions)",
                        label: "Lines Deleted"
                    )
                }
                .padding()
                
                Divider()
                
                // Contributors
                VStack(alignment: .leading, spacing: 12) {
                    Text("Contributors")
                        .font(.headline)
                    
                    ForEach(viewModel.contributors, id: \.name) { contributor in
                        HStack {
                            Text(contributor.name)
                            Spacer()
                            Text("\(contributor.commits) commits")
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                    }
                }
                .padding()
                
                Divider()
                
                // File type breakdown
                VStack(alignment: .leading, spacing: 12) {
                    Text("File Types")
                        .font(.headline)
                    
                    ForEach(viewModel.fileTypeStats, id: \.extension) { stat in
                        HStack {
                            FileTypeIcon(fileName: "file.\(stat.extension)")

                            Text(".\(stat.extension)")

                            Spacer()

                            Text("\(stat.count) files")
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                    }
                }
                .padding()
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.left.arrow.right.circle")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.textPrimary)
            
            Text("Select branches to compare")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
            
            Text("Choose a base and compare branch to see differences")
                .font(.caption)
                .foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Branch Picker Popover

struct BranchPickerPopover: View {
    @Environment(AppState.self) var appState
    @Binding var selectedBranch: String
    @Binding var isPresented: Bool
    
    @State private var searchText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Search
            DSSearchField(placeholder: "Search branches...", text: $searchText)
                .padding(8)
            
            Divider()
            
            // Branch list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredBranches, id: \.name) { branch in
                        Button {
                            selectedBranch = branch.name
                            isPresented = false
                        } label: {
                            HStack {
                                Image(systemName: "arrow.branch")
                                    .foregroundStyle(branch.isHead ? AppTheme.success : AppTheme.info)

                                Text(branch.name)
                                    .lineLimit(1)

                                Spacer()

                                if branch.isHead {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(AppTheme.success)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(width: 300, height: 400)
        }
    }
    
    private var filteredBranches: [Branch] {
        let branches = appState.currentRepository?.branches ?? []
        
        if searchText.isEmpty {
            return branches
        }
        
        return branches.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
}

// MARK: - Supporting Views

struct ComparisonCommitRow: View {
    let commit: Commit
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(AppTheme.info)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(commit.message)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(commit.shortSHA)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(AppTheme.textPrimary)
                    
                    Text("•")
                        .foregroundStyle(AppTheme.textPrimary)
                    
                    Text(commit.author)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textPrimary)
                    
                    Text("•")
                        .foregroundStyle(AppTheme.textPrimary)
                    
                    Text(commit.date.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundStyle(AppTheme.textPrimary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

struct ChangedFileRow: View {
    let file: FileStatus
    
    var body: some View {
        HStack(spacing: 12) {
            StatusIcon(status: file.status)

            FileTypeIcon(fileName: file.filename)

            Text(file.path)
                .lineLimit(1)

            Spacer()

            if file.hasChanges {
                DiffStatsView(additions: file.additions, deletions: file.deletions)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

struct ComparisonStatCard: View {
    let icon: String
    let color: Color
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(color)
            
            Text(value)
                .font(.system(size: 24, weight: .bold))
            
            Text(label)
                .font(.caption)
                .foregroundStyle(AppTheme.textPrimary)
        }
        .frame(width: 140, height: 120)
        .background(color.opacity(0.1))
        .clipShape(.rect(cornerRadius: 12))
    }
}

// MARK: - View Model

@MainActor
class BranchComparisonViewModel: ObservableObject {
    nonisolated(unsafe) private static let isoFormatter = ISO8601DateFormatter()

    @Published var commits: [Commit] = []
    @Published var changedFiles: [FileStatus] = []
    @Published var diff = ""
    @Published var isLoading = false
    
    @Published var totalAdditions = 0
    @Published var totalDeletions = 0
    @Published var contributors: [BranchContributor] = []
    @Published var fileTypeStats: [FileTypeStat] = []
    
    private var appState: AppState?
    
    func configure(appState: AppState) {
        self.appState = appState
    }
    
    func compare(base: String, compare: String) async {
        guard let appState = appState,
              let repoPath = appState.currentRepository?.path else {
            return
        }
        
        isLoading = true
        
        // Get commits
        commits = await loadCommits(base: base, compare: compare, repoPath: repoPath)
        
        // Get changed files
        changedFiles = await loadChangedFiles(base: base, compare: compare, repoPath: repoPath)
        
        // Get diff
        do {
            diff = try await appState.gitService.getDiff(from: base, to: compare)
        } catch {
            diff = "Error loading diff: \(error.localizedDescription)"
        }
        
        // Calculate stats
        calculateStats()
        
        isLoading = false
    }
    
    private func loadCommits(base: String, compare: String, repoPath: String) async -> [Commit] {
        let shell = ShellExecutor.shared
        let result = await shell.execute(
            "git",
            arguments: ["log", "--format=%H|%an|%ae|%ai|%s", "\(base)..\(compare)"],
            workingDirectory: repoPath
        )
        
        if result.exitCode == 0 {
            return result.stdout
                .components(separatedBy: .newlines)
                .filter { !$0.isEmpty }
                .compactMap { line -> Commit? in
                    let parts = line.components(separatedBy: "|")
                    guard parts.count >= 5 else { return nil }

                    let parsedDate = Self.isoFormatter.date(from: parts[3]) ?? Date()

                    return Commit(
                        sha: parts[0],
                        message: parts[4],
                        author: parts[1],
                        authorEmail: parts[2],
                        authorDate: parsedDate,
                        committer: parts[1],  // Use author as committer
                        committerEmail: parts[2],
                        committerDate: parsedDate,
                        parentSHAs: []
                    )
                }
        }
        
        return []
    }
    
    private func loadChangedFiles(base: String, compare: String, repoPath: String) async -> [FileStatus] {
        let shell = ShellExecutor.shared
        let result = await shell.execute(
            "git",
            arguments: ["diff", "--name-status", "--numstat", base, compare],
            workingDirectory: repoPath
        )
        
        if result.exitCode == 0 {
            // Parse files
            // TODO: Implement proper parsing
            return []
        }
        
        return []
    }
    
    private func calculateStats() {
        totalAdditions = changedFiles.reduce(0) { $0 + $1.additions }
        totalDeletions = changedFiles.reduce(0) { $0 + $1.deletions }
        
        // Contributors
        var contributorDict: [String: Int] = [:]
        for commit in commits {
            contributorDict[commit.author, default: 0] += 1
        }
        contributors = contributorDict.map { BranchContributor(name: $0.key, commits: $0.value) }
            .sorted { $0.commits > $1.commits }
        
        // File types
        var fileTypeDict: [String: Int] = [:]
        for file in changedFiles {
            let ext = file.fileExtension
            fileTypeDict[ext, default: 0] += 1
        }
        fileTypeStats = fileTypeDict.map { FileTypeStat(extension: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
}

// MARK: - Models

struct BranchContributor {
    let name: String
    let commits: Int
}

struct FileTypeStat {
    let `extension`: String
    let count: Int
}
