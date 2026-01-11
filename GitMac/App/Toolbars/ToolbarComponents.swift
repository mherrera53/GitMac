import SwiftUI

// MARK: - Custom Toolbar Button
struct ToolbarActionButton: View {
    let icon: String
    let title: String
    let helpText: String // Tooltip text
    let color: Color
    let action: () -> Void
    var displayMode: ContentView.ToolbarDisplayMode = .iconAndText // Default fallback
    @AppStorage("toolbarDisplayMode") private var storedMode: ContentView.ToolbarDisplayMode = .iconAndText

    // Default initializer with empty help text if not provided (though we are providing it)
    init(icon: String, title: String, helpText: String = "", color: Color = AppTheme.textSecondary, displayMode: ContentView.ToolbarDisplayMode? = nil, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.helpText = helpText
        self.color = color
        self.action = action
        if let mode = displayMode {
            self._storedMode = AppStorage(wrappedValue: mode, "toolbarDisplayMode")
        }
    }

    @State private var isHovering = false
    @Environment(\.isEnabled) var isEnabled

    var body: some View {
        Button(action: action) {
            ZStack {
                if storedMode == .iconOnly {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                } else {
                    VStack(spacing: 2) {
                        Image(systemName: icon)
                            .font(.system(size: 14))
                        Text(title)
                            .font(.system(size: 9, weight: .semibold))
                    }
                }
            }
            .foregroundColor(isEnabled ? color : AppTheme.textMuted.opacity(0.5))
            .frame(width: storedMode == .iconOnly ? 36 : 50, height: storedMode == .iconOnly ? 32 : 40)
            .background(isHovering && isEnabled ? AppTheme.backgroundTertiary : Color.clear)
            .cornerRadius(6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(helpText)
        .onHover { isHovering = $0 }
    }
}
