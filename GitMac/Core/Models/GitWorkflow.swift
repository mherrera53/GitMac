import Foundation

struct GitWorkflow: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var icon: String
    var color: String
    var triggerCondition: WorkflowTrigger
    var steps: [WorkflowStep]
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        color: String,
        triggerCondition: WorkflowTrigger,
        steps: [WorkflowStep],
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.triggerCondition = triggerCondition
        self.steps = steps
        self.isEnabled = isEnabled
    }
}

enum WorkflowTrigger: Codable, Equatable {
    case always
    case onBranch(pattern: String)
    case notOnBranch(pattern: String)
    case hasStaged
    case manual
}

enum WorkflowStep: Codable, Equatable, Identifiable {
    var id: String {
        switch self {
        case .fetch(let r): return "fetch-\(r)"
        case .createBranch(let s): return "branch-\(s)"
        case .checkout(let b): return "checkout-\(b)"
        case .checkoutMain: return "checkoutMain"
        case .stash: return "stash"
        case .stashPop: return "stashPop"
        case .stageAll: return "stageAll"
        case .stageFiles(let p): return "stageFiles-\(p.joined())"
        case .commit(let s): return "commit-\(s)"
        case .push(let u, let f): return "push-\(u)-\(f)"
        case .pull(let r): return "pull-\(r)"
        case .rebaseOnMain: return "rebaseOnMain"
        case .createTag(let s): return "tag-\(s)"
        case .openPR(let d, let a): return "openPR-\(d)-\(a)"
        case .runCommand(let c): return "run-\(c)"
        case .notify(let m): return "notify-\(m)"
        case .waitForConfirmation(let m): return "wait-\(m)"
        }
    }

    case fetch(remote: String)
    case createBranch(nameStrategy: BranchNameStrategy)
    case checkout(branch: String)
    case checkoutMain
    case stash
    case stashPop
    case stageAll
    case stageFiles(patterns: [String])
    case commit(messageStrategy: CommitMessageStrategy)
    case push(setUpstream: Bool, force: Bool)
    case pull(rebase: Bool)
    case rebaseOnMain
    case createTag(nameStrategy: BranchNameStrategy)
    case openPR(draft: Bool, autoFill: Bool)
    case runCommand(command: String)
    case notify(message: String)
    case waitForConfirmation(message: String)

    var displayName: String {
        switch self {
        case .fetch(let r): return "Fetch (\(r))"
        case .createBranch: return "Create Branch"
        case .checkout(let b): return "Checkout \(b)"
        case .checkoutMain: return "Checkout Main"
        case .stash: return "Stash"
        case .stashPop: return "Stash Pop"
        case .stageAll: return "Stage All"
        case .stageFiles: return "Stage Files"
        case .commit: return "Commit"
        case .push(let u, let f): return u ? "Push (set upstream)" : f ? "Push (force)" : "Push"
        case .pull(let r): return r ? "Pull (rebase)" : "Pull"
        case .rebaseOnMain: return "Rebase on Main"
        case .createTag: return "Create Tag"
        case .openPR: return "Open PR"
        case .runCommand(let c): return "Run: \(c)"
        case .notify(let m): return "Notify: \(m)"
        case .waitForConfirmation: return "Wait for Confirmation"
        }
    }

    var icon: String {
        switch self {
        case .fetch: return "arrow.down.circle"
        case .createBranch: return "arrow.triangle.branch"
        case .checkout, .checkoutMain: return "arrow.right.circle"
        case .stash: return "tray.and.arrow.down"
        case .stashPop: return "tray.and.arrow.up"
        case .stageAll: return "plus.circle"
        case .stageFiles: return "doc.badge.plus"
        case .commit: return "checkmark.circle"
        case .push: return "arrow.up.circle"
        case .pull: return "arrow.down.circle.fill"
        case .rebaseOnMain: return "arrow.triangle.merge"
        case .createTag: return "tag"
        case .openPR: return "arrow.triangle.pull"
        case .runCommand: return "terminal"
        case .notify: return "bell"
        case .waitForConfirmation: return "hand.raised"
        }
    }
}

enum BranchNameStrategy: Codable, Equatable, CustomStringConvertible {
    case aiGenerated
    case fromCommitMessage
    case userInput
    case template(String)

