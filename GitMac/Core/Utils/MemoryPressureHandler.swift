import Foundation
import Dispatch

/// Handles memory pressure events and notifies observers to clear caches
/// Uses DispatchSource to monitor system memory pressure
@MainActor
final class MemoryPressureHandler: ObservableObject {
    static let shared = MemoryPressureHandler()

    /// Notification posted when memory pressure is detected
    static let memoryPressureNotification = Notification.Name("MemoryPressureDetected")

    private var memoryPressureSource: DispatchSourceMemoryPressure?
    @Published private(set) var isUnderPressure = false

    private init() {
        setupMemoryPressureMonitoring()
    }

    private func setupMemoryPressureMonitoring() {
        memoryPressureSource = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: .main
        )

        memoryPressureSource?.setEventHandler { [weak self] in
            guard let self else { return }
            let event = self.memoryPressureSource?.data ?? []

            Task { @MainActor in
                if event.contains(.critical) {
                    self.handleCriticalPressure()
                } else if event.contains(.warning) {
                    self.handleWarningPressure()
                }
            }
        }

        memoryPressureSource?.resume()
    }

    private func handleWarningPressure() {
        isUnderPressure = true

        // Clear URL caches
        URLCache.shared.removeAllCachedResponses()

        // Notify observers to clear their caches
        NotificationCenter.default.post(
            name: Self.memoryPressureNotification,
            object: self,
            userInfo: ["level": "warning"]
        )

        // Reset after a delay
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            isUnderPressure = false
        }
    }

    private func handleCriticalPressure() {
        isUnderPressure = true

        // Clear URL caches
        URLCache.shared.removeAllCachedResponses()

        // Clear image caches
        clearImageCaches()

        // Notify observers to clear their caches with critical level
        NotificationCenter.default.post(
            name: Self.memoryPressureNotification,
            object: self,
            userInfo: ["level": "critical"]
        )

        // Reset after a delay
        Task {
            try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
            isUnderPressure = false
        }
    }

    private func clearImageCaches() {
        // Clear any image-related caches
        // AvatarService has its own cache that will be cleared via notification
    }

    /// Manually trigger cache clearing (for debugging or explicit cleanup)
    func clearAllCaches() {
        URLCache.shared.removeAllCachedResponses()
        NotificationCenter.default.post(
            name: Self.memoryPressureNotification,
            object: self,
            userInfo: ["level": "manual"]
        )
    }

    deinit {
        memoryPressureSource?.cancel()
    }
}

// MARK: - View Extension for Memory Pressure

import SwiftUI

extension View {
    /// Clears the provided closure's caches when memory pressure is detected
    func onMemoryPressure(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: MemoryPressureHandler.memoryPressureNotification)) { _ in
            action()
        }
    }
}
