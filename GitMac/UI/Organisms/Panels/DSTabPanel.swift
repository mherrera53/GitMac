//
//  DSTabPanel.swift
//  GitMac
//
//  Created on 2025-12-28.
//  Atomic Design System - Organism: Tab Panel
//

import SwiftUI

/// Tab item definition for DSTabPanel
struct DSTabItem: Identifiable, Equatable {
    let id: String
    let title: String
    let icon: String?
    let badge: Int?

    init(id: String, title: String, icon: String? = nil, badge: Int? = nil) {
        self.id = id
        self.title = title
        self.icon = icon
        self.badge = badge
    }
}

/// Tab panel organism with tab navigation
/// Features animated tab switching and customizable tab items
struct DSTabPanel<Content: View>: View {
    let tabs: [DSTabItem]
    @Binding var selectedTab: String
    let showDivider: Bool
    @ViewBuilder let content: (String) -> Content

    init(
        tabs: [DSTabItem],
        selectedTab: Binding<String>,
        showDivider: Bool = true,
        @ViewBuilder content: @escaping (String) -> Content
    ) {
        self.tabs = tabs
        self._selectedTab = selectedTab
        self.showDivider = showDivider
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab header
            HStack(spacing: 0) {
                ForEach(tabs) { tab in
                    DSInternalTabButton(
                        tab: tab,
                        isSelected: selectedTab == tab.id
                    ) {
                        withAnimation(DesignTokens.Animation.spring) {
                            selectedTab = tab.id
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.top, DesignTokens.Spacing.sm)
            .background(AppTheme.backgroundSecondary)

            if showDivider {
                DSDivider()
            }

            // Tab content
            content(selectedTab)
                .transition(.opacity.combined(with: .move(edge: .trailing)))
                .id(selectedTab)
        }
        .background(AppTheme.background)
        .cornerRadius(DesignTokens.CornerRadius.lg)
    }
}

// MARK: - Tab Button

private struct DSInternalTabButton: View {
    let tab: DSTabItem
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: DesignTokens.Spacing.xs) {
                // Icon
                if let icon = tab.icon {
                    DSIcon(
                        icon,
                        size: .sm,
                        color: isSelected ? AppTheme.accent : AppTheme.textSecondary
                    )
                }

                // Title
                Text(tab.title)
                    .font(DesignTokens.Typography.callout)
                    .foregroundColor(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
                    .fontWeight(isSelected ? .semibold : .regular)

                // Badge
                if let badge = tab.badge, badge > 0 {
                    Text("\(badge)")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, DesignTokens.Spacing.xs)
                        .padding(.vertical, DesignTokens.Spacing.xxs)
                        .background(AppTheme.accent)
                        .cornerRadius(DesignTokens.CornerRadius.sm)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                    .fill(isSelected ? AppTheme.backgroundSecondary : (isHovering ? AppTheme.backgroundSecondary.opacity(0.5) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
        .animation(DesignTokens.Animation.fastEasing, value: isSelected)
        .animation(DesignTokens.Animation.fastEasing, value: isHovering)
    }
}

// MARK: - Previews

#Preview("DSTabPanel Basic") {
    struct TabPanelDemo: View {
        @State private var selectedTab = "general"

        let tabs = [
            DSTabItem(id: "general", title: "General", icon: "gear"),
            DSTabItem(id: "advanced", title: "Advanced", icon: "slider.horizontal.3"),
            DSTabItem(id: "about", title: "About", icon: "info.circle")
        ]

        var body: some View {
            DSTabPanel(
                tabs: tabs,
                selectedTab: $selectedTab
            ) { tabId in
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    switch tabId {
                    case "general":
                        Text("General Settings")
                            .font(DesignTokens.Typography.headline)
                        ForEach(1...3, id: \.self) { i in
                            HStack {
                                DSIcon("checkmark.circle", size: .sm, color: AppTheme.success)
                                Text("General option \(i)")
                            }
                        }

                    case "advanced":
                        Text("Advanced Settings")
                            .font(DesignTokens.Typography.headline)
                        ForEach(1...4, id: \.self) { i in
                            HStack {
                                DSIcon("wrench.fill", size: .sm, color: AppTheme.warning)
                                Text("Advanced option \(i)")
                            }
                        }

                    case "about":
                        Text("About")
                            .font(DesignTokens.Typography.headline)
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                            Text("Version: 1.0.0")
                            Text("Build: 2025-12-28")
                            Text("GitMac Team")
                        }
                        .foregroundColor(AppTheme.textSecondary)

                    default:
                        Text("Unknown tab")
                    }
                }
                .foregroundColor(AppTheme.textPrimary)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(width: 500, height: 300)
            .padding()
            .background(AppTheme.background)
        }
    }

    return TabPanelDemo()
}

#Preview("DSTabPanel With Badges") {
    struct BadgeTabDemo: View {
        @State private var selectedTab = "inbox"

        let tabs = [
            DSTabItem(id: "inbox", title: "Inbox", icon: "tray.fill", badge: 12),
            DSTabItem(id: "starred", title: "Starred", icon: "star.fill", badge: 3),
            DSTabItem(id: "sent", title: "Sent", icon: "paperplane.fill", badge: nil),
            DSTabItem(id: "trash", title: "Trash", icon: "trash.fill", badge: 0)
        ]

        var body: some View {
            DSTabPanel(
                tabs: tabs,
                selectedTab: $selectedTab
            ) { tabId in
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    Text(tabId.capitalized)
                        .font(DesignTokens.Typography.headline)
                        .foregroundColor(AppTheme.textPrimary)

                    ScrollView {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                            ForEach(1...10, id: \.self) { i in
                                HStack {
                                    DSIcon("envelope", size: .sm, color: AppTheme.accent)
                                    Text("Message \(i)")
                                        .font(DesignTokens.Typography.body)
                                    Spacer()
                                }
                            }
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(width: 600, height: 350)
            .padding()
            .background(AppTheme.background)
        }
    }

    return BadgeTabDemo()
}

#Preview("DSTabPanel Animated") {
    struct AnimatedTabDemo: View {
        @State private var selectedTab = "files"
        @State private var fileCount = 5
        @State private var commitCount = 3

        let tabs = [
            DSTabItem(id: "files", title: "Files", icon: "doc.text"),
            DSTabItem(id: "commits", title: "Commits", icon: "clock.arrow.circlepath"),
            DSTabItem(id: "branches", title: "Branches", icon: "arrow.branch")
        ]

        var body: some View {
            VStack {
                DSTabPanel(
                    tabs: tabs,
                    selectedTab: $selectedTab
                ) { tabId in
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                        switch tabId {
                        case "files":
                            Text("Changed Files (\(fileCount))")
                                .font(DesignTokens.Typography.headline)
                            ScrollView {
                                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                                    ForEach(0..<fileCount, id: \.self) { i in
                                        HStack {
                                            DSIcon("doc.fill", size: .sm, color: AppTheme.success)
                                            Text("File\(i + 1).swift")
                                                .font(DesignTokens.Typography.body)
                                            Spacer()
                                        }
                                        .transition(.opacity.combined(with: .move(edge: .leading)))
                                    }
                                }
                            }

                        case "commits":
                            Text("Recent Commits (\(commitCount))")
                                .font(DesignTokens.Typography.headline)
                            ScrollView {
                                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                                    ForEach(0..<commitCount, id: \.self) { i in
                                        HStack {
                                            DSIcon("clock.fill", size: .sm, color: AppTheme.accent)
                                            Text("Commit \(i + 1)")
                                                .font(DesignTokens.Typography.body)
                                            Spacer()
                                        }
                                        .transition(.opacity.combined(with: .move(edge: .leading)))
                                    }
                                }
                            }

                        case "branches":
                            Text("Branches")
                                .font(DesignTokens.Typography.headline)
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                                ForEach(["main", "develop", "feature/tabs"], id: \.self) { branch in
                                    HStack {
                                        DSIcon("arrow.branch", size: .sm, color: AppTheme.warning)
                                        Text(branch)
                                            .font(DesignTokens.Typography.body)
                                    }
                                }
                            }

                        default:
                            EmptyView()
                        }
                    }
                    .foregroundColor(AppTheme.textPrimary)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .animation(DesignTokens.Animation.spring, value: fileCount)
                    .animation(DesignTokens.Animation.spring, value: commitCount)
                }
                .frame(width: 600, height: 400)

                // Controls
                HStack(spacing: DesignTokens.Spacing.md) {
                    if selectedTab == "files" {
                        Button("Add File") {
                            withAnimation(DesignTokens.Animation.spring) {
                                fileCount = min(fileCount + 1, 15)
                            }
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Remove File") {
                            withAnimation(DesignTokens.Animation.spring) {
                                fileCount = max(fileCount - 1, 1)
                            }
                        }
                        .buttonStyle(.bordered)
                    } else if selectedTab == "commits" {
                        Button("Add Commit") {
                            withAnimation(DesignTokens.Animation.spring) {
                                commitCount = min(commitCount + 1, 10)
                            }
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Remove Commit") {
                            withAnimation(DesignTokens.Animation.spring) {
                                commitCount = max(commitCount - 1, 1)
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
            }
            .padding()
            .background(AppTheme.background)
        }
    }

    return AnimatedTabDemo()
}
