import SwiftUI
import AppKit

// MARK: - Terminal Tab Model

struct TerminalTab: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var workingDirectory: String

    static func == (lhs: TerminalTab, rhs: TerminalTab) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Multi-Tab Terminal View

struct TerminalView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var tabManager = TerminalTabManager()
    @State private var aiEnabled = true

    var body: some View {
        VStack(spacing: 0) {
            // Compact tab bar with controls
            TerminalTabBar(
                tabs: $tabManager.tabs,
                selectedTab: $tabManager.selectedTabId,
                aiEnabled: $aiEnabled,
                onAddTab: { tabManager.addTab(workingDirectory: appState.currentRepository?.path ?? NSHomeDirectory()) },
                onCloseTab: { tabManager.closeTab($0) },
                onClear: { tabManager.currentSession?.clear() },
                isRunning: tabManager.currentSession?.isRunning ?? false
            )

            // Active terminal session
            if let session = tabManager.currentSession {
                TerminalSessionView(
                    session: session,
                    aiEnabled: aiEnabled,
                    repoPath: appState.currentRepository?.path
                )
            }
        }
        .background(TerminalColors.background)
        .onAppear {
            if tabManager.tabs.isEmpty {
                tabManager.addTab(workingDirectory: appState.currentRepository?.path ?? NSHomeDirectory())
            }
        }
        .onChange(of: appState.currentRepository?.path) { _, newPath in
            if let path = newPath {
                tabManager.currentSession?.setWorkingDirectory(path)
            }
        }
    }
}

// MARK: - Terminal Tab Manager

@MainActor
class TerminalTabManager: ObservableObject {
    @Published var tabs: [TerminalTab] = []
    @Published var selectedTabId: UUID?
    @Published var sessions: [UUID: TerminalViewModel] = [:]

    var currentSession: TerminalViewModel? {
        guard let id = selectedTabId else { return nil }
        return sessions[id]
    }

    func addTab(workingDirectory: String) {
        let dirName = (workingDirectory as NSString).lastPathComponent
        let tab = TerminalTab(name: dirName, workingDirectory: workingDirectory)
        tabs.append(tab)

        let session = TerminalViewModel()
        session.setWorkingDirectory(workingDirectory)
        sessions[tab.id] = session

        selectedTabId = tab.id
    }

    func closeTab(_ id: UUID) {
        guard tabs.count > 1 else { return } // Keep at least one tab

        if let index = tabs.firstIndex(where: { $0.id == id }) {
            tabs.remove(at: index)
            sessions.removeValue(forKey: id)

            // Select adjacent tab
            if selectedTabId == id {
                let newIndex = min(index, tabs.count - 1)
                selectedTabId = tabs[newIndex].id
            }
        }
    }

    func selectTab(_ id: UUID) {
        selectedTabId = id
    }
}

// MARK: - Compact Tab Bar

struct TerminalTabBar: View {
    @Binding var tabs: [TerminalTab]
    @Binding var selectedTab: UUID?
    @Binding var aiEnabled: Bool
    let onAddTab: () -> Void
    let onCloseTab: (UUID) -> Void
    let onClear: () -> Void
    let isRunning: Bool
    var repoPath: String?
    var onOpenWave: (() -> Void)?
    var onOpenLazygit: (() -> Void)?
    @State private var showAIChat = false

    var body: some View {
        HStack(spacing: 0) {
            // Tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 1) {
                    ForEach(tabs) { tab in
                        TerminalTabButton(
                            tab: tab,
                            isSelected: tab.id == selectedTab,
                            onSelect: { selectedTab = tab.id },
                            onClose: { onCloseTab(tab.id) },
                            canClose: tabs.count > 1
                        )
                    }

                    // Add tab button
                    Button(action: onAddTab) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(TerminalColors.textMuted)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .help("New tab")
                }
                .padding(.horizontal, 4)
            }

            Spacer()

            // Controls
            HStack(spacing: 6) {
                // Open in Wave button
                Button {
                    onOpenWave?()
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "wave.3.right")
                            .font(.system(size: 9))
                        Text("Wave")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundColor(TerminalColors.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(TerminalColors.accent.opacity(0.1))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help("Open in Wave Terminal")

                // Open lazygit button
                Button {
                    onOpenLazygit?()
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 9))
                        Text("lazygit")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help("Open lazygit TUI")

                Divider()
                    .frame(height: 16)

                // AI Chat button
                Button {
                    showAIChat.toggle()
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 9))
                        Text("Chat")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundColor(.purple)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help("AI Chat Assistant")
                .popover(isPresented: $showAIChat) {
                    TerminalAIChatView(repoPath: repoPath)
                        .frame(width: 400, height: 500)
                }

