import SwiftUI
import AppKit

// MARK: - Ghostty Native Terminal View
//
// CONDITIONAL COMPILATION:
// To enable Ghostty integration, add the following to your Xcode build settings:
// - Swift Compiler - Custom Flags: OTHER_SWIFT_FLAGS = -D GHOSTTY_AVAILABLE
// - Ensure GhosttyKit.xcframework is in the Frameworks/ folder
//
// CI builds will skip this code since GHOSTTY_AVAILABLE won't be defined

#if GHOSTTY_AVAILABLE

// MARK: - GhosttyTerminal Placeholder
// This placeholder enables the code to compile when GHOSTTY_AVAILABLE is set
// but the actual GhosttyKit framework isn't linked. The real GhosttyKit should
// be imported via: @_exported import GhosttyKit (when available)
class GhosttyTerminal {
    var terminalView: NSView? { nil }
    var onTitleChange: ((String) -> Void)?
    var onDirectoryChange: ((String) -> Void)?
    init?(config: ghostty_config_options_t) { return nil }
    func setWorkingDirectory(_ path: String) {}
    func writeInput(_ text: String) {}
    func cleanup() {}
}

struct ghostty_config_options_t {
    var font_family: UnsafeMutablePointer<CChar>? = nil
    var font_size: Int32 = 13
    var theme: UnsafeMutablePointer<CChar>? = nil
    var gpu_renderer: Bool = true
}

/// Native Ghostty terminal integration
struct GhosttyNativeView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = GhosttyViewModel()

    var body: some View {
        GhosttyTerminalRepresentable(viewModel: viewModel)
            .background(GhosttyColors.background)
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
}

// MARK: - Ghostty NSViewRepresentable

struct GhosttyTerminalRepresentable: NSViewRepresentable {
    @ObservedObject var viewModel: GhosttyViewModel

    func makeNSView(context: Context) -> NSView {
        // Configure Ghostty with Tokyo Night theme
        var config = ghostty_config_options_t()
        config.font_family = strdup("JetBrains Mono")
        config.font_size = 13
        config.theme = strdup("tokyo-night")
        config.gpu_renderer = true

        // Create Ghostty terminal instance
        guard let terminal = GhosttyTerminal(config: config) else {
            // Fallback to a placeholder view if Ghostty fails
            let errorView = NSTextField(labelWithString: "Ghostty not available")
            errorView.textColor = .red
            errorView.alignment = .center
            return errorView
        }

        // Free allocated strings
        if let fontFamily = config.font_family {
            free(UnsafeMutableRawPointer(mutating: fontFamily))
        }
        if let theme = config.theme {
            free(UnsafeMutableRawPointer(mutating: theme))
        }

        // Store terminal reference
        context.coordinator.terminal = terminal

        // Set up callbacks
        terminal.onTitleChange = { title in
            viewModel.terminalTitle = title
        }

        terminal.onDirectoryChange = { directory in
            viewModel.currentDirectory = (directory as NSString).lastPathComponent
        }

        // Return the native Ghostty view
        guard let terminalView = terminal.terminalView else {
            let errorView = NSTextField(labelWithString: "Failed to create terminal view")
            errorView.textColor = .red
            return errorView
        }

        return terminalView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Handle updates if needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    class Coordinator: NSObject {
        var viewModel: GhosttyViewModel
        var terminal: GhosttyTerminal?

        init(viewModel: GhosttyViewModel) {
            self.viewModel = viewModel
        }

        deinit {
            terminal?.cleanup()
        }
    }
}

// Note: GhosttyViewModel is defined in TerminalView.swift

#else
// MARK: - Ghostty Stub (When Framework Not Available)

/// Stub view when Ghostty framework is not available
struct GhosttyNativeView: View {
    var body: some View {
        VStack {
            Spacer()
            Text("Ghostty Terminal")
                .font(.title2)
                .foregroundStyle(AppTheme.textPrimary)
            Text("GhosttyKit framework not available")
                .font(.caption)
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
    }
}

#endif

// MARK: - Ghostty Color Scheme (Now using dynamic AppTheme)

@MainActor
enum GhosttyColors {
    static var background: Color { AppTheme.background }
    static var backgroundSecondary: Color { AppTheme.backgroundSecondary }
    static var textPrimary: Color { AppTheme.textPrimary }
    static var textSecondary: Color { AppTheme.textSecondary }
    static var textMuted: Color { AppTheme.textMuted }
    static var accent: Color { AppTheme.accent }
    static var cursor: Color { AppTheme.textPrimary }
    static var selection: Color { AppTheme.selection }

    // ANSI Colors (Using AppTheme semantic colors)
    static var black: Color { AppTheme.background }
    static var red: Color { AppTheme.error }
    static var green: Color { AppTheme.success }
    static var yellow: Color { AppTheme.warning }
    static var blue: Color { AppTheme.accent }
    static var magenta: Color { AppTheme.accentPurple }
    static var cyan: Color { AppTheme.accentCyan }
    static var white: Color { AppTheme.textPrimary }
}

// MARK: - AI Command Suggestion Model (local to Ghostty)
// Note: Main AICommandSuggestion is in TerminalAIService.swift

struct GhosttyAICommandSuggestion: Identifiable {
    let id = UUID()
    let command: String
    let description: String?
}
