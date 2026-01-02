//
//  RepositoryActivityViewModel.swift
//  GitMac
//
//  Repository-based activity tracking with commit history and contribution graph
//

import SwiftUI
import Combine
import CommonCrypto

// MARK: - Models

struct Contributor: Identifiable, Hashable {
    var id: String { email }
    let name: String
    let email: String
    var commitCount: Int
    var lastCommitDate: Date?
    var avatarURL: URL?
    
    // Gravatar URL from email
    var gravatarURL: URL? {
        let hash = email.lowercased().trimmingCharacters(in: CharacterSet.whitespaces).md5
        return URL(string: "https://www.gravatar.com/avatar/\(hash)?d=identicon&s=64")
    }
}

struct ContributionDay: Identifiable {
    var id: Date { date }
    let date: Date
    var commitCount: Int
    
    var intensity: Double {
        switch commitCount {
        case 0: return 0
        case 1...2: return 0.25
        case 3...5: return 0.5
        case 6...10: return 0.75
        default: return 1.0
        }
    }
}

struct CommitActivity: Identifiable {
    let id: String // commit hash
    let message: String
    let author: String
    let authorEmail: String
    let date: Date
    let filesChanged: Int
    let insertions: Int
    let deletions: Int
}

// MARK: - ViewModel

@MainActor
class RepositoryActivityViewModel: ObservableObject {
    @Published var contributors: [Contributor] = []
    @Published var recentCommits: [CommitActivity] = []
    @Published var contributionDays: [ContributionDay] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var totalCommits: Int = 0
    @Published var activeDays: Int = 0
    
    private var currentRepositoryPath: String?
    private var cancellables = Set<AnyCancellable>()
    private let shell = ShellExecutor()
    
    // MARK: - Load Data
    
    func loadActivity(for repositoryPath: String) async {
        guard currentRepositoryPath != repositoryPath else { return }
        currentRepositoryPath = repositoryPath
        
        isLoading = true
        error = nil
        
        do {
            // Load all data in parallel
            async let contributorsTask = loadContributors(repoPath: repositoryPath)
            async let commitsTask = loadRecentCommits(repoPath: repositoryPath, limit: 50)
            async let graphTask = loadContributionGraph(repoPath: repositoryPath, days: 365)
            
            let (loadedContributors, loadedCommits, loadedGraph) = try await (contributorsTask, commitsTask, graphTask)
            
            contributors = loadedContributors
            recentCommits = loadedCommits
            contributionDays = loadedGraph
            totalCommits = loadedCommits.count
            activeDays = loadedGraph.filter { $0.commitCount > 0 }.count
            
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func refresh() async {
        guard let path = currentRepositoryPath else { return }
        currentRepositoryPath = nil // Force reload
        await loadActivity(for: path)
    }
    
    // MARK: - Git Commands
    
    private func loadContributors(repoPath: String) async throws -> [Contributor] {
        // git shortlog -sne --all
        let result = await shell.execute(
            "sh", arguments: ["-c", "git shortlog -sne --all 2>/dev/null | head -20"],
            workingDirectory: repoPath
        )
        
        var contributors: [Contributor] = []
        
        for line in result.output.components(separatedBy: "\n") where !line.isEmpty {
            // Format: "   123\tName <email>"
            let trimmed = line.trimmingCharacters(in: CharacterSet.whitespaces)
            guard let tabIndex = trimmed.firstIndex(of: "\t") else { continue }
            
            let countStr = String(trimmed[..<tabIndex]).trimmingCharacters(in: CharacterSet.whitespaces)
            let rest = String(trimmed[trimmed.index(after: tabIndex)...])
            
            guard let count = Int(countStr) else { continue }
            
            // Parse "Name <email>"
            if let emailStart = rest.lastIndex(of: "<"),
               let emailEnd = rest.lastIndex(of: ">") {
                let name = String(rest[..<emailStart]).trimmingCharacters(in: CharacterSet.whitespaces)
                let email = String(rest[rest.index(after: emailStart)..<emailEnd])
                
                contributors.append(Contributor(
                    name: name,
                    email: email,
                    commitCount: count,
                    lastCommitDate: nil
                ))
            }
        }
        
        return contributors.sorted { $0.commitCount > $1.commitCount }
    }
    
    private func loadRecentCommits(repoPath: String, limit: Int) async throws -> [CommitActivity] {
        // git log with custom format
        let format = "%H|%s|%an|%ae|%aI|%h"
        let result = await shell.execute(
            "git", arguments: ["log", "--all", "-n", "\(limit)", "--format=\(format)"],
            workingDirectory: repoPath
        )
        
        var commits: [CommitActivity] = []
        let dateFormatter = ISO8601DateFormatter()
        
        for line in result.output.components(separatedBy: "\n") where !line.isEmpty {
            let parts = line.components(separatedBy: "|")
            guard parts.count >= 5 else { continue }
            
            let hash = parts[0]
            let message = parts[1]
            let author = parts[2]
            let email = parts[3]
            let dateStr = parts[4]
            
            let date = dateFormatter.date(from: dateStr) ?? Date()
            
            commits.append(CommitActivity(
                id: hash,
                message: message,
                author: author,
                authorEmail: email,
                date: date,
                filesChanged: 0,
                insertions: 0,
                deletions: 0
            ))
        }
        
        return commits
    }
    
    private func loadContributionGraph(repoPath: String, days: Int) async throws -> [ContributionDay] {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) ?? endDate
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        // Get commit counts per day
        let startStr = dateFormatter.string(from: startDate)
        let result = await shell.execute(
            "sh", arguments: ["-c", "git log --all --since=\"\(startStr)\" --format=\"%ad\" --date=short 2>/dev/null | sort | uniq -c"],
            workingDirectory: repoPath
        )
        
        // Parse results into dictionary
        var commitsByDate: [String: Int] = [:]
        for line in result.output.components(separatedBy: "\n") where !line.isEmpty {
            let parts = line.trimmingCharacters(in: CharacterSet.whitespaces).components(separatedBy: " ")
            guard parts.count >= 2,
                  let count = Int(parts[0]) else { continue }
            let dateKey = parts[1]
            commitsByDate[dateKey] = count
        }
        
        // Generate all days in range
        var contributionDays: [ContributionDay] = []
        var currentDate = startDate
        
        while currentDate <= endDate {
            let dateKey = dateFormatter.string(from: currentDate)
            let count = commitsByDate[dateKey] ?? 0
            contributionDays.append(ContributionDay(date: currentDate, commitCount: count))
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? endDate
        }
        
        return contributionDays
    }
}

// MARK: - String MD5 Extension

extension String {
    var md5: String {
        let data = Data(self.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        
        data.withUnsafeBytes { buffer in
            _ = CC_MD5(buffer.baseAddress, CC_LONG(data.count), &digest)
        }
        
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
