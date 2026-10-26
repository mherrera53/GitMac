import AppKit
import SwiftUI
import Testing
@testable import GitMac

@MainActor @Observable private final class ResizerFixtureState {
    var height: CGFloat = 50
    var maximum: CGFloat = 200
}

@MainActor private struct ResizerFixtureView: View {
    let state: ResizerFixtureState
    var body: some View {
        UniversalResizer(dimension: Binding(get: { state.height }, set: { state.height = $0 }),
                         minDimension: 0, maxDimension: state.maximum, orientation: .vertical)
    }
}

@Suite("Native resizer follows the current window height", .serialized)
@MainActor struct NativeResizerTests {
    @Test func changingMaximumUpdatesTheExistingNativeDragHandler() async throws {
        _ = NSApplication.shared
        let state = ResizerFixtureState()
        let host = NSHostingView(rootView: ResizerFixtureView(state: state))
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 320, height: 100),
                              styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        try await Task.sleep(nanoseconds: 100_000_000)
        func findResizer(_ view: NSView) -> UniversalResizerNSView? {
            if let resizer = view as? UniversalResizerNSView { return resizer }
            return view.subviews.lazy.compactMap { findResizer($0) }.first
        }
        let original = try #require(findResizer(host))
        original.onDragChanged?(1000)
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(state.height == 200)

        state.height = 50
        state.maximum = 60
        try await Task.sleep(nanoseconds: 100_000_000)
        host.layoutSubtreeIfNeeded()
        let updated = try #require(findResizer(host))
        #expect(updated === original)
        updated.onDragChanged?(1000)
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(state.height == 60)
    }
}
