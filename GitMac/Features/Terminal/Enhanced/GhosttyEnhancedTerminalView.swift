//
//  GhosttyEnhancedTerminalView.swift
//  GitMac
//
//  Enhanced terminal view with input tracking for AI suggestions
//

#if GHOSTTY_AVAILABLE
import SwiftUI
import AppKit
import GhosttyKit

// MARK: - Enhanced Terminal View

enum TerminalInputMode {
    case direct       // Ghostty handles keyboard input directly
    case externalBar  // External input bar sends commands, Ghostty is output-only
}

struct GhosttyEnhancedTerminalView: NSViewRepresentable {
    @ObservedObject var viewModel: GhosttyViewModel
    @ObservedObject var enhancedViewModel: GhosttyEnhancedViewModel
    let initialDirectory: String
    let aiEnabled: Bool
    let repoPath: String?
    var inputMode: TerminalInputMode = .direct

    // Static initialization state
    private static var ghosttyInitialized = false
    private static let initLock = NSLock()

    private static func initializeGhosttyOnce() -> Bool {
        initLock.lock()
        defer { initLock.unlock() }

        guard !ghosttyInitialized else { return true }

        let result = ghostty_init(0, nil)
        ghosttyInitialized = (result == GHOSTTY_SUCCESS)
        return ghosttyInitialized
    }

    func makeNSView(context: Context) -> EnhancedGhosttyContainerView {
        // Initialize Ghostty
        guard Self.initializeGhosttyOnce() else {
            let container = EnhancedGhosttyContainerView(frame: NSMakeRect(0, 0, 800, 600))
            return container
        }

        let workingDir = initialDirectory

        // Defer the viewModel update to avoid publishing during view updates
        DispatchQueue.main.async {
            viewModel.currentDirectory = workingDir
        }

        // Create container with enhanced tracking
        let container = EnhancedGhosttyContainerView(frame: NSMakeRect(0, 0, 800, 600))
        container.viewModel = viewModel
        container.enhancedViewModel = enhancedViewModel
        container.aiEnabled = aiEnabled
        container.repoPath = repoPath
        container.inputMode = inputMode

        // Create Ghostty config
        let config = ghostty_config_new()
        ghostty_config_load_default_files(config)
        ghostty_config_finalize(config)

        // Runtime config
        var runtime_config = ghostty_runtime_config_s()
        runtime_config.userdata = UnsafeMutableRawPointer(Unmanaged.passUnretained(context.coordinator).toOpaque())
        runtime_config.supports_selection_clipboard = true
        runtime_config.wakeup_cb = { _ in }
        runtime_config.action_cb = { _, _, _ in return true }
        runtime_config.read_clipboard_cb = nil
        runtime_config.write_clipboard_cb = nil
        runtime_config.confirm_read_clipboard_cb = nil
        runtime_config.close_surface_cb = nil

        // Create Ghostty app
        let app = ghostty_app_new(&runtime_config, config)
        guard app != nil else {
            return container
        }

        // Surface config
        var surface_config = ghostty_surface_config_new()
        surface_config.platform_tag = GHOSTTY_PLATFORM_MACOS
        surface_config.platform.macos.nsview = UnsafeMutableRawPointer(Unmanaged.passUnretained(container).toOpaque())
        surface_config.userdata = UnsafeMutableRawPointer(Unmanaged.passUnretained(context.coordinator).toOpaque())
        surface_config.scale_factor = Double(NSScreen.main?.backingScaleFactor ?? 2.0)
        surface_config.font_size = 13.0

        // Store working directory data
        let workingDirCString = workingDir.utf8CString
        context.coordinator.workingDirectoryData = workingDirCString.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }
        surface_config.working_directory = context.coordinator.workingDirectoryData!.withUnsafeBytes { $0.baseAddress?.assumingMemoryBound(to: CChar.self) }

        // Set shell command with working directory
        let shellCommand = "/bin/zsh -c \"cd '\(workingDir)' && exec /bin/zsh -l\""
        let shellCommandCString = (shellCommand as NSString).utf8String!
        let shellCommandData = Data(bytes: shellCommandCString, count: strlen(shellCommandCString) + 1)
        context.coordinator.shellCommandData = shellCommandData
        surface_config.command = context.coordinator.shellCommandData!.withUnsafeBytes { $0.baseAddress?.assumingMemoryBound(to: CChar.self) }

        // Create surface
        let surface = ghostty_surface_new(app!, &surface_config)
        guard surface != nil else {
            ghostty_app_free(app!)
            return container
        }

        // Store references
        container.surface = surface
        context.coordinator.app = app
        context.coordinator.surface = surface
        context.coordinator.viewModel = viewModel
        viewModel.surface = surface

