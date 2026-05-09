import SwiftUI

/// State-aware push button that shows ahead count and disables when nothing to push
struct PushToolbarButton: View {
    @Environment(AppState.self) var appState
    @State private var isHovered = false
    @State private var aheadCount: Int = 0
    @State private var currentBranchName: String?

    /// Whether the button should be enabled
    private var isEnabled: Bool {
        aheadCount > 0 && currentBranchName != nil
    }

    /// Dynamic icon based on state
    private var iconName: String {
        aheadCount > 0 ? "arrow.up.to.line.circle.fill" : "arrow.up.to.line"
    }

    /// Dynamic color based on state
    private var iconColor: Color {
        if !isEnabled {
            return AppTheme.textMuted.opacity(0.5)
        }
        return AppTheme.success
    }

    /// Help text for tooltip
    private var helpText: String {
        if aheadCount > 0 {
            return "Push \(aheadCount) commit\(aheadCount == 1 ? "" : "s") to remote"
        }
        return "Nothing to push"
    }

    var body: some View {
        Button {
            Logger.debug("PushButton tapped: isEnabled=\(isEnabled), aheadCount=\(aheadCount), branch=\(currentBranchName ?? "nil")")
            if isEnabled {
                NotificationCenter.default.post(name: .push, object: nil)
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                // Main icon
                Image(systemName: iconName)
                    .renderingMode(.template)
                    .font(.system(size: DesignTokens.Toolbar.iconSize, weight: .regular))
                    .foregroundStyle(iconColor)
                    .frame(
                        width: DesignTokens.Toolbar.iconOnlyButtonSize.width,
                        height: DesignTokens.Toolbar.iconOnlyButtonSize.height
                    )
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                            .fill(isHovered && isEnabled ? AppTheme.hover : Color.clear)
                    )

                // Badge showing ahead count
                if aheadCount > 0 {
                    Text("\(aheadCount)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            Capsule()
                                .fill(AppTheme.success)
                                .shadow(color: AppTheme.success.opacity(0.4), radius: 2, y: 1)
                        )
                        .offset(x: 6, y: -4)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .help(helpText)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: aheadCount)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onAppear { updateFromBranchManager() }
        .onReceive(NotificationCenter.default.publisher(for: .repositoryDidRefresh)) { _ in
            updateFromBranchManager()
        }
        .onReceive(NotificationCenter.default.publisher(for: .branchDidChange)) { _ in
            updateFromBranchManager()
        }
        .onReceive(NotificationCenter.default.publisher(for: .branchDidCheckout)) { _ in
            updateFromBranchManager()
        }
        .onChange(of: appState.activeTabId) { _, _ in
            updateFromBranchManager()
        }
    }

    private func updateFromBranchManager() {
        let branch = appState.branchManager?.currentBranch
        aheadCount = branch?.aheadBehind?.ahead ?? 0
        currentBranchName = branch?.name
    }
}

/// State-aware fetch button that shows behind count
struct FetchToolbarButton: View {
    @Environment(AppState.self) var appState
    @State private var isHovered = false
    @State private var behindCount: Int = 0

    /// Dynamic icon based on state
    private var iconName: String {
        behindCount > 0 ? "arrow.counterclockwise.circle.fill" : "arrow.counterclockwise"
    }

    /// Dynamic color based on state
    private var iconColor: Color {
        if behindCount > 0 {
            return AppTheme.warning
        }
        return AppTheme.info
    }

    /// Help text for tooltip
    private var helpText: String {
        if behindCount > 0 {
            return "\(behindCount) commit\(behindCount == 1 ? "" : "s") behind remote - Fetch to update"
        }
        return "Fetch from remote"
    }

