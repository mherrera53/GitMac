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
        guard tabs.count > 1 else { return } // Keep at least one tab

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

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar with terminal tabs
            EnhancedTerminalTabBar(
                tabs: $tabManager.tabs,
                selectedTab: $tabManager.selectedTabId,
                viewMode: $viewMode,
                onAddTab: { tabManager.addTab(workingDirectory: appState.currentRepository?.path ?? NSHomeDirectory()) },
                onCloseTab: { tabManager.closeTab($0) },
                onShareSession: { showSessionSheet = true }
            )

            // Main content based on view mode
            if let viewModel = tabManager.currentViewModel,
               let enhancedViewModel = tabManager.currentEnhancedViewModel {
                GeometryReader { geometry in
                    ZStack(alignment: .topLeading) {
                        contentView(viewModel: viewModel, enhancedViewModel: enhancedViewModel)

                        // AI suggestions overlay (only in terminal mode)
                        if viewMode == .terminal {
                            VStack(alignment: .leading, spacing: 0) {
                                Spacer()
                                    .frame(height: 60) // Space from top

                                if !enhancedViewModel.aiSuggestions.isEmpty && !enhancedViewModel.currentInput.isEmpty {
                                    suggestionsOverlay(enhancedViewModel: enhancedViewModel)
                                } else if enhancedViewModel.isLoadingAI && !enhancedViewModel.currentInput.isEmpty {
                                    loadingIndicator
                                }

                                Spacer()
                            }
                        }
                    }
                }
                .background(AppTheme.background)
            }
        }
        .background(AppTheme.background)
        .sheet(isPresented: $showSessionSheet) {
            if let enhancedViewModel = tabManager.currentEnhancedViewModel,
               let currentSession = createCurrentSession(from: enhancedViewModel) {
                SessionSharingSheet(session: currentSession)
            }
        }
        .onAppear {
            if tabManager.tabs.isEmpty {
                tabManager.addTab(workingDirectory: appState.currentRepository?.path ?? NSHomeDirectory())
            }
        }
        .onChange(of: appState.currentRepository?.path) { _, newPath in
            if let path = newPath, let viewModel = tabManager.currentViewModel, let enhancedViewModel = tabManager.currentEnhancedViewModel {
                 viewModel.setWorkingDirectory(path)
                 enhancedViewModel.updateContext(repoPath: path)
             }
        }
    }

    // MARK: - Content Views

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
        .background(suggestionBackground)
        .frame(maxWidth: 500)
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
        ZStack {
            Circle()
                .fill(index == enhancedViewModel.selectedSuggestionIndex ? AppTheme.accent.opacity(0.15) : Color.clear)
                .frame(width: 28, height: 28)

            Image(systemName: isFromAI ? "sparkles" : "terminal")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(index == enhancedViewModel.selectedSuggestionIndex ? AppTheme.accent : AppTheme.textSecondary)
        }
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
