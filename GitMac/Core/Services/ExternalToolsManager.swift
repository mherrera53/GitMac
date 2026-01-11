import SwiftUI
import AppKit

/// External Tools Manager - Launch external diff/merge tools
/// Supports popular tools like Beyond Compare, Kaleidoscope, VS Code, etc.
@MainActor
class ExternalToolsManager: ObservableObject {
    static let shared = ExternalToolsManager()
    
    @Published var availableTools: [ExternalTool] = []
    @Published var selectedDiffTool: ExternalTool?
    @Published var selectedMergeTool: ExternalTool?
    
    private let defaults = UserDefaults.standard
    private let diffToolKey = "selectedDiffTool"
    private let mergeToolKey = "selectedMergeTool"
    
    init() {
        detectAvailableTools()
        loadSavedTools()
    }
    
    // MARK: - Tool Detection
    
    func detectAvailableTools() {
        availableTools = ExternalTool.allCases.filter { $0.isInstalled }
    }
    
    func refreshTools() {
        detectAvailableTools()
    }
    
    // MARK: - Tool Selection
    
    func setDiffTool(_ tool: ExternalTool?) {
        selectedDiffTool = tool
        if let tool = tool {
            defaults.set(tool.id, forKey: diffToolKey)
        } else {
            defaults.removeObject(forKey: diffToolKey)
        }
    }
    
    func setMergeTool(_ tool: ExternalTool?) {
        selectedMergeTool = tool
        if let tool = tool {
            defaults.set(tool.id, forKey: mergeToolKey)
        } else {
            defaults.removeObject(forKey: mergeToolKey)
        }
    }
    
    // MARK: - Launch Tools
    
    func openDiff(oldFile: String, newFile: String) {
        guard let tool = selectedDiffTool else {
            // Fallback to system default
            openWithSystemDefault(oldFile)
            return
        }
        
        launchTool(tool, with: [oldFile, newFile])
    }
    
    func openMerge(base: String, local: String, remote: String, merged: String) {
        guard let tool = selectedMergeTool else {
            openWithSystemDefault(merged)
            return
        }
        
        launchTool(tool, with: [base, local, remote, merged])
    }
    
    func openFile(_ path: String, with tool: ExternalTool? = nil) {
        if let tool = tool {
            launchTool(tool, with: [path])
        } else {
            openWithSystemDefault(path)
        }
    }
    
    // MARK: - Private
    
    private func launchTool(_ tool: ExternalTool, with arguments: [String]) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: tool.executablePath)
        task.arguments = tool.buildArguments(for: arguments)
        
        do {
            try task.run()
        } catch {
            NotificationManager.shared.error(
                "Failed to launch \(tool.name)",
                detail: error.localizedDescription
            )
        }
    }
    
    private func openWithSystemDefault(_ path: String) {
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }
    
    private func loadSavedTools() {
        if let diffToolId = defaults.string(forKey: diffToolKey),
           let tool = ExternalTool(rawValue: diffToolId) {
            selectedDiffTool = tool
        }
        
        if let mergeToolId = defaults.string(forKey: mergeToolKey),
           let tool = ExternalTool(rawValue: mergeToolId) {
            selectedMergeTool = tool
        }
    }
}

// MARK: - External Tool

enum ExternalTool: String, CaseIterable, Identifiable {
    case beyondCompare = "beyond_compare"
    case kaleidoscope = "kaleidoscope"
    case vsCode = "vs_code"
    case sublimeText = "sublime_text"
    case sublimeMerge = "sublime_merge"
    case deltaWalker = "delta_walker"
    case araxis = "araxis"
    case p4merge = "p4merge"
    case meld = "meld"
    case diffMerge = "diff_merge"
    case fileMerge = "file_merge"
    case xcode = "xcode"
    
    var id: String { rawValue }
    
    var name: String {
        switch self {
        case .beyondCompare: return "Beyond Compare"
        case .kaleidoscope: return "Kaleidoscope"
        case .vsCode: return "VS Code"
        case .sublimeText: return "Sublime Text"
        case .sublimeMerge: return "Sublime Merge"
        case .deltaWalker: return "DeltaWalker"
        case .araxis: return "Araxis Merge"
        case .p4merge: return "P4Merge"
        case .meld: return "Meld"
        case .diffMerge: return "DiffMerge"
        case .fileMerge: return "FileMerge (Xcode)"
        case .xcode: return "Xcode"
        }
    }
    
    var bundleIdentifier: String {
        switch self {
        case .beyondCompare: return "com.ScooterSoftware.BeyondCompare"
        case .kaleidoscope: return "com.blackpixel.kaleidoscope"
        case .vsCode: return "com.microsoft.VSCode"
        case .sublimeText: return "com.sublimetext.3"
        case .sublimeMerge: return "com.sublimemerge"
        case .deltaWalker: return "com.deltopia.DeltaWalker"
        case .araxis: return "com.araxis.merge"
        case .p4merge: return "com.perforce.p4merge"
        case .meld: return "org.gnome.meld"
        case .diffMerge: return "com.sourcegear.DiffMerge"
        case .fileMerge: return "com.apple.FileMerge"
        case .xcode: return "com.apple.dt.Xcode"
        }
    }
    
    var executablePath: String {
        guard let appPath = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return ""
        }
        
