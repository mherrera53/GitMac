import SwiftUI
import AppKit

// MARK: - Ghostty Direct Integration
//
// This file provides direct integration with Ghostty using its C API from GhosttyKit.xcframework
// This is a minimal wrapper that creates a Ghostty terminal surface without the full Swift layer.
//
// CONDITIONAL COMPILATION:
// To enable Ghostty integration, add the following to your Xcode build settings:
// - Swift Compiler - Custom Flags: OTHER_SWIFT_FLAGS = -D GHOSTTY_AVAILABLE
// - Ensure GhosttyKit.xcframework is in the Frameworks/ folder
//
// CI builds will skip this code since GHOSTTY_AVAILABLE won't be defined

#if GHOSTTY_AVAILABLE

/// Native Ghostty terminal view using GhosttyKit framework
struct GhosttyDirectView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = GhosttyDirectViewModel()
    @State private var aiEnabled = true
    @State private var showAIChat = false

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbarView

            // Ghostty Surface
            ZStack {
                GhosttyDirectRepresentable(viewModel: viewModel)
                    .background(Color(hex: "1a1b26"))

                // AI suggestions overlay
                if aiEnabled && (!viewModel.aiSuggestions.isEmpty || viewModel.isLoadingSuggestions) {
                    VStack {
                        Spacer()
                        aiSuggestionsView
                            .padding(.bottom, DesignTokens.Spacing.sm)
                            .padding(.horizontal, DesignTokens.Spacing.sm)
                    }
                }
            }

            // Status bar
            statusBarView
        }
        .onAppear {
            if let repoPath = appState.currentRepository?.path {
                viewModel.setWorkingDirectory(repoPath)
            }
        }
        .onChange(of: appState.currentRepository?.path) { _, newPath in
            if let path = newPath {
                viewModel.setWorkingDirectory(path)
            }
        }
    }

    // MARK: - Toolbar

    private var toolbarView: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: "folder")
                    .font(DesignTokens.Typography.caption2)
                    .foregroundColor(AppTheme.textSecondary)
                Text(viewModel.currentDirectory)
                    .font(DesignTokens.Typography.caption2)
                    .lineLimit(1)
            }
            .foregroundColor(AppTheme.textSecondary)

            Spacer()

            // AI Chat
            Button {
                showAIChat.toggle()
            } label: {
                Image(systemName: "sparkles")
                    .font(DesignTokens.Typography.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(AppTheme.accent)
            .help("AI Assistant")
            .popover(isPresented: $showAIChat) {
                TerminalAIChatView(repoPath: appState.currentRepository?.path)
                    .frame(width: 400, height: 500)
            }

            // AI Toggle
            Toggle(isOn: $aiEnabled) {
                HStack(spacing: DesignTokens.Spacing.xxs) {
                    Image(systemName: "sparkles")
                        .font(DesignTokens.Typography.caption2)
                        .foregroundColor(AppTheme.textSecondary)
                    Text("AI")
                        .font(DesignTokens.Typography.caption2)
                }
            }
            .toggleStyle(.button)
            .buttonStyle(.plain)
            .foregroundColor(aiEnabled ? AppTheme.accent : AppTheme.textSecondary)
            .help("AI Suggestions")

            // Clear
            Button {
                viewModel.clearTerminal()
            } label: {
                Image(systemName: "trash")
                    .font(DesignTokens.Typography.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(AppTheme.textSecondary)
            .help("Clear Terminal")
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
        .background(Color(hex: "16161e"))
    }

    // MARK: - AI Suggestions (Warp-style)

    private var aiSuggestionsView: some View {
        suggestionPanel
    }

    private var suggestionPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            suggestionHeader
            Divider().background(Color(hex: "283457"))
            suggestionsList
        }
        .background(Color(hex: "16161e").opacity(0.98))
        .cornerRadius(DesignTokens.CornerRadius.xl)
        .shadow(color: AppTheme.background.opacity(0.3), radius: 20)
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.bottom, DesignTokens.Spacing.md)
        .frame(maxWidth: 600)
    }

    private var suggestionHeader: some View {
        HStack(spacing: DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs) {
            Image(systemName: "sparkles")
                .font(DesignTokens.Typography.caption2)
                .foregroundColor(AppTheme.accent)
            Text("AI Suggestions")
                .font(DesignTokens.Typography.caption2)
                .foregroundColor(AppTheme.accent)
            if viewModel.isLoadingSuggestions {
                ProgressView().scaleEffect(0.5).frame(width: DesignTokens.Size.iconSM, height: DesignTokens.Size.iconSM)
            }
            Spacer()
            Text("Tab • ↑↓")
                .font(DesignTokens.Typography.caption2)
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
        .background(Color(hex: "1a1b26"))
    }

    @ViewBuilder
    private var suggestionsList: some View {
        if !viewModel.aiSuggestions.isEmpty {
            ForEach(Array(viewModel.aiSuggestions.prefix(5).enumerated()), id: \.offset) { index, suggestion in
                suggestionRow(suggestion: suggestion, index: index)
                if index < viewModel.aiSuggestions.count - 1 {
                    Divider().background(Color(hex: "283457").opacity(0.5))
                }
            }
        } else if viewModel.isLoadingSuggestions {
            HStack {
                Spacer()
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.7)
                Text("Loading AI suggestions...")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.accent)
                Spacer()
            }
            .padding(DesignTokens.Spacing.md)
        } else {
            Text("Type to get AI suggestions...")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(AppTheme.textSecondary)
                .padding(DesignTokens.Spacing.md)
        }
    }

    private func suggestionRow(suggestion: TerminalSuggestion, index: Int) -> some View {
        Button {
            viewModel.applySuggestion(suggestion)
        } label: {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Circle()
                        .fill(index == viewModel.selectedSuggestionIndex ? Color(hex: "7aa2f7") : Color.clear)
                        .frame(width: DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs, height: DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
                    Text(suggestion.command)
                        .font(DesignTokens.Typography.callout)
                        .foregroundColor(Color(hex: "c0caf5"))
                    Spacer()
                    if suggestion.confidence > 0.8 {
                        Text("HIGH")
                            .font(DesignTokens.Typography.caption2)
                            .foregroundColor(AppTheme.success)
                            .padding(.horizontal, DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
                            .padding(.vertical, DesignTokens.Spacing.xxs)
                            .background(AppTheme.success.opacity(0.2))
                            .cornerRadius(DesignTokens.CornerRadius.sm)
                    }
                }
                if !suggestion.description.isEmpty {
                    Text(suggestion.description)
                        .font(DesignTokens.Typography.caption2)
                        .foregroundColor(AppTheme.textSecondary)
                        .lineLimit(2)
                        .padding(.leading, DesignTokens.Size.iconMD - DesignTokens.Spacing.xxs)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(index == viewModel.selectedSuggestionIndex ? Color(hex: "283457") : Color.clear)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Status Bar

    private var statusBarView: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: "terminal")
                    .font(DesignTokens.Typography.caption2)
                    .foregroundColor(AppTheme.textSecondary)
                Text("\(viewModel.commandCount) commands")
                    .font(DesignTokens.Typography.caption2)
            }

            Spacer()

            // Ghostty indicator
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: "bolt.fill")
                    .font(DesignTokens.Typography.caption2)
                Text("Ghostty")
                    .font(DesignTokens.Typography.caption2)
            }
            .foregroundColor(AppTheme.success)

            if viewModel.isRunning {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: DesignTokens.Size.iconSM, height: DesignTokens.Size.iconSM)
                    Text("Running...")
                        .font(DesignTokens.Typography.caption2)
                }
                .foregroundColor(AppTheme.accent)
            }
        }
        .foregroundColor(AppTheme.textSecondary)
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(Color(hex: "16161e"))
    }
}

