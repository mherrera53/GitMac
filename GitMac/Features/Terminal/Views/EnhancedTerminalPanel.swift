import SwiftUI

enum TerminalViewMode: String, CaseIterable {
    case terminal = "Terminal"
    case blocks = "Blocks"
    case workflows = "Workflows"
}

// MARK: - Terminal Tab Model

struct EnhancedTerminalTab: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var workingDirectory: String

    static func == (lhs: EnhancedTerminalTab, rhs: EnhancedTerminalTab) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Enhanced Terminal Tab Manager

@MainActor
class EnhancedTerminalTabManager: ObservableObject {
    @Published var tabs: [EnhancedTerminalTab] = []
    @Published var selectedTabId: UUID?
    @Published var viewModels: [UUID: GhosttyViewModel] = [:]
    @Published var enhancedViewModels: [UUID: GhosttyEnhancedViewModel] = [:]

    var currentViewModel: GhosttyViewModel? {
        guard let id = selectedTabId else { return nil }
        return viewModels[id]
    }

    var currentEnhancedViewModel: GhosttyEnhancedViewModel? {
        guard let id = selectedTabId else { return nil }
        return enhancedViewModels[id]
    }

    func addTab(workingDirectory: String) {
        let dirName = (workingDirectory as NSString).lastPathComponent
        let tab = EnhancedTerminalTab(name: dirName, workingDirectory: workingDirectory)
        tabs.append(tab)

        let viewModel = GhosttyViewModel()
        viewModel.setWorkingDirectory(workingDirectory)
        viewModels[tab.id] = viewModel

        let enhancedViewModel = GhosttyEnhancedViewModel()
        enhancedViewModel.updateContext(repoPath: workingDirectory)
        enhancedViewModels[tab.id] = enhancedViewModel

        selectedTabId = tab.id
    }

    func closeTab(_ id: UUID) {
        // Allow closing the last tab (handled by empty state UI)
        if let index = tabs.firstIndex(where: { $0.id == id }) {
            tabs.remove(at: index)
            viewModels.removeValue(forKey: id)
            enhancedViewModels.removeValue(forKey: id)

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

struct EnhancedTerminalPanel: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var tabManager = EnhancedTerminalTabManager()
    @State private var viewMode: TerminalViewMode = .terminal
    @State private var showSessionSheet = false
    @State private var showCommandPalette = false
    
    // AI Input state
    @State private var nlInputText = ""
    @State private var isTranslating = false
    @State private var nlTranslationResult: NLCommandResponse?
    
    // AI Agent state
    @State private var showAIAgentPalette = false
    @State private var selectedAIMode: AIAgentMode?

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar with terminal tabs
            EnhancedTerminalTabBar(
                tabs: $tabManager.tabs,
                selectedTab: $tabManager.selectedTabId,
                viewMode: $viewMode,
                onAddTab: { tabManager.addTab(workingDirectory: appState.currentRepository?.path ?? NSHomeDirectory()) },
                onCloseTab: { tabManager.closeTab($0) },
                onShareSession: { showSessionSheet = true },
                onTogglePalette: { showCommandPalette.toggle() }
            )

            // Main content based on view mode
            if let viewModel = tabManager.currentViewModel,
               let enhancedViewModel = tabManager.currentEnhancedViewModel {
                mainContentView(viewModel: viewModel, enhancedViewModel: enhancedViewModel)
            } else {
                // Empty State
                VStack(spacing: 16) {
                    Text("No Terminal Session")
                        .font(DesignTokens.Typography.headline)
                        .foregroundColor(AppTheme.textSecondary)
                    
                    Text("Open a new terminal to get started")
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(AppTheme.textMuted)
                    
                    Button(action: {
                        tabManager.addTab(workingDirectory: appState.currentRepository?.path ?? NSHomeDirectory())
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16))
                            Text("New Terminal")
                                .font(DesignTokens.Typography.body)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(AppTheme.accent)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.background)
            }
        }
        .background(AppTheme.background)
        .sheet(isPresented: $showSessionSheet) {
            Text("Session Share")
                .padding()
        }
        .sheet(isPresented: $showCommandPalette) {
            Text("Command Palette")
                .padding()
        }
    }
    
