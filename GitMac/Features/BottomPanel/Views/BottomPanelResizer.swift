//
//  BottomPanelResizer.swift
//  GitMac
//
//  Created by GitMac on 2025-12-28.
//

import SwiftUI
import AppKit

// MARK: - Custom Resizer View

/// Custom NSView-based resizer that prevents window dragging
fileprivate class ResizerNSView: NSView {
    var onDrag: ((CGFloat) -> Void)?
    var onHover: ((Bool) -> Void)?
    var isDragging = false
    var initialMouseLocation: NSPoint?
    var initialHeight: CGFloat = 0

    override var mouseDownCanMoveWindow: Bool { false }
    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func mouseDown(with event: NSEvent) {
        isDragging = true
        initialMouseLocation = NSEvent.mouseLocation
        NSCursor.resizeUpDown.push()
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging, let initial = initialMouseLocation else { return }
        let current = NSEvent.mouseLocation
        let delta = current.y - initial.y
        onDrag?(delta)
        initialMouseLocation = current
    }

    override func mouseUp(with event: NSEvent) {
        isDragging = false
        NSCursor.pop()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for trackingArea in trackingAreas {
            removeTrackingArea(trackingArea)
        }

        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways]
        let trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }

    override func mouseEntered(with event: NSEvent) {
        NSCursor.resizeUpDown.push()
        onHover?(true)
    }

    override func mouseExited(with event: NSEvent) {
        if !isDragging {
            NSCursor.pop()
        }
        onHover?(false)
    }
}

/// SwiftUI wrapper for custom resizer
fileprivate struct CustomResizerView: NSViewRepresentable {
    @Binding var height: CGFloat
    @Binding var isHovering: Bool
    @Binding var isDragging: Bool

    let minHeight: CGFloat
    let maxHeight: CGFloat

    func makeNSView(context: Context) -> ResizerNSView {
        let view = ResizerNSView()
        view.onDrag = { delta in
            let newHeight = height + delta
            height = max(minHeight, min(maxHeight, newHeight))
        }
        view.onHover = { hovering in
            isHovering = hovering
        }
        return view
    }

    func updateNSView(_ nsView: ResizerNSView, context: Context) {
        isDragging = nsView.isDragging
    }
}

// MARK: - Bottom Panel Resizer

struct BottomPanelResizer: View {
    @Binding var height: CGFloat
    @State private var isHovering = false
    @State private var isDragging = false

    let minHeight: CGFloat = 100
    let maxHeight: CGFloat = 600

    var body: some View {
        ZStack {
            // Custom NSView resizer that prevents window dragging
            CustomResizerView(
                height: $height,
                isHovering: $isHovering,
                isDragging: $isDragging,
                minHeight: minHeight,
                maxHeight: maxHeight
            )

            // Visual indicator
            Rectangle()
                .fill(isDragging ? AppTheme.accent : (isHovering ? AppTheme.border : AppTheme.border.opacity(0.5)))
                .frame(height: 4)
                .allowsHitTesting(false)
        }
        .frame(height: 12)
    }
}
