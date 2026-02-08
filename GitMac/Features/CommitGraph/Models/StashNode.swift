import Foundation

// MARK: - Stash Node Model
struct StashNode: Identifiable {
    let id: String
    let stash: Stash
}

// MARK: - Stash Notification Names
extension Notification.Name {
    static let applyStash = Notification.Name("applyStash")
    static let popStashAtIndex = Notification.Name("popStashAtIndex")
    static let dropStash = Notification.Name("dropStash")
    static let loadFirstFileDiff = Notification.Name("loadFirstFileDiff")
}