// MARK: - Ghostty NSViewRepresentable

struct GhosttyDirectRepresentable: NSViewRepresentable {
    @ObservedObject var viewModel: GhosttyDirectViewModel

    func makeNSView(context: Context) -> GhosttyNativeView {
        let view = GhosttyNativeView()

        // Store reference
        context.coordinator.nativeView = view
        viewModel.nativeView = view
        view.viewModel = viewModel

        // Ghostty will initialize automatically when view moves to window

        return view
    }

    func updateNSView(_ nsView: GhosttyNativeView, context: Context) {
        // Handle updates if needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    class Coordinator: NSObject {
        var viewModel: GhosttyDirectViewModel
        weak var nativeView: GhosttyNativeView?

        init(viewModel: GhosttyDirectViewModel) {
            self.viewModel = viewModel
        }

        deinit {
            nativeView?.cleanup()
        }
    }
}

// MARK: - Ghostty Native View (NSView)

class GhosttyNativeView: NSView {
    private var app: ghostty_app_t?
    var surface: ghostty_surface_t? // Make surface accessible to ViewModel
    private var config: ghostty_config_t?
    private static var ghosttyInitialized = false
    private static let initLock = NSLock()

    private var hasInitialized = false
    weak var viewModel: GhosttyDirectViewModel?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor(red: 0.1, green: 0.11, blue: 0.15, alpha: 1.0).cgColor

