import Foundation

/// Stores recent commit messages and user-defined templates
@MainActor
@Observable
final class CommitMessageHistory {
    static let shared = CommitMessageHistory()

    private static let recentMessagesKey = "com.gitmac.recentCommitMessages"
    private static let templatesKey = "com.gitmac.commitTemplates"
    private static let maxRecentMessages = 20

    var recentMessages: [String] = []
    var templates: [CommitTemplate] = []

    private init() {
        loadRecentMessages()
        loadTemplates()
    }

    func recordMessage(_ message: String) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Remove duplicate if exists
        recentMessages.removeAll { $0 == trimmed }
        // Insert at front
        recentMessages.insert(trimmed, at: 0)
        // Trim to max
        if recentMessages.count > Self.maxRecentMessages {
            recentMessages = Array(recentMessages.prefix(Self.maxRecentMessages))
        }
        saveRecentMessages()
    }

    func addTemplate(name: String, template: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTemplate = template.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedTemplate.isEmpty else { return }

        // Replace if name exists
        templates.removeAll { $0.name == trimmedName }
        templates.append(CommitTemplate(name: trimmedName, template: trimmedTemplate))
        saveTemplates()
    }

    func removeTemplate(at index: Int) {
        guard templates.indices.contains(index) else { return }
        templates.remove(at: index)
        saveTemplates()
    }

    func clearHistory() {
        recentMessages.removeAll()
        saveRecentMessages()
    }

    // MARK: - Persistence

    private func loadRecentMessages() {
        recentMessages = UserDefaults.standard.stringArray(forKey: Self.recentMessagesKey) ?? []
    }

    private func saveRecentMessages() {
        UserDefaults.standard.set(recentMessages, forKey: Self.recentMessagesKey)
    }

    private func loadTemplates() {
        guard let data = UserDefaults.standard.data(forKey: Self.templatesKey),
              let decoded = try? JSONDecoder().decode([CommitTemplate].self, from: data) else {
            return
        }
        templates = decoded
    }

    private func saveTemplates() {
        if let data = try? JSONEncoder().encode(templates) {
            UserDefaults.standard.set(data, forKey: Self.templatesKey)
        }
    }
}

struct CommitTemplate: Codable, Identifiable {
    var id: String { name }
    let name: String
    let template: String
}
