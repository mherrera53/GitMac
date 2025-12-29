import Foundation
import SwiftUI

/// Remote Operation Status - Tracks push/pull/fetch operations
@MainActor
class RemoteOperationTracker: ObservableObject {
    static let shared = RemoteOperationTracker()
    
    @Published var lastOperation: RemoteOperation?
    @Published var operations: [RemoteOperation] = []
    
    private let maxOperations = 50
    
    func recordPush(success: Bool, branch: String, remote: String = "origin", error: String? = nil, commitCount: Int = 0) {
        let operation = RemoteOperation(
            type: .push,
            success: success,
            branch: branch,
            remote: remote,
            timestamp: Date(),
            error: error,
            commitCount: commitCount
        )
        
        addOperation(operation)
    }
    
    func recordPull(success: Bool, branch: String, remote: String = "origin", error: String? = nil, commitCount: Int = 0) {
        let operation = RemoteOperation(
            type: .pull,
            success: success,
            branch: branch,
            remote: remote,
            timestamp: Date(),
            error: error,
            commitCount: commitCount
        )
        
        addOperation(operation)
    }
    
    func recordFetch(success: Bool, remote: String = "origin", error: String? = nil) {
        let operation = RemoteOperation(
            type: .fetch,
            success: success,
            branch: "",
            remote: remote,
            timestamp: Date(),
            error: error
        )

        addOperation(operation)
    }

    func recordMerge(success: Bool, sourceBranch: String, targetBranch: String, error: String? = nil) {
        let operation = RemoteOperation(
            type: .merge,
            success: success,
            branch: "\(sourceBranch) → \(targetBranch)",
            remote: "",
            timestamp: Date(),
            error: error
        )

        addOperation(operation)
    }
    
    private func addOperation(_ operation: RemoteOperation) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.lastOperation = operation
            self.operations.insert(operation, at: 0)
            
            // Limit size
            if self.operations.count > self.maxOperations {
                self.operations.removeLast()
            }
            
            // Save to UserDefaults
            self.saveOperations()
            
            // Post notification for UI updates
            NotificationCenter.default.post(name: .remoteOperationCompleted, object: operation)
        }
    }
    
    func getLastOperation(for branch: String, type: RemoteOperationType? = nil) -> RemoteOperation? {
        operations.first { op in
            op.branch == branch && (type == nil || op.type == type)
        }
    }
    
    func clearHistory() {
        operations.removeAll()
        lastOperation = nil
        saveOperations()
    }
    
    // MARK: - Persistence
    
    private func saveOperations() {
        if let encoded = try? JSONEncoder().encode(Array(operations.prefix(10))) {
            UserDefaults.standard.set(encoded, forKey: "remoteOperations")
        }
    }
    
    func loadOperations() {
        if let data = UserDefaults.standard.data(forKey: "remoteOperations"),
           let decoded = try? JSONDecoder().decode([RemoteOperation].self, from: data) {
            operations = decoded
            lastOperation = operations.first
        }
    }
}

// MARK: - Remote Operation Model

struct RemoteOperation: Identifiable, Codable {
    let id: UUID
    let type: RemoteOperationType
    let success: Bool
    let branch: String
    let remote: String
    let timestamp: Date
    let error: String?
    let commitCount: Int?
    
    init(
        id: UUID = UUID(),
        type: RemoteOperationType,
        success: Bool,
        branch: String,
        remote: String,
        timestamp: Date,
        error: String? = nil,
        commitCount: Int? = nil
    ) {
        self.id = id
        self.type = type
        self.success = success
        self.branch = branch
        self.remote = remote
        self.timestamp = timestamp
        self.error = error
        self.commitCount = commitCount
    }
    
    var displayMessage: String {
        let action = type.displayName
        let result = success ? "exitoso" : "falló"
        
        var msg = "\(action) \(result)"
        
        if let count = commitCount, count > 0 {
            msg += " (\(count) commits)"
        }
        
        if !success, let error = error {
            msg += ": \(error)"
        }
        
        return msg
    }
    
    var icon: String {
        if success {
            return type.successIcon
        } else {
            return "xmark.circle.fill"
        }
    }
    
    var color: Color {
        if success {
            return .green
        } else {
            return .red
        }
    }
}

enum RemoteOperationType: String, Codable {
    case push
    case pull
    case fetch
    case merge

    var displayName: String {
        switch self {
        case .push: return "Push"
        case .pull: return "Pull"
        case .fetch: return "Fetch"
        case .merge: return "Merge"
        }
    }

