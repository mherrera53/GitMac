import Foundation

/// Service for managing branch protection rules
/// Prevents accidental force pushes and pushes to protected branches
@MainActor
class BranchProtectionService: ObservableObject {
    static let shared = BranchProtectionService()

    private let protectedPatternsKey = "protectedBranchPatterns"
    private let forcePushEnabledKey = "forcePushProtectionEnabled"

    /// Whether force push protection is enabled globally
    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: forcePushEnabledKey) }
    }

    /// Branch name patterns that are protected (supports wildcards)
    @Published var protectedPatterns: [String] {
        didSet { UserDefaults.standard.set(protectedPatterns, forKey: protectedPatternsKey) }
    }

    private init() {
        self.isEnabled = UserDefaults.standard.object(forKey: forcePushEnabledKey) as? Bool ?? true
        self.protectedPatterns = UserDefaults.standard.stringArray(forKey: protectedPatternsKey)
            ?? ["main", "master", "develop", "release/*", "hotfix/*"]
    }

    /// Check if a branch is protected
    func isProtected(_ branchName: String) -> Bool {
        guard isEnabled else { return false }
        return protectedPatterns.contains { pattern in
            matchesPattern(branchName, pattern: pattern)
        }
    }

    /// Evaluate push and return the protection level
    func evaluatePush(branchName: String, isForce: Bool, isForceWithLease: Bool) -> PushProtectionResult {
        let protected = isProtected(branchName)

        if isForce && protected {
            return .blocked(
                reason: "Force push to protected branch '\(branchName)' is blocked.",
                severity: .critical
            )
        }

        if isForce {
            return .requiresConfirmation(
                reason: "You are about to force push to '\(branchName)'. This will rewrite remote history and may cause data loss for collaborators.",
                severity: .warning
            )
        }

        if isForceWithLease && protected {
            return .requiresConfirmation(
                reason: "Force push with lease to protected branch '\(branchName)'. This is safer than --force but still rewrites history.",
                severity: .warning
            )
        }

        if isForceWithLease {
            return .requiresConfirmation(
                reason: "Force push with lease to '\(branchName)'. Remote history will be rewritten if no one else has pushed.",
                severity: .info
            )
        }

        if protected {
            return .requiresConfirmation(
                reason: "Pushing to protected branch '\(branchName)'. Please ensure this is intentional.",
                severity: .info
            )
        }

        return .allowed
    }

    // MARK: - Pattern Matching

    private func matchesPattern(_ name: String, pattern: String) -> Bool {
        if pattern.contains("*") {
            // Simple wildcard matching: "release/*" matches "release/1.0"
            let parts = pattern.split(separator: "*", maxSplits: 1, omittingEmptySubsequences: false)
            if parts.count == 2 {
                let prefix = String(parts[0])
                let suffix = String(parts[1])
                return name.hasPrefix(prefix) && name.hasSuffix(suffix)
            }
        }
        return name == pattern
    }
}

// MARK: - Protection Result

enum PushProtectionResult {
    case allowed
    case requiresConfirmation(reason: String, severity: ProtectionSeverity)
    case blocked(reason: String, severity: ProtectionSeverity)

    var isAllowed: Bool {
        if case .allowed = self { return true }
        return false
    }
}

enum ProtectionSeverity {
    case info
    case warning
    case critical

    var title: String {
        switch self {
        case .info: return "Push Confirmation"
        case .warning: return "Force Push Warning"
        case .critical: return "Push Blocked"
        }
    }

    var icon: String {
        switch self {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.octagon.fill"
        }
    }
}

// MARK: - Push Confirmation Model

struct PushConfirmation: Identifiable {
    let id = UUID()
    let branchName: String
    let result: PushProtectionResult
    let onConfirm: () async -> Void
    let onCancel: () -> Void
}