                // AI toggle
                Button {
                    aiEnabled.toggle()
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 9))
                        Text("AI")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundColor(aiEnabled ? TerminalColors.accent : TerminalColors.textMuted)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(aiEnabled ? TerminalColors.accent.opacity(0.15) : Color.clear)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help(aiEnabled ? "AI suggestions enabled" : "AI suggestions disabled")

                // Clear button
                Button(action: onClear) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundColor(TerminalColors.textMuted)
                }
                .buttonStyle(.plain)
                .help("Clear terminal")

                // Running indicator
                if isRunning {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 16, height: 16)
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 28)
        .background(TerminalColors.headerBackground)
    }
}

// MARK: - Tab Button

struct TerminalTabButton: View {
    let tab: TerminalTab
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    let canClose: Bool

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 4) {
                Image(systemName: "terminal")
                    .font(.system(size: 9))

                Text(tab.name)
                    .font(.system(size: 11))
                    .lineLimit(1)

                if isHovered && canClose {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(TerminalColors.textMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .foregroundColor(isSelected ? TerminalColors.textPrimary : TerminalColors.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? TerminalColors.blockBackground : (isHovered ? TerminalColors.blockBackground.opacity(0.5) : Color.clear))
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Terminal Session View

struct TerminalSessionView: View {
    @ObservedObject var session: TerminalViewModel
    let aiEnabled: Bool
    let repoPath: String?

    @State private var commandInput = ""
    @State private var showSuggestions = false
    @State private var suggestions: [TerminalSuggestion] = []
    @State private var selectedSuggestion = 0
    @State private var isLoadingAI = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Command blocks
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(session.commandBlocks) { block in
                            CommandBlockView(
                                block: block,
                                onExplainError: { explainError(block: block) }
                            )
                            .id(block.id)
                        }
                    }
                    .padding(12)
                }
                .background(TerminalColors.background)
                .onChange(of: session.commandBlocks.count) { _, _ in
                    if let lastBlock = session.commandBlocks.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(lastBlock.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Command input
            CommandInputArea(
                commandInput: $commandInput,
                suggestions: suggestions,
                showSuggestions: showSuggestions,
                selectedSuggestion: $selectedSuggestion,
                prompt: session.prompt,
                isRunning: session.isRunning,
                isLoadingAI: isLoadingAI,
                isInputFocused: _isInputFocused,
                onSubmit: executeCommand,
                onArrowUp: { commandInput = session.previousCommand() },
                onArrowDown: { commandInput = session.nextCommand() },
                onTab: applySuggestion,
                onSelectSuggestion: selectSuggestion
            )
        }
        .onAppear {
            isInputFocused = true
        }
        .onChange(of: commandInput) { _, newValue in
            updateSuggestions(for: newValue)
        }
    }

    private func executeCommand() {
        guard !commandInput.isEmpty else { return }
        showSuggestions = false

        Task {
            await session.execute(commandInput)
            commandInput = ""
        }
    }

    private func updateSuggestions(for input: String) {
        let staticSuggestions = GitCommandSuggestions.suggestionsWithDescriptions(for: input)
        suggestions = staticSuggestions
        showSuggestions = !input.isEmpty && input.count >= 2
        selectedSuggestion = 0

        if aiEnabled && input.count >= 3 {
            session.debouncedAISuggestions(
                input: input,
                repoPath: repoPath
            ) { aiSuggestions, loading in
                isLoadingAI = loading
                if !aiSuggestions.isEmpty {
                    var merged = aiSuggestions
                    for s in staticSuggestions {
                        if !merged.contains(where: { $0.command == s.command }) {
                            merged.append(s)
                        }
                    }
                    suggestions = Array(merged.prefix(6))
                }
            }
        }
    }

    private func applySuggestion() {
        guard !suggestions.isEmpty, selectedSuggestion < suggestions.count else { return }
        commandInput = suggestions[selectedSuggestion].command
        showSuggestions = false
    }

    private func selectSuggestion(at index: Int) {
        guard index < suggestions.count else { return }
        commandInput = suggestions[index].command
        showSuggestions = false
    }

    private func explainError(block: CommandBlock) {
        guard block.exitCode != 0 else { return }
        let errorText = block.output.filter { $0.type == .stderr }.map { $0.text }.joined(separator: "\n")

        Task {
            await session.explainError(
                command: block.command,
                error: errorText,
                repoPath: repoPath
            )
        }
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: 1)
    }
}

