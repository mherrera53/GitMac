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
    @StateObject private var themeManager = ThemeManager.shared

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
                            .font(DesignTokens.Typography.caption2)
                            .foregroundColor(TerminalColors.textMuted)
                            .frame(width: DesignTokens.Size.iconXL, height: DesignTokens.Size.iconXL)
                    }
                    .buttonStyle(.plain)
                    .help("New tab")
                }
                .padding(.horizontal, DesignTokens.Spacing.xs)
            }

            Spacer()

            // Controls
            HStack(spacing: DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs) {
                // Open in Wave button
                Button {
                    onOpenWave?()
                } label: {
                    HStack(spacing: DesignTokens.Spacing.xxs) {
                        Image(systemName: "wave.3.right")
                            .font(DesignTokens.Typography.caption2)
                        Text("Wave")
                            .font(DesignTokens.Typography.caption2)
                    }
                    .foregroundColor(TerminalColors.accent)
                    .padding(.horizontal, DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
                    .padding(.vertical, DesignTokens.Spacing.xxs)
                    .background(TerminalColors.accent.opacity(0.1))
                    .cornerRadius(DesignTokens.CornerRadius.sm)
                }
                .buttonStyle(.plain)
                .help("Open in Wave Terminal")

                // Open lazygit button
                Button {
                    onOpenLazygit?()
                } label: {
                    HStack(spacing: DesignTokens.Spacing.xxs) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(DesignTokens.Typography.caption2)
                        Text("lazygit")
                            .font(DesignTokens.Typography.caption2)
                    }
                    .foregroundColor(AppTheme.warning)
                    .padding(.horizontal, DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
                    .padding(.vertical, DesignTokens.Spacing.xxs)
                    .background(AppTheme.warning.opacity(0.1))
                    .cornerRadius(DesignTokens.CornerRadius.sm)
                }
                .buttonStyle(.plain)
                .help("Open lazygit TUI")

                Divider()
                    .frame(height: DesignTokens.Size.iconMD)

                // AI Chat button
                Button {
                    showAIChat.toggle()
                } label: {
                    HStack(spacing: DesignTokens.Spacing.xxs) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(DesignTokens.Typography.caption2)
                        Text("Chat")
                            .font(DesignTokens.Typography.caption2)
                    }
                    .foregroundColor(AppTheme.accent)
                    .padding(.horizontal, DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
                    .padding(.vertical, DesignTokens.Spacing.xxs)
                    .background(AppTheme.accent.opacity(0.1))
                    .cornerRadius(DesignTokens.CornerRadius.sm)
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
                    HStack(spacing: DesignTokens.Spacing.xxs) {
                        Image(systemName: "sparkles")
                            .font(DesignTokens.Typography.caption2)
                        Text("AI")
                            .font(DesignTokens.Typography.caption2)
                    }
                    .foregroundColor(aiEnabled ? TerminalColors.accent : TerminalColors.textMuted)
                    .padding(.horizontal, DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
                    .padding(.vertical, DesignTokens.Spacing.xxs)
                    .background(aiEnabled ? TerminalColors.accent.opacity(0.15) : Color.clear)
                    .cornerRadius(DesignTokens.CornerRadius.sm)
                }
                .buttonStyle(.plain)
                .help(aiEnabled ? "AI suggestions enabled" : "AI suggestions disabled")

                // Clear button
                Button(action: onClear) {
                    Image(systemName: "trash")
                        .font(DesignTokens.Typography.caption2)
                        .foregroundColor(TerminalColors.textMuted)
                }
                .buttonStyle(.plain)
                .help("Clear terminal")

                // Running indicator
                if isRunning {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: DesignTokens.Size.iconMD, height: DesignTokens.Size.iconMD)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
        }
        .frame(height: DesignTokens.Size.buttonHeightMD)
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
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: "terminal")
                    .font(DesignTokens.Typography.caption2)
                    .foregroundColor(AppTheme.textSecondary)

                Text(tab.name)
                    .font(DesignTokens.Typography.caption)
                    .lineLimit(1)

                if isHovered && canClose {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(DesignTokens.Typography.caption2)
                            .foregroundColor(TerminalColors.textMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .foregroundColor(isSelected ? TerminalColors.textPrimary : TerminalColors.textSecondary)
            .padding(.horizontal, DesignTokens.Spacing.sm + DesignTokens.Spacing.xxs)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(isSelected ? TerminalColors.blockBackground : (isHovered ? TerminalColors.blockBackground.opacity(0.5) : Color.clear))
            .cornerRadius(DesignTokens.CornerRadius.sm)
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
                    LazyVStack(spacing: DesignTokens.Spacing.sm + DesignTokens.Spacing.xxs) {
                        ForEach(session.commandBlocks) { block in
                            CommandBlockView(
                                block: block,
                                onExplainError: { explainError(block: block) }
                            )
                            .id(block.id)
                        }
                    }
                    .padding(DesignTokens.Spacing.md)
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
            HStack(spacing: DesignTokens.Spacing.sm) {
                // Status indicator
                Circle()
                    .fill(statusColor)
                    .frame(width: DesignTokens.Spacing.sm, height: DesignTokens.Spacing.sm)

                // Directory
                Text((block.workingDirectory as NSString).lastPathComponent)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(TerminalColors.textSecondary)

                // Command
                Text(block.command)
                    .font(DesignTokens.Typography.callout)
                    .foregroundColor(TerminalColors.command)
                    .lineLimit(1)

                Spacer()

                // Timestamp
                Text(block.timestamp.formatted(.dateTime.hour().minute().second()))
                    .font(DesignTokens.Typography.caption2)
                    .foregroundColor(TerminalColors.textMuted)

                // Buttons (visible on hover)
                if isHovered {
                    HStack(spacing: DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs) {
                        // Explain error button (only for failed commands)
                        if block.isComplete && block.exitCode != 0 {
                            Button {
                                onExplainError?()
                            } label: {
                                HStack(spacing: DesignTokens.Spacing.xxs) {
                                    Image(systemName: "sparkles")
                                        .font(DesignTokens.Typography.caption2)
                                    Text("Explain")
                                        .font(DesignTokens.Typography.caption2)
                                }
                                .foregroundColor(TerminalColors.accent)
                                .padding(.horizontal, DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
                                .padding(.vertical, DesignTokens.Spacing.xxs)
                                .background(TerminalColors.accent.opacity(0.15))
                                .cornerRadius(DesignTokens.CornerRadius.sm)
                            }
                            .buttonStyle(.plain)
                            .help("Explain error with AI")
                        }

                        Button {
                            copyToClipboard()
                        } label: {
                            Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                                .font(DesignTokens.Typography.caption2)
                                .foregroundColor(isCopied ? TerminalColors.success : TerminalColors.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .help("Copy output")
                    }
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(TerminalColors.blockBackground.opacity(0.5))

            // Output
            if !block.output.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(block.output) { line in
                        OutputLineView(line: line)
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.sm)
            }

            // Exit code (if non-zero)
            if block.isComplete && block.exitCode != 0 {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "xmark.circle.fill")
                        .font(DesignTokens.Typography.caption2)
                    Text("Exit code: \(block.exitCode)")
                        .font(DesignTokens.Typography.caption2)
                }
                .foregroundColor(TerminalColors.error)
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.bottom, DesignTokens.Spacing.sm)
            }

            // AI Explanation (if available)
            if let explanation = block.aiExplanation {
                HStack(alignment: .top, spacing: DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs) {
                    Image(systemName: "sparkles")
                        .font(DesignTokens.Typography.caption2)
                        .foregroundColor(TerminalColors.accent)
                    Text(explanation)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(TerminalColors.textSecondary)
                        .textSelection(.enabled)
                }
                .padding(DesignTokens.Spacing.sm + DesignTokens.Spacing.xxs)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(TerminalColors.accent.opacity(0.08))
                .cornerRadius(DesignTokens.CornerRadius.md)
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.bottom, DesignTokens.Spacing.sm + DesignTokens.Spacing.xxs)
            }
        }
        .background(TerminalColors.blockBackground)
        .cornerRadius(DesignTokens.CornerRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
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
            .font(DesignTokens.Typography.callout)
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
            HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
                // Prompt
                Text(prompt)
                    .font(DesignTokens.Typography.callout)
                    .foregroundColor(TerminalColors.prompt)
                    .padding(.top, DesignTokens.Spacing.xxs)

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
                        .frame(width: DesignTokens.Size.iconMD, height: DesignTokens.Size.iconMD)
                        .padding(.top, DesignTokens.Spacing.xxs)
                } else if isLoadingAI {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        Image(systemName: "sparkles")
                            .font(DesignTokens.Typography.caption2)
                            .foregroundColor(TerminalColors.accent)
                        ProgressView()
                            .scaleEffect(0.5)
                    }
                    .frame(width: DesignTokens.Size.iconXL + DesignTokens.Spacing.sm, height: DesignTokens.Size.iconMD)
                    .padding(.top, DesignTokens.Spacing.xxs)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.sm + DesignTokens.Spacing.xxs)
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
                    .font(DesignTokens.Typography.callout)
                    .foregroundColor(TerminalColors.textMuted)
                    .padding(.top, DesignTokens.Spacing.xxs)
                    .padding(.leading, DesignTokens.Spacing.xs)
            }

            // Text Editor
            TextEditor(text: $text)
                .font(DesignTokens.Typography.callout)
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
        .padding(.horizontal, DesignTokens.Spacing.xs)
        .padding(.vertical, DesignTokens.Spacing.xxs)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm + DesignTokens.Spacing.xxs)
                .fill(TerminalColors.background.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm + DesignTokens.Spacing.xxs)
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
                HStack(spacing: DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs) {
                    Image(systemName: "sparkles")
                        .font(DesignTokens.Typography.caption2)
                        .foregroundColor(TerminalColors.accent)
                    Text("Getting AI suggestions...")
                        .font(DesignTokens.Typography.caption2)
                        .foregroundColor(TerminalColors.textMuted)
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.5)
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
            }

            ForEach(Array(suggestions.prefix(6).enumerated()), id: \.offset) { index, suggestion in
                HStack(spacing: DesignTokens.Spacing.sm) {
                    // AI indicator
                    if suggestion.isFromAI {
                        Image(systemName: "sparkles")
                            .font(DesignTokens.Typography.caption2)
                            .foregroundColor(TerminalColors.accent)
                    } else {
                        Image(systemName: "terminal")
                            .font(DesignTokens.Typography.caption2)
                            .foregroundColor(TerminalColors.textMuted)
                    }

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                        Text(suggestion.command)
                            .font(DesignTokens.Typography.callout)
                            .foregroundColor(index == selectedIndex ? TerminalColors.textPrimary : TerminalColors.textSecondary)

                        if !suggestion.description.isEmpty {
                            Text(suggestion.description)
                                .font(DesignTokens.Typography.caption2)
                                .foregroundColor(TerminalColors.textMuted)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    if index == selectedIndex {
                        Text("Tab ↹")
                            .font(DesignTokens.Typography.caption2)
                            .foregroundColor(TerminalColors.textMuted)
                            .padding(.horizontal, DesignTokens.Spacing.xs)
                            .padding(.vertical, DesignTokens.Spacing.xxs)
                            .background(TerminalColors.blockBackground)
                            .cornerRadius(DesignTokens.CornerRadius.sm)
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
        .cornerRadius(DesignTokens.CornerRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                .stroke(TerminalColors.blockBorder, lineWidth: 1)
        )
        .shadow(color: AppTheme.background.opacity(0.3), radius: DesignTokens.CornerRadius.sm, x: 0, y: DesignTokens.Spacing.xs)
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.top, DesignTokens.Spacing.sm)
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
                let aiSuggestions = try await TerminalAIService.shared.suggestTerminalCommands(
                    input: input,
                    repoPath: repoPath,
                    recentCommands: Array(commandHistory.suffix(5))
                )

                // Convert AICommandSuggestion to TerminalSuggestion
                let suggestions = aiSuggestions.map { aiSug in
                    TerminalSuggestion(
                        command: aiSug.command,
                        description: aiSug.description,
                        confidence: aiSug.confidence,
                        isFromAI: aiSug.isFromAI
                    )
                }

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
            let explanation = try await TerminalAIService.shared.explainTerminalError(
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
                    .foregroundColor(AppTheme.accent)
                Text("AI Terminal Assistant")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.plain)
            }
            .padding()
            .background(AppTheme.backgroundSecondary)

            Divider()

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
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
                                    .foregroundColor(AppTheme.textPrimary)
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
            HStack(spacing: DesignTokens.Spacing.sm) {
                TextField("Ask about git commands, errors, or code...", text: $inputText)
                    .textFieldStyle(.plain)
                    .padding(DesignTokens.Spacing.sm + DesignTokens.Spacing.xxs)
                    .background(AppTheme.backgroundSecondary)
                    .cornerRadius(DesignTokens.CornerRadius.lg)
                    .onSubmit { sendMessage() }

                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(AppTheme.textPrimary)
                        .padding(DesignTokens.Spacing.sm + DesignTokens.Spacing.xxs)
                        .background(inputText.isEmpty ? AppTheme.textMuted : AppTheme.accent)
                        .cornerRadius(DesignTokens.CornerRadius.lg)
                }
                .buttonStyle(.plain)
                .disabled(inputText.isEmpty || isLoading)
            }
            .padding()
            .background(AppTheme.backgroundSecondary)
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
        HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
            if message.role == .assistant {
                Image(systemName: "sparkles")
                    .foregroundColor(AppTheme.accent)
                    .frame(width: DesignTokens.Size.iconXL, height: DesignTokens.Size.iconXL)
            }

            Text(message.content)
                .textSelection(.enabled)
                .font(DesignTokens.Typography.body)
                .padding(DesignTokens.Spacing.sm + DesignTokens.Spacing.xxs)
                .background(message.role == .user ? AppTheme.info.opacity(0.15) : AppTheme.backgroundSecondary)
                .cornerRadius(DesignTokens.CornerRadius.xl)

            if message.role == .user {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(AppTheme.info)
                    .frame(width: DesignTokens.Size.iconXL, height: DesignTokens.Size.iconXL)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }
}