    var description: String {
        switch self {
        case .aiGenerated: return "aiGenerated"
        case .fromCommitMessage: return "fromCommitMessage"
        case .userInput: return "userInput"
        case .template(let t): return "template(\(t))"
        }
    }
}

enum CommitMessageStrategy: Codable, Equatable, CustomStringConvertible {
    case userProvided
    case aiGenerated
    case template(String)

    var description: String {
        switch self {
        case .userProvided: return "userProvided"
        case .aiGenerated: return "aiGenerated"
        case .template(let t): return "template(\(t))"
        }
    }
}

// MARK: - Default Workflows

extension GitWorkflow {
    static let defaultWorkflows: [GitWorkflow] = [
        GitWorkflow(
            name: "Quick Commit",
            icon: "checkmark.circle",
            color: "#4CAF50",
            triggerCondition: .always,
            steps: [.commit(messageStrategy: .userProvided)],
            isEnabled: true
        ),
        GitWorkflow(
            name: "Smart Commit (from main)",
            icon: "arrow.triangle.branch",
            color: "#2196F3",
            triggerCondition: .onBranch(pattern: "main|master"),
            steps: [
                .stash,
                .createBranch(nameStrategy: .aiGenerated),
                .stashPop,
                .stageAll,
                .commit(messageStrategy: .userProvided),
                .push(setUpstream: true, force: false),
                .openPR(draft: false, autoFill: true)
            ],
            isEnabled: true
        ),
        GitWorkflow(
            name: "Commit & PR",
            icon: "arrow.up.circle",
            color: "#FF9800",
            triggerCondition: .notOnBranch(pattern: "main|master"),
            steps: [
                .commit(messageStrategy: .userProvided),
                .push(setUpstream: false, force: false),
                .openPR(draft: false, autoFill: true)
            ],
            isEnabled: true
        ),
        GitWorkflow(
            name: "Hotfix Express",
            icon: "flame",
            color: "#F44336",
            triggerCondition: .manual,
            steps: [
                .stash,
                .checkoutMain,
                .pull(rebase: true),
                .createBranch(nameStrategy: .template("hotfix/{{date}}-{{short_desc}}")),
                .stashPop,
                .stageAll,
                .commit(messageStrategy: .userProvided),
                .push(setUpstream: true, force: false),
                .openPR(draft: false, autoFill: true),
                .notify(message: "Hotfix branch created and PR opened")
            ],
            isEnabled: false
        ),
        GitWorkflow(
            name: "Feature Complete",
            icon: "checkmark.seal",
            color: "#9C27B0",
            triggerCondition: .notOnBranch(pattern: "main|master"),
            steps: [
                .fetch(remote: "origin"),
                .rebaseOnMain,
                .stageAll,
                .commit(messageStrategy: .userProvided),
                .push(setUpstream: true, force: true),
                .openPR(draft: false, autoFill: true),
                .notify(message: "Feature branch rebased and PR created")
            ],
            isEnabled: false
        ),
        GitWorkflow(
            name: "WIP Save",
            icon: "clock.badge.checkmark",
            color: "#607D8B",
            triggerCondition: .always,
            steps: [
                .stageAll,
                .commit(messageStrategy: .template("wip: {{message}}")),
                .push(setUpstream: true, force: false),
                .notify(message: "Work in progress saved and pushed")
            ],
            isEnabled: false
        ),
        GitWorkflow(
            name: "Release Cut",
            icon: "shippingbox",
            color: "#E91E63",
            triggerCondition: .onBranch(pattern: "main|master"),
            steps: [
                .pull(rebase: false),
                .createBranch(nameStrategy: .userInput),
                .createTag(nameStrategy: .userInput),
                .push(setUpstream: true, force: false),
                .openPR(draft: false, autoFill: true),
                .notify(message: "Release branch and tag created")
            ],
            isEnabled: false
        ),
        GitWorkflow(
            name: "Sync Branch",
            icon: "arrow.triangle.2.circlepath",
            color: "#00BCD4",
            triggerCondition: .notOnBranch(pattern: "main|master"),
            steps: [
                .fetch(remote: "origin"),
                .rebaseOnMain,
                .push(setUpstream: false, force: true),
                .notify(message: "Branch synced with main")
            ],
            isEnabled: false
        )
    ]
}