        return container
    }

    func updateNSView(_ nsView: EnhancedGhosttyContainerView, context: Context) {
        nsView.aiEnabled = aiEnabled
        nsView.repoPath = repoPath
        nsView.inputMode = inputMode
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel, enhancedViewModel: enhancedViewModel)
    }

    class Coordinator: NSObject {
        var viewModel: GhosttyViewModel?
        var enhancedViewModel: GhosttyEnhancedViewModel
        var app: ghostty_app_t?
        var surface: ghostty_surface_t?
        var workingDirectoryData: Data?
        var shellCommandData: Data?

        init(viewModel: GhosttyViewModel, enhancedViewModel: GhosttyEnhancedViewModel) {
            self.viewModel = viewModel
            self.enhancedViewModel = enhancedViewModel
        }

        deinit {
            if let surface = surface {
                ghostty_surface_free(surface)
            }
            if let app = app {
                ghostty_app_free(app)
            }
        }
    }
}

// MARK: - Enhanced Container View

class EnhancedGhosttyContainerView: NSView {
    weak var viewModel: GhosttyViewModel?
    var enhancedViewModel: GhosttyEnhancedViewModel?
    var aiEnabled: Bool = true
    var repoPath: String?
    var surface: ghostty_surface_t?
    var inputMode: TerminalInputMode = .direct

    // Track current input
    private var currentInputBuffer: String = ""
    private var lastCommandTime: Date?