// MARK: - Terminal Colors (Warp-inspired dark theme)

struct TerminalColors {
    static let background = Color(hex: "0D1117")
    static let blockBackground = Color(hex: "161B22")
    static let blockBorder = Color(hex: "30363D")
    static let inputBackground = Color(hex: "21262D")
    static let headerBackground = Color(hex: "161B22")

    static let textPrimary = Color(hex: "E6EDF3")
    static let textSecondary = Color(hex: "8B949E")
    static let textMuted = Color(hex: "6E7681")

    static let prompt = Color(hex: "7EE787")  // Green
    static let command = Color(hex: "E6EDF3")
    static let output = Color(hex: "C9D1D9")
    static let error = Color(hex: "F85149")
    static let system = Color(hex: "58A6FF")
    static let warning = Color(hex: "D29922")
    static let success = Color(hex: "3FB950")

    static let accent = Color(hex: "58A6FF")
    static let selection = Color(hex: "388BFD").opacity(0.3)
}

// MARK: - Command Block (Warp-style)

struct CommandBlock: Identifiable {
    let id = UUID()
    let command: String
    let workingDirectory: String
    let timestamp: Date
    var output: [OutputLine] = []
    var isComplete: Bool = false
    var exitCode: Int32 = 0
    var aiExplanation: String? = nil
}

struct OutputLine: Identifiable {
    let id = UUID()
    let text: String
    let type: OutputType
}

enum OutputType {
    case stdout
    case stderr
    case system
}

struct CommandBlockView: View {
    let block: CommandBlock
    var onExplainError: (() -> Void)? = nil
    @State private var isHovered = false
    @State private var isCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Command header
            HStack(spacing: 8) {
                // Status indicator
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                // Directory
                Text((block.workingDirectory as NSString).lastPathComponent)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(TerminalColors.textSecondary)

                // Command
                Text(block.command)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(TerminalColors.command)
                    .lineLimit(1)

                Spacer()

                // Timestamp
                Text(block.timestamp.formatted(.dateTime.hour().minute().second()))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(TerminalColors.textMuted)

                // Buttons (visible on hover)
                if isHovered {
                    HStack(spacing: 6) {
                        // Explain error button (only for failed commands)
                        if block.isComplete && block.exitCode != 0 {
                            Button {
                                onExplainError?()
                            } label: {
                                HStack(spacing: 2) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 9, weight: .medium))
                                    Text("Explain")
                                        .font(.system(size: 9, weight: .medium))
                                }
                                .foregroundColor(TerminalColors.accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(TerminalColors.accent.opacity(0.15))
                                .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                            .help("Explain error with AI")
                        }

                        Button {
                            copyToClipboard()
                        } label: {
                            Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(isCopied ? TerminalColors.success : TerminalColors.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .help("Copy output")
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(TerminalColors.blockBackground.opacity(0.5))

            // Output
            if !block.output.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(block.output) { line in
                        OutputLineView(line: line)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            // Exit code (if non-zero)
            if block.isComplete && block.exitCode != 0 {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                    Text("Exit code: \(block.exitCode)")
                        .font(.system(size: 10, design: .monospaced))
                }
                .foregroundColor(TerminalColors.error)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }

            // AI Explanation (if available)
            if let explanation = block.aiExplanation {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                        .foregroundColor(TerminalColors.accent)
                    Text(explanation)
                        .font(.system(size: 11))
                        .foregroundColor(TerminalColors.textSecondary)
                        .textSelection(.enabled)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(TerminalColors.accent.opacity(0.08))
                .cornerRadius(6)
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }
        }
        .background(TerminalColors.blockBackground)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHovered ? TerminalColors.accent.opacity(0.5) : TerminalColors.blockBorder, lineWidth: 1)
        )
        .onHover { isHovered = $0 }
    }

    var statusColor: Color {
        if !block.isComplete {
            return TerminalColors.warning
        }
        return block.exitCode == 0 ? TerminalColors.success : TerminalColors.error
    }

