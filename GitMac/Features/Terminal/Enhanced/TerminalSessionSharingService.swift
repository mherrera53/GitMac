//
//  TerminalSessionSharingService.swift
//  GitMac
//
//  Session sharing and collaboration for terminal
//

import Foundation
import SwiftUI

// MARK: - Terminal Session Model

struct TerminalSession: Identifiable, Codable {
    let id: UUID
    let name: String
    let createdAt: Date
    var commands: [TrackedCommand]
    var collaborators: [Collaborator]
    var isShared: Bool
    var shareToken: String?

    init(name: String, commands: [TrackedCommand] = []) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.commands = commands
        self.collaborators = []
        self.isShared = false
    }
}

struct Collaborator: Identifiable, Codable {
    let id: UUID
    let name: String
    let email: String?
    var isActive: Bool
    var joinedAt: Date

    init(name: String, email: String? = nil) {
        self.id = UUID()
        self.name = name
        self.email = email
        self.isActive = true
        self.joinedAt = Date()
    }
}

// MARK: - Session Export Format

struct SessionExport: Codable {
    let session: TerminalSession
    let exportedAt: Date
    let exportedBy: String
    let version: String

    init(session: TerminalSession, exportedBy: String) {
        self.session = session
        self.exportedAt = Date()
        self.exportedBy = exportedBy
        self.version = "1.0"
    }
}

// MARK: - Session Sharing Service

@MainActor
class TerminalSessionSharingService: ObservableObject {
    static let shared = TerminalSessionSharingService()

    @Published var currentSession: TerminalSession?
    @Published var savedSessions: [TerminalSession] = []
    @Published var sharedSessions: [TerminalSession] = []

    private init() {
        loadSessions()
    }

    // MARK: - Session Management

    func createSession(name: String, commands: [TrackedCommand]) -> TerminalSession {
        let session = TerminalSession(name: name, commands: commands)
        savedSessions.append(session)
        currentSession = session
        saveSessions()
        return session
    }

    func saveCurrentSession(name: String, commands: [TrackedCommand]) {
        if var session = currentSession {
            session.commands = commands
            if let index = savedSessions.firstIndex(where: { $0.id == session.id }) {
                savedSessions[index] = session
            }
        } else {
            _ = createSession(name: name, commands: commands)
        }
        saveSessions()
    }

    func deleteSession(_ id: UUID) {
        savedSessions.removeAll { $0.id == id }
        if currentSession?.id == id {
            currentSession = nil
        }
        saveSessions()
    }

    // MARK: - Export/Import

    func exportSession(_ session: TerminalSession) throws -> Data {
        let export = SessionExport(session: session, exportedBy: NSFullUserName())
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(export)
    }

    func exportSessionToFile(_ session: TerminalSession) throws -> URL {
        let data = try exportSession(session)

        // Create filename
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let timestamp = formatter.string(from: Date())
        let filename = "terminal-session-\(session.name.replacingOccurrences(of: " ", with: "-"))-\(timestamp).json"

        // Save to Downloads folder
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        let fileURL = downloadsURL.appendingPathComponent(filename)

        try data.write(to: fileURL)
        return fileURL
    }

    func importSession(from url: URL) throws -> TerminalSession {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let export = try decoder.decode(SessionExport.self, from: data)
        var session = export.session

        // Generate new ID to avoid conflicts
        session = TerminalSession(name: "\(session.name) (Imported)", commands: session.commands)

        savedSessions.append(session)
        saveSessions()

        return session
    }

    func importSession(from data: Data) throws -> TerminalSession {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let export = try decoder.decode(SessionExport.self, from: data)
        var session = export.session

        // Generate new ID
        session = TerminalSession(name: "\(session.name) (Imported)", commands: session.commands)

        savedSessions.append(session)
        saveSessions()

        return session
    }

    // MARK: - Sharing

    func shareSession(_ session: TerminalSession) -> String {
        // Generate share token
        let token = generateShareToken()

        // Update session
        if let index = savedSessions.firstIndex(where: { $0.id == session.id }) {
            savedSessions[index].isShared = true
            savedSessions[index].shareToken = token
            saveSessions()
        }

        // In a real implementation, this would upload to a server
        // For now, we'll just return the token
        return token
    }

    func unshareSession(_ session: TerminalSession) {
        if let index = savedSessions.firstIndex(where: { $0.id == session.id }) {
            savedSessions[index].isShared = false
            savedSessions[index].shareToken = nil
            saveSessions()
        }
    }

