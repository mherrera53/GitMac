import Foundation

// MARK: - Timeline Item (Commit or Stash or Uncommitted Changes)
enum TimelineItem: Identifiable {
    case uncommitted(staged: Int, unstaged: Int)
    case commit(GraphNode)
    case stash(StashNode)

    var id: String {
        switch self {
        case .uncommitted: return "uncommitted-changes"
        case .commit(let node): return node.id
        case .stash(let stash): return stash.id
        }
    }

    var date: Date {
        switch self {
        case .uncommitted: return Date() // Always most recent
        case .commit(let node): return node.commit.authorDate
        case .stash(let stash): return stash.stash.date
        }
    }
}
