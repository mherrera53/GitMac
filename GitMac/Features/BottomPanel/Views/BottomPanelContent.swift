//
//  BottomPanelContent.swift
//  GitMac
//
//  Created by GitMac on 2025-12-28.
//

import SwiftUI
import AppKit

struct BottomPanelContent: View {
    let tab: BottomPanelTab
    @Environment(AppState.self) var appState

    var body: some View {
        Group {
            switch tab.type {
            case .terminal:
                TerminalPanelContent()
            case .taiga:
                TaigaPanelContent()
            case .planner:
                PlannerPanelContent()
            case .linear:
                LinearPanelContent()
            case .jira:
                JiraPanelContent()
            case .notion:
                NotionPanelContent()
            case .teamActivity:
                TeamActivityPanelContent()
            case .analytics:
                AnalyticsPanelContent()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.panel)
    }
}

// MARK: - Panel Content Views

struct TerminalPanelContent: View {
    @Environment(AppState.self) var appState

    var body: some View {
        // Ghostty + Custom AI Input
        GhosttyWithAIInput()
            .environment(appState)
    }
}

// MARK: - Ghostty + AI Input View

struct GhosttyWithAIInput: View {
    @Environment(AppState.self) var appState
    @State private var inputText = ""
    @StateObject private var ghosttyConnector = GhosttyConnector()
    @FocusState private var isInputFocused: Bool

    var body: some View {
        #if GHOSTTY_AVAILABLE
        VStack(spacing: 0) {
            // Ghostty output area
            GhosttyOutputView(connector: ghosttyConnector, repoPath: appState.currentRepository?.path)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // AI-powered multiline input bar
            AIInputBar(
                text: $inputText,
                isFocused: $isInputFocused,
                workingDirectory: appState.currentRepository?.path ?? "~",
                onSubmit: { command in
                    sendCommand(command)
                }
            )
        }
        .background(AppTheme.background)
        .onAppear {
            isInputFocused = true
        }
        .onChange(of: appState.currentRepository?.path) { _, newPath in
            if let path = newPath {
                ghosttyConnector.sendText("cd \(path)\n")
            }
        }
        #else
        Text("Ghostty not available")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.background)
        #endif
    }

    private func sendCommand(_ command: String) {
        guard !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        Logger.debug("[Terminal] Sending command: \(command)")
        ghosttyConnector.sendText(command + "\n")
        inputText = ""
    }
}

// MARK: - Ghostty Connector (holds reference to NSView)

@MainActor
class GhosttyConnector: ObservableObject {
    weak var ghosttyView: GhosttyPureNSView?

    func sendText(_ text: String) {
        Logger.debug("[Connector] sendText called, view: \(ghosttyView != nil ? "exists" : "nil")")
        ghosttyView?.sendText(text)
    }
}


// AIInputBar has been moved to Features/Terminal/Views/TerminalInputBar.swift


// MARK: - Ghostty Output View

#if GHOSTTY_AVAILABLE
struct GhosttyOutputView: NSViewRepresentable {
    @ObservedObject var connector: GhosttyConnector
    let repoPath: String?

    func makeNSView(context: Context) -> GhosttyPureNSView {
        let view = GhosttyPureNSView(repoPath: repoPath)
        view.disableKeyboardInput = true // Output only - use custom input bar
        // Connect the view to the connector
        DispatchQueue.main.async {
            connector.ghosttyView = view
            Logger.debug("[GhosttyOutput] View connected to connector")
        }
        return view
    }

    func updateNSView(_ nsView: GhosttyPureNSView, context: Context) {
        // Ensure connector stays connected
        if connector.ghosttyView == nil {
            connector.ghosttyView = nsView
        }
    }
}
#endif

// MARK: - Pure Ghostty View (100% native, no custom input bar)

struct GhosttyPureView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        #if GHOSTTY_AVAILABLE
        GhosttyPureTerminal(repoPath: appState.currentRepository?.path)
        #else
        Text("Ghostty not available")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.background)
        #endif
    }
}

#if GHOSTTY_AVAILABLE
struct GhosttyPureTerminal: NSViewRepresentable {
    let repoPath: String?

    func makeNSView(context: Context) -> GhosttyPureNSView {
        let view = GhosttyPureNSView(repoPath: repoPath)
        return view
    }