        // Initialize Ghostty global state once
        Self.initializeGhosttyOnce()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        // Initialize when view is added to window
        if window != nil && !hasInitialized {
            hasInitialized = true
            initialize()
        }
    }

    // MARK: - First Responder

    override var acceptsFirstResponder: Bool {
        return true
    }

    override func becomeFirstResponder() -> Bool {
        print("[Ghostty] View became first responder")
        if let surface = surface {
            ghostty_surface_set_focus(surface, true)
        }
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        print("[Ghostty] View resigned first responder")
        if let surface = surface {
            ghostty_surface_set_focus(surface, false)
        }
        return super.resignFirstResponder()
    }

    // MARK: - Keyboard Input

    override func keyDown(with event: NSEvent) {
        guard surface != nil else { return }

        let keyCode = event.keyCode
        let characters = event.characters ?? ""
        let modifiers = event.modifierFlags

        print("[Ghostty] Key: code=\(keyCode), char='\(characters)'")

        // Handle special keys directly using ghostty_surface_key()
        switch keyCode {
        case 51: // Delete/Backspace
            print("[Ghostty] Backspace (keyCode 51)")
            sendKey(GHOSTTY_KEY_BACKSPACE, keyCode: 51)
            viewModel?.onBackspace()
            return

        case 36: // Return/Enter
            print("[Ghostty] Enter")
            sendKey(GHOSTTY_KEY_ENTER, keyCode: 36, text: "\r")
            viewModel?.onEnter()
            return

        case 48: // Tab
            print("[Ghostty] Tab")
            // If we have AI suggestions, apply the selected one
            if let vm = viewModel, !vm.aiSuggestions.isEmpty {
                vm.applySelectedSuggestion()
            } else {
                sendKey(GHOSTTY_KEY_TAB, keyCode: 48, text: "\t")
            }
            return

        case 53: // Escape
            print("[Ghostty] Escape")
            sendKey(GHOSTTY_KEY_ESCAPE, keyCode: 53)
            return

        case 123: // Left Arrow
            print("[Ghostty] Left Arrow")
            sendKey(GHOSTTY_KEY_ARROW_LEFT, keyCode: 123)
            return

        case 124: // Right Arrow
            print("[Ghostty] Right Arrow")
            sendKey(GHOSTTY_KEY_ARROW_RIGHT, keyCode: 124)
            return

        case 125: // Down Arrow
            print("[Ghostty] Down Arrow")
            sendKey(GHOSTTY_KEY_ARROW_DOWN, keyCode: 125)
            return

        case 126: // Up Arrow
            print("[Ghostty] Up Arrow")
            sendKey(GHOSTTY_KEY_ARROW_UP, keyCode: 126)
            return

        case 117: // Forward Delete
            print("[Ghostty] Forward Delete")
            sendKey(GHOSTTY_KEY_DELETE, keyCode: 117)
            return

        case 115: // Home
            print("[Ghostty] Home")
            sendKey(GHOSTTY_KEY_HOME, keyCode: 115)
            return

        case 119: // End
            print("[Ghostty] End")
            sendKey(GHOSTTY_KEY_END, keyCode: 119)
            return

        case 116: // Page Up
            print("[Ghostty] Page Up")
            sendKey(GHOSTTY_KEY_PAGE_UP, keyCode: 116)
            return

        case 121: // Page Down
            print("[Ghostty] Page Down")
            sendKey(GHOSTTY_KEY_PAGE_DOWN, keyCode: 121)
            return

        default:
            // For regular characters
            if !characters.isEmpty {
                print("[Ghostty] Regular char: '\(characters)'")

                // Handle Ctrl+ combinations
                if modifiers.contains(.control) && !modifiers.contains(.command) {
                    // Send control character
                    if let firstChar = characters.first, firstChar.isLetter {
                        let ctrlChar = Character(UnicodeScalar(firstChar.uppercased().unicodeScalars.first!.value - 64)!)
                        sendText(String(ctrlChar))
                        return
                    }
                }

                sendText(characters)
                viewModel?.onTextInput(characters)
            }
        }
    }

    override func flagsChanged(with event: NSEvent) {
        // Handle modifier keys for suggestion navigation
        let modifiers = event.modifierFlags

        if modifiers.contains(.control) {
            if event.keyCode == 110 { // Ctrl+N - Next suggestion
                viewModel?.selectNextSuggestion()
            } else if event.keyCode == 112 { // Ctrl+P - Previous suggestion
                viewModel?.selectPreviousSuggestion()
            }
        }
    }

    private func sendText(_ text: String) {
        guard let surface = surface else { return }
        text.withCString { cString in
            let length = strlen(cString)
            ghostty_surface_text(surface, cString, UInt(length))
        }
    }

    /// Send a key event using ghostty_surface_key() for special keys
    private func sendKey(_ key: ghostty_input_key_e, mods: ghostty_input_mods_e = GHOSTTY_MODS_NONE, keyCode: UInt32 = 0, text: String? = nil) {
        guard let surface = surface else { return }

        var keyStruct = ghostty_input_key_s(
            action: GHOSTTY_ACTION_PRESS,
            mods: mods,
            consumed_mods: GHOSTTY_MODS_NONE,
            keycode: keyCode,
            text: nil,
            unshifted_codepoint: 0,
            composing: false
        )

        if let text = text {
            text.withCString { cString in
                keyStruct.text = cString
                _ = ghostty_surface_key(surface, keyStruct)
            }
        } else {
            _ = ghostty_surface_key(surface, keyStruct)
        }
    }

    private static func initializeGhosttyOnce() {
        initLock.lock()
        defer { initLock.unlock() }

        guard !ghosttyInitialized else { return }

        // Get process arguments
        let args = CommandLine.arguments

        // Convert Swift String array to C char** array
        var cArgs = args.map { strdup($0) }
        defer { cArgs.forEach { free($0) } }

        // Call ghostty_init()
        let result = ghostty_init(UInt(cArgs.count), &cArgs)
        if result != 0 {
            print("❌ ghostty_init() failed with code: \(result)")
            return
        }

        print("✅ Ghostty global state initialized")
        ghosttyInitialized = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)

        // Update surface size when frame changes
        if let surface = surface, newSize.width > 0 && newSize.height > 0 {
            print("[Ghostty] Frame resized to: \(newSize.width)x\(newSize.height)")
            ghostty_surface_set_size(surface, UInt32(newSize.width), UInt32(newSize.height))
            ghostty_surface_draw(surface)
        }
    }

    func initialize() {
        // Ensure Ghostty global state is initialized
        guard Self.ghosttyInitialized else {
            showError("Ghostty global state not initialized")
            return
        }

        print("[Ghostty] Starting terminal initialization...")

        // Create Ghostty configuration
        print("[Ghostty] Creating config...")
        config = ghostty_config_new()
        guard config != nil else {
            showError("Failed to create Ghostty config")
            return
        }
        print("[Ghostty] Config created successfully")

        // Load default configuration
        ghostty_config_load_default_files(config)
        ghostty_config_finalize(config)

        // Create runtime configuration
        var runtimeConfig = ghostty_runtime_config_s()
        runtimeConfig.userdata = Unmanaged.passUnretained(self).toOpaque()
        runtimeConfig.supports_selection_clipboard = false

        // Set up callbacks - these are required by Ghostty
        runtimeConfig.wakeup_cb = { userdata in
            // Wake up callback - required for async operations
        }

        runtimeConfig.action_cb = { app, target, action in
            // Action callback - handles terminal actions
            // Return false to let Ghostty handle it, true if we handled it
            return false
        }

        runtimeConfig.read_clipboard_cb = nil
        runtimeConfig.confirm_read_clipboard_cb = nil
        runtimeConfig.write_clipboard_cb = nil
        runtimeConfig.close_surface_cb = nil

        // Create Ghostty app
        print("[Ghostty] Creating app...")
        app = ghostty_app_new(&runtimeConfig, config)
        guard app != nil else {
            showError("Failed to create Ghostty app")
            return
        }
        print("[Ghostty] App created successfully")

        // Create surface configuration
        var surfaceConfig = ghostty_surface_config_new()
        surfaceConfig.platform_tag = GHOSTTY_PLATFORM_MACOS
        surfaceConfig.platform = ghostty_platform_u(macos: ghostty_platform_macos_s(
            nsview: Unmanaged.passUnretained(self).toOpaque()
        ))
        surfaceConfig.userdata = Unmanaged.passUnretained(self).toOpaque()
        surfaceConfig.scale_factor = Double(NSScreen.main?.backingScaleFactor ?? 2.0)
        surfaceConfig.font_size = 13.0

        // Set working directory to repository path if available
        if let repoPath = viewModel?.repoPath {
            surfaceConfig.working_directory = UnsafePointer(strdup(repoPath))
            print("[Ghostty] Setting working directory to: \(repoPath)")
        } else {
            surfaceConfig.working_directory = nil
        }

        surfaceConfig.command = nil
        surfaceConfig.env_vars = nil
        surfaceConfig.env_var_count = 0
        surfaceConfig.initial_input = nil
        surfaceConfig.wait_after_command = false

        // Create Ghostty surface
        print("[Ghostty] Creating surface...")
        surface = ghostty_surface_new(app, &surfaceConfig)
        guard surface != nil else {
            showError("Failed to create Ghostty surface")
            return
        }
        print("[Ghostty] Surface created successfully")

        print("✅ Ghostty Terminal initialized successfully")

        // Set initial size
        if frame.width > 0 && frame.height > 0 {
            print("[Ghostty] Setting surface size: \(frame.width)x\(frame.height)")
            ghostty_surface_set_size(surface, UInt32(frame.width), UInt32(frame.height))
        }

        // Set focus to activate the surface
        ghostty_surface_set_focus(surface, true)

        // Trigger initial draw
        print("[Ghostty] Triggering initial draw...")
        ghostty_surface_draw(surface)

        print("[Ghostty] Initialization complete, terminal should be visible")

        // Make this view the first responder to receive keyboard events
        DispatchQueue.main.async { [weak self] in
            self?.window?.makeFirstResponder(self)
        }
    }

    private func showError(_ message: String) {
        print("❌ Ghostty Error: \(message)")

        let label = NSTextField(labelWithString: "Ghostty Terminal Error\n\n\(message)\n\nCheck Console for details.")
        label.alignment = .center
        label.textColor = NSColor.systemRed
        label.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        label.maximumNumberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false

        addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20)
        ])
    }

    func cleanup() {
        // Free Ghostty resources
        if let surface = surface {
            ghostty_surface_free(surface)
            self.surface = nil
        }

        if let app = app {
            ghostty_app_free(app)
            self.app = nil
        }

        if let config = config {
            ghostty_config_free(config)
            self.config = nil
        }

        print("✅ Ghostty Terminal cleanup complete")
    }
}

