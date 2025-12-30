import Foundation

/// Parsed search query with filters
struct SearchQuery {
    var freeText: String?
    var message: String?
    var author: String?
    var commitSHA: String?
    var file: String?
    var type: CommitType?
    var change: String?
    var afterDate: Date?
    var beforeDate: Date?
    var isMyChanges: Bool = false

    enum CommitType: String {
        case stash
        case merge
        case regular
    }

    /// Check if a commit matches this query
    func matches(_ commit: Commit, currentUserEmail: String?) -> Bool {
        // My changes filter
        if isMyChanges {
            guard let userEmail = currentUserEmail,
                  commit.authorEmail.lowercased() == userEmail.lowercased() else {
                return false
            }
        }

        // Message filter
        if let messageFilter = message {
            guard commit.message.lowercased().contains(messageFilter.lowercased()) else {
                return false
            }
        }

        // Author filter
        if let authorFilter = author {
            let lowerFilter = authorFilter.lowercased()
            guard commit.author.lowercased().contains(lowerFilter) ||
                  commit.authorEmail.lowercased().contains(lowerFilter) else {
                return false
            }
        }

        // Commit SHA filter
        if let shaFilter = commitSHA {
            guard commit.sha.lowercased().hasPrefix(shaFilter.lowercased()) else {
                return false
            }
        }

        // Type filter
        if let typeFilter = type {
            switch typeFilter {
            case .stash:
                guard commit.isStash else { return false }
            case .merge:
                guard commit.isMergeCommit else { return false }
            case .regular:
                guard !commit.isMergeCommit && !commit.isStash else { return false }
            }
        }

        // Date filters
        if let after = afterDate {
            guard commit.authorDate >= after else { return false }
        }

        if let before = beforeDate {
            guard commit.authorDate <= before else { return false }
        }

        // Free text search (fallback)
        if let text = freeText, !text.isEmpty {
            let lower = text.lowercased()
            let matchesMessage = commit.message.lowercased().contains(lower)
            let matchesAuthor = commit.author.lowercased().contains(lower)
            let matchesSHA = commit.sha.lowercased().contains(lower)
            guard matchesMessage || matchesAuthor || matchesSHA else {
                return false
            }
        }

        return true
    }

    /// User-friendly description of active filters
    var description: String {
        var parts: [String] = []

        if isMyChanges { parts.append("My changes") }
        if let msg = message { parts.append("Message: \"\(msg)\"") }
        if let auth = author { parts.append("Author: \(auth)") }
        if let sha = commitSHA { parts.append("SHA: \(sha)") }
        if let f = file { parts.append("File: \(f)") }
        if let t = type { parts.append("Type: \(t.rawValue)") }
        if let after = afterDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            parts.append("After: \(formatter.string(from: after))")
        }
        if let before = beforeDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            parts.append("Before: \(formatter.string(from: before))")
        }

        return parts.isEmpty ? "All commits" : parts.joined(separator: ", ")
    }
}