    func updateNSView(_ nsView: GhosttyPureNSView, context: Context) {
        // Update if repo changes
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject {
    }
}

// MARK: - Native Ghostty NSView

class GhosttyPureNSView: NSView {
    private var app: ghostty_app_t?
    private var surface: ghostty_surface_t?
    private var config: ghostty_config_t?
    private var hasInitialized = false
    private let repoPath: String?

    // For hybrid mode: disable keyboard input when using external input bar
    var disableKeyboardInput = false

    private static var ghosttyInitialized = false
    private static let initLock = NSLock()

    init(repoPath: String?) {
        self.repoPath = repoPath
        super.init(frame: .zero)
        self.wantsLayer = true
        Self.initializeGhosttyOnce()
    }

    // MARK: - Public API for external input

    func sendText(_ text: String) {
        guard let surface = surface else {
            Logger.debug("[Ghostty] sendText failed: surface is nil")
            return
        }

        // Split text and newlines - send newlines as Enter key
        var remaining = text
        while !remaining.isEmpty {
            if remaining.hasPrefix("\n") {
                // Send Enter key
                sendEnter()
                remaining.removeFirst()
            } else if let nlIndex = remaining.firstIndex(of: "\n") {
                // Send text before newline
                let textPart = String(remaining[..<nlIndex])
                textPart.withCString { cString in
                    ghostty_surface_text(surface, cString, UInt(strlen(cString)))
                }
                remaining = String(remaining[nlIndex...])
            } else {
                // No more newlines, send rest
                remaining.withCString { cString in
                    ghostty_surface_text(surface, cString, UInt(strlen(cString)))
                }
                remaining = ""
            }
        }
    }

    func sendEnter() {
        guard let surface = surface else { return }
        // Send Enter as key press with \r as text
        var keyInput = ghostty_input_key_s(
            action: GHOSTTY_ACTION_PRESS,
            mods: GHOSTTY_MODS_NONE,
            consumed_mods: GHOSTTY_MODS_NONE,
            keycode: 36, // macOS keycode for Return
            text: nil,
            unshifted_codepoint: 0,
            composing: false
        )
        "\r".withCString { cString in
            keyInput.text = cString
            _ = ghostty_surface_key(surface, keyInput)
        }
    }

    func sendKey(_ key: ghostty_input_key_e, mods: ghostty_input_mods_e = GHOSTTY_MODS_NONE) {
        guard let surface = surface else { return }
        let keyInput = ghostty_input_key_s(
            action: GHOSTTY_ACTION_PRESS,
            mods: mods,
            consumed_mods: GHOSTTY_MODS_NONE,
            keycode: 0,
            text: nil,
            unshifted_codepoint: 0,
            composing: false
        )
        _ = ghostty_surface_key(surface, keyInput)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil && !hasInitialized {
            hasInitialized = true
            initializeGhostty()
        }
    }

    override func becomeFirstResponder() -> Bool {
        if let surface = surface {
            ghostty_surface_set_focus(surface, true)
        }
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        if let surface = surface {
            ghostty_surface_set_focus(surface, false)
        }
        return super.resignFirstResponder()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        if let surface = surface, newSize.width > 0 && newSize.height > 0 {
            ghostty_surface_set_size(surface, UInt32(newSize.width), UInt32(newSize.height))
            ghostty_surface_draw(surface)
        }
    }

    // MARK: - Keyboard

    override func keyDown(with event: NSEvent) {
        // Skip keyboard input if using external input bar
        guard !disableKeyboardInput, let surface = surface else { return }

        let keyCode = event.keyCode
        let characters = event.characters ?? ""
        let mods = convertModifiers(event.modifierFlags)

        // Map macOS keyCode to Ghostty key
        let ghosttyKey = mapKeyCode(keyCode)

        if ghosttyKey != GHOSTTY_KEY_UNIDENTIFIED {
            // Send as key event
            var keyInput = ghostty_input_key_s(
                action: GHOSTTY_ACTION_PRESS,
                mods: mods,
                consumed_mods: GHOSTTY_MODS_NONE,
                keycode: UInt32(keyCode),
                text: nil,
                unshifted_codepoint: 0,
                composing: false
            )

            if !characters.isEmpty {
                characters.withCString { cString in
                    keyInput.text = cString
                    _ = ghostty_surface_key(surface, keyInput)
                }
            } else {
                _ = ghostty_surface_key(surface, keyInput)
            }
        } else if !characters.isEmpty {
            // Send as text
            characters.withCString { cString in
                ghostty_surface_text(surface, cString, UInt(strlen(cString)))
            }
        }
    }

