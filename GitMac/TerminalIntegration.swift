import SwiftUI
import AppKit

/// Terminal Integration - Embedded terminal with Git context
/// Provides terminal access within GitMac for advanced operations
struct TerminalView: View {
    @StateObject private var viewModel = TerminalViewModel()
    @EnvironmentObject var appState: AppState
    
    @State private var commandInput = ""
    @State private var showHistory = false
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            terminalToolbar
            
            Divider()
            
            // Terminal output
            terminalOutput
            
            Divider()
            
            // Command input
            commandInputView
        }
        .background(AppTheme.background)
        .onAppear {
            isInputFocused = true
            if let repoPath = appState.currentRepository?.path {
                viewModel.setWorkingDirectory(repoPath)
            }
        }
    }
    
    // MARK: - Toolbar
    
    private var terminalToolbar: some View {
        HStack {
            // Working directory
            HStack(spacing: 4) {
                Image(systemName: "folder")
                    .foregroundColor(AppTheme.success)
                Text(viewModel.workingDirectory)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(AppTheme.success)
            }
            
            Spacer()
            
            // Branch indicator
            if let branch = appState.currentRepository?.currentBranch?.name {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.branch")
                        .foregroundColor(AppTheme.accentCyan)
                    Text(branch)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(AppTheme.accentCyan)
                }
            }
            
            Spacer()
            
            // Quick commands
            Menu {
                Button("git status") {
                    executeCommand("git status")
                }
                Button("git log --oneline -10") {
                    executeCommand("git log --oneline -10")
                }
                Button("git diff") {
                    executeCommand("git diff")
                }
                
                Divider()
                
                Button("Clear") {
                    viewModel.clearOutput()
                }
            } label: {
                Image(systemName: "terminal")
            }
            .menuStyle(.borderlessButton)
            .foregroundColor(AppTheme.textPrimary)
            
            // History
            Button {
                showHistory.toggle()
            } label: {
                Image(systemName: "clock.arrow.circlepath")
            }
            .buttonStyle(.borderless)
            .foregroundColor(AppTheme.textPrimary)
            .popover(isPresented: $showHistory) {
                CommandHistoryView(
                    history: viewModel.commandHistory,
                    onSelect: { command in
                        commandInput = command
                        showHistory = false
                    }
                )
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(AppTheme.background.opacity(0.9))
    }
    
    // MARK: - Terminal Output
    
    private var terminalOutput: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(viewModel.outputLines) { line in
                        TerminalLineView(line: line)
                            .id(line.id)
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.outputLines.count) { _, _ in
                if let lastLine = viewModel.outputLines.last {
                    withAnimation {
                        proxy.scrollTo(lastLine.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    // MARK: - Command Input
    
    private var commandInputView: some View {
        HStack(spacing: 8) {
            // Prompt
            Text(viewModel.prompt)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(AppTheme.success)
            
            // Input field
            TextField("", text: $commandInput)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(AppTheme.textPrimary)
                .focused($isInputFocused)
                .onSubmit {
                    executeCommand(commandInput)
                    commandInput = ""
                }
        }
        .padding()
        .background(AppTheme.background.opacity(0.9))
    }
    
    // MARK: - Actions
    
    private func executeCommand(_ command: String) {
        guard !command.isEmpty else { return }
        
        Task {
            await viewModel.execute(command: command)
            
            // Refresh repository if git command
            if command.hasPrefix("git") {
                try? await appState.gitService.refresh()
            }
        }
    }
}

// MARK: - Terminal Line View

struct TerminalLineView: View {
    let line: TerminalLine
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(line.text)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(lineColor)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var lineColor: Color {
        switch line.type {
        case .command:
            return .green
        case .output:
            return .white
        case .error:
            return .red
        case .success:
            return .cyan
        }
    }
}

// MARK: - Command History View

struct CommandHistoryView: View {
    let history: [String]
    let onSelect: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Command History")
                .font(.headline)
                .padding()
            
            Divider()
            
            if history.isEmpty {
                Text("No command history")
                    .foregroundColor(AppTheme.textPrimary)
                    .padding()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(Array(history.reversed().enumerated()), id: \.offset) { index, command in
                            Button {
                                onSelect(command)
                            } label: {
                                HStack {
                                    Text(command)
                                        .font(.system(.body, design: .monospaced))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .frame(width: 400, height: 300)
    }
}

// MARK: - Terminal Line Model

struct TerminalLine: Identifiable {
    let id: UUID
    let text: String
    let type: TerminalLineType
    let timestamp: Date
    
    init(text: String, type: TerminalLineType) {
        self.id = UUID()
        self.text = text
        self.type = type
        self.timestamp = Date()
    }
}

enum TerminalLineType {
    case command
    case output
    case error
    case success
}

// MARK: - View Model

@MainActor
class TerminalViewModel: ObservableObject {
    @Published var outputLines: [TerminalLine] = []
    @Published var commandHistory: [String] = []
    @Published var workingDirectory: String = "~"
    @Published var isExecuting = false
    
    private let maxHistory = 100
    private let maxOutputLines = 1000
    
    var prompt: String {
        "➜ "
    }
    
    func setWorkingDirectory(_ path: String) {
        workingDirectory = path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }
    
    func execute(command: String) async {
        guard !isExecuting else { return }
        
        isExecuting = true
        
        // Add command to history
        if !commandHistory.contains(command) {
            commandHistory.append(command)
            if commandHistory.count > maxHistory {
                commandHistory.removeFirst()
            }
        }
        
        // Display command
        addLine(TerminalLine(text: "\(prompt)\(command)", type: .command))
        
        // Execute command
        let result = await executeShellCommand(command)
        
        // Display output
        if !result.output.isEmpty {
            for line in result.output.components(separatedBy: .newlines) {
                if !line.isEmpty {
                    addLine(TerminalLine(text: line, type: result.exitCode == 0 ? .output : .error))
                }
            }
        }
        
        // Display exit status if error
        if result.exitCode != 0 {
            addLine(TerminalLine(text: "❌ Exit code: \(result.exitCode)", type: .error))
        }
        
        isExecuting = false
    }
    
    func clearOutput() {
        outputLines.removeAll()
    }
    
    private func addLine(_ line: TerminalLine) {
        outputLines.append(line)
        
        // Limit output size
        if outputLines.count > maxOutputLines {
            outputLines.removeFirst(outputLines.count - maxOutputLines)
        }
    }
    
    private func executeShellCommand(_ command: String) async -> (output: String, exitCode: Int32) {
        let task = Process()
        let pipe = Pipe()
        let errorPipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = errorPipe
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-c", command]
        task.currentDirectoryURL = URL(fileURLWithPath: workingDirectory.replacingOccurrences(of: "~", with: NSHomeDirectory()))
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            
            var output = String(data: data, encoding: .utf8) ?? ""
            if !errorData.isEmpty {
                output += String(data: errorData, encoding: .utf8) ?? ""
            }
            
            return (output, task.terminationStatus)
        } catch {
            return ("Error: \(error.localizedDescription)", 1)
        }
    }
}

// MARK: - Terminal Settings

struct TerminalSettings: Codable {
    var fontSize: CGFloat = 12
    var fontFamily: String = "Menlo"
    var backgroundColor: String = "#000000"
    var textColor: String = "#FFFFFF"
    var cursorColor: String = "#00FF00"
    
    static let `default` = TerminalSettings()
}

// MARK: - Advanced Terminal View with Tabs

struct AdvancedTerminalView: View {
    @StateObject private var manager = TerminalManager.shared
    @State private var selectedTab = 0
    @State private var showNewTab = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(manager.terminals.enumerated()), id: \.offset) { index, terminal in
                        IntegrationTerminalTab(
                            title: "Terminal \(index + 1)",
                            isSelected: selectedTab == index,
                            onSelect: { selectedTab = index },
                            onClose: {
                                manager.closeTerminal(at: index)
                                if selectedTab >= manager.terminals.count {
                                    selectedTab = max(0, manager.terminals.count - 1)
                                }
                            }
                        )
                    }
                    
                    // New tab button
                    Button {
                        manager.createTerminal()
                        selectedTab = manager.terminals.count - 1
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.textPrimary)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(height: 32)
            .background(AppTheme.background.opacity(0.9))
            
            Divider()
            
            // Terminal content
            if !manager.terminals.isEmpty && selectedTab < manager.terminals.count {
                TerminalView()
                    .id(selectedTab)
            } else {
                emptyTerminalView
            }
        }
    }
    
    private var emptyTerminalView: some View {
        VStack {
            Image(systemName: "terminal")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.textSecondary)

            Text("No terminal sessions")
                .foregroundColor(AppTheme.textSecondary)
            
            Button("New Terminal") {
                manager.createTerminal()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
    }
}

// MARK: - Integration Terminal Tab View

struct IntegrationTerminalTab: View {
    let title: String
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(isSelected ? .white : AppTheme.textSecondary)

            if isHovered {
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8))
                        .foregroundColor(AppTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isSelected ? AppTheme.selection : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onHover { isHovered = $0 }
    }
}

// MARK: - Terminal Manager

class TerminalManager: ObservableObject {
    static let shared = TerminalManager()
    
    @Published var terminals: [TerminalViewModel] = []
    
    init() {
        createTerminal()
    }
    
    func createTerminal() {
        let terminal = TerminalViewModel()
        terminals.append(terminal)
    }
    
    func closeTerminal(at index: Int) {
        guard index < terminals.count else { return }
        terminals.remove(at: index)
        
        // Always keep at least one terminal
        if terminals.isEmpty {
            createTerminal()
        }
    }
}
