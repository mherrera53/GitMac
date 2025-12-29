import Foundation

/// Represents a Git stash entry
struct Stash: Identifiable, Equatable, Hashable {
    let id: UUID
    let index: Int
    let message: String
    let sha: String
    let date: Date
    let branchName: String?

    init(
        index: Int,
        message: String,
        sha: String,
        date: Date,
        branchName: String? = nil
    ) {
        self.id = UUID()
        self.index = index
        self.message = message
        self.sha = sha
        self.date = date
        self.branchName = branchName
    }

    var reference: String {
        "stash@{\(index)}"
    }

    var shortSHA: String {
        String(sha.prefix(7))
    }

    var displayMessage: String {
        // Remove "WIP on branch:" prefix if present
        if message.hasPrefix("WIP on ") {
            let parts = message.split(separator: ":", maxSplits: 1)
            if parts.count > 1 {
                return String(parts[1]).trimmingCharacters(in: .whitespaces)
            }
        }
        return message
    }

    var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    static func == (lhs: Stash, rhs: Stash) -> Bool {
        lhs.sha == rhs.sha
    }
}

/// Stash options
struct StashOptions {
    var message: String?
    var includeUntracked: Bool = true
    var keepIndex: Bool = false
    var all: Bool = false

    var arguments: [String] {
        var args: [String] = ["push"]

        if let message = message {
            args.append("-m")
            args.append(message)
        }

        if includeUntracked {
            args.append("--include-untracked")
        }

        if keepIndex {
            args.append("--keep-index")
        }

        if all {
            args.append("--all")
        }

        return args
    }
}

/// Stash apply options
struct StashApplyOptions {
    var index: Bool = false // --index flag to restore staged changes
    var stashRef: String = "stash@{0}"

    var arguments: [String] {
        var args: [String] = []

        if index {
            args.append("--index")
        }

        args.append(stashRef)

        return args
    }
}

/// Stash content (files changed in stash)
struct StashContent {
    let stash: Stash
    let files: [FileDiff]
    let stats: DiffStats

    var totalAdditions: Int { stats.additions }
    var totalDeletions: Int { stats.deletions }
    var filesChanged: Int { files.count }
}

/// Represents a file in a stash
struct StashFile: Identifiable {
    let id = UUID()
    let path: String
    let filename: String
    let status: FileStatusType

    var statusLetter: String {
        status.rawValue
    }

    var statusColor: Color {
        switch status {
        case .added: return .green
        case .modified: return .orange
        case .deleted: return .red
        case .renamed: return .blue
        case .copied: return .blue
        default: return .gray
        }
    }
}

import SwiftUI