    // Cursor overlay to hide Ghostty cursor in external bar mode
    private var cursorOverlay: NSView?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }

    // Only accept first responder in direct input mode
    override var acceptsFirstResponder: Bool {
        inputMode == .direct
    }

    override func becomeFirstResponder() -> Bool {
        return inputMode == .direct
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if inputMode == .direct {
            window?.makeFirstResponder(self)
        }
    }

    override func keyDown(with event: NSEvent) {
        // In external bar mode, don't handle keyboard events - let them pass through
        if inputMode == .externalBar {
            // Only allow scroll-related keys (Page Up/Down, etc.)
            let scrollKeys: Set<UInt16> = [116, 121, 115, 119] // Page Up, Page Down, Home, End
            if scrollKeys.contains(event.keyCode) {
                // Allow scroll keys to pass to Ghostty for scrolling
                if let surface = surface {
                    let mods: ghostty_input_mods_e = GHOSTTY_MODS_NONE
                    var key = ghostty_input_key_s()
                    key.action = GHOSTTY_ACTION_PRESS
                    key.mods = mods
                    key.keycode = UInt32(event.keyCode)
                    _ = ghostty_surface_key(surface, key)
                }
            }
            return
        }

        // Intercept arrow keys and Enter when AI suggestions are visible
        if let enhanced = enhancedViewModel, !enhanced.aiSuggestions.isEmpty {
            // Arrow Up (126) - Navigate suggestions up
            if event.keyCode == 126 {
                enhanced.selectPreviousSuggestion()
                return
            }
            // Arrow Down (125) - Navigate suggestions down
            if event.keyCode == 125 {
                enhanced.selectNextSuggestion()
                return
            }
            // Enter (36 or 76) - Apply selected suggestion
            if event.keyCode == 36 || event.keyCode == 76 {
                if let vm = viewModel {
                    enhanced.applySelectedSuggestion(to: vm)
                    currentInputBuffer = ""
                }
                return
            }
            // Escape (53) - Dismiss suggestions
            if event.keyCode == 53 {
                enhanced.aiSuggestions.removeAll()
                enhanced.currentInput = ""
                return
            }
             // Tab (48) or Right Arrow (124) - Auto-complete/Apply
            if event.keyCode == 48 || event.keyCode == 124 {
                if let vm = viewModel {
                    enhanced.applySelectedSuggestion(to: vm)
                    currentInputBuffer = ""
                }
                return
            }
        }

        // Track input for AI suggestions
        if let characters = event.characters {
            handleInputTracking(characters, event: event)
        }

        // Pass to Ghostty
        guard let surface = surface else {
            super.keyDown(with: event)
            return
        }

        var mods: ghostty_input_mods_e = GHOSTTY_MODS_NONE
        let flags = event.modifierFlags

        if flags.contains(.shift) { mods = ghostty_input_mods_e(mods.rawValue | GHOSTTY_MODS_SHIFT.rawValue) }
        if flags.contains(.control) { mods = ghostty_input_mods_e(mods.rawValue | GHOSTTY_MODS_CTRL.rawValue) }
        if flags.contains(.option) { mods = ghostty_input_mods_e(mods.rawValue | GHOSTTY_MODS_ALT.rawValue) }
        if flags.contains(.command) { mods = ghostty_input_mods_e(mods.rawValue | GHOSTTY_MODS_SUPER.rawValue) }

        // Special handling for Ctrl+C (Interrupt)
        if flags.contains(.control) {
            if let chars = event.charactersIgnoringModifiers, chars == "c" {
                // Force send Ctrl+C (ETX - End of Text)
                var key = ghostty_input_key_s()
                key.action = GHOSTTY_ACTION_PRESS
                key.mods = mods
                key.keycode = UInt32(event.keyCode)
                
                // Use explicit ETX character (0x03)
                let etx = "\u{03}"
                etx.utf8CString.withUnsafeBufferPointer { buffer in
                    key.text = buffer.baseAddress
                    _ = ghostty_surface_key(surface, key)
                }
                return
            }
        }

        var key = ghostty_input_key_s()
        key.action = GHOSTTY_ACTION_PRESS
        key.mods = mods
        key.keycode = UInt32(event.keyCode)

        if let characters = event.characters {
            characters.utf8CString.withUnsafeBufferPointer { buffer in
                key.text = buffer.baseAddress
                _ = ghostty_surface_key(surface, key)
            }
        }
    }

    override func keyUp(with event: NSEvent) {
        guard let surface = surface else {
            super.keyUp(with: event)
            return
        }

        var mods: ghostty_input_mods_e = GHOSTTY_MODS_NONE
        let flags = event.modifierFlags

        if flags.contains(.shift) { mods = ghostty_input_mods_e(mods.rawValue | GHOSTTY_MODS_SHIFT.rawValue) }
        if flags.contains(.control) { mods = ghostty_input_mods_e(mods.rawValue | GHOSTTY_MODS_CTRL.rawValue) }
        if flags.contains(.option) { mods = ghostty_input_mods_e(mods.rawValue | GHOSTTY_MODS_ALT.rawValue) }
        if flags.contains(.command) { mods = ghostty_input_mods_e(mods.rawValue | GHOSTTY_MODS_SUPER.rawValue) }

        var key = ghostty_input_key_s()
        key.action = GHOSTTY_ACTION_RELEASE
        key.mods = mods
        key.keycode = UInt32(event.keyCode)

        if let characters = event.characters {
            characters.utf8CString.withUnsafeBufferPointer { buffer in
                key.text = buffer.baseAddress
                _ = ghostty_surface_key(surface, key)
            }
        }
    }

    override func scrollWheel(with event: NSEvent) {
        guard let surface = surface else {
            super.scrollWheel(with: event)
            return
        }

        // Get scroll delta
        let deltaX = event.scrollingDeltaX
        let deltaY = event.scrollingDeltaY

        // Build modifiers
        var mods: ghostty_input_scroll_mods_t = 0
        let flags = event.modifierFlags
        if flags.contains(.shift) { mods |= Int32(GHOSTTY_MODS_SHIFT.rawValue) }
        if flags.contains(.control) { mods |= Int32(GHOSTTY_MODS_CTRL.rawValue) }
        if flags.contains(.option) { mods |= Int32(GHOSTTY_MODS_ALT.rawValue) }
        if flags.contains(.command) { mods |= Int32(GHOSTTY_MODS_SUPER.rawValue) }

        // Send scroll event to Ghostty
        ghostty_surface_mouse_scroll(surface, deltaX, deltaY, mods)
    }

    private func handleInputTracking(_ input: String, event: NSEvent) {
        guard aiEnabled, let enhanced = enhancedViewModel else { return }

        // Check if Enter was pressed
        if event.keyCode == 36 || event.keyCode == 76 {
            if !currentInputBuffer.isEmpty {
                enhanced.trackCommand(currentInputBuffer)
                currentInputBuffer = ""
                lastCommandTime = Date()
            }
            return
        }

        // Ignore arrow keys and navigation keys
        let ignoredKeyCodes: Set<UInt16> = [
            123, 124, 125, 126, // Arrows
            116, 121, // Page Up/Down
            115, 119, // Home/End
            53, // Esc
            48, // Tab
        ]

        if ignoredKeyCodes.contains(event.keyCode) {
            return
        }

        // Check if backspace
        if event.keyCode == 51 {
            if !currentInputBuffer.isEmpty {
                currentInputBuffer.removeLast()
            }
        } else {
            // Only append printable characters
            let printable = input.filter { char in
                !char.isNewline && !(char.unicodeScalars.first?.properties.generalCategory == .control)
            }
            if !printable.isEmpty {
                currentInputBuffer += printable
            }
        }

        // Update AI suggestions
        if currentInputBuffer.count >= 2 {
            enhanced.updateInput(currentInputBuffer, repoPath: repoPath)
        } else {
            enhanced.aiSuggestions.removeAll()
        }
    }
}
#endif
