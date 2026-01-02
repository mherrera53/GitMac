//
//  AnalyticsViewModel.swift
//  GitMac
//
//  ViewModel for repository analytics calculations
//

import SwiftUI
import Combine

// MARK: - Time Range

enum AnalyticsTimeRange: String, CaseIterable {
    case week = "7d"
    case month = "30d"
    case quarter = "90d"
    case year = "365d"
    
    var displayName: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .quarter: return "Quarter"
        case .year: return "Year"
        }
    }
    
    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        case .year: return 365
        }
    }
}

// MARK: - Analytics Models

struct RepositoryMetrics {
    var totalCommits: Int = 0
    var totalContributors: Int = 0
    var totalFiles: Int = 0
    var totalLines: Int = 0
    var activeBranches: Int = 0
    var staleBranches: Int = 0
    var daysSinceLastCommit: Int = 0
    var commitsTrend: Double? = nil
    var linesTrend: Double? = nil
}

struct CommitActivityItem: Identifiable {
    let id = UUID()
    let date: Date
    var count: Int
}

struct LanguageItem: Identifiable {
    let id = UUID()
    let language: String
    var lines: Int
    var percentage: Double
    var color: Color
}

struct TopContributor: Identifiable {
    let id = UUID()
    let rank: Int
    let name: String
    let email: String
    var commits: Int
    var percentage: Double
    
    var avatarURL: URL? {
        let hash = email.lowercased().trimmingCharacters(in: CharacterSet.whitespaces).data(using: .utf8)?.base64EncodedString() ?? ""
        return URL(string: "https://www.gravatar.com/avatar/\(hash.prefix(32))?d=identicon&s=64")
    }
}

struct ActivityItem: Identifiable {
    let id = UUID()
    let type: ActivityType
    let description: String
    let date: Date
    
    enum ActivityType {
        case commit
        case branch
        case tag
        case merge
        
        var icon: String {
            switch self {
            case .commit: return "arrow.triangle.branch"
            case .branch: return "arrow.triangle.pull"
            case .tag: return "tag.fill"
            case .merge: return "arrow.triangle.merge"
            }
        }
    }
    
    var icon: String { type.icon }
    
    var color: Color {
        switch type {
        case .commit: return .blue
        case .branch: return .green
        case .tag: return .orange
        case .merge: return .purple
        }
    }
    
    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - ViewModel

@MainActor
class AnalyticsViewModel: ObservableObject {
    @Published var metrics = RepositoryMetrics()
    @Published var commitActivity: [CommitActivityItem] = []
    @Published var languageBreakdown: [LanguageItem] = []
    @Published var topContributors: [TopContributor] = []
    @Published var recentActivity: [ActivityItem] = []
    @Published var healthScore: Int = 0
    
    @Published var timeRange: AnalyticsTimeRange = .month {
        didSet {
            Task { await refresh() }
        }
    }
    
    @Published var isLoading = false
    @Published var error: String?
    
    private var currentRepositoryPath: String?
    private let shell = ShellExecutor()
    
    // MARK: - Load Analytics
    
    func loadAnalytics(for repositoryPath: String) async {
        guard currentRepositoryPath != repositoryPath else { return }
        currentRepositoryPath = repositoryPath
        
        isLoading = true
        error = nil
        
        do {
            // Load all analytics in parallel
            async let metricsTask = loadMetrics(repoPath: repositoryPath)
            async let activityTask = loadCommitActivity(repoPath: repositoryPath)
            async let languagesTask = loadLanguageBreakdown(repoPath: repositoryPath)
            async let contributorsTask = loadTopContributors(repoPath: repositoryPath)
            async let recentTask = loadRecentActivity(repoPath: repositoryPath)
            
            let (loadedMetrics, activity, languages, contributors, recent) = try await (
                metricsTask, activityTask, languagesTask, contributorsTask, recentTask
            )
            
            metrics = loadedMetrics
            commitActivity = activity
            languageBreakdown = languages
            topContributors = contributors
            recentActivity = recent
            
            calculateHealthScore()
            
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func refresh() async {
        guard let path = currentRepositoryPath else { return }
        currentRepositoryPath = nil
        await loadAnalytics(for: path)
    }
    
    // MARK: - Metrics
    
    private func loadMetrics(repoPath: String) async throws -> RepositoryMetrics {
        var metrics = RepositoryMetrics()
        
        // Total commits
        let commitCount = await shell.execute(
            "git", arguments: ["rev-list", "--count", "HEAD"],
            workingDirectory: repoPath
        )
        metrics.totalCommits = Int(commitCount.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)) ?? 0
        
        // Total contributors
        let contributorCount = await shell.execute(
            "sh", arguments: ["-c", "git shortlog -sn --all 2>/dev/null | wc -l"],
            workingDirectory: repoPath
        )
        metrics.totalContributors = Int(contributorCount.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)) ?? 0
        
        // Total files
        let fileCount = await shell.execute(
            "sh", arguments: ["-c", "git ls-files 2>/dev/null | wc -l"],
            workingDirectory: repoPath
        )
        metrics.totalFiles = Int(fileCount.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)) ?? 0
        
