//
//  GitProgressTracker.swift
//  GitMac
//
//  Service for tracking git operation progress in real-time
//

import SwiftUI
import Combine

@MainActor
class GitProgressTracker: ObservableObject {
    static let shared = GitProgressTracker()

    @Published var activeOperations: [GitOperation] = []

    private init() {}

    // MARK: - Operation Management

    func startOperation(type: GitOperation.OperationType, repositoryPath: String) -> UUID {
        let operation = GitOperation(type: type, repositoryPath: repositoryPath)
        activeOperations.append(operation)
        return operation.id
    }

    func updateProgress(operationId: UUID, phase: GitOperation.Phase, current: Int, total: Int, message: String? = nil) {
        guard let index = activeOperations.firstIndex(where: { $0.id == operationId }) else { return }

        activeOperations[index].progress = GitOperation.Progress(current: current, total: total)
        activeOperations[index].phase = phase
        if let message = message {
            activeOperations[index].message = message
        }
    }

    func completeOperation(operationId: UUID, success: Bool = true, error: Error? = nil) {
        guard let index = activeOperations.firstIndex(where: { $0.id == operationId }) else { return }

        if success {
            activeOperations[index].phase = .complete
        } else {
            activeOperations[index].phase = .failed(error ?? NSError(domain: "GitMac", code: -1))
        }

        // Remove after 2 seconds
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            activeOperations.removeAll(where: { $0.id == operationId })
        }
    }

    func cancelOperation(operationId: UUID) {
        activeOperations.removeAll(where: { $0.id == operationId })
    }

    // MARK: - Models

    struct GitOperation: Identifiable {
        let id = UUID()
        let type: OperationType
        let repositoryPath: String
        var progress: Progress
        var phase: Phase
        var message: String
        let startTime = Date()

        init(type: OperationType, repositoryPath: String) {
            self.type = type
            self.repositoryPath = repositoryPath
            self.progress = Progress(current: 0, total: 100)
            self.phase = .starting
            self.message = type.initialMessage
        }

        var isActive: Bool {
            switch phase {
            case .complete, .failed:
                return false
            default:
                return true
            }
        }

        enum OperationType {
            case push
            case pull
            case fetch
            case clone
            case sync

            var icon: String {
                switch self {
                case .push: return "arrow.up.circle"
                case .pull: return "arrow.down.circle"
                case .fetch: return "arrow.down.circle.dotted"
                case .clone: return "square.and.arrow.down"
                case .sync: return "arrow.triangle.2.circlepath"
                }
            }

            var initialMessage: String {
                switch self {
                case .push: return "Pushing changes..."
                case .pull: return "Pulling changes..."
                case .fetch: return "Fetching updates..."
                case .clone: return "Cloning repository..."
                case .sync: return "Syncing..."
                }
            }
        }

        enum Phase {
            case starting
            case counting
            case compressing
            case writing
            case receiving
            case resolving
            case updating
            case complete
            case failed(Error)

            var description: String {
                switch self {
                case .starting: return "Starting"
                case .counting: return "Counting objects"
                case .compressing: return "Compressing"
                case .writing: return "Writing objects"
                case .receiving: return "Receiving objects"
                case .resolving: return "Resolving deltas"
                case .updating: return "Updating refs"
                case .complete: return "Complete"
                case .failed: return "Failed"
                }
            }
        }

        struct Progress {
            var current: Int
            var total: Int

            var percentage: Double {
                total > 0 ? Double(current) / Double(total) * 100 : 0
            }

            var isIndeterminate: Bool {
                total == 0
            }
        }
    }
}

// MARK: - Progress Parsing Utilities

extension GitProgressTracker {
    /// Parse git progress output and extract progress information
    /// Examples:
    /// - "Counting objects: 100% (5/5)"
    /// - "Compressing objects: 50% (3/6)"
    /// - "Writing objects: 33% (1/3)"
    static func parseProgress(from output: String) -> (phase: GitOperation.Phase, current: Int, total: Int)? {
        let patterns: [(phase: GitOperation.Phase, pattern: String)] = [
            (.counting, "Counting objects:\\s+(\\d+)% \\((\\d+)/(\\d+)\\)"),
            (.compressing, "Compressing objects:\\s+(\\d+)% \\((\\d+)/(\\d+)\\)"),
            (.writing, "Writing objects:\\s+(\\d+)% \\((\\d+)/(\\d+)\\)"),
            (.receiving, "Receiving objects:\\s+(\\d+)% \\((\\d+)/(\\d+)\\)"),
            (.resolving, "Resolving deltas:\\s+(\\d+)% \\((\\d+)/(\\d+)\\)")
        ]

        for (phase, pattern) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)),
               match.numberOfRanges == 4 {

                let currentRange = Range(match.range(at: 2), in: output)
                let totalRange = Range(match.range(at: 3), in: output)

                if let currentRange = currentRange,
                   let totalRange = totalRange,
                   let current = Int(output[currentRange]),
                   let total = Int(output[totalRange]) {
                    return (phase, current, total)
                }
            }
        }

        return nil
    }
}
