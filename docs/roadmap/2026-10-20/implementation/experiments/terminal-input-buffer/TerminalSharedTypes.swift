//
//  TerminalSharedTypes.swift
//  GitMac
//
//  Shared types for terminal components
//

import SwiftUI
import AppKit

// MARK: - AI Text Editor

/// Native typing owns the current text. Only explicit replacements advance the
/// revision that authorizes SwiftUI to write back into the NSTextView.
@MainActor final class TerminalInputBuffer: ObservableObject {
    struct Snapshot: Equatable, Sendable {
        let text: String
        let replacementRevision: UInt64
    }
    @Published private(set) var snapshot: Snapshot
    var text: String { snapshot.text }

    init(text: String = "") {
        snapshot = Snapshot(text: text, replacementRevision: 0)
    }

    func nativeTextChanged(_ value: String) {
        guard value != snapshot.text else { return }
        snapshot = Snapshot(text: value, replacementRevision: snapshot.replacementRevision)
    }

    func replace(_ value: String) {
        snapshot = Snapshot(text: value, replacementRevision: snapshot.replacementRevision &+ 1)
    }
}

struct AITextEditor: NSViewRepresentable {
    @ObservedObject var buffer: TerminalInputBuffer
    var isFocused: FocusState<Bool>.Binding
    let onSubmit: (String) -> Void
    let onTab: () -> Void
    let onArrowUp: () -> Void
    let onArrowDown: () -> Void
    let onEscape: () -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = AITextView()

        textView.delegate = context.coordinator
        textView.coordinator = context.coordinator
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.backgroundColor = .clear
        textView.textColor = NSColor(AppTheme.textPrimary)
        textView.insertionPointColor = NSColor(AppTheme.accent)
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.allowsUndo = true
        textView.isVerticallyResizable = true
        textView.setAccessibilityIdentifier("terminal-command-input")
        textView.textContainer?.widthTracksTextView = true
        textView.string = buffer.text
        context.coordinator.appliedReplacementRevision = buffer.snapshot.replacementRevision

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = false
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.parent = self
        textView.textColor = NSColor(AppTheme.textPrimary)
        textView.insertionPointColor = NSColor(AppTheme.accent)
        let state = buffer.snapshot
        if state.replacementRevision > context.coordinator.appliedReplacementRevision && !textView.hasMarkedText() {
            textView.string = state.text
            context.coordinator.appliedReplacementRevision = state.replacementRevision
        }
        if isFocused.wrappedValue && textView.window?.firstResponder !== textView {
            DispatchQueue.main.async {
                if isFocused.wrappedValue && textView.window?.firstResponder !== textView {
                    textView.window?.makeFirstResponder(textView)
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: AITextEditor
        var appliedReplacementRevision: UInt64 = 0

        init(_ parent: AITextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            if let textView = notification.object as? NSTextView {
                parent.buffer.nativeTextChanged(textView.string)
            }
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if textView.hasMarkedText() { return false }
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                if NSEvent.modifierFlags.contains(.shift) {
                    return false // Allow shift+enter for newline
                }
                parent.onSubmit(textView.string)
                return true
            }
            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                parent.onTab()
                return true
            }
            if commandSelector == #selector(NSResponder.moveUp(_:)) {
                parent.onArrowUp()
                return true
            }
            if commandSelector == #selector(NSResponder.moveDown(_:)) {
                parent.onArrowDown()
                return true
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                parent.onEscape()
                return true
            }
            return false
        }
    }
}

class AITextView: NSTextView {
    weak var coordinator: AITextEditor.Coordinator?

    override func keyDown(with event: NSEvent) {
        if PerformanceProbe.isEnabled && [8, 39].contains(event.keyCode) {
            NSLog("GitMacInput key=%@ flags=%@ scalars=%@ marked=%@",
                  String(event.keyCode), String(event.modifierFlags.rawValue),
                  String(describing: event.characters?.unicodeScalars.map(\.value)), String(hasMarkedText()))
        }
        super.keyDown(with: event)
    }

    override func insertText(_ insertString: Any, replacementRange: NSRange) {
        let value = (insertString as? String) ?? (insertString as? NSAttributedString)?.string ?? ""
        if PerformanceProbe.isEnabled && (value.contains("c") || value.contains("'")) {
            NSLog("GitMacInput insert scalars=%@", String(describing: value.unicodeScalars.map(\.value)))
        }
        super.insertText(insertString, replacementRange: replacementRange)
    }
}

// MARK: - Debouncer

class Debouncer {
    private let delay: TimeInterval
    private var workItem: DispatchWorkItem?

    init(delay: TimeInterval) {
        self.delay = delay
    }

    func debounce(action: @escaping () -> Void) {
        workItem?.cancel()
        workItem = DispatchWorkItem(block: action)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem!)
    }
}

// MARK: - Collection Extensions

extension Sequence where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
