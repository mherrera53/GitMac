//
//  RepositoryActivityViewModel.swift
//  GitMac
//
//  Repository-based activity tracking with commit history and contribution graph
//

import SwiftUI
import Combine
import CommonCrypto
import CryptoKit

// MARK: - Models

struct Contributor: Identifiable, Hashable {
    let id: String  // GitHub username or normalized name
    let name: String
    let email: String
    var commitCount: Int
    var lastCommitDate: Date?
    var avatarURL: URL?
    var githubUsername: String?

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
            "sh", arguments: ["-c", "git shortlog -sne --all 2>/dev/null"],
            workingDirectory: repoPath
        )

        // Parse raw contributors
        var rawContributors: [(name: String, email: String, count: Int)] = []

        for line in result.output.components(separatedBy: "\n") where !line.isEmpty {
            let trimmed = line.trimmingCharacters(in: CharacterSet.whitespaces)
            guard let tabIndex = trimmed.firstIndex(of: "\t") else { continue }

            let countStr = String(trimmed[..<tabIndex]).trimmingCharacters(in: CharacterSet.whitespaces)
            let rest = String(trimmed[trimmed.index(after: tabIndex)...])

            guard let count = Int(countStr) else { continue }

            if let emailStart = rest.lastIndex(of: "<"),
               let emailEnd = rest.lastIndex(of: ">") {
                let name = String(rest[..<emailStart]).trimmingCharacters(in: CharacterSet.whitespaces)
                let email = String(rest[rest.index(after: emailStart)..<emailEnd])
                rawContributors.append((name, email, count))
            }
        }

        // Try to get GitHub info for unification
        let (githubOwner, githubRepo) = await parseGitHubRemote(repoPath: repoPath)
        let token = try? await KeychainManager.shared.getGitHubToken()

        var emailToGitHubUser: [String: String] = [:]

        if let owner = githubOwner, let repo = githubRepo, let token = token {
            // Load GitHub contributors
            let ghContributors = await fetchGitHubContributors(owner: owner, repo: repo, token: token)

            // For each GitHub contributor, get their emails
            for ghContrib in ghContributors.prefix(30) {
                let emails = await fetchContributorEmails(owner: owner, repo: repo, username: ghContrib.login, token: token)
                for email in emails {
                    emailToGitHubUser[email.lowercased()] = ghContrib.login.lowercased()
                }
            }
        }

        // Build name -> GitHub username map
        var nameToGitHubUser: [String: String] = [:]
        for raw in rawContributors {
            let normalizedName = raw.name.lowercased().trimmingCharacters(in: .whitespaces)
            let email = raw.email.lowercased()
            if let username = emailToGitHubUser[email] {
                nameToGitHubUser[normalizedName] = username
            }
        }

        // Unify contributors
        var unifiedContributors: [String: (name: String, email: String, count: Int, ghUsername: String?)] = [:]

        for raw in rawContributors {
            let email = raw.email.lowercased()
            let normalizedName = raw.name.lowercased().trimmingCharacters(in: .whitespaces)

            let unifyKey: String
            let ghUsername: String?

            if let username = emailToGitHubUser[email] {
                unifyKey = "gh:\(username)"
                ghUsername = username
            } else if let username = nameToGitHubUser[normalizedName] {
                unifyKey = "gh:\(username)"
                ghUsername = username
            } else {
                unifyKey = "name:\(normalizedName)"
                ghUsername = nil
            }

            if var existing = unifiedContributors[unifyKey] {
                existing.count += raw.count
                unifiedContributors[unifyKey] = existing
            } else {
                unifiedContributors[unifyKey] = (raw.name, email, raw.count, ghUsername)
            }
        }

        return unifiedContributors.map { key, value in
            Contributor(
                id: key,
                name: value.name,
                email: value.email,
                commitCount: value.count,
                lastCommitDate: nil,
                avatarURL: nil,
                githubUsername: value.ghUsername
            )
        }.sorted { $0.commitCount > $1.commitCount }
    }

    private func parseGitHubRemote(repoPath: String) async -> (owner: String?, repo: String?) {
        let result = await shell.execute(
            "git", arguments: ["remote", "get-url", "origin"],
            workingDirectory: repoPath
        )

        guard result.isSuccess else { return (nil, nil) }

        let url = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if let match = url.range(of: "github.com[/:]([^/]+)/([^/.]+)", options: .regularExpression) {
            let path = String(url[match])
            let parts = path.replacingOccurrences(of: "github.com", with: "")
                .replacingOccurrences(of: ":", with: "/")
                .split(separator: "/")
                .map(String.init)
            if parts.count >= 2 {
                return (parts[0], parts[1].replacingOccurrences(of: ".git", with: ""))
            }
        }
        return (nil, nil)
    }

    private func fetchGitHubContributors(owner: String, repo: String, token: String) async -> [(login: String, avatarUrl: String)] {
        guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/contributors?per_page=100") else {
            return []
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return []
            }

            return json.compactMap { item -> (login: String, avatarUrl: String)? in
                guard let login = item["login"] as? String,
                      let avatarUrl = item["avatar_url"] as? String else { return nil }
                return (login, avatarUrl)
            }
        } catch {
            return []
        }
    }

    private func fetchContributorEmails(owner: String, repo: String, username: String, token: String) async -> [String] {
        guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/commits?author=\(username)&per_page=30") else {
            return []
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return []
            }

            var emails = Set<String>()
            for item in json {
                if let commit = item["commit"] as? [String: Any],
                   let author = commit["author"] as? [String: Any],
                   let email = author["email"] as? String {
                    emails.insert(email)
                }
            }
            return Array(emails)
        } catch {
            return []
        }
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
        let digest = Insecure.MD5.hash(data: Data(self.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
