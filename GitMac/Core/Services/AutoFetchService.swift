import Foundation
import Combine

/// Background service that periodically runs `git fetch --all --prune`
/// for the active repository based on user-configured interval.
@MainActor
@Observable
final class AutoFetchService {
    static let shared = AutoFetchService()

    var lastFetchDate: Date?
    var isFetching = false

    private let shellExecutor = ShellExecutor.shared
    private var timerCancellable: AnyCancellable?
    private var activityCancellable: AnyCancellable?
    private var settingsCancellable: AnyCancellable?

    private init() {
        setupActivityObserver()
        setupSettingsObserver()
        restartTimerIfNeeded()
    }

    // MARK: - Timer Management

    private func restartTimerIfNeeded() {
        timerCancellable?.cancel()
        timerCancellable = nil

        guard UserDefaults.standard.bool(forKey: "autoFetch") else { return }

        let intervalMinutes = UserDefaults.standard.integer(forKey: "autoFetchInterval")
        let interval = TimeInterval(max(intervalMinutes, 1) * 60)

        timerCancellable = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.fetchIfActive()
                }
            }
    }

    private func setupActivityObserver() {
        // Fetch immediately when app becomes active again
        activityCancellable = NotificationCenter.default
            .publisher(for: .appDidBecomeActiveAgain)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.fetchIfActive()
                }
            }
    }

    private func setupSettingsObserver() {
        // Re-check timer when settings change
        settingsCancellable = NotificationCenter.default
            .publisher(for: UserDefaults.didChangeNotification)
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.restartTimerIfNeeded()
            }
    }

    // MARK: - Fetch

    func fetchIfActive() async {
        guard UserDefaults.standard.bool(forKey: "autoFetch") else { return }
        guard AppActivityManager.shared.isAppActive else { return }
        guard !isFetching else { return }

        guard let repoPath = AppState.shared.currentRepository?.path else { return }

        isFetching = true
        defer { isFetching = false }

        let result = await shellExecutor.execute(
            "git",
            arguments: ["fetch", "--all", "--prune"],
            workingDirectory: repoPath
        )

        if result.exitCode == 0 {
            lastFetchDate = Date()
            NotificationCenter.default.post(name: .repositoryDidRefresh, object: repoPath)
        }
    }

    /// Formatted string for "last fetched X ago" display
    var lastFetchDescription: String? {
        guard let date = lastFetchDate else { return nil }
        let interval = Date().timeIntervalSince(date)

        if interval < 60 {
            return "Fetched just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "Fetched \(minutes)m ago"
        } else {
            let hours = Int(interval / 3600)
            return "Fetched \(hours)h ago"
        }
    }
}