    @ViewBuilder
    private func mainContentView(viewModel: GhosttyViewModel, enhancedViewModel: GhosttyEnhancedViewModel) -> some View {
        GeometryReader { geometry in
            // Main Layout: Content + Input Block
            VStack(spacing: 0) {
                // 1. Content Area (Terminal/Blocks)
                ZStack(alignment: .bottomLeading) {
                    contentView(viewModel: viewModel, enhancedViewModel: enhancedViewModel)
                        .frame(maxHeight: .infinity)
                        .blur(radius: showSessionSheet ? 3 : 0)

                    // Command Suggestions Overlay (Floating above terminal content)
                    if viewMode == .terminal, !enhancedViewModel.aiSuggestions.isEmpty {
                        VStack {
                            Spacer()
                            suggestionsOverlay(enhancedViewModel: enhancedViewModel)
                                .padding(.bottom, 8)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                    
                    if enhancedViewModel.isLoadingAI {
                        VStack {
                            Spacer()
                            loadingIndicator
                                .padding(.bottom, 8)
                        }
                    }
                    
                    // AI Agent Command Palette Overlay
                    if showAIAgentPalette {
                        VStack {
                            Spacer()
                            HStack {
                                AIAgentCommandPalette(
                                    isVisible: $showAIAgentPalette,
                                    currentInput: Binding(
                                        get: { enhancedViewModel.currentInput },
                                        set: { enhancedViewModel.updateInput($0, repoPath: appState.currentRepository?.path) }
                                    ),
                                    selectedMode: $selectedAIMode,
                                    onCommandSelected: { command in
                                        // Handle command execution
                                        if command.hasPrefix("/") {
                                            enhancedViewModel.currentInput = command
                                            if let viewModel = tabManager.currentViewModel {
                                                viewModel.writeInput(command + "\n")
                                                enhancedViewModel.trackCommand(command)
                                                enhancedViewModel.currentInput = ""
                                            }
                                        }
                                    }
                                )
                                Spacer()
                            }
                            .padding(.bottom, 60) // Position above command input
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                
                // 2. Warp-style AI Input Bar (Always Visible)
                warpAIInputBar
                
                // 3. Terminal Command Input
                if viewMode == .terminal {
                    terminalCommandInput(viewModel: viewModel, enhancedViewModel: enhancedViewModel)
                }
            }
        }
    }
    
    @ViewBuilder
    private var warpAIInputBar: some View {
        VStack(spacing: 0) {
            // Divider
            Divider()
                .background(AppTheme.border)
            
            // AI Input Bar
            HStack(spacing: 12) {
                // AI icon with subtle glow
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppTheme.accent)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(AppTheme.accent.opacity(0.1))
                    )
                
                // AI input field
                TextField("Ask Warp AI...", text: $nlInputText)
                    .font(.system(size: 14))
                    .textFieldStyle(.plain)
                    .lineLimit(1...3)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.inputBackground)
                    .cornerRadius(8)
                    .onSubmit {
                        Task {
                            await translateInput()
                        }
                    }
                
                // Send button
                Group {
                    if isTranslating {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.accent))
                    } else {
                        Button(action: {
                            Task {
                                await translateInput()
                            }
                        }) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(nlInputText.isEmpty ? AppTheme.textMuted : AppTheme.accent)
                        }
                        .disabled(nlInputText.isEmpty)
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppTheme.backgroundSecondary)
            
            // AI Results (if any)
            if let result = nlTranslationResult {
                aiResultView(result: result)
            }
        }
    }
    
    @ViewBuilder
    private func aiResultView(result: NLCommandResponse) -> some View {
        VStack(spacing: 12) {
            // Divider
            Divider()
                .background(AppTheme.border.opacity(0.5))
            
            // Result card
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Text(result.category.rawValue)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppTheme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.accent.opacity(0.1))
                        .cornerRadius(6)
                    
                    Spacer()
                    
                    // Confidence stars
                    HStack(spacing: 2) {
                        ForEach(0..<5) { i in
                            Image(systemName: i < Int(result.confidence * 5) ? "star.fill" : "star")
                                .font(.system(size: 8))
                                .foregroundColor(i < Int(result.confidence * 5) ? AppTheme.accent : AppTheme.border)
                        }
                    }
                }
                
                // Command
                HStack(spacing: 8) {
                    Button(action: {
                        executeCommand(result.command)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                            
                            Text(result.command)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppTheme.accent)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                    
                    // Copy button
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(result.command, forType: .string)
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(AppTheme.backgroundTertiary)
                            .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Explanation
                Text(result.explanation)
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .background(AppTheme.background)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
    
    @ViewBuilder
    private func terminalCommandInput(viewModel: GhosttyViewModel, enhancedViewModel: GhosttyEnhancedViewModel) -> some View {
        VStack(spacing: 0) {
            Divider()
                .background(AppTheme.border)
            
            HStack(spacing: 12) {
                // Current working directory
                if let selectedTabId = tabManager.selectedTabId,
                   let currentTab = tabManager.tabs.first(where: { $0.id == selectedTabId }) {
                    let cwd = currentTab.workingDirectory
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.textMuted)
                        Text(URL(fileURLWithPath: cwd).lastPathComponent)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(AppTheme.textMuted)
                    }
                }
                
                Spacer()
                
                // Command input
                TextField("Enter command...", text: Binding(
                    get: { enhancedViewModel.currentInput },
                    set: { value in
                        enhancedViewModel.updateInput(value, repoPath: appState.currentRepository?.path)
                        
                        // Check for slash command
                        if value == "/" && !showAIAgentPalette {
                            showAIAgentPalette = true
                        } else if !value.hasPrefix("/") && showAIAgentPalette {
                            showAIAgentPalette = false
                        }
                    }
                ))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .textFieldStyle(.plain)
                    .foregroundColor(AppTheme.textPrimary)
                    .onSubmit {
                        if let viewModel = tabManager.currentViewModel {
                            viewModel.writeInput(enhancedViewModel.currentInput + "\n")
                            enhancedViewModel.trackCommand(enhancedViewModel.currentInput)
                            enhancedViewModel.currentInput = ""
                        }
                    }
                
                // Execute button
                Button(action: {
                    if let viewModel = tabManager.currentViewModel {
                        viewModel.writeInput(enhancedViewModel.currentInput + "\n")
                        enhancedViewModel.trackCommand(enhancedViewModel.currentInput)
                        enhancedViewModel.currentInput = ""
                    }
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(enhancedViewModel.currentInput.isEmpty ? AppTheme.textMuted : AppTheme.accent)
                }
                .disabled(enhancedViewModel.currentInput.isEmpty)
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppTheme.backgroundSecondary.opacity(0.95))
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: -2)
        }
        .frame(height: 56)
    }
    
    @ViewBuilder
    private func contentView(viewModel: GhosttyViewModel, enhancedViewModel: GhosttyEnhancedViewModel) -> some View {
        switch viewMode {
        case .terminal:
            terminalView(viewModel: viewModel, enhancedViewModel: enhancedViewModel)
        case .blocks:
            blocksView(enhancedViewModel: enhancedViewModel)
        case .workflows:
            workflowsView(enhancedViewModel: enhancedViewModel)
        }
    }

    private func blocksView(enhancedViewModel: GhosttyEnhancedViewModel) -> some View {
        TerminalBlocksView(viewModel: enhancedViewModel)
    }

    private func workflowsView(enhancedViewModel: GhosttyEnhancedViewModel) -> some View {
        TerminalWorkflowsView(viewModel: enhancedViewModel)
    }

    // MARK: - Subviews

    private func terminalView(viewModel: GhosttyViewModel, enhancedViewModel: GhosttyEnhancedViewModel) -> some View {
        GhosttyEnhancedTerminalView(
            viewModel: viewModel,
            enhancedViewModel: enhancedViewModel,
            initialDirectory: appState.currentRepository?.path ?? NSHomeDirectory(),
            aiEnabled: true,
            repoPath: appState.currentRepository?.path
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func suggestionsOverlay(enhancedViewModel: GhosttyEnhancedViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(enhancedViewModel.aiSuggestions.prefix(5).enumerated()), id: \.offset) { index, suggestion in
                suggestionRow(suggestion: suggestion, index: index, enhancedViewModel: enhancedViewModel)

                if index < enhancedViewModel.aiSuggestions.count - 1 && index < 4 {
                    Divider()
                        .background(AppTheme.backgroundSecondary)
                }
            }
        }
        .padding(.vertical, 8)
        .background(suggestionBackground)
        .frame(maxWidth: 500)
        .overlay(alignment: .topTrailing) {
             Button {
                 enhancedViewModel.aiSuggestions.removeAll()
                 enhancedViewModel.currentInput = ""
             } label: {
                 Image(systemName: "xmark")
                     .font(.system(size: 10, weight: .bold))
                     .foregroundColor(AppTheme.textSecondary)
                     .padding(8)
                     .background(AppTheme.backgroundSecondary.opacity(0.8))
                     .clipShape(Circle())
             }
             .buttonStyle(.plain)
             .offset(x: -8, y: 8)
        }
        .padding(.leading, 20)
        .transition(.opacity.combined(with: .move(edge: .top)))
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: enhancedViewModel.aiSuggestions.count)
    }