    override func keyUp(with event: NSEvent) {
        guard let surface = surface else { return }

        let keyCode = event.keyCode
        let mods = convertModifiers(event.modifierFlags)
        let ghosttyKey = mapKeyCode(keyCode)

        if ghosttyKey != GHOSTTY_KEY_UNIDENTIFIED {
            let keyInput = ghostty_input_key_s(
                action: GHOSTTY_ACTION_RELEASE,
                mods: mods,
                consumed_mods: GHOSTTY_MODS_NONE,
                keycode: UInt32(keyCode),
                text: nil,
                unshifted_codepoint: 0,
                composing: false
            )
            _ = ghostty_surface_key(surface, keyInput)
        }
    }

    override func flagsChanged(with event: NSEvent) {
        // Handle modifier key changes if needed
    }

    // MARK: - Mouse

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        guard let surface = surface else { return }
        let point = convert(event.locationInWindow, from: nil)
        let mods = convertModifiers(event.modifierFlags)
        ghostty_surface_mouse_pos(surface, point.x, Double(frame.height) - point.y, mods)
        ghostty_surface_mouse_button(surface, GHOSTTY_MOUSE_PRESS, GHOSTTY_MOUSE_LEFT, mods)
    }

    override func mouseUp(with event: NSEvent) {
        guard let surface = surface else { return }
        let mods = convertModifiers(event.modifierFlags)
        ghostty_surface_mouse_button(surface, GHOSTTY_MOUSE_RELEASE, GHOSTTY_MOUSE_LEFT, mods)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let surface = surface else { return }
        let point = convert(event.locationInWindow, from: nil)
        let mods = convertModifiers(event.modifierFlags)
        ghostty_surface_mouse_pos(surface, point.x, Double(frame.height) - point.y, mods)
    }

    override func scrollWheel(with event: NSEvent) {
        guard let surface = surface else { return }
        ghostty_surface_mouse_scroll(surface, event.scrollingDeltaX, event.scrollingDeltaY, 0)
    }

    // MARK: - Initialization

    private static func initializeGhosttyOnce() {
        initLock.lock()
        defer { initLock.unlock() }

        guard !ghosttyInitialized else { return }

        let args = CommandLine.arguments
        var cArgs = args.map { strdup($0) }
        defer { cArgs.forEach { free($0) } }

        let result = ghostty_init(UInt(cArgs.count), &cArgs)
        if result == GHOSTTY_SUCCESS {
            Logger.debug("✅ Ghostty initialized")
            ghosttyInitialized = true
        } else {
            Logger.debug("❌ Ghostty init failed: \(result)")
        }
    }

    private func initializeGhostty() {
        guard Self.ghosttyInitialized else {
            showError("Ghostty not initialized")
            return
        }

        // Create config
        config = ghostty_config_new()
        guard config != nil else {
            showError("Failed to create config")
            return
        }
        ghostty_config_load_default_files(config)
        ghostty_config_finalize(config)

        // Runtime config with callbacks
        var runtimeConfig = ghostty_runtime_config_s()
        runtimeConfig.userdata = Unmanaged.passUnretained(self).toOpaque()
        runtimeConfig.supports_selection_clipboard = false
        runtimeConfig.wakeup_cb = { _ in }
        runtimeConfig.action_cb = { _, _, _ in false }

        // Create app
        app = ghostty_app_new(&runtimeConfig, config)
        guard app != nil else {
            showError("Failed to create app")
            return
        }

        // Surface config
        var surfaceConfig = ghostty_surface_config_new()
        surfaceConfig.platform_tag = GHOSTTY_PLATFORM_MACOS
        surfaceConfig.platform = ghostty_platform_u(macos: ghostty_platform_macos_s(
            nsview: Unmanaged.passUnretained(self).toOpaque()
        ))
        surfaceConfig.userdata = Unmanaged.passUnretained(self).toOpaque()
        surfaceConfig.scale_factor = Double(window?.backingScaleFactor ?? 2.0)
        surfaceConfig.font_size = 13.0

        if let path = repoPath {
            surfaceConfig.working_directory = UnsafePointer(strdup(path))
        }

        // Create surface
        surface = ghostty_surface_new(app, &surfaceConfig)
        guard surface != nil else {
            showError("Failed to create surface")
            return
        }

        Logger.debug("✅ Ghostty terminal ready")

        // Set size and focus
        if frame.width > 0 && frame.height > 0 {
            ghostty_surface_set_size(surface, UInt32(frame.width), UInt32(frame.height))
        }
        ghostty_surface_set_focus(surface, true)
        ghostty_surface_draw(surface)

        DispatchQueue.main.async { [weak self] in
            self?.window?.makeFirstResponder(self)
        }
    }

