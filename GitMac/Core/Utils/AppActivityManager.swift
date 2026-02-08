import SwiftUI
import Combine

// MARK: - Notification Names (nonisolated so any context can reference them)
extension Notification.Name {
    /// Posted when the app should pause background work
    static let appDidBecomeInactive = Notification.Name("AppActivityManager.appDidBecomeInactive")
    /// Posted when the app should resume background work
    static let appDidBecomeActiveAgain = Notification.Name("AppActivityManager.appDidBecomeActive")
}

/// Centralized manager that pauses all background work when the app is not active.
/// Monitors NSApplication.isActive and posts notifications to suspend/resume
/// file watchers, timers, network polling, and other background tasks.
@MainActor
final class AppActivityManager: ObservableObject {
    static let shared = AppActivityManager()

    /// Whether the app is currently active (frontmost and visible)
    @Published private(set) var isAppActive: Bool = true

    private var cancellables = Set<AnyCancellable>()

    /// Grace period before pausing — avoids flickering when switching windows briefly
    private let pauseDelay: TimeInterval = 3.0
    private var pauseTask: Task<Void, Never>?

    private init() {
        setupObservers()
    }

    private func setupObservers() {
        // Monitor app activation
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleBecameActive()
            }
            .store(in: &cancellables)

        // Monitor app deactivation (user switched to another app)
        NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleResignedActive()
            }
            .store(in: &cancellables)

        // Also monitor when all windows are miniaturized or hidden
        NotificationCenter.default.publisher(for: NSApplication.didHideNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleResignedActive()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didUnhideNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleBecameActive()
            }
            .store(in: &cancellables)
    }

    private func handleBecameActive() {
        // Cancel any pending pause
        pauseTask?.cancel()
        pauseTask = nil

        guard !isAppActive else { return }
        isAppActive = true
        NotificationCenter.default.post(name: .appDidBecomeActiveAgain, object: nil)
    }

    private func handleResignedActive() {
        guard isAppActive else { return }

        // Delay pause to avoid flickering on quick app switches
        pauseTask?.cancel()
        pauseTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64((self?.pauseDelay ?? 3.0) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.isAppActive = false
            NotificationCenter.default.post(name: .appDidBecomeInactive, object: nil)
        }
    }
}