    func copyToClipboard() {
        let text = block.output.map { $0.text }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        isCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isCopied = false
        }
    }
}

struct OutputLineView: View {
    let line: OutputLine

    var body: some View {
        Text(line.text)
            .font(.system(size: 12, design: .monospaced))
            .foregroundColor(textColor)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    var textColor: Color {
        switch line.type {
        case .stdout: return TerminalColors.output
        case .stderr: return TerminalColors.error
        case .system: return TerminalColors.system
        }
    }
}

// MARK: - Command Input Area

struct CommandInputArea: View {
    @Binding var commandInput: String
    let suggestions: [TerminalSuggestion]
    let showSuggestions: Bool
    @Binding var selectedSuggestion: Int
    let prompt: String
    let isRunning: Bool
    let isLoadingAI: Bool
    @FocusState var isInputFocused: Bool
    let onSubmit: () -> Void
    let onArrowUp: () -> Void
    let onArrowDown: () -> Void
    let onTab: () -> Void
    let onSelectSuggestion: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(TerminalColors.blockBorder)
                .frame(height: 1)

            // Suggestions popup
            if showSuggestions && !suggestions.isEmpty {
                AISuggestionsPopup(
                    suggestions: suggestions,
                    selectedIndex: selectedSuggestion,
                    isLoadingAI: isLoadingAI,
                    onSelect: onSelectSuggestion
                )
            }

            // Multi-line expandable input (Warp-style)
            HStack(alignment: .top, spacing: 8) {
                // Prompt
                Text(prompt)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(TerminalColors.prompt)
                    .padding(.top, 2)

                // Expandable text input
                ExpandableTextEditor(
                    text: $commandInput,
                    placeholder: "Enter command or describe what you want...",
                    isInputFocused: _isInputFocused,
                    onSubmit: onSubmit,
                    onArrowUp: {
                        if showSuggestions && selectedSuggestion > 0 {
                            selectedSuggestion -= 1
                        } else {
                            onArrowUp()
                        }
                    },
                    onArrowDown: {
                        if showSuggestions && selectedSuggestion < suggestions.count - 1 {
                            selectedSuggestion += 1
                        } else {
                            onArrowDown()
                        }
                    },
                    onTab: onTab
                )

                // Loading/Running indicator
                if isRunning {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
                        .padding(.top, 2)
                } else if isLoadingAI {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10))
                            .foregroundColor(TerminalColors.accent)
                        ProgressView()
                            .scaleEffect(0.5)
                    }
                    .frame(width: 32, height: 16)
                    .padding(.top, 2)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(TerminalColors.inputBackground)
        }
    }
}

// MARK: - Expandable Text Editor (Warp-style multi-line input)

struct ExpandableTextEditor: View {
    @Binding var text: String
    let placeholder: String
    @FocusState var isInputFocused: Bool
    let onSubmit: () -> Void
    let onArrowUp: () -> Void
    let onArrowDown: () -> Void
    let onTab: () -> Void

    @State private var textHeight: CGFloat = 22

    private var lineCount: Int {
        max(1, text.components(separatedBy: "\n").count)
    }

    private var dynamicHeight: CGFloat {
        // Min 22 (single line), max 200 (about 10 lines)
        let baseHeight: CGFloat = 22
        let lineHeight: CGFloat = 18
        let calculated = baseHeight + CGFloat(max(0, lineCount - 1)) * lineHeight
        return min(200, calculated)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Placeholder
            if text.isEmpty {
                Text(placeholder)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(TerminalColors.textMuted)
                    .padding(.top, 2)
                    .padding(.leading, 4)
            }

            // Text Editor
            TextEditor(text: $text)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(TerminalColors.command)
                .scrollContentBackground(.hidden)
                .focused($isInputFocused)
                .frame(minHeight: 22, maxHeight: dynamicHeight)
                .fixedSize(horizontal: false, vertical: true)
                .onKeyPress(.return, phases: .down) { _ in
                    // Shift+Return = new line, Return alone = submit
                    if NSEvent.modifierFlags.contains(.shift) {
                        return .ignored // Let TextEditor handle it (new line)
                    } else {
                        onSubmit()
                        return .handled
                    }
                }
                .onKeyPress(.upArrow) {
                    // Only handle if at first line
                    if !text.contains("\n") || text.hasPrefix(text.components(separatedBy: "\n").first ?? "") {
                        onArrowUp()
                        return .handled
                    }
                    return .ignored
                }
                .onKeyPress(.downArrow) {
                    // Only handle if at last line
                    let lines = text.components(separatedBy: "\n")
                    if lines.count <= 1 {
                        onArrowDown()
                        return .handled
                    }
                    return .ignored
                }
                .onKeyPress(.tab) {
                    onTab()
                    return .handled
                }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(TerminalColors.background.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isInputFocused ? TerminalColors.accent.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }
}

struct AISuggestionsPopup: View {
    let suggestions: [TerminalSuggestion]
    let selectedIndex: Int
    let isLoadingAI: Bool
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // AI loading indicator
            if isLoadingAI {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                        .foregroundColor(TerminalColors.accent)
                    Text("Getting AI suggestions...")
                        .font(.system(size: 10))
                        .foregroundColor(TerminalColors.textMuted)
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.5)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }

