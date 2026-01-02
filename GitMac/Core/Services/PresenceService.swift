//
//  PresenceService.swift
//  GitMac
//
//  Real-time presence using Bonjour/mDNS for local network discovery
//

import SwiftUI
import Network
import Combine

// MARK: - Active User Model

struct ActiveUser: Identifiable, Equatable, Codable {
    let id: String
    let name: String
    let email: String
    let hostName: String
    var currentFile: String?
    var currentRepository: String?
    var lastSeen: Date
    var status: UserStatus
    
    enum UserStatus: String, Codable {
        case active = "active"
        case idle = "idle"
        case away = "away"
        
        @MainActor var color: Color {
            switch self {
            case .active: return AppTheme.success
            case .idle: return AppTheme.warning
            case .away: return AppTheme.textMuted
            }
        }
    }
    
    var gravatarURL: URL? {
        let hash = email.lowercased().trimmingCharacters(in: .whitespaces).md5Hash
        return URL(string: "https://www.gravatar.com/avatar/\(hash)?d=identicon&s=32")
    }
}

// MARK: - Presence Message

struct PresenceMessage: Codable {
    let userId: String
    let userName: String
    let userEmail: String
    let hostName: String
    let repositoryPath: String?
    let currentFile: String?
    let status: ActiveUser.UserStatus
    let timestamp: Date
}

// MARK: - Presence Service

@MainActor
class PresenceService: ObservableObject {
    static let shared = PresenceService()
    
    // MARK: - Published Properties
    
    @Published var activeUsers: [ActiveUser] = []
    @Published var isEnabled: Bool = false {
        didSet {
            if isEnabled {
                startBroadcasting()
            } else {
                stopBroadcasting()
            }
            UserDefaults.standard.set(isEnabled, forKey: "presenceEnabled")
        }
    }
    @Published var connectionStatus: ConnectionStatus = .disconnected
    
    enum ConnectionStatus {
        case disconnected
        case connecting
        case connected
        case error(String)
        
        var displayName: String {
            switch self {
            case .disconnected: return "Disconnected"
            case .connecting: return "Connecting..."
            case .connected: return "Connected"
            case .error: return "Error"
            }
        }
    }
    
    // MARK: - Private Properties
    
    private let serviceType = "_gitmac._tcp"
    private let serviceDomain = "local."
    private var listener: NWListener?
    private var browser: NWBrowser?
    private var connections: [String: NWConnection] = [:]
    private var broadcastTimer: Timer?
    private var cleanupTimer: Timer?
    
    private var currentUser: ActiveUser?
    private var currentRepository: String?
    private var currentFile: String?
    