    private func showError(_ message: String) {
        Logger.debug("❌ Ghostty: \(message)")
        let label = NSTextField(labelWithString: message)
        label.textColor = .systemRed
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    private func convertModifiers(_ flags: NSEvent.ModifierFlags) -> ghostty_input_mods_e {
        var mods = GHOSTTY_MODS_NONE.rawValue
        if flags.contains(.shift) { mods |= GHOSTTY_MODS_SHIFT.rawValue }
        if flags.contains(.control) { mods |= GHOSTTY_MODS_CTRL.rawValue }
        if flags.contains(.option) { mods |= GHOSTTY_MODS_ALT.rawValue }
        if flags.contains(.command) { mods |= GHOSTTY_MODS_SUPER.rawValue }
        return ghostty_input_mods_e(rawValue: mods)
    }

    private func mapKeyCode(_ keyCode: UInt16) -> ghostty_input_key_e {
        switch keyCode {
        case 36: return GHOSTTY_KEY_ENTER
        case 48: return GHOSTTY_KEY_TAB
        case 51: return GHOSTTY_KEY_BACKSPACE
        case 53: return GHOSTTY_KEY_ESCAPE
        case 117: return GHOSTTY_KEY_DELETE
        case 123: return GHOSTTY_KEY_ARROW_LEFT
        case 124: return GHOSTTY_KEY_ARROW_RIGHT
        case 125: return GHOSTTY_KEY_ARROW_DOWN
        case 126: return GHOSTTY_KEY_ARROW_UP
        case 115: return GHOSTTY_KEY_HOME
        case 119: return GHOSTTY_KEY_END
        case 116: return GHOSTTY_KEY_PAGE_UP
        case 121: return GHOSTTY_KEY_PAGE_DOWN
        case 49: return GHOSTTY_KEY_SPACE
        default: return GHOSTTY_KEY_UNIDENTIFIED
        }
    }

    func cleanup() {
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
    }

    override func removeFromSuperview() {
        cleanup()
        super.removeFromSuperview()
    }
}
#endif

struct TaigaPanelContent: View {
    @State private var dummyHeight: CGFloat = 300
    var body: some View {
        TaigaTicketsPanel(height: $dummyHeight, onClose: {})
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PlannerPanelContent: View {
    @State private var dummyHeight: CGFloat = 300
    var body: some View {
        PlannerTasksPanel(height: $dummyHeight, onClose: {})
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct LinearPanelContent: View {
    @State private var dummyHeight: CGFloat = 300
    var body: some View {
        LinearPanel(height: $dummyHeight, onClose: {})
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct JiraPanelContent: View {
    @State private var dummyHeight: CGFloat = 300
    var body: some View {
        JiraPanel(height: $dummyHeight, onClose: {})
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct NotionPanelContent: View {
    @State private var dummyHeight: CGFloat = 300
    var body: some View {
        NotionPanel(height: $dummyHeight, onClose: {})
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct TeamActivityPanelContent: View {
    var body: some View {
        RepositoryActivityPanel()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct AnalyticsPanelContent: View {
    var body: some View {
        AnalyticsDashboard()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PlaceholderPanelContent: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: icon)
                .font(DesignTokens.Typography.iconXXXXL)
                .foregroundStyle(AppTheme.textMuted)

            Text(title)
                .font(DesignTokens.Typography.title3)
                .fontWeight(.medium)
                .foregroundStyle(AppTheme.textPrimary)

            Text(message)
                .font(DesignTokens.Typography.body)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
    }
}

// Empty state view when no tabs are open
struct EmptyPanelView: View {
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "tray")
                .font(DesignTokens.Typography.iconXXXXL)
                .foregroundStyle(AppTheme.textMuted)

            Text("No panels open")
                .font(DesignTokens.Typography.headline)
                .foregroundStyle(AppTheme.textSecondary)

            Text("Click the + button or toolbar icons to add panels")
                .font(DesignTokens.Typography.callout)
                .foregroundStyle(AppTheme.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.panel)
    }
}

// MARK: - Block Terminal View (Warp-style with blocks)

struct BlockTerminalView: View {
    @Environment(AppState.self) var appState
    @StateObject private var viewModel = BlockTerminalViewModel()
    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Command blocks area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.blocks) { block in
                            WarpBlockView(block: block)
                                .id(block.id)
                        }
                    }
                    .padding(12)
                }
                .onChange(of: viewModel.blocks.count) { _, _ in
                    if let lastBlock = viewModel.blocks.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(lastBlock.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Multiline input bar at bottom
            MultilineInputBar(
                text: $inputText,
                isFocused: $isInputFocused,
                workingDirectory: viewModel.workingDirectory,
                onSubmit: { command in
                    executeCommand(command)
                }
            )
        }
        .background(AppTheme.background)
        .onAppear {
            if let path = appState.currentRepository?.path {
                viewModel.setWorkingDirectory(path)
            }
            isInputFocused = true
        }
        .onChange(of: appState.currentRepository?.path) { _, newPath in
            if let path = newPath {
                viewModel.setWorkingDirectory(path)
            }
        }
    }

    private func executeCommand(_ command: String) {
        guard !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        Task {
            await viewModel.execute(command)
        }
        inputText = ""
    }
}

// MARK: - Block Terminal ViewModel

@MainActor
class BlockTerminalViewModel: ObservableObject {
    @Published var blocks: [WarpBlock] = []
    @Published var workingDirectory: String = NSHomeDirectory()
    @Published var isRunning = false

    private let shellExecutor = ShellExecutor.shared
    private var commandHistory: [String] = []
    private var historyIndex: Int = -1

    func setWorkingDirectory(_ path: String) {
        workingDirectory = path
    }

    func execute(_ command: String) async {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCommand.isEmpty else { return }

        // Handle cd specially
        if trimmedCommand.hasPrefix("cd ") {
            let path = String(trimmedCommand.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            handleCd(path)
            return
        } else if trimmedCommand == "cd" {
            handleCd(NSHomeDirectory())
            return
        }

        // Handle clear
        if trimmedCommand == "clear" || trimmedCommand == "cls" {
            blocks.removeAll()
            return
        }

        // Add to history
        commandHistory.append(trimmedCommand)
        historyIndex = commandHistory.count

        // Create block
        let block = WarpBlock(
            command: trimmedCommand,
            workingDirectory: workingDirectory
        )
        blocks.append(block)
        let blockIndex = blocks.count - 1

        isRunning = true

        // Execute using zsh for better compatibility
        let result = await shellExecutor.execute(
            "/bin/zsh",
            arguments: ["-c", trimmedCommand],
            workingDirectory: workingDirectory
        )

        // Update block
        var output: [WarpOutputLine] = []

        if !result.stdout.isEmpty {
            for line in result.stdout.components(separatedBy: .newlines) where !line.isEmpty {
                output.append(WarpOutputLine(text: line, type: .stdout))
            }
        }

        if !result.stderr.isEmpty {
            for line in result.stderr.components(separatedBy: .newlines) where !line.isEmpty {
                output.append(WarpOutputLine(text: line, type: .stderr))
            }
        }

        blocks[blockIndex].output = output
        blocks[blockIndex].exitCode = result.exitCode
        blocks[blockIndex].isComplete = true

        isRunning = false
    }

    private func handleCd(_ path: String) {
        var newPath: String

        if path.hasPrefix("/") {
            newPath = path
        } else if path.hasPrefix("~") {
            newPath = path.replacingOccurrences(of: "~", with: NSHomeDirectory())
        } else {
            newPath = (workingDirectory as NSString).appendingPathComponent(path)
        }

        // Resolve .. and .
        newPath = (newPath as NSString).standardizingPath

        if FileManager.default.fileExists(atPath: newPath) {
            workingDirectory = newPath

            let block = WarpBlock(
                command: "cd \(path)",
                workingDirectory: workingDirectory,
                output: [],
                exitCode: 0,
                isComplete: true
            )
            blocks.append(block)
        } else {
            var block = WarpBlock(
                command: "cd \(path)",
                workingDirectory: workingDirectory
            )
            block.output = [WarpOutputLine(text: "cd: no such directory: \(path)", type: .stderr)]
            block.exitCode = 1
            block.isComplete = true
            blocks.append(block)
        }
    }

    func previousCommand() -> String {
        guard !commandHistory.isEmpty else { return "" }
        if historyIndex > 0 { historyIndex -= 1 }
        return commandHistory[historyIndex]
    }

    func nextCommand() -> String {
        guard !commandHistory.isEmpty else { return "" }
        if historyIndex < commandHistory.count - 1 {
            historyIndex += 1
            return commandHistory[historyIndex]
        }
        historyIndex = commandHistory.count
        return ""
    }
}

// MARK: - Warp Block Model

struct WarpBlock: Identifiable {
    let id = UUID()
    let command: String
    let workingDirectory: String
    let timestamp = Date()
    var output: [WarpOutputLine] = []
    var exitCode: Int32 = 0
    var isComplete: Bool = false
}

struct WarpOutputLine: Identifiable {
    let id = UUID()
    let text: String
    let type: WarpOutputType
}

enum WarpOutputType {
    case stdout, stderr, system
}

// MARK: - Warp-style Block View

struct WarpBlockView: View {
    let block: WarpBlock
    @State private var isHovered = false
    @State private var isCollapsed = false
    @State private var isCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with command
            HStack(spacing: 8) {
                // Status indicator
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)

                // Directory
                Text((block.workingDirectory as NSString).lastPathComponent)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.textMuted)

                Text("›")
                    .foregroundStyle(AppTheme.textMuted)

                // Command
                Text(block.command)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(isCollapsed ? 1 : nil)

                Spacer()

                // Actions on hover
                if isHovered {
                    HStack(spacing: 6) {
                        // Collapse toggle
                        if !block.output.isEmpty {
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    isCollapsed.toggle()
                                }
                            } label: {
                                Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(AppTheme.textMuted)
                            }
                            .buttonStyle(.plain)
                        }

                        // Copy button
                        Button {
                            copyOutput()
                        } label: {
                            Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(isCopied ? AppTheme.success : AppTheme.textMuted)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Running indicator
                if !block.isComplete {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppTheme.backgroundSecondary.opacity(0.5))

            // Output
            if !isCollapsed && !block.output.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(block.output) { line in
                        Text(line.text)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(line.type == .stderr ? AppTheme.error : AppTheme.textPrimary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            // Exit code if non-zero
            if block.isComplete && block.exitCode != 0 {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                    Text("Exit \(block.exitCode)")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(AppTheme.error)
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
            }
        }
        .background(AppTheme.backgroundSecondary)
        .clipShape(.rect(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHovered ? AppTheme.accent.opacity(0.3) : AppTheme.border.opacity(0.3), lineWidth: 1)
        )
        .onHover { isHovered = $0 }
    }

    var statusColor: Color {
        if !block.isComplete { return AppTheme.warning }
        return block.exitCode == 0 ? AppTheme.success : AppTheme.error
    }

    func copyOutput() {
        let text = block.output.map { $0.text }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text.isEmpty ? block.command : text, forType: .string)
        isCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { isCopied = false }
    }
}

// MARK: - Multiline Input Bar (supports paste multiline)

struct MultilineInputBar: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let workingDirectory: String
    let onSubmit: (String) -> Void

    @State private var textEditorHeight: CGFloat = 32

    private var isMultiline: Bool {
        text.contains("\n") || text.count > 60
    }

    private var lineCount: Int {
        max(1, text.components(separatedBy: "\n").count)
    }

    private var dynamicHeight: CGFloat {
        let base: CGFloat = 32
        let perLine: CGFloat = 18
        let calculated = base + CGFloat(max(0, lineCount - 1)) * perLine
        return min(150, calculated)
    }

    // Static completions for inline suggestions
    private static let completions: [String: String] = [
        "gi": "git", "git": "git status", "git s": "git status", "git st": "git status",
        "git a": "git add .", "git ad": "git add .", "git add": "git add .",
        "git c": "git commit -m \"\"", "git co": "git commit -m \"\"",
        "git p": "git push", "git pu": "git push",
        "git pl": "git pull", "git pul": "git pull",
        "git ch": "git checkout", "git b": "git branch", "git br": "git branch",
        "git d": "git diff", "git di": "git diff",
        "git l": "git log --oneline", "git lo": "git log --oneline",
        "git f": "git fetch", "git m": "git merge", "git r": "git rebase",
        "git sta": "git stash", "ls": "ls -la",
    ]

    private var ghostText: String {
        guard !text.isEmpty, !text.contains("\n") else { return "" }
        let key = text.lowercased().trimmingCharacters(in: .whitespaces)
        if let suggestion = Self.completions[key], suggestion.count > text.count {
            return String(suggestion.dropFirst(text.count))
        }
        return ""
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top border
            Rectangle()
                .fill(AppTheme.border.opacity(0.3))
                .frame(height: 1)

            HStack(alignment: .bottom, spacing: 8) {
                // Directory indicator
                Text((workingDirectory as NSString).lastPathComponent)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.textMuted)
                    .padding(.bottom, 6)

                Text("$")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AppTheme.accent)
                    .padding(.bottom, 6)

                // Input area
                ZStack(alignment: .topLeading) {
                    // Ghost text for single line
                    if !ghostText.isEmpty && lineCount == 1 {
                        HStack(spacing: 0) {
                            Text(text)
                                .font(.system(size: 13, design: .monospaced))
                                .opacity(0)
                            Text(ghostText)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(AppTheme.textMuted.opacity(0.4))
                            Text(" ⇥")
                                .font(.system(size: 9))
                                .foregroundStyle(AppTheme.textMuted.opacity(0.3))
                        }
                        .padding(.top, 6)
                    }

                    // Placeholder
                    if text.isEmpty {
                        Text("Enter command...")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(AppTheme.textMuted.opacity(0.5))
                            .padding(.top, 6)
                    }

                    // Text editor
                    MultilineTextField(
                        text: $text,
                        isFocused: isFocused,
                        onSubmit: {
                            // Apply ghost text on Tab or submit on Enter
                            onSubmit(text)
                        },
                        onTab: {
                            if !ghostText.isEmpty {
                                if let suggestion = Self.completions[text.lowercased().trimmingCharacters(in: .whitespaces)] {
                                    text = suggestion
                                }
                            }
                        }
                    )
                    .frame(height: dynamicHeight)
                }
                .frame(maxWidth: .infinity)

                // Submit button (visible for multiline)
                if isMultiline {
                    Button {
                        onSubmit(text)
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.accent)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 6)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(AppTheme.backgroundSecondary)
        }
    }
}

// MARK: - Multiline TextField (NSTextView based)

struct MultilineTextField: NSViewRepresentable {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let onSubmit: () -> Void
    let onTab: () -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = MultilineNSTextView()

        textView.delegate = context.coordinator
        textView.coordinator = context.coordinator
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.backgroundColor = .clear
        textView.textColor = NSColor(AppTheme.textPrimary)
        textView.insertionPointColor = NSColor(AppTheme.accent)
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineBreakMode = .byWordWrapping

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        if isFocused.wrappedValue {
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MultilineTextField

        init(_ parent: MultilineTextField) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            // Enter without shift = submit
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                if NSEvent.modifierFlags.contains(.shift) {
                    return false // Let it insert newline
                }
                parent.onSubmit()
                return true
            }
            // Tab = autocomplete
            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                parent.onTab()
                return true
            }
            return false
        }
    }
}

class MultilineNSTextView: NSTextView {
    weak var coordinator: MultilineTextField.Coordinator?

    override func keyDown(with event: NSEvent) {
        super.keyDown(with: event)
    }
}

// Helper extensions are in Features/Terminal/Core/TerminalSharedTypes.swift
