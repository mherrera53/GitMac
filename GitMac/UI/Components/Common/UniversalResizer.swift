//
//  UniversalResizer.swift
//  GitMac
//
//  Created by GitMac on 2025-12-28.
//

import SwiftUI
import AppKit

// MARK: - Universal Resizer NSView

/// Vista nativa que maneja resize sin permitir drag de ventana
class UniversalResizerNSView: NSView {
    // Callbacks
    var onDragChanged: ((CGFloat) -> Void)?
    var onHoverChanged: ((Bool) -> Void)?
    var onDraggingStateChanged: ((Bool) -> Void)?

    // Configuration
    var orientation: UniversalResizer.Orientation = .horizontal

    // State
    private var isDragging = false {
        didSet {
            if isDragging != oldValue {
                onDraggingStateChanged?(isDragging)
            }
        }
    }
    private var dragStartLocation: NSPoint = .zero
    private var trackingArea: NSTrackingArea?
    private var cursorUpdateScheduled = false

    // CRITICAL: Prevent window dragging
    override var mouseDownCanMoveWindow: Bool { false }
    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true

        // Force this view to accept events
        self.layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        isDragging = true
        dragStartLocation = event.locationInWindow
        pushCursor()
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }

        let currentLocation = event.locationInWindow
        let delta: CGFloat

        switch orientation {
        case .horizontal:
            delta = currentLocation.x - dragStartLocation.x
        case .vertical:
            delta = currentLocation.y - dragStartLocation.y
        }

        onDragChanged?(delta)
        dragStartLocation = currentLocation
    }

    override func mouseUp(with event: NSEvent) {
        isDragging = false
        popCursor()
    }

    // MARK: - Tracking Area

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let existingArea = trackingArea {
            removeTrackingArea(existingArea)
        }

        let options: NSTrackingArea.Options = [
            .mouseEnteredAndExited,
            .activeInActiveApp,
            .inVisibleRect
        ]

        trackingArea = NSTrackingArea(
            rect: bounds,
            options: options,
            owner: self,
            userInfo: nil
        )

        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        if !isDragging {
            pushCursor()
        }
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        if !isDragging {
            popCursor()
        }
        onHoverChanged?(false)
    }

    // MARK: - Cursor Management

    private func pushCursor() {
        guard !cursorUpdateScheduled else { return }
        cursorUpdateScheduled = true

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch self.orientation {
            case .horizontal:
                NSCursor.resizeLeftRight.push()
            case .vertical:
                NSCursor.resizeUpDown.push()
            }
            self.cursorUpdateScheduled = false
        }
    }

    private func popCursor() {
        DispatchQueue.main.async {
            NSCursor.pop()
        }
    }
}

// MARK: - SwiftUI Wrapper

struct UniversalResizer: View {
    // Bindings
    @Binding var dimension: CGFloat

    // Configuration
    let minDimension: CGFloat
    let maxDimension: CGFloat
    let orientation: Orientation
    var invertDirection: Bool = false  // For right-side panels

    // State
    @State private var isHovering = false
    @State private var isDragging = false

    enum Orientation {
        case horizontal // For left/right resize
        case vertical   // For top/bottom resize
    }

    var body: some View {
        ZStack {
            // The actual resizer NSView
            ResizerViewRepresentable(
                dimension: $dimension,
                isHovering: $isHovering,
                isDragging: $isDragging,
                minDimension: minDimension,
                maxDimension: maxDimension,
                orientation: orientation,
                invertDirection: invertDirection
            )

            // Visual indicator (non-interactive) - subtle like Xcode
            Rectangle()
                .fill(visualColor)
                .frame(
                    width: orientation == .horizontal ? 1 : nil,
                    height: orientation == .vertical ? 1 : nil
                )
                .allowsHitTesting(false)
        }
        .frame(
            width: orientation == .horizontal ? 5 : nil,
            height: orientation == .vertical ? 5 : nil
        )
    }

    private var visualColor: Color {
        if isDragging {
            return AppTheme.accent
        } else if isHovering {
            return Color.gray.opacity(0.6)
        } else {
            return Color.gray.opacity(0.3)
        }
    }
}

// MARK: - NSViewRepresentable

private struct ResizerViewRepresentable: NSViewRepresentable {
    @Binding var dimension: CGFloat
    @Binding var isHovering: Bool
    @Binding var isDragging: Bool

    let minDimension: CGFloat
    let maxDimension: CGFloat
    let orientation: UniversalResizer.Orientation
    let invertDirection: Bool

    func makeNSView(context: Context) -> UniversalResizerNSView {
        let view = UniversalResizerNSView()
        view.orientation = orientation

        setupCallbacks(for: view)
        return view
    }

    func updateNSView(_ nsView: UniversalResizerNSView, context: Context) {
        // Only update orientation if changed
        if nsView.orientation != orientation {
            nsView.orientation = orientation
        }
    }

    private func setupCallbacks(for view: UniversalResizerNSView) {
        view.onDragChanged = { [minDimension, maxDimension] delta in
            // For left panel: drag right (+) = increase width
            // For right panel: drag left (-) = increase width (invert)
            // For vertical: drag up (+) = decrease height (invert)
            var adjustedDelta = delta
            if invertDirection {
                adjustedDelta = -delta
            }

            DispatchQueue.main.async {
                let newDimension = dimension + adjustedDelta
                let clampedDimension = max(minDimension, min(maxDimension, newDimension))

                // Only update if value actually changed to avoid unnecessary redraws
                if abs(dimension - clampedDimension) > 0.1 {
                    dimension = clampedDimension
                }
            }
        }

        view.onHoverChanged = { hovering in
            DispatchQueue.main.async {
                isHovering = hovering
            }
        }

        view.onDraggingStateChanged = { dragging in
            DispatchQueue.main.async {
                isDragging = dragging
            }
        }
    }
}