    private init() {
        isEnabled = UserDefaults.standard.bool(forKey: "presenceEnabled")
        
        // Start cleanup timer
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.cleanupStaleUsers()
            }
        }
    }
    
    // Cleanup handled by stopBroadcasting()
    
    // MARK: - User Configuration
    
    func configureUser(name: String, email: String) {
        let hostName = Host.current().localizedName ?? "Unknown"
        currentUser = ActiveUser(
            id: UUID().uuidString,
            name: name,
            email: email,
            hostName: hostName,
            currentFile: nil,
            currentRepository: nil,
            lastSeen: Date(),
            status: .active
        )
    }
    
    func updateCurrentLocation(repository: String?, file: String?) {
        currentRepository = repository
        currentFile = file
        broadcastPresence()
    }
    
    func updateStatus(_ status: ActiveUser.UserStatus) {
        currentUser?.status = status
        broadcastPresence()
    }
    
    // MARK: - Broadcasting
    
    func startBroadcasting() {
        guard currentUser != nil else {
            // Configure with default user
            configureUser(
                name: NSFullUserName(),
                email: "\(NSUserName())@\(Host.current().localizedName ?? "local")"
            )
            return startBroadcasting()
        }
        
        connectionStatus = .connecting
        
        // Start listener
        startListener()
        
        // Start browser
        startBrowser()
        
        // Start broadcast timer
        broadcastTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.broadcastPresence()
            }
        }
        
        connectionStatus = .connected
    }
    
    func stopBroadcasting() {
        broadcastTimer?.invalidate()
        broadcastTimer = nil
        
        listener?.cancel()
        listener = nil
        
        browser?.cancel()
        browser = nil
        
        for connection in connections.values {
            connection.cancel()
        }
        connections.removeAll()
        
        activeUsers.removeAll()
        connectionStatus = .disconnected
    }
    
    // MARK: - Network Listener
    
    private func startListener() {
        do {
            let parameters = NWParameters.tcp
            parameters.includePeerToPeer = true
            
            listener = try NWListener(using: parameters)
            listener?.service = NWListener.Service(type: serviceType, domain: serviceDomain)
            
            listener?.stateUpdateHandler = { [weak self] state in
                Task { @MainActor [weak self] in
                    switch state {
                    case .ready:
                        self?.connectionStatus = .connected
                    case .failed(let error):
                        self?.connectionStatus = .error(error.localizedDescription)
                    default:
                        break
                    }
                }
            }
            
            listener?.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in
                    self?.handleNewConnection(connection)
                }
            }
            
            listener?.start(queue: .global(qos: .userInitiated))
        } catch {
            connectionStatus = .error(error.localizedDescription)
        }
    }
    
    // MARK: - Network Browser
    
    private func startBrowser() {
        let descriptor = NWBrowser.Descriptor.bonjour(type: serviceType, domain: serviceDomain)
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        
        browser = NWBrowser(for: descriptor, using: parameters)
        
        browser?.browseResultsChangedHandler = { [weak self] results, changes in
            Task { @MainActor [weak self] in
                self?.handleBrowseResults(results)
            }
        }
        
        browser?.start(queue: .global(qos: .userInitiated))
    }
    
    private func handleBrowseResults(_ results: Set<NWBrowser.Result>) {
        for result in results {
            if case .service(let name, _, _, _) = result.endpoint {
                // Don't connect to ourselves
                if name != currentUser?.id {
                    connectToPeer(result.endpoint)
                }
            }
        }
    }
    
    // MARK: - Connections
    
    private func connectToPeer(_ endpoint: NWEndpoint) {
        let connection = NWConnection(to: endpoint, using: .tcp)
        
        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                switch state {
                case .ready:
                    self?.receiveMessage(from: connection)
                case .cancelled, .failed:
                    if case .service(let name, _, _, _) = endpoint {
                        self?.connections.removeValue(forKey: name)
                        self?.activeUsers.removeAll { $0.id == name }
                    }
                default:
                    break
                }
            }
        }
        
        if case .service(let name, _, _, _) = endpoint {
            connections[name] = connection
        }
        
        connection.start(queue: .global(qos: .userInitiated))
    }
    
    private func handleNewConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                switch state {
                case .ready:
                    self?.receiveMessage(from: connection)
                default:
                    break
                }
            }
        }
        
        connection.start(queue: .global(qos: .userInitiated))
    }
    
    // MARK: - Message Handling
    
    private func broadcastPresence() {
        guard let user = currentUser else { return }
        
        let message = PresenceMessage(
            userId: user.id,
            userName: user.name,
            userEmail: user.email,
            hostName: user.hostName,
            repositoryPath: currentRepository,
            currentFile: currentFile,
            status: user.status,
            timestamp: Date()
        )
        
        guard let data = try? JSONEncoder().encode(message) else { return }
        
        for connection in connections.values {
            connection.send(content: data, completion: .idempotent)
        }
    }
    
    private func receiveMessage(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
            Task { @MainActor [weak self] in
                if let data = data,
                   let message = try? JSONDecoder().decode(PresenceMessage.self, from: data) {
                    self?.handlePresenceMessage(message)
                }
                
                if error == nil {
                    self?.receiveMessage(from: connection)
                }
            }
        }
    }
    
    private func handlePresenceMessage(_ message: PresenceMessage) {
        let user = ActiveUser(
            id: message.userId,
            name: message.userName,
            email: message.userEmail,
            hostName: message.hostName,
            currentFile: message.currentFile,
            currentRepository: message.repositoryPath,
            lastSeen: message.timestamp,
            status: message.status
        )
        
        if let index = activeUsers.firstIndex(where: { $0.id == user.id }) {
            activeUsers[index] = user
        } else {
            activeUsers.append(user)
        }
    }
    
    // MARK: - Cleanup
    
    private func cleanupStaleUsers() {
        let staleThreshold = Date().addingTimeInterval(-60) // 1 minute
        activeUsers.removeAll { $0.lastSeen < staleThreshold }
    }
}

