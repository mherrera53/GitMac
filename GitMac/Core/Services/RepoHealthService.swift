import Foundation
import Combine

@MainActor
@Observable
final class RepoHealthService {
    static let shared = RepoHealthService()

    var lastMaintenanceDate: Date?
    var conflictWarning: String?
    var conflictingFiles: [String] = []
    var isRunningMaintenance = false

    private let shell = ShellExecutor.shared
    private var maintenanceTimer: AnyCancellable?
    private var conflictTimer: AnyCancellable?
    private var activityCancellable: AnyCancellable?
    private var repoChangeCancellable: AnyCancellable?

    private init() {
        setupTimers()
        setupObservers()
    }

    // MARK: - Setup

    private func setupTimers() {
        maintenanceTimer = Timer.publish(every: 3600, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.runMaintenanceIfNeeded()
                }
            }

        conflictTimer = Timer.publish(every: 120, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.checkConflicts()
                }
            }
    }

    private func setupObservers() {
        activityCancellable = NotificationCenter.default
            .publisher(for: .appDidBecomeActiveAgain)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.onRepoOpened()
                }
            }

        repoChangeCancellable = NotificationCenter.default
            .publisher(for: .repositoryDidRefresh)
            .debounce(for: .seconds(5), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.checkConflicts()
                }
            }
    }

    // MARK: - Repo Opened

    func onRepoOpened() async {
        guard let repoPath = AppState.shared.currentRepository?.path else { return }
        guard AppActivityManager.shared.isAppActive else { return }

        await WorkspaceSettingsManager.shared.detectAndCacheMainBranch(for: repoPath)
        await enableRerere(at: repoPath)
        await runMaintenanceIfNeeded()
        await checkConflicts()
    }

    // MARK: - Rerere

    private func enableRerere(at repoPath: String) async {
        let check = await shell.execute(
            "git", arguments: ["config", "--local", "rerere.enabled"],
            workingDirectory: repoPath
        )
        let current = check.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if current != "true" {
            _ = await shell.execute(
                "git", arguments: ["config", "--local", "rerere.enabled", "true"],
                workingDirectory: repoPath
            )
            _ = await shell.execute(
                "git", arguments: ["config", "--local", "rerere.autoupdate", "true"],
                workingDirectory: repoPath
            )
        }
    }

    // MARK: - Maintenance (gc + prune)

    func runMaintenanceIfNeeded() async {
        guard !isRunningMaintenance else { return }
        guard AppActivityManager.shared.isAppActive else { return }
        guard let repoPath = AppState.shared.currentRepository?.path else { return }

        if let last = lastMaintenanceDate, Date().timeIntervalSince(last) < 3600 {
            return
        }

        isRunningMaintenance = true
        defer { isRunningMaintenance = false }

        _ = await shell.execute(
            "git", arguments: ["gc", "--auto", "--quiet"],
            workingDirectory: repoPath
        )

        _ = await shell.execute(
            "git", arguments: ["prune", "--expire", "2.weeks.ago"],
            workingDirectory: repoPath
        )

        _ = await shell.execute(
            "git", arguments: ["reflog", "expire", "--expire=90.days", "--all"],
            workingDirectory: repoPath
        )

        lastMaintenanceDate = Date()
    }

    // MARK: - Conflict Prevention

    func checkConflicts() async {
        guard AppActivityManager.shared.isAppActive else { return }
        guard let repoPath = AppState.shared.currentRepository?.path else { return }

        let branchResult = await shell.execute(
            "git", arguments: ["rev-parse", "--abbrev-ref", "HEAD"],
            workingDirectory: repoPath
        )
        let currentBranch = branchResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !currentBranch.isEmpty, currentBranch != "HEAD" else { return }

        let mainBranch = WorkspaceSettingsManager.shared.getMainBranch(for: repoPath)
        guard currentBranch != mainBranch else {
            conflictWarning = nil
            conflictingFiles = []
            return
        }

        let remoteMain = "origin/\(mainBranch)"
        let remoteExists = await shell.execute(
            "git", arguments: ["rev-parse", "--verify", remoteMain],
            workingDirectory: repoPath
        )
        guard remoteExists.isSuccess else { return }

        let mergeBase = await shell.execute(
            "git", arguments: ["merge-base", "HEAD", remoteMain],
            workingDirectory: repoPath
        )
        guard mergeBase.isSuccess else { return }
        let base = mergeBase.stdout.trimmingCharacters(in: .whitespacesAndNewlines)

        let myFiles = await shell.execute(
            "git", arguments: ["diff", "--name-only", base, "HEAD"],
            workingDirectory: repoPath
        )
        let theirFiles = await shell.execute(
            "git", arguments: ["diff", "--name-only", base, remoteMain],
            workingDirectory: repoPath
        )

        let mySet = Set(myFiles.stdout.components(separatedBy: "\n").filter { !$0.isEmpty })
        let theirSet = Set(theirFiles.stdout.components(separatedBy: "\n").filter { !$0.isEmpty })
        let overlapping = Array(mySet.intersection(theirSet)).sorted()

        if overlapping.isEmpty {
            conflictWarning = nil
            conflictingFiles = []
        } else {
            conflictingFiles = overlapping
            let preview = overlapping.prefix(3).joined(separator: ", ")
            let more = overlapping.count > 3 ? " (+\(overlapping.count - 3) more)" : ""
            conflictWarning = "\(overlapping.count) file(s) modified on both '\(currentBranch)' and '\(mainBranch)': \(preview)\(more)"

            NotificationManager.shared.warning(
                "Potential merge conflicts",
                detail: conflictWarning
            )
        }
    }
}