        // Lines of code (approximate)
        let lineCount = await shell.execute(
            "sh", arguments: ["-c", "git ls-files | head -100 | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}'"],
            workingDirectory: repoPath
        )
        metrics.totalLines = Int(lineCount.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)) ?? 0
        
        // Active branches
        let branchCount = await shell.execute(
            "sh", arguments: ["-c", "git branch -a 2>/dev/null | wc -l"],
            workingDirectory: repoPath
        )
        metrics.activeBranches = Int(branchCount.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)) ?? 0
        
        // Days since last commit
        let lastCommit = await shell.execute(
            "git", arguments: ["log", "-1", "--format=%ct"],
            workingDirectory: repoPath
        )
        if let timestamp = Double(lastCommit.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)) {
            let lastDate = Date(timeIntervalSince1970: timestamp)
            metrics.daysSinceLastCommit = Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
        }
        
        return metrics
    }
    
    // MARK: - Commit Activity
    
    private func loadCommitActivity(repoPath: String) async throws -> [CommitActivityItem] {
        let days = timeRange.days
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let startStr = dateFormatter.string(from: startDate)
        
        let result = await shell.execute(
            "sh", arguments: ["-c", "git log --all --since=\"\(startStr)\" --format=\"%ad\" --date=short 2>/dev/null | sort | uniq -c"],
            workingDirectory: repoPath
        )
        
        var commitsByDate: [String: Int] = [:]
        for line in result.output.components(separatedBy: "\n") where !line.isEmpty {
            let parts = line.trimmingCharacters(in: CharacterSet.whitespaces).components(separatedBy: " ")
            guard parts.count >= 2, let count = Int(parts[0]) else { continue }
            commitsByDate[parts[1]] = count
        }
        
        // Generate all days
        var items: [CommitActivityItem] = []
        var currentDate = startDate
        let endDate = Date()
        
        while currentDate <= endDate {
            let dateKey = dateFormatter.string(from: currentDate)
            let count = commitsByDate[dateKey] ?? 0
            items.append(CommitActivityItem(date: currentDate, count: count))
            currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) ?? endDate
        }
        
        return items
    }
    
    // MARK: - Language Breakdown
    
    private func loadLanguageBreakdown(repoPath: String) async throws -> [LanguageItem] {
        let result = await shell.execute(
            "sh", arguments: ["-c", "git ls-files 2>/dev/null | head -500"],
            workingDirectory: repoPath
        )
        
        var extensionCounts: [String: Int] = [:]
        
        for file in result.output.components(separatedBy: "\n") where !file.isEmpty {
            if let ext = file.split(separator: ".").last {
                let language = languageName(for: String(ext))
                extensionCounts[language, default: 0] += 1
            }
        }
        
        let total = extensionCounts.values.reduce(0, +)
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .cyan, .yellow, .red]
        
        let items = extensionCounts.sorted { $0.value > $1.value }
            .prefix(8)
            .enumerated()
            .map { index, pair in
                LanguageItem(
                    language: pair.key,
                    lines: pair.value,
                    percentage: total > 0 ? Double(pair.value) / Double(total) : 0,
                    color: colors[index % colors.count]
                )
            }
        
        return items
    }
    
    private func languageName(for ext: String) -> String {
        let mapping: [String: String] = [
            "swift": "Swift",
            "m": "Objective-C",
            "h": "Objective-C",
            "py": "Python",
            "js": "JavaScript",
            "ts": "TypeScript",
            "tsx": "TypeScript",
            "jsx": "JavaScript",
            "java": "Java",
            "kt": "Kotlin",
            "go": "Go",
            "rs": "Rust",
            "rb": "Ruby",
            "php": "PHP",
            "c": "C",
            "cpp": "C++",
            "cs": "C#",
            "html": "HTML",
            "css": "CSS",
            "scss": "SCSS",
            "json": "JSON",
            "yaml": "YAML",
            "yml": "YAML",
            "md": "Markdown",
            "sh": "Shell",
            "sql": "SQL"
        ]
        return mapping[ext.lowercased()] ?? ext.uppercased()
    }
    
    // MARK: - Top Contributors
    
    private func loadTopContributors(repoPath: String) async throws -> [TopContributor] {
        let result = await shell.execute(
            "sh", arguments: ["-c", "git shortlog -sne --all 2>/dev/null | head -10"],
            workingDirectory: repoPath
        )
        
        var contributors: [TopContributor] = []
        var totalCommits = 0
        
        for (index, line) in result.output.components(separatedBy: "\n").enumerated() where !line.isEmpty {
            let trimmed = line.trimmingCharacters(in: CharacterSet.whitespaces)
            guard let tabIndex = trimmed.firstIndex(of: "\t") else { continue }
            
            let countStr = String(trimmed[..<tabIndex]).trimmingCharacters(in: CharacterSet.whitespaces)
            let rest = String(trimmed[trimmed.index(after: tabIndex)...])
            
            guard let count = Int(countStr) else { continue }
            totalCommits += count
            
            var name = rest
            var email = ""
            
            if let emailStart = rest.lastIndex(of: "<"),
               let emailEnd = rest.lastIndex(of: ">") {
                name = String(rest[..<emailStart]).trimmingCharacters(in: CharacterSet.whitespaces)
                email = String(rest[rest.index(after: emailStart)..<emailEnd])
            }
            
            contributors.append(TopContributor(
                rank: index + 1,
                name: name,
                email: email,
                commits: count,
                percentage: 0
            ))
        }
        
        // Calculate percentages
        return contributors.map { contributor in
            var updated = contributor
            updated.percentage = totalCommits > 0 ? Double(contributor.commits) / Double(totalCommits) : 0
            return updated
        }
    }
    
    // MARK: - Recent Activity
    
    private func loadRecentActivity(repoPath: String) async throws -> [ActivityItem] {
        let result = await shell.execute(
            "git", arguments: ["log", "--all", "-n", "10", "--format=%s|%aI"],
            workingDirectory: repoPath
        )
        
        let dateFormatter = ISO8601DateFormatter()
        
        return result.output.components(separatedBy: "\n").compactMap { line -> ActivityItem? in
            guard !line.isEmpty else { return nil }
            let parts = line.components(separatedBy: "|")
            guard parts.count >= 2 else { return nil }
            
            let message = parts[0]
            let dateStr = parts[1]
            let date = dateFormatter.date(from: dateStr) ?? Date()
            
            // Determine activity type from message
            let type: ActivityItem.ActivityType
            if message.lowercased().contains("merge") {
                type = .merge
            } else if message.lowercased().contains("tag") {
                type = .tag
            } else if message.lowercased().contains("branch") {
                type = .branch
            } else {
                type = .commit
            }
            
            return ActivityItem(type: type, description: message, date: date)
        }
    }
    
    // MARK: - Health Score
    
    private func calculateHealthScore() {
        var score = 100
        
        // Deduct for days since last commit
        if metrics.daysSinceLastCommit > 30 {
            score -= 30
        } else if metrics.daysSinceLastCommit > 7 {
            score -= 15
        } else if metrics.daysSinceLastCommit > 1 {
            score -= 5
        }
        
        // Deduct for stale branches
        score -= min(20, metrics.staleBranches * 2)
        
        // Bonus for multiple contributors
        if metrics.totalContributors > 3 {
            score = min(100, score + 10)
        }
        
        // Bonus for recent activity
        let recentCommits = commitActivity.suffix(7).reduce(0) { $0 + $1.count }
        if recentCommits > 10 {
            score = min(100, score + 10)
        }
        
        healthScore = max(0, score)
    }
}