// MARK: - Presence Indicator View

struct PresenceIndicatorView: View {
    @StateObject private var presenceService = PresenceService.shared
    
    var body: some View {
        if presenceService.isEnabled {
            HStack(spacing: DesignTokens.Spacing.sm) {
                // Connection status
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                
                // Active users count
                if !presenceService.activeUsers.isEmpty {
                    Text("\(presenceService.activeUsers.count) online")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                    
                    // User avatars
                    HStack(spacing: -4) {
                        ForEach(presenceService.activeUsers.prefix(3)) { user in
                            AsyncImage(url: user.gravatarURL) { image in
                                image.resizable()
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                            .frame(width: 20, height: 20)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(AppTheme.background, lineWidth: 1)
                            )
                        }
                        
                        if presenceService.activeUsers.count > 3 {
                            Text("+\(presenceService.activeUsers.count - 3)")
                                .font(.caption2)
                                .foregroundColor(AppTheme.textMuted)
                                .frame(width: 20, height: 20)
                                .background(AppTheme.backgroundTertiary)
                                .clipShape(Circle())
                        }
                    }
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(AppTheme.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.sm)
        }
    }
    
    private var statusColor: Color {
        switch presenceService.connectionStatus {
        case .connected: return AppTheme.success
        case .connecting: return AppTheme.warning
        case .disconnected: return AppTheme.textMuted
        case .error: return AppTheme.error
        }
    }
}

// MARK: - Active Users Panel

struct ActiveUsersPanel: View {
    @StateObject private var presenceService = PresenceService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // Header
            HStack {
                Text("Team Online")
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
                
                Spacer()
                
                Toggle("", isOn: $presenceService.isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            
            if presenceService.isEnabled {
                if presenceService.activeUsers.isEmpty {
                    VStack(spacing: DesignTokens.Spacing.sm) {
                        Image(systemName: "person.2.slash")
                            .font(.title)
                            .foregroundColor(AppTheme.textMuted)
                        
                        Text("No team members online")
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else {
                    ForEach(presenceService.activeUsers) { user in
                        ActiveUserRow(user: user)
                    }
                }
            } else {
                Text("Enable presence to see team members")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .padding()
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(DesignTokens.CornerRadius.md)
    }
}

struct ActiveUserRow: View {
    let user: ActiveUser
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // Avatar with status
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: user.gravatarURL) { image in
                    image.resizable()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundColor(AppTheme.textSecondary)
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                
                Circle()
                    .fill(user.status.color)
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle()
                            .stroke(AppTheme.backgroundSecondary, lineWidth: 2)
                    )
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(user.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.textPrimary)
                
                if let file = user.currentFile {
                    Text(file.components(separatedBy: "/").last ?? file)
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                        .lineLimit(1)
                } else if let repo = user.currentRepository {
                    Text(repo.components(separatedBy: "/").last ?? repo)
                        .font(.caption)
                        .foregroundColor(AppTheme.textMuted)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Host name
            Text(user.hostName)
                .font(.caption2)
                .foregroundColor(AppTheme.textMuted)
        }
        .padding(DesignTokens.Spacing.sm)
        .background(AppTheme.backgroundTertiary.opacity(0.5))
        .cornerRadius(DesignTokens.CornerRadius.sm)
    }
}