// MARK: - Ghostty Native Terminal Integration

#if GHOSTTY_AVAILABLE

/// Native Ghostty terminal view with Warp-like AI overlay
struct GhosttyNativeView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = GhosttyViewModel()
    @StateObject private var enhancedViewModel = GhosttyEnhancedViewModel()
    @State private var aiEnabled = true
    @State private var showAIChat = false
    @State private var showCommandPalette = false
    @FocusState private var terminalFocused: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                // Header bar with directory info and controls
                GhosttyHeaderBar(
                    repositoryName: appState.currentRepository?.name ?? "~",
                    currentDirectory: viewModel.currentDirectory,
                    aiEnabled: $aiEnabled,
                    showAIChat: $showAIChat,
                    onClear: {
                        viewModel.clearTerminal()
                        enhancedViewModel.clearCommands()
                    },
                    onOpenPalette: { showCommandPalette = true }
                )

                // Ghostty terminal with enhanced tracking
                ZStack(alignment: .bottom) {
                    // Enhanced Ghostty terminal with AI tracking
                    GhosttyEnhancedTerminalView(
                        viewModel: viewModel,
                        enhancedViewModel: enhancedViewModel,
                        initialDirectory: appState.currentRepository?.path ?? NSHomeDirectory(),
                        aiEnabled: aiEnabled,
                        repoPath: appState.currentRepository?.path
                    )
                    .focused($terminalFocused)

                    // AI Suggestions overlay (appears above input)
                    if aiEnabled && !enhancedViewModel.currentInput.isEmpty && !enhancedViewModel.aiSuggestions.isEmpty {
                        AICommandSuggestionsOverlay(
                            suggestions: enhancedViewModel.aiSuggestions,
                            selectedIndex: enhancedViewModel.selectedSuggestionIndex,
                            isLoading: enhancedViewModel.isLoadingAI,
                            onSelect: { suggestion in
                                enhancedViewModel.applySuggestion(suggestion, to: viewModel)
                            }
                        )
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .background(GhosttyColors.background)
            }

            // Command Palette (Cmd+K)
            if showCommandPalette {
                TerminalCommandPaletteView(
                    isPresented: $showCommandPalette,
                    onExecute: { [viewModel, enhancedViewModel] command in
                        enhancedViewModel.executeWorkflow(command, in: viewModel)
                    }
                )
            }
        }
        .onChange(of: appState.currentRepository?.path) { _, newPath in
            if let path = newPath {
                viewModel.setWorkingDirectory(path)
                enhancedViewModel.updateContext(repoPath: path)
            }
        }
        .onAppear {
            terminalFocused = true
        }
    }
}

