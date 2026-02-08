import Foundation

// MARK: - Graph Notification Names
extension Notification.Name {
    static let createBranchFromCommit = Notification.Name("createBranchFromCommit")
    static let createTagFromCommit = Notification.Name("createTagFromCommit")
    static let cherryPickCommit = Notification.Name("cherryPickCommit")
    static let revertCommit = Notification.Name("revertCommit")
    static let resetToCommit = Notification.Name("resetToCommit")
    static let rebaseOntoCommit = Notification.Name("rebaseOntoCommit")
    static let interactiveRebase = Notification.Name("interactiveRebase")
    static let diffWithHead = Notification.Name("diffWithHead")
    static let compareCommit = Notification.Name("compareCommit")
    static let showStaleBranchCleanup = Notification.Name("showStaleBranchCleanup")
}