            ForEach(Array(suggestions.prefix(6).enumerated()), id: \.offset) { index, suggestion in
                HStack(spacing: 8) {
                    // AI indicator
                    if suggestion.isFromAI {
                        Image(systemName: "sparkles")
                            .font(.system(size: 9))
                            .foregroundColor(TerminalColors.accent)
                    } else {
                        Image(systemName: "terminal")
                            .font(.system(size: 9))
                            .foregroundColor(TerminalColors.textMuted)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestion.command)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(index == selectedIndex ? TerminalColors.textPrimary : TerminalColors.textSecondary)

                        if !suggestion.description.isEmpty {
                            Text(suggestion.description)
                                .font(.system(size: 10))
                                .foregroundColor(TerminalColors.textMuted)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    if index == selectedIndex {
                        Text("Tab ↹")
                            .font(.system(size: 9))
                            .foregroundColor(TerminalColors.textMuted)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(TerminalColors.blockBackground)
                            .cornerRadius(3)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(index == selectedIndex ? TerminalColors.selection : Color.clear)
                .onTapGesture {
                    onSelect(index)
                }
            }
        }
        .background(TerminalColors.inputBackground)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(TerminalColors.blockBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

// MARK: - View Model

@MainActor
class TerminalViewModel: ObservableObject {
    @Published var commandBlocks: [CommandBlock] = []
    @Published var isRunning = false
    @Published var prompt = "~ $"

    private var workingDirectory: String = ""
    private var commandHistory: [String] = []
    private var historyIndex: Int = -1
    private var currentProcess: Process?
    private let shellExecutor = ShellExecutor()

    // AI suggestions
    private var aiSuggestionTask: Task<Void, Never>?
    private var aiSuggestionCache: [String: [TerminalSuggestion]] = [:]
    private var lastAISuggestionInput: String = ""

    init() {
        // Welcome block
        var welcomeBlock = CommandBlock(
            command: "welcome",
            workingDirectory: "~",
            timestamp: Date()
        )
        welcomeBlock.output = [
            OutputLine(text: "Welcome to GitMac Terminal", type: .system),
            OutputLine(text: "Type 'help' for commands, or describe what you want (AI)", type: .system),
        ]
        welcomeBlock.isComplete = true
        commandBlocks.append(welcomeBlock)
    }

    // MARK: - AI Suggestions

    func debouncedAISuggestions(
        input: String,
        repoPath: String?,
        completion: @escaping ([TerminalSuggestion], Bool) -> Void
    ) {
        // Cancel previous request
        aiSuggestionTask?.cancel()

        // Check cache first
        let cacheKey = input.lowercased()
        if let cached = aiSuggestionCache[cacheKey] {
            completion(cached, false)
            return
        }

        // Skip if same as last input
        guard input != lastAISuggestionInput else { return }
        lastAISuggestionInput = input

        // Debounce - wait 300ms before calling AI
        aiSuggestionTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms

            guard !Task.isCancelled else { return }

            completion([], true) // Show loading

            do {
                let suggestions = try await AIService.shared.suggestTerminalCommands(
                    input: input,
                    repoPath: repoPath,
                    recentCommands: Array(commandHistory.suffix(5))
                )

                guard !Task.isCancelled else { return }

                // Cache results
                if !suggestions.isEmpty {
                    aiSuggestionCache[cacheKey] = suggestions

                    // Limit cache size
                    if aiSuggestionCache.count > 100 {
                        aiSuggestionCache.removeAll()
                    }
                }

                completion(suggestions, false)
            } catch {
                completion([], false)
            }
        }
    }

    func explainError(command: String, error: String, repoPath: String?) async {
        // Find the block with this command
        guard let index = commandBlocks.lastIndex(where: { $0.command == command }) else { return }

        do {
            let explanation = try await AIService.shared.explainTerminalError(
                command: command,
                error: error,
                repoPath: repoPath
            )
            commandBlocks[index].aiExplanation = explanation
        } catch {
            commandBlocks[index].aiExplanation = "Could not get AI explanation: \(error.localizedDescription)"
        }
    }

    func setWorkingDirectory(_ path: String) {
        workingDirectory = path
        updatePrompt()
    }

    func execute(_ command: String) async {
        // Add to history
        commandHistory.append(command)
        historyIndex = commandHistory.count

        // Create new block
        var block = CommandBlock(
            command: command,
            workingDirectory: workingDirectory,
            timestamp: Date()
        )

        // Handle built-in commands
        if let result = handleBuiltInCommand(command) {
            block.output = result.output
            block.isComplete = true
            block.exitCode = result.exitCode
            commandBlocks.append(block)
            return
        }

        commandBlocks.append(block)
        let blockIndex = commandBlocks.count - 1

        isRunning = true

        // Execute command
        let result = await shellExecutor.execute(
            "bash",
            arguments: ["-c", command],
            workingDirectory: workingDirectory
        )

        // Update block with output
        var outputs: [OutputLine] = []

        if !result.stdout.isEmpty {
            for line in result.stdout.components(separatedBy: .newlines) {
                if !line.isEmpty {
                    outputs.append(OutputLine(text: line, type: .stdout))
                }
            }
        }

        if !result.stderr.isEmpty {
            for line in result.stderr.components(separatedBy: .newlines) {
                if !line.isEmpty {
                    outputs.append(OutputLine(text: line, type: .stderr))
                }
            }
        }

        commandBlocks[blockIndex].output = outputs
        commandBlocks[blockIndex].isComplete = true
        commandBlocks[blockIndex].exitCode = result.exitCode

        isRunning = false
    }

    func clear() {
        commandBlocks.removeAll()
    }

    func stop() {
        currentProcess?.terminate()
        isRunning = false
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
        } else {
            historyIndex = commandHistory.count
            return ""
        }
    }

    // Git shortcuts
    private let gitShortcuts: [String: String] = [
        "gs": "git status",
        "ga": "git add",
        "gc": "git commit",
        "gp": "git push",
        "gl": "git pull",
        "gco": "git checkout",
        "gb": "git branch",
        "gd": "git diff",
        "gf": "git fetch",
        "gm": "git merge",
        "gr": "git rebase",
        "gst": "git stash",
        "glog": "git log --oneline --graph -20",
    ]

    // GitHub CLI shortcuts
    private let ghShortcuts: [String: String] = [
        "ghpr": "gh pr list",
        "ghprc": "gh pr create",
        "ghprv": "gh pr view",
        "ghprm": "gh pr merge",
        "ghis": "gh issue list",
        "ghisc": "gh issue create",
        "ghrun": "gh run list",
        "ghwf": "gh workflow list",
    ]

    private func handleBuiltInCommand(_ command: String) -> (output: [OutputLine], exitCode: Int32)? {
        let parts = command.split(separator: " ")
        guard let cmd = parts.first else { return nil }
        let cmdString = String(cmd)
        let args = parts.dropFirst().joined(separator: " ")

        switch cmdString {
        case "clear", "cls":
            clear()
            return ([], 0)

        case "cd":
            return handleCd(args: args)

        case "help":
            return (helpOutput(), 0)

        case "history":
            let lines = commandHistory.enumerated().map { OutputLine(text: "  \($0.offset + 1)  \($0.element)", type: .stdout) }
            return (lines, 0)

        default:
            // Check shortcuts
            if let expanded = gitShortcuts[cmdString] {
                Task { await execute(args.isEmpty ? expanded : "\(expanded) \(args)") }
                return nil
            }
            if let expanded = ghShortcuts[cmdString] {
                Task { await execute(args.isEmpty ? expanded : "\(expanded) \(args)") }
                return nil
            }
            return nil
        }
    }

    private func handleCd(args: String) -> (output: [OutputLine], exitCode: Int32) {
        let path: String
        if args.isEmpty {
            path = NSHomeDirectory()
        } else if args.hasPrefix("/") {
            path = args
        } else if args == "~" {
            path = NSHomeDirectory()
        } else {
            path = (workingDirectory as NSString).appendingPathComponent(args)
        }

        if FileManager.default.fileExists(atPath: path) {
            workingDirectory = path
            updatePrompt()
            return ([], 0)
        } else {
            return ([OutputLine(text: "cd: no such directory: \(args)", type: .stderr)], 1)
        }
    }

    private func helpOutput() -> [OutputLine] {
        let help = [
            "GitMac Terminal Commands:",
            "",
            "Built-in:",
            "  clear       Clear terminal",
            "  cd <path>   Change directory",
            "  history     Show command history",
            "  help        Show this help",
            "",
            "Git shortcuts:",
            "  gs   git status      gp   git push",
            "  ga   git add         gl   git pull",
            "  gc   git commit      gco  git checkout",
            "  gb   git branch      gd   git diff",
            "  gf   git fetch       gm   git merge",
            "  gr   git rebase      gst  git stash",
            "  glog git log --oneline --graph",
            "",
            "GitHub CLI (gh):",
            "  ghpr   pr list       ghprc  pr create",
            "  ghis   issue list    ghisc  issue create",
            "  ghrun  run list      ghwf   workflow list",
            "",
            "Use ↑↓ for history, Tab for autocomplete",
        ]
        return help.map { OutputLine(text: $0, type: .system) }
    }

    private func updatePrompt() {
        let dirName = (workingDirectory as NSString).lastPathComponent
        prompt = "\(dirName) $"
    }
}

// MARK: - Git Command Suggestions

struct GitCommandSuggestions {
    // Commands with descriptions
    static let commandsWithDescriptions: [String: [(String, String)]] = [
        "git": [
            ("status", "Show working tree status"),
            ("add", "Add file contents to index"),
            ("commit", "Record changes to repository"),
            ("push", "Update remote refs"),
            ("pull", "Fetch and integrate changes"),
            ("fetch", "Download objects and refs"),
            ("branch", "List, create, or delete branches"),
            ("checkout", "Switch branches or restore files"),
            ("merge", "Join development histories"),
            ("rebase", "Reapply commits on top of another base"),
            ("stash", "Stash changes in dirty directory"),
            ("log", "Show commit logs"),
            ("diff", "Show changes between commits"),
            ("reset", "Reset current HEAD to state"),
            ("cherry-pick", "Apply changes from commits"),
            ("tag", "Create, list, or delete tags"),
        ],
        "git add": [
            ("-A", "Add all changes"),
            ("-p", "Interactively choose hunks"),
            ("--all", "Add all files"),
            (".", "Add current directory"),
        ],
        "git commit": [
            ("-m", "Commit with message"),
            ("-a", "Auto-stage modified files"),
            ("--amend", "Amend previous commit"),
            ("--no-edit", "Keep commit message"),
        ],
        "git push": [
            ("-u", "Set upstream for the branch"),
            ("--force", "Force update remote refs"),
            ("--force-with-lease", "Safe force push"),
            ("origin", "Push to origin remote"),
        ],
        "git checkout": [
            ("-b", "Create and checkout new branch"),
            ("--", "Restore working tree files"),
        ],
        "git branch": [
            ("-d", "Delete branch"),
            ("-D", "Force delete branch"),
            ("-m", "Move/rename branch"),
            ("-a", "List all branches"),
            ("-r", "List remote branches"),
        ],
        "git stash": [
            ("push", "Stash changes"),
            ("pop", "Apply and remove stash"),
            ("apply", "Apply stash"),
            ("list", "List stashes"),
            ("drop", "Remove stash"),
            ("clear", "Remove all stashes"),
        ],
        "git reset": [
            ("--soft", "Keep changes staged"),
            ("--hard", "Discard all changes"),
            ("--mixed", "Unstage changes"),
            ("HEAD~1", "Reset to previous commit"),
        ],
        "git log": [
            ("--oneline", "One line per commit"),
            ("--graph", "Show graph"),
            ("--all", "Show all branches"),
            ("-n 10", "Limit to 10 commits"),
        ],
        "gh": [
            ("pr", "Work with pull requests"),
            ("issue", "Work with issues"),
            ("repo", "Work with repositories"),
            ("run", "View workflow runs"),
            ("workflow", "Manage workflows"),
            ("auth", "Authenticate gh"),
        ],
        "gh pr": [
            ("list", "List pull requests"),
            ("create", "Create pull request"),
            ("view", "View pull request"),
            ("merge", "Merge pull request"),
            ("checkout", "Checkout pull request"),
        ],
        "gh issue": [
            ("list", "List issues"),
            ("create", "Create issue"),
            ("view", "View issue"),
            ("close", "Close issue"),
        ],
    ]

    static func suggestionsWithDescriptions(for input: String) -> [TerminalSuggestion] {
        let trimmed = input.trimmingCharacters(in: .whitespaces)

        for (prefix, suggestions) in commandsWithDescriptions {
            if trimmed == prefix || (trimmed.hasPrefix(prefix) && trimmed.count == prefix.count) {
                return suggestions.map {
                    TerminalSuggestion(
                        command: "\(prefix) \($0.0)",
                        description: $0.1,
                        confidence: 1.0,
                        isFromAI: false
                    )
                }
            }
            if trimmed.hasPrefix(prefix + " ") {
                let remaining = String(trimmed.dropFirst(prefix.count + 1)).lowercased()
                return suggestions
                    .filter { $0.0.lowercased().hasPrefix(remaining) }
                    .map {
                        TerminalSuggestion(
                            command: "\(prefix) \($0.0)",
                            description: $0.1,
                            confidence: 1.0,
                            isFromAI: false
                        )
                    }
            }
        }

        // Common starting commands
        if !trimmed.isEmpty {
            let starters = [
                ("git status", "Show working tree status"),
                ("git add .", "Stage all changes"),
                ("git commit -m \"\"", "Commit with message"),
                ("git push", "Push to remote"),
                ("git pull", "Pull from remote"),
                ("git log --oneline", "View recent commits"),
            ]
            return starters
                .filter { $0.0.lowercased().hasPrefix(trimmed.lowercased()) }
                .map {
                    TerminalSuggestion(
                        command: $0.0,
                        description: $0.1,
                        confidence: 0.8,
                        isFromAI: false
                    )
                }
        }

        return []
    }
}

// MARK: - AI Chat View for Terminal

struct TerminalAIChatView: View {
    var repoPath: String?
    @State private var messages: [TerminalAIChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                Text("AI Terminal Assistant")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { message in
                            TerminalAIChatBubble(message: message)
                                .id(message.id)
                        }

                        if isLoading {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Thinking...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Input
            HStack(spacing: 8) {
                TextField("Ask about git commands, errors, or code...", text: $inputText)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    .onSubmit { sendMessage() }

                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .padding(10)
                        .background(inputText.isEmpty ? Color.gray : Color.purple)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(inputText.isEmpty || isLoading)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
    }

    private func sendMessage() {
        let userText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userText.isEmpty else { return }

        messages.append(TerminalAIChatMessage(role: .user, content: userText))
        inputText = ""
        isLoading = true

        Task {
            do {
                let aiService = AIService()
                let systemPrompt = buildContext()
                // Use generateCommitMessage as a general-purpose AI call
                // The diff parameter will contain our prompt
                let prompt = """
                \(systemPrompt)

                User question: \(userText)

                Provide a helpful, concise response:
                """
                let response = try await aiService.generateCommitMessage(diff: prompt)

                await MainActor.run {
                    messages.append(TerminalAIChatMessage(role: .assistant, content: response))
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    messages.append(TerminalAIChatMessage(
                        role: .assistant,
                        content: "Error: \(error.localizedDescription)\n\nMake sure you have configured an AI provider in Settings > AI."
                    ))
                    isLoading = false
                }
            }
        }
    }

    private func buildContext() -> String {
        var context = """
        You are a helpful Git and terminal assistant. Help with:
        - Git commands and workflows
        - Terminal commands
        - Debugging errors
        Be concise and provide practical solutions.
        """
        if let path = repoPath {
            context += "\n\nRepository: \(path)"
        }
        return context
    }
}

struct TerminalAIChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let content: String
    enum Role { case user, assistant }
}

struct TerminalAIChatBubble: View {
    let message: TerminalAIChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .assistant {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                    .frame(width: 24, height: 24)
            }

            Text(message.content)
                .textSelection(.enabled)
                .font(.system(size: 13))
                .padding(10)
                .background(message.role == .user ? Color.blue.opacity(0.15) : Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)

            if message.role == .user {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.blue)
                    .frame(width: 24, height: 24)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }
}
