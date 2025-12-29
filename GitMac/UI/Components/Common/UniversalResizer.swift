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
        NSCursor.resizeUpDown.push()
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }

        let currentLocation = event.locationInWindow
        let delta = currentLocation.y - dragStartLocation.y

        onDragChanged?(delta)
        dragStartLocation = currentLocation
    }

    override func mouseUp(with event: NSEvent) {
        isDragging = false
        NSCursor.pop()
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
            NSCursor.resizeUpDown.push()
        }
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        if !isDragging {
            NSCursor.pop()
        }
        onHoverChanged?(false)
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
                orientation: orientation
            )

            // Visual indicator (non-interactive)
            Rectangle()
                .fill(visualColor)
                .frame(
                    width: orientation == .horizontal ? 4 : nil,
                    height: orientation == .vertical ? 4 : nil
                )
                .allowsHitTesting(false)
        }
        .frame(
            width: orientation == .horizontal ? 12 : nil,
            height: orientation == .vertical ? 12 : nil
        )
    }

    private var visualColor: Color {
        if isDragging {
            return AppTheme.accent
        } else if isHovering {
            return AppTheme.border
        } else {
            return AppTheme.border.opacity(0.5)
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

    func makeNSView(context: Context) -> UniversalResizerNSView {
        let view = UniversalResizerNSView()

        view.onDragChanged = { delta in
            let adjustedDelta = orientation == .vertical ? delta : -delta
            let newDimension = dimension + adjustedDelta
            dimension = max(minDimension, min(maxDimension, newDimension))
        }

        view.onHoverChanged = { hovering in
            isHovering = hovering
        }

        view.onDraggingStateChanged = { dragging in
            isDragging = dragging
        }

        return view
    }

    func updateNSView(_ nsView: UniversalResizerNSView, context: Context) {
        // Re-bind callbacks in case bindings changed
        nsView.onDragChanged = { delta in
            let adjustedDelta = orientation == .vertical ? delta : -delta
            let newDimension = dimension + adjustedDelta
            dimension = max(minDimension, min(maxDimension, newDimension))
        }

        nsView.onHoverChanged = { hovering in
            isHovering = hovering
        }

        nsView.onDraggingStateChanged = { dragging in
            isDragging = dragging
        }
    }
}