// MARK: - Ghostty Header Bar

struct GhosttyHeaderBar: View {
    let repositoryName: String
    let currentDirectory: String
    @Binding var aiEnabled: Bool
    @Binding var showAIChat: Bool
    let onClear: () -> Void
    var onOpenPalette: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // Directory info
            HStack(spacing: DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs) {
                Image(systemName: "folder.fill")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(GhosttyColors.accent)

                Text(repositoryName)
                    .font(DesignTokens.Typography.callout)
                    .foregroundColor(GhosttyColors.textPrimary)

                Text("•")
                    .foregroundColor(GhosttyColors.textMuted)

                Text(currentDirectory)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(GhosttyColors.textMuted)
                    .lineLimit(1)
            }
            .padding(.leading, DesignTokens.Spacing.md)

            Spacer()

            // Controls
            HStack(spacing: DesignTokens.Spacing.sm) {
                // Command Palette button (Cmd+K)
                if let openPalette = onOpenPalette {
                    Button {
                        openPalette()
                    } label: {
                        HStack(spacing: DesignTokens.Spacing.xxs) {
                            Image(systemName: "command")
                                .font(DesignTokens.Typography.caption2)
                            Text("Palette")
                                .font(DesignTokens.Typography.caption2)
                        }
                        .foregroundColor(GhosttyColors.accent)
                        .padding(.horizontal, DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
                        .padding(.vertical, DesignTokens.Spacing.xs)
                        .background(GhosttyColors.accent.opacity(0.1))
                        .cornerRadius(DesignTokens.CornerRadius.sm)
                    }
                    .buttonStyle(.plain)
                    .help("Command Palette (⌘K)")
                    .keyboardShortcut("k", modifiers: .command)
                }

                // AI Chat button
                Button {
                    showAIChat.toggle()
                } label: {
                    HStack(spacing: DesignTokens.Spacing.xxs) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(DesignTokens.Typography.caption2)
                        Text("Chat")
                            .font(DesignTokens.Typography.caption2)
                    }
                    .foregroundColor(AppTheme.accent)
                    .padding(.horizontal, DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                    .background(AppTheme.accent.opacity(0.1))
                    .cornerRadius(DesignTokens.CornerRadius.sm)
                }
                .buttonStyle(.plain)
                .help("AI Terminal Assistant")
                .popover(isPresented: $showAIChat) {
                    TerminalAIChatView(repoPath: currentDirectory)
                        .frame(width: 400, height: 500)
                }

                // AI toggle
                Button {
                    aiEnabled.toggle()
                } label: {
                    HStack(spacing: DesignTokens.Spacing.xxs) {
                        Image(systemName: "sparkles")
                            .font(DesignTokens.Typography.caption2)
                        Text("AI")
                            .font(DesignTokens.Typography.caption2)
                    }
                    .foregroundColor(aiEnabled ? GhosttyColors.accent : GhosttyColors.textMuted)
                    .padding(.horizontal, DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                    .background(aiEnabled ? GhosttyColors.accent.opacity(0.15) : Color.clear)
                    .cornerRadius(DesignTokens.CornerRadius.sm)
                }
                .buttonStyle(.plain)
                .help(aiEnabled ? "AI suggestions enabled" : "AI suggestions disabled")

                // Clear button
                Button(action: onClear) {
                    Image(systemName: "trash")
                        .font(DesignTokens.Typography.caption2)
                        .foregroundColor(GhosttyColors.textMuted)
                }
                .buttonStyle(.plain)
                .help("Clear terminal (Cmd+K)")
            }
            .padding(.trailing, DesignTokens.Spacing.md)
        }
        .frame(height: DesignTokens.Size.buttonHeightMD + DesignTokens.Spacing.xs)
        .background(GhosttyColors.backgroundSecondary)
        .overlay(
            Rectangle()
                .fill(GhosttyColors.textMuted.opacity(0.2))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

// MARK: - Custom NSView for Ghostty with keyboard handling

class GhosttyTerminalNSView: NSView {
    var surface: ghostty_surface_t?

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        return true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        handleKeyEvent(event, action: GHOSTTY_ACTION_PRESS)
    }

    override func keyUp(with event: NSEvent) {
        handleKeyEvent(event, action: GHOSTTY_ACTION_RELEASE)
    }

    private func handleKeyEvent(_ event: NSEvent, action: ghostty_input_action_e) {
        guard let surface = surface else { return }

        // Convert NSEvent modifiers to Ghostty modifiers
        var mods: ghostty_input_mods_e = GHOSTTY_MODS_NONE
        let flags = event.modifierFlags

        if flags.contains(.shift) { mods = ghostty_input_mods_e(mods.rawValue | GHOSTTY_MODS_SHIFT.rawValue) }
        if flags.contains(.control) { mods = ghostty_input_mods_e(mods.rawValue | GHOSTTY_MODS_CTRL.rawValue) }
        if flags.contains(.option) { mods = ghostty_input_mods_e(mods.rawValue | GHOSTTY_MODS_ALT.rawValue) }
        if flags.contains(.command) { mods = ghostty_input_mods_e(mods.rawValue | GHOSTTY_MODS_SUPER.rawValue) }

        // Create Ghostty input key structure
        var key = ghostty_input_key_s()
        key.action = action
        key.mods = mods
        key.consumed_mods = GHOSTTY_MODS_NONE
        key.keycode = UInt32(event.keyCode)
        key.composing = false

        // Get text from event
        if let characters = event.characters {
            characters.utf8CString.withUnsafeBufferPointer { buffer in
                key.text = buffer.baseAddress

                // Get unshifted codepoint
                if let unshifted = event.charactersIgnoringModifiers?.unicodeScalars.first {
                    key.unshifted_codepoint = unshifted.value
                }

                // Send key to Ghostty surface
                _ = ghostty_surface_key(surface, key)
            }
        } else {
            // For keys without characters (like arrow keys), send without text
            key.text = nil
            key.unshifted_codepoint = 0
            _ = ghostty_surface_key(surface, key)
        }
    }
}

// MARK: - Ghostty NSViewRepresentable

struct GhosttyTerminalRepresentable: NSViewRepresentable {
    @ObservedObject var viewModel: GhosttyViewModel
    let initialDirectory: String

    // Static initialization state
    private static var ghosttyInitialized = false
    private static let initLock = NSLock()

    // Initialize Ghostty library (must be called before any other Ghostty functions)
    private static func initializeGhosttyOnce() -> Bool {
        initLock.lock()
        defer { initLock.unlock() }

        guard !ghosttyInitialized else { return true }

        // Call ghostty_init() with default parameters
        let result = ghostty_init(0, nil)
        ghosttyInitialized = (result == GHOSTTY_SUCCESS)

        if ghosttyInitialized {
            print("✅ Ghostty library initialized successfully")
        } else {
            print("❌ Ghostty initialization failed with code: \(result)")
        }

        return ghosttyInitialized
    }

    func makeNSView(context: Context) -> NSView {
        // Initialize Ghostty library first time
        guard Self.initializeGhosttyOnce() else {
            let errorView = NSTextField(labelWithString: "Failed to initialize Ghostty library")
            errorView.textColor = .red
            errorView.alignment = .center
            errorView.backgroundColor = NSColor(red: 0.1, green: 0.11, blue: 0.15, alpha: 1.0)
            errorView.isBordered = false
            return errorView
        }

        // Get working directory from initialDirectory parameter (passed from appState)
        let workingDir = initialDirectory
        viewModel.currentDirectory = workingDir // Update viewModel to match
        print("🔧 Terminal working directory: \(workingDir)")
        print("🔍 Repository detected: \(workingDir.contains("isi.hospital") ? "ISI Hospital" : workingDir.contains("anysubscription") ? "AnySubscription" : "Other")")

        // Create custom container view with keyboard handling
        let containerView = GhosttyTerminalNSView(frame: NSMakeRect(0, 0, 800, 600))

        // Create Ghostty configuration (now safe after initialization)
        let config = ghostty_config_new()
        ghostty_config_load_default_files(config)
        ghostty_config_finalize(config)

        // Runtime configuration with callbacks
        var runtime_config = ghostty_runtime_config_s()
        runtime_config.userdata = UnsafeMutableRawPointer(Unmanaged.passUnretained(context.coordinator).toOpaque())
        runtime_config.supports_selection_clipboard = true
        runtime_config.wakeup_cb = { _ in }
        runtime_config.action_cb = { _, _, _ in return true }
        runtime_config.read_clipboard_cb = nil
        runtime_config.write_clipboard_cb = nil
        runtime_config.confirm_read_clipboard_cb = nil
        runtime_config.close_surface_cb = nil

        // Create the Ghostty app
        let app = ghostty_app_new(&runtime_config, config)
        guard app != nil else {
            let errorView = NSTextField(labelWithString: "Failed to create Ghostty app")
            errorView.textColor = .red
            errorView.alignment = .center
            errorView.backgroundColor = NSColor(red: 0.1, green: 0.11, blue: 0.15, alpha: 1.0)
            errorView.isBordered = false
            return errorView
        }

        // Surface configuration
        var surface_config = ghostty_surface_config_new()
        surface_config.platform_tag = GHOSTTY_PLATFORM_MACOS
        surface_config.platform.macos.nsview = UnsafeMutableRawPointer(Unmanaged.passUnretained(containerView).toOpaque())
        surface_config.userdata = UnsafeMutableRawPointer(Unmanaged.passUnretained(context.coordinator).toOpaque())
        surface_config.scale_factor = Double(NSScreen.main?.backingScaleFactor ?? 2.0)
        surface_config.font_size = 13.0

        // Store working directory C string data to keep it alive
        let workingDirCString = workingDir.utf8CString
        context.coordinator.workingDirectoryData = workingDirCString.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }
        surface_config.working_directory = context.coordinator.workingDirectoryData!.withUnsafeBytes { $0.baseAddress?.assumingMemoryBound(to: CChar.self) }

        // Set shell command to start in the correct directory
        // Use /bin/zsh explicitly with cd command
        let shellCommand = "/bin/zsh -c \"cd '\(workingDir)' && exec /bin/zsh -l\""
        let shellCommandCString = (shellCommand as NSString).utf8String!
        let shellCommandData = Data(bytes: shellCommandCString, count: strlen(shellCommandCString) + 1)
        context.coordinator.shellCommandData = shellCommandData
        surface_config.command = context.coordinator.shellCommandData!.withUnsafeBytes { $0.baseAddress?.assumingMemoryBound(to: CChar.self) }

        // Create the surface
        let surface = ghostty_surface_new(app!, &surface_config)
        guard surface != nil else {
            ghostty_app_free(app!)
            ghostty_config_free(config)

            let errorView = NSTextField(labelWithString: "Failed to create Ghostty surface")
            errorView.textColor = .red
            errorView.alignment = .center
            errorView.backgroundColor = NSColor(red: 0.1, green: 0.11, blue: 0.15, alpha: 1.0)
            errorView.isBordered = false
            return errorView
        }

        // Store references
        context.coordinator.app = app
        context.coordinator.config = config
        context.coordinator.surface = surface
        viewModel.surface = surface

        // Connect surface to container view for keyboard events
        containerView.surface = surface

        print("✅ Terminal created in directory: \(workingDir)")

        return containerView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Handle updates if needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    class Coordinator: NSObject {
        var viewModel: GhosttyViewModel
        var app: ghostty_app_t?
        var config: ghostty_config_t?
        var surface: ghostty_surface_t?
        var workingDirectoryData: Data? // Keep the C string data alive
        var shellCommandData: Data? // Keep shell command C string alive

        init(viewModel: GhosttyViewModel) {
            self.viewModel = viewModel
        }

        deinit {
            if let surface = surface {
                ghostty_surface_free(surface)
            }
            if let app = app {
                ghostty_app_free(app)
            }
            if let config = config {
                ghostty_config_free(config)
            }
        }
    }
}

// MARK: - Ghostty ViewModel

@MainActor
class GhosttyViewModel: ObservableObject {
    @Published var currentDirectory = NSHomeDirectory()
    @Published var terminalTitle = "Terminal"

    var surface: ghostty_surface_t?

    func setWorkingDirectory(_ path: String) {
        // Store the full path, not just the directory name
        currentDirectory = path
        terminalTitle = (path as NSString).lastPathComponent
    }

    func writeInput(_ text: String) {
        guard let surface = surface else { return }
        text.utf8CString.withUnsafeBufferPointer { buffer in
            if let baseAddress = buffer.baseAddress {
                ghostty_surface_text(surface, baseAddress, UInt(buffer.count - 1))
            }
        }
    }

    func clearTerminal() {
        // Send Ctrl+L to clear the terminal
        writeInput("\u{0C}") // ASCII form feed (Ctrl+L)
    }
}

// MARK: - Ghostty Color Scheme

enum GhosttyColors {
    static let background = Color(hex: "1a1b26")
    static let backgroundSecondary = Color(hex: "16161e")
    static let textPrimary = Color(hex: "c0caf5")
    static let textMuted = Color(hex: "565f89")
    static let accent = Color(hex: "7aa2f7")
    static let cursor = Color(hex: "c0caf5")
    static let selection = Color(hex: "283457")

    // ANSI Colors (Tokyo Night theme)
    static let black = Color(hex: "15161e")
    static let red = Color(hex: "f7768e")
    static let green = Color(hex: "9ece6a")
    static let yellow = Color(hex: "e0af68")
    static let blue = Color(hex: "7aa2f7")
    static let magenta = Color(hex: "bb9af7")
    static let cyan = Color(hex: "7dcfff")
    static let white = Color(hex: "a9b1d6")
}

#endif