// MARK: - ViewModel

class GhosttyDirectViewModel: ObservableObject {
    @Published var currentInput = ""
    @Published var currentDirectory = "~"
    @Published var commandCount = 0
    @Published var isRunning = false
    @Published var aiSuggestions: [TerminalSuggestion] = []
    @Published var selectedSuggestionIndex = 0
    @Published var isLoadingSuggestions = false

    weak var nativeView: GhosttyNativeView?

    private var suggestionTask: Task<Void, Never>?
    private var lastSuggestionInput = ""
    private let aiService = AIService.shared

    var repoPath: String?

    func setWorkingDirectory(_ path: String) {
        currentDirectory = (path as NSString).lastPathComponent
        repoPath = path
    }

    func clearTerminal() {
        if let surface = nativeView?.surface {
            // Send Ctrl+L to clear
            let clear = "\u{0C}"
            clear.withCString { cString in
                ghostty_surface_text(surface, cString, 1)
            }
        }
    }

    func applySuggestion(_ suggestion: TerminalSuggestion) {
        guard let surface = nativeView?.surface else { return }

        // Clear current input
        for _ in 0..<currentInput.count {
            let backspace = "\u{7f}"
            backspace.withCString { cString in
                ghostty_surface_text(surface, cString, 1)
            }
        }

        // Write suggestion
        suggestion.command.withCString { cString in
            let length = strlen(cString)
            ghostty_surface_text(surface, cString, UInt(length))
        }

        aiSuggestions.removeAll()
        currentInput = suggestion.command
    }