    var body: some View {
        Button {
            NotificationCenter.default.post(name: .fetch, object: nil)
        } label: {
            ZStack(alignment: .topTrailing) {
                // Main icon
                Image(systemName: iconName)
                    .renderingMode(.template)
                    .font(.system(size: DesignTokens.Toolbar.iconSize, weight: .regular))
                    .foregroundStyle(iconColor)
                    .frame(
                        width: DesignTokens.Toolbar.iconOnlyButtonSize.width,
                        height: DesignTokens.Toolbar.iconOnlyButtonSize.height
                    )
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                            .fill(isHovered ? AppTheme.hover : Color.clear)
                    )

                // Badge showing behind count
                if behindCount > 0 {
                    Text("\(behindCount)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            Capsule()
                                .fill(AppTheme.warning)
                                .shadow(color: AppTheme.warning.opacity(0.4), radius: 2, y: 1)
                        )
                        .offset(x: 6, y: -4)
                }
            }
        }
        .buttonStyle(.plain)
        .help(helpText)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: behindCount)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onAppear { updateFromBranchManager() }
        .onReceive(NotificationCenter.default.publisher(for: .repositoryDidRefresh)) { _ in
            updateFromBranchManager()
        }
        .onReceive(NotificationCenter.default.publisher(for: .branchDidChange)) { _ in
            updateFromBranchManager()
        }
        .onReceive(NotificationCenter.default.publisher(for: .branchDidCheckout)) { _ in
            updateFromBranchManager()
        }
        .onChange(of: appState.activeTabId) { _, _ in
            updateFromBranchManager()
        }
    }

    private func updateFromBranchManager() {
        behindCount = appState.branchManager?.currentBranch?.aheadBehind?.behind ?? 0
    }
}

/// State-aware pull button that shows behind count and indicates if pull is available
struct PullToolbarButton: View {
    @Environment(AppState.self) var appState
    @State private var isHovered = false
    @State private var behindCount: Int = 0

    /// Dynamic icon based on state
    private var iconName: String {
        behindCount > 0 ? "arrow.down.to.line.circle.fill" : "arrow.down.to.line"
    }

    /// Dynamic color based on state
    private var iconColor: Color {
        if behindCount > 0 {
            return AppTheme.warning
        }
        return AppTheme.info
    }

    /// Help text for tooltip
    private var helpText: String {
        if behindCount > 0 {
            return "Pull \(behindCount) commit\(behindCount == 1 ? "" : "s") from remote"
        }
        return "Pull from remote"
    }

    var body: some View {
        Button {
            NotificationCenter.default.post(name: .pull, object: nil)
        } label: {
            ZStack(alignment: .topTrailing) {
                // Main icon
                Image(systemName: iconName)
                    .renderingMode(.template)
                    .font(.system(size: DesignTokens.Toolbar.iconSize, weight: .regular))
                    .foregroundStyle(iconColor)
                    .frame(
                        width: DesignTokens.Toolbar.iconOnlyButtonSize.width,
                        height: DesignTokens.Toolbar.iconOnlyButtonSize.height
                    )
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                            .fill(isHovered ? AppTheme.hover : Color.clear)
                    )

                // Badge showing behind count
                if behindCount > 0 {
                    Text("\(behindCount)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            Capsule()
                                .fill(AppTheme.warning)
                                .shadow(color: AppTheme.warning.opacity(0.4), radius: 2, y: 1)
                        )
                        .offset(x: 6, y: -4)
                }
            }
        }
        .buttonStyle(.plain)
        .help(helpText)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: behindCount)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onAppear { updateFromBranchManager() }
        .onReceive(NotificationCenter.default.publisher(for: .repositoryDidRefresh)) { _ in
            updateFromBranchManager()
        }
        .onReceive(NotificationCenter.default.publisher(for: .branchDidChange)) { _ in
            updateFromBranchManager()
        }
        .onReceive(NotificationCenter.default.publisher(for: .branchDidCheckout)) { _ in
            updateFromBranchManager()
        }
        .onChange(of: appState.activeTabId) { _, _ in
            updateFromBranchManager()
        }
    }

    private func updateFromBranchManager() {
        behindCount = appState.branchManager?.currentBranch?.aheadBehind?.behind ?? 0
    }
}

// MARK: - Preview

#Preview("Push/Fetch/Pull Toolbar Buttons") {
    HStack(spacing: 12) {
        PullToolbarButton()
        FetchToolbarButton()
        PushToolbarButton()
    }
    .padding()
    .background(AppTheme.background)
}