    var successIcon: String {
        switch self {
        case .push: return "arrow.up.circle.fill"
        case .pull: return "arrow.down.circle.fill"
        case .fetch: return "arrow.clockwise.circle.fill"
        case .merge: return "arrow.merge"
        }
    }
}

// MARK: - Remote Status Badge View

struct RemoteStatusBadge: View {
    let operation: RemoteOperation
    let compact: Bool
    
    init(operation: RemoteOperation, compact: Bool = false) {
        self.operation = operation
        self.compact = compact
    }
    
    var body: some View {
        if compact {
            compactView
        } else {
            fullView
        }
    }
    
    private var compactView: some View {
        Image(systemName: operation.icon)
            .font(.system(size: 12))
            .foregroundColor(operation.color)
            .help(operation.displayMessage)
    }
    
    private var fullView: some View {
        HStack(spacing: 6) {
            Image(systemName: operation.icon)
                .foregroundColor(operation.color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(operation.type.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Text(operation.success ? "Exitoso" : "Falló")
                    .font(.caption2)
                    .foregroundColor(AppTheme.textPrimary)
            }
            
            if let count = operation.commitCount, count > 0 {
                Text("\(count)")
                    .font(.caption2)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(operation.color.opacity(0.2))
                    .cornerRadius(3)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(operation.color.opacity(0.1))
        .cornerRadius(6)
        .help(operation.displayMessage)
    }
}

// MARK: - Graph Integration View

struct CommitGraphWithStatus: View {
    @ObservedObject var tracker = RemoteOperationTracker.shared
    let currentBranch: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // Status bar at top of graph
            if let operation = currentBranchOperation {
                statusBar(operation: operation)
            }
            
            // Original CommitGraphView
            CommitGraphView()
        }
    }
    
    private var currentBranchOperation: RemoteOperation? {
        guard let branch = currentBranch else { return nil }
        return tracker.getLastOperation(for: branch)
    }
    
    private func statusBar(operation: RemoteOperation) -> some View {
        HStack(spacing: 12) {
            RemoteStatusBadge(operation: operation, compact: false)
            
            Text(operation.timestamp.formatted(.relative(presentation: .named)))
                .font(.caption)
                .foregroundColor(AppTheme.textPrimary)
            
            Spacer()
            
            if !operation.success, let error = operation.error {
                Button {
                    // Show error details
                    NotificationManager.shared.error(
                        "\(operation.type.displayName) failed",
                        detail: error
                    )
                } label: {
                    Label("Details", systemImage: "info.circle")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(operation.color.opacity(0.05))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(operation.color.opacity(0.3)),
            alignment: .bottom
        )
    }
}

// MARK: - Remote Operations Panel

struct RemoteOperationsPanel: View {
    @ObservedObject var tracker = RemoteOperationTracker.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Remote Operations")
                    .font(.headline)
                
                Spacer()
                
                if !tracker.operations.isEmpty {
                    Button {
                        tracker.clearHistory()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(AppTheme.error)
                    }
                    .buttonStyle(.borderless)
                    .help("Clear History")
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Operations list
            if tracker.operations.isEmpty {
                emptyState
            } else {
                operationsList
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.up.arrow.down.circle")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.textPrimary)
            
            Text("No remote operations yet")
                .foregroundColor(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var operationsList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(tracker.operations) { operation in
                    RemoteOperationRow(operation: operation)
                }
            }
        }
    }
}

struct RemoteOperationRow: View {
    let operation: RemoteOperation
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: operation.icon)
                .font(.system(size: 20))
                .foregroundColor(operation.color)
                .frame(width: 32)
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(operation.type.displayName)
                        .fontWeight(.medium)
                    
                    Text("→")
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Text("\(operation.remote)/\(operation.branch)")
                        .foregroundColor(AppTheme.textPrimary)
                }
                .font(.body)
                
                if !operation.success, let error = operation.error {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(AppTheme.error)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Metadata
            VStack(alignment: .trailing, spacing: 2) {
                Text(operation.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundColor(AppTheme.textPrimary)
                
                if let count = operation.commitCount, count > 0 {
                    Text("\(count) commits")
                        .font(.caption2)
                        .foregroundColor(AppTheme.textPrimary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHovered ? AppTheme.textSecondary.opacity(0.05) : Color.clear)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let remoteOperationCompleted = Notification.Name("remoteOperationCompleted")
}