        switch self {
        case .beyondCompare:
            return appPath.appendingPathComponent("Contents/MacOS/bcomp").path
        case .kaleidoscope:
            return appPath.appendingPathComponent("Contents/MacOS/ksdiff").path
        case .vsCode:
            return "/usr/local/bin/code"
        case .sublimeText:
            return "/usr/local/bin/subl"
        case .sublimeMerge:
            return "/usr/local/bin/smerge"
        case .p4merge:
            return appPath.appendingPathComponent("Contents/MacOS/p4merge").path
        case .fileMerge:
            return "/usr/bin/opendiff"
        case .xcode:
            return "/usr/bin/xed"
        default:
            return appPath.appendingPathComponent("Contents/MacOS/\(name.replacingOccurrences(of: " ", with: ""))").path
        }
    }
    
    var isInstalled: Bool {
        if self == .vsCode || self == .sublimeText || self == .sublimeMerge {
            // Check CLI tools
            return FileManager.default.fileExists(atPath: executablePath)
        }
        
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil
    }
    
    var icon: String {
        switch self {
        case .beyondCompare, .kaleidoscope, .deltaWalker, .araxis, .diffMerge:
            return "arrow.left.arrow.right.circle"
        case .vsCode, .sublimeText, .xcode:
            return "chevron.left.forwardslash.chevron.right"
        case .sublimeMerge, .p4merge, .meld:
            return "arrow.triangle.merge"
        case .fileMerge:
            return "doc.text.magnifyingglass"
        }
    }
    
    var supportsDiff: Bool {
        return true // All tools support diff
    }
    
    var supportsMerge: Bool {
        switch self {
        case .beyondCompare, .kaleidoscope, .araxis, .p4merge, .meld, .fileMerge, .sublimeMerge:
            return true
        default:
            return false
        }
    }
    
    func buildArguments(for files: [String]) -> [String] {
        switch self {
        case .beyondCompare:
            return files
        case .kaleidoscope:
            return files
        case .vsCode:
            return ["--diff"] + files
        case .sublimeText:
            return files
        case .sublimeMerge:
            return ["mergetool"] + files
        case .p4merge:
            return files
        case .fileMerge:
            return files
        case .xcode:
            return files
        default:
            return files
        }
    }
}

// MARK: - External Tools Settings View

struct ExternalToolsSettingsView: View {
    @StateObject private var manager = ExternalToolsManager.shared
    @State private var showCustomToolEditor = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("External Tools")
                .font(.title2)
                .fontWeight(.bold)
            
            // Diff tool selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Diff Tool")
                    .font(.headline)
                
                Picker("Diff Tool", selection: $manager.selectedDiffTool) {
                    Text("System Default").tag(nil as ExternalTool?)
                    
                    Divider()
                    
                    ForEach(manager.availableTools.filter { $0.supportsDiff }) { tool in
                        Label(tool.name, systemImage: tool.icon)
                            .tag(tool as ExternalTool?)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 300)
                .onChange(of: manager.selectedDiffTool) { _, newValue in
                    manager.setDiffTool(newValue)
                }
            }
            
            Divider()
            
            // Merge tool selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Merge Tool")
                    .font(.headline)
                
                Picker("Merge Tool", selection: $manager.selectedMergeTool) {
                    Text("System Default").tag(nil as ExternalTool?)
                    
                    Divider()
                    
                    ForEach(manager.availableTools.filter { $0.supportsMerge }) { tool in
                        Label(tool.name, systemImage: tool.icon)
                            .tag(tool as ExternalTool?)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 300)
                .onChange(of: manager.selectedMergeTool) { _, newValue in
                    manager.setMergeTool(newValue)
                }
            }
            
            Divider()
            
            // Available tools
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Detected Tools")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button {
                        manager.refreshTools()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Refresh")
                }
                
                if manager.availableTools.isEmpty {
                    Text("No external tools detected")
                        .foregroundColor(AppTheme.textPrimary)
                        .padding()
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(manager.availableTools) { tool in
                                ToolRow(tool: tool)
                            }
                        }
                    }
                    .frame(height: 200)
                }
            }
            
            Divider()
            
            // Install instructions
            DisclosureGroup("Installation Help") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("To use command-line tools:")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        InstructionItem(
                            tool: "VS Code",
                            instruction: "Install 'code' command: Cmd+Shift+P → 'Shell Command: Install code command in PATH'"
                        )
                        
                        InstructionItem(
                            tool: "Sublime Text",
                            instruction: "Install 'subl' command: ln -s '/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl' /usr/local/bin/subl"
                        )
                        
                        InstructionItem(
                            tool: "Sublime Merge",
                            instruction: "Install 'smerge' command: ln -s '/Applications/Sublime Merge.app/Contents/SharedSupport/bin/smerge' /usr/local/bin/smerge"
                        )
                    }
                }
                .padding()
            }
        }
        .padding()
    }
}

struct ToolRow: View {
    let tool: ExternalTool
    
    var body: some View {
        HStack {
            Image(systemName: tool.icon)
                .foregroundColor(AppTheme.accent)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(tool.name)
                    .font(.body)
                
                HStack(spacing: 8) {
                    if tool.supportsDiff {
                        Label("Diff", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(AppTheme.success)
                    }
                    
                    if tool.supportsMerge {
                        Label("Merge", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(AppTheme.accent)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(AppTheme.success)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppTheme.textSecondary.opacity(0.05))
        .cornerRadius(8)
    }
}

struct InstructionItem: View {
    let tool: String
    let instruction: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("**\(tool):**")
                .font(.caption)
            
            Text(instruction)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(AppTheme.textPrimary)
                .textSelection(.enabled)
        }
    }
}

// MARK: - Context Menu Integration

extension View {
    func externalToolsContextMenu(for filePath: String) -> some View {
        self.contextMenu {
            Menu("Open with...") {
                ForEach(ExternalToolsManager.shared.availableTools.filter { $0.supportsDiff }) { tool in
                    Button {
                        ExternalToolsManager.shared.openFile(filePath, with: tool)
                    } label: {
                        Label(tool.name, systemImage: tool.icon)
                    }
                }
                
                Divider()
                
                Button("System Default") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: filePath))
                }
            }
        }
    }
}