    private var loadingIndicator: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.7)
                .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.accent))

            Text("AI thinking...")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(loadingBackground)
        .padding(.leading, 20)
        .transition(.opacity.combined(with: .scale))
    }

    private var suggestionBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(AppTheme.background.opacity(0.98))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppTheme.accent.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 8)
    }

    private var loadingBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(AppTheme.background.opacity(0.95))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppTheme.accent.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 4)
    }



    private func suggestionRow(suggestion: AICommandSuggestion, index: Int, enhancedViewModel: GhosttyEnhancedViewModel) -> some View {
        Button {
            if let viewModel = tabManager.currentViewModel {
                applySuggestion(suggestion, to: viewModel, enhancedViewModel: enhancedViewModel)
            }
        } label: {
            HStack(spacing: 12) {
                suggestionIcon(index: index, isFromAI: suggestion.isFromAI, enhancedViewModel: enhancedViewModel)
                suggestionContent(suggestion: suggestion, index: index, enhancedViewModel: enhancedViewModel)
                Spacer()
                if index == enhancedViewModel.selectedSuggestionIndex {
                    shortcutHint
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(index == enhancedViewModel.selectedSuggestionIndex ? AppTheme.accent.opacity(0.08) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    private func suggestionIcon(index: Int, isFromAI: Bool, enhancedViewModel: GhosttyEnhancedViewModel) -> some View {
            Image(systemName: isFromAI ? "sparkles" : "terminal")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(index == enhancedViewModel.selectedSuggestionIndex ? AppTheme.accent : AppTheme.textSecondary)
    }

    private func suggestionContent(suggestion: AICommandSuggestion, index: Int, enhancedViewModel: GhosttyEnhancedViewModel) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(suggestion.command)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(index == enhancedViewModel.selectedSuggestionIndex ? AppTheme.textPrimary : AppTheme.textSecondary)

            if !suggestion.description.isEmpty {
                Text(suggestion.description)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textMuted)
                    .lineLimit(2)
            }
        }
    }

    private var shortcutHint: some View {
        HStack(spacing: 4) {
            Image(systemName: "return")
                .font(.system(size: 10, weight: .semibold))
            Text("enter")
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundColor(AppTheme.textMuted)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(4)
    }

    private func applySuggestion(_ suggestion: AICommandSuggestion, to viewModel: GhosttyViewModel, enhancedViewModel: GhosttyEnhancedViewModel) {
        // Clear current buffer
        enhancedViewModel.currentInput = ""
        enhancedViewModel.aiSuggestions.removeAll()

        // Send command to terminal
        viewModel.writeInput(suggestion.command + "\n")

        // Track command in history
        enhancedViewModel.trackCommand(suggestion.command)
    }

    // MARK: - Session Management
    
    private func translateInput() async {
        guard !nlInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isTranslating = true
        nlTranslationResult = nil
        
        let context = NLContext(
            workingDirectory: tabManager.tabs.first { $0.id == tabManager.selectedTabId }?.workingDirectory ?? NSHomeDirectory(),
            gitBranch: appState.currentRepository?.currentBranch?.name,
            recentCommands: tabManager.currentEnhancedViewModel?.trackedCommands.suffix(5).map { $0.command } ?? [],
            environment: ProcessInfo.processInfo.environment,
            osType: "macOS"
        )
        
        let result = await TerminalAIService.shared.translateNaturalLanguage(
            input: nlInputText,
            context: context
        )
        
        withAnimation(.easeInOut(duration: 0.3)) {
            nlTranslationResult = result
        }
        
        isTranslating = false
    }
    
    private func executeCommand(_ command: String) {
        if let viewModel = tabManager.currentViewModel {
            viewModel.writeInput(command + "\n")
            tabManager.currentEnhancedViewModel?.trackCommand(command)
        }
    }

    private func createCurrentSession(from enhancedViewModel: GhosttyEnhancedViewModel) -> TerminalSession? {
        guard !enhancedViewModel.trackedCommands.isEmpty else { return nil }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        let sessionName = "Session \(dateFormatter.string(from: Date()))"

        return TerminalSession(
            name: sessionName,
            commands: enhancedViewModel.trackedCommands
        )
    }
}

// MARK: - Enhanced Terminal Tab Bar

struct EnhancedTerminalTabBar: View {
    @Binding var tabs: [EnhancedTerminalTab]
    @Binding var selectedTab: UUID?
    @Binding var viewMode: TerminalViewMode
    let onAddTab: () -> Void
    let onCloseTab: (UUID) -> Void
    let onShareSession: () -> Void
    let onTogglePalette: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Terminal tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 1) {
                    ForEach(tabs) { tab in
                        EnhancedTerminalTabButton(
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
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppTheme.textMuted)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .help("New tab")
                }
                .padding(.horizontal, 8)
            }

            Divider()
                .frame(height: 20)
                .padding(.horizontal, 8)

            // View mode picker (compact)
            Picker("", selection: $viewMode) {
                ForEach(TerminalViewMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 220)

            Spacer()

            // Share session button
            Button(action: onShareSession) {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 11, weight: .medium))
                    Text("Share")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(AppTheme.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(AppTheme.backgroundTertiary)
                .cornerRadius(5)
            }
            .buttonStyle(.plain)
            .help("Share terminal session")
            .padding(.trailing, 8)
            
            // Command Palette Button
            Button(action: { 
                // Toggle command palette via binding/callback would be better, but need to pass it up
                // For now, we need to expose a way to trigger it. 
                // Let's add a callback to this view
                onTogglePalette()
            }) {
                Image(systemName: "command")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(AppTheme.backgroundTertiary)
                    .cornerRadius(5)
            }
            .buttonStyle(.plain)
            .help("Command Palette (Cmd+Shift+P)")
            .padding(.trailing, 12)
        }
        .frame(height: 38)
        .background(AppTheme.backgroundSecondary)
    }
}