    func joinSharedSession(token: String) async throws -> TerminalSession {
        // In a real implementation, this would fetch from a server
        // For now, we'll throw an error
        throw NSError(domain: "TerminalSessionSharing",
                     code: 1,
                     userInfo: [NSLocalizedDescriptionKey: "Server-based sharing not yet implemented. Use Export/Import for now."])
    }

    // MARK: - Collaborators

    func addCollaborator(_ collaborator: Collaborator, to sessionId: UUID) {
        if let index = savedSessions.firstIndex(where: { $0.id == sessionId }) {
            savedSessions[index].collaborators.append(collaborator)
            saveSessions()
        }
    }

    func removeCollaborator(_ collaboratorId: UUID, from sessionId: UUID) {
        if let sessionIndex = savedSessions.firstIndex(where: { $0.id == sessionId }) {
            savedSessions[sessionIndex].collaborators.removeAll { $0.id == collaboratorId }
            saveSessions()
        }
    }

    // MARK: - Persistence

    private func saveSessions() {
        guard let data = try? JSONEncoder().encode(savedSessions) else { return }
        UserDefaults.standard.set(data, forKey: "terminal.savedSessions")
    }

    private func loadSessions() {
        guard let data = UserDefaults.standard.data(forKey: "terminal.savedSessions"),
              let sessions = try? JSONDecoder().decode([TerminalSession].self, from: data) else {
            return
        }
        savedSessions = sessions
    }

    private func generateShareToken() -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<32).map { _ in characters.randomElement()! })
    }

    // MARK: - Session Analytics

    func getSessionStats(_ session: TerminalSession) -> SessionStats {
        let totalCommands = session.commands.count
        let successfulCommands = session.commands.filter { $0.exitCode == 0 }.count
        let failedCommands = session.commands.filter { ($0.exitCode ?? 0) != 0 }.count
        let totalDuration = session.commands.compactMap { $0.duration }.reduce(0, +)

        let gitCommands = session.commands.filter { $0.command.starts(with: "git ") }.count

        return SessionStats(
            totalCommands: totalCommands,
            successfulCommands: successfulCommands,
            failedCommands: failedCommands,
            totalDuration: totalDuration,
            gitCommands: gitCommands,
            collaboratorCount: session.collaborators.count
        )
    }
}

struct SessionStats {
    let totalCommands: Int
    let successfulCommands: Int
    let failedCommands: Int
    let totalDuration: TimeInterval
    let gitCommands: Int
    let collaboratorCount: Int

    var successRate: Double {
        guard totalCommands > 0 else { return 0 }
        return Double(successfulCommands) / Double(totalCommands)
    }

    var averageDuration: TimeInterval {
        guard totalCommands > 0 else { return 0 }
        return totalDuration / Double(totalCommands)
    }
}

// MARK: - Session Sharing UI

struct SessionSharingSheet: View {
    let session: TerminalSession
    @Environment(\.dismiss) var dismiss
    @State private var shareToken: String = ""
    @State private var showCopied = false

    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Share Session")
                .font(.system(size: 18, weight: .semibold))

            // Session Info
            VStack(alignment: .leading, spacing: 8) {
                Text(session.name)
                    .font(.system(size: 16, weight: .medium))
                Text("\(session.commands.count) commands")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(AppTheme.backgroundSecondary)
            .cornerRadius(8)

            // Export Options
            VStack(spacing: 12) {
                Button {
                    exportToFile()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Export to File")
                        Spacer()
                    }
                    .padding()
                    .background(AppTheme.backgroundSecondary)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Button {
                    copyToClipboard()
                } label: {
                    HStack {
                        Image(systemName: "doc.on.doc")
                        Text(showCopied ? "Copied!" : "Copy Session Data")
                        Spacer()
                        if showCopied {
                            Image(systemName: "checkmark")
                                .foregroundColor(AppTheme.success)
                        }
                    }
                    .padding()
                    .background(AppTheme.backgroundSecondary)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button("Done") {
                dismiss()
            }
            .foregroundColor(AppTheme.accent)
        }
        .padding()
        .frame(width: 400, height: 300)
        .background(AppTheme.background)
    }

    private func exportToFile() {
        do {
            let url = try TerminalSessionSharingService.shared.exportSessionToFile(session)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            print("Export failed: \(error)")
        }
    }

    private func copyToClipboard() {
        do {
            let data = try TerminalSessionSharingService.shared.exportSession(session)
            if let jsonString = String(data: data, encoding: .utf8) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(jsonString, forType: .string)
                showCopied = true

                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showCopied = false
                }
            }
        } catch {
            print("Copy failed: \(error)")
        }
    }
}