    func onTextInput(_ text: String) {
        currentInput += text
        fetchAISuggestionsIfNeeded()
    }

    func onBackspace() {
        if !currentInput.isEmpty {
            currentInput.removeLast()
        }
        fetchAISuggestionsIfNeeded()
    }

    func onEnter() {
        currentInput = ""
        aiSuggestions.removeAll()
        commandCount += 1
    }

    private func fetchAISuggestionsIfNeeded() {
        // Cancel previous task
        suggestionTask?.cancel()

        // Don't fetch if input is too short
        let trimmed = currentInput.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else {
            print("[AI] Input too short: '\(trimmed)'")
            aiSuggestions.removeAll()
            return
        }

        // Check if input changed significantly
        guard trimmed != lastSuggestionInput else { return }
        lastSuggestionInput = trimmed

        print("[AI] Fetching suggestions for: '\(trimmed)'")

        // Debounce: wait 300ms before fetching
        suggestionTask = Task { @MainActor in
            isLoadingSuggestions = true

            do {
                try await Task.sleep(nanoseconds: 300_000_000) // 300ms
                guard !Task.isCancelled else { return }

                print("[AI] Calling AIService.suggestTerminalCommands...")
                let suggestions = try await aiService.suggestTerminalCommands(
                    input: trimmed,
                    repoPath: repoPath
                )

                guard !Task.isCancelled else { return }
                print("[AI] Received \(suggestions.count) suggestions")
                aiSuggestions = suggestions
                selectedSuggestionIndex = 0
                isLoadingSuggestions = false
            } catch {
                if !Task.isCancelled {
                    print("[AI] Error fetching suggestions: \(error)")
                    aiSuggestions.removeAll()
                    isLoadingSuggestions = false
                }
            }
        }
    }