// MARK: - Enhanced Terminal Tab Button

struct EnhancedTerminalTabButton: View {
    let tab: EnhancedTerminalTab
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    let canClose: Bool

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 6) {
                Image(systemName: "terminal")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? AppTheme.accent : AppTheme.textMuted)

                Text(tab.name)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)

                if isHovered && canClose {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(AppTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .foregroundColor(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? AppTheme.background : (isHovered ? AppTheme.background.opacity(0.5) : Color.clear))
            .cornerRadius(5)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - AI Agent Command Palette

struct AIAgentCommandPalette: View {
    @Binding var isVisible: Bool
    @Binding var currentInput: String
    @Binding var selectedMode: AIAgentMode?
    let onCommandSelected: (String) -> Void
    
    @State private var searchText = ""
    @State private var selectedIndex = 0
    @FocusState private var isFocused: Bool
    
    private let commands: [AIAgentCommand] = [
        .init(command: "add-mcp", description: "Add new MCP server", icon: "server.rack"),
        .init(command: "add-prompt", description: "Add custom instructions", icon: "text.bubble"),
        .init(command: "add-rule", description: "Set global behavior rules", icon: "gear"),
        .init(command: "linear", description: "Fix a linear issue", icon: "link"),
        .init(command: "github", description: "Create GitHub issue/PR", icon: "branch"),
        .init(command: "database", description: "Query database", icon: "tablecells"),
        .init(command: "docs", description: "Search documentation", icon: "books.vertical"),
        .init(command: "test", description: "Run tests", icon: "play.rectangle")
    ]
    
    private let modes: [AIAgentMode] = [
        .init(name: "Build features", icon: "hammer.fill", color: Color.blue),
        .init(name: "Fix bugs", icon: "ladybug.fill", color: Color.red),
        .init(name: "Debug prod", icon: "lizard.fill", color: Color.orange)
    ]
    
    var filteredCommands: [AIAgentCommand] {
        if searchText.isEmpty {
            return commands
        }
        return commands.filter { $0.command.contains(searchText.lowercased()) || $0.description.lowercased().contains(searchText.lowercased()) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppTheme.accent)
                
                Text("AI Agent Commands")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                
                Spacer()
                
                Button(action: {
                    isVisible = false
                    currentInput = ""
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.textMuted)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppTheme.backgroundSecondary)
            
            // Search input
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.textMuted)
                
                TextField("Type command or search...", text: $searchText)
                    .font(.system(size: 14))
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .onSubmit {
                        if !filteredCommands.isEmpty {
                            selectCommand(filteredCommands[selectedIndex])
                        }
                    }
                    .onKeyPress { key in
                        return .ignored
                    }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppTheme.inputBackground)
            .cornerRadius(8)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            
            // Command list
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(filteredCommands.enumerated()), id: \.offset) { index, command in
                        AIAgentCommandRow(
                            command: command,
                            isSelected: index == selectedIndex,
                            onSelect: { selectCommand(command) }
                        )
                        .onAppear {
                            if index == selectedIndex {
                                selectedIndex = index
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 300)
            .background(AppTheme.background)
            
            // Mode selection
            if selectedMode == nil {
                VStack(spacing: 8) {
                    Text("Select work mode")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.textMuted)
                    
                    HStack(spacing: 8) {
                        ForEach(modes, id: \.name) { mode in
                            Button(action: {
                                selectedMode = mode
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: mode.icon)
                                        .font(.system(size: 12, weight: .medium))
                                    Text(mode.name)
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(mode.color)
                                .cornerRadius(16)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(16)
                .background(AppTheme.backgroundSecondary)
            }
        }
        .frame(width: 400)
        .background(AppTheme.background)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
        .onAppear {
            isFocused = true
            searchText = String(currentInput.dropFirst())
        }
        .onChange(of: searchText) { _, newValue in
            currentInput = "/" + newValue
        }
    }
    
    private func selectCommand(_ command: AIAgentCommand) {
        onCommandSelected("/" + command.command)
        isVisible = false
        currentInput = ""
        searchText = ""
    }
}

// MARK: - Command Row

struct AIAgentCommandRow: View {
    let command: AIAgentCommand
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: command.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.accent)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("/" + command.command)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Text(command.description)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textMuted)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? AppTheme.accent.opacity(0.1) : Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Models

struct AIAgentCommand {
    let command: String
    let description: String
    let icon: String
}

struct AIAgentMode {
    let name: String
    let icon: String
    let color: Color
}