    func selectNextSuggestion() {
        guard !aiSuggestions.isEmpty else { return }
        selectedSuggestionIndex = (selectedSuggestionIndex + 1) % aiSuggestions.count
    }

    func selectPreviousSuggestion() {
        guard !aiSuggestions.isEmpty else { return }
        selectedSuggestionIndex = selectedSuggestionIndex > 0 ? selectedSuggestionIndex - 1 : aiSuggestions.count - 1
    }

    func applySelectedSuggestion() {
        guard !aiSuggestions.isEmpty else { return }
        applySuggestion(aiSuggestions[selectedSuggestionIndex])
    }
}

#else
// MARK: - Ghostty Stub (When Framework Not Available)

/// Stub view when Ghostty framework is not available
struct GhosttyDirectView: View {
    var body: some View {
        VStack {
            Spacer()
            Text("Ghostty Terminal")
                .font(.title2)
                .foregroundColor(AppTheme.textPrimary)
            Text("GhosttyKit framework not available")
                .font(.caption)
                .foregroundColor(AppTheme.textPrimary)
            Text("Enable GHOSTTY_AVAILABLE flag in build settings")
                .font(.caption2)
                .foregroundColor(AppTheme.textPrimary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "1a1b26"))
    }
}

// Stub ViewModel
class GhosttyDirectViewModel: ObservableObject {
    func setWorkingDirectory(_ path: String) {}
}

#endif

// Note: TerminalSuggestion is defined in AIService.swift
