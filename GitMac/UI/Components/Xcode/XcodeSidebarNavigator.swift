//
//  XcodeSidebarNavigator.swift
//  GitMac
//
//  Created on 2025-12-29.
//  Xcode-style horizontal navigator tabs for sidebar
//

import SwiftUI

/// Navigator type for sidebar sections
enum SidebarNavigator: String, CaseIterable, Identifiable {
    case repositories = "Repositories"
    case branches = "Branches"
    case remote = "Remote"
    case stashes = "Stashes"
    case tags = "Tags"
    case worktrees = "Worktrees"
    case submodules = "Submodules"
    case hooks = "Hooks"
    case cicd = "CI/CD"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .repositories:
            return "folder.fill"
        case .branches:
            return "arrow.triangle.branch"
        case .remote:
            return "arrow.triangle.2.circlepath"
        case .stashes:
            return "archivebox.fill"
        case .tags:
            return "tag.fill"
        case .worktrees:
            return "doc.on.doc.fill"
        case .submodules:
            return "shippingbox.fill"
        case .hooks:
            return "link"
        case .cicd:
            return "gearshape.2.fill"
        }
    }

    var tooltip: String {
        switch self {
        case .repositories:
            return "Show Repositories"
        case .branches:
            return "Show Local Branches"
        case .remote:
            return "Show Remote Branches"
        case .stashes:
            return "Show Stashes"
        case .tags:
            return "Show Tags"
        case .worktrees:
            return "Show Worktrees"
        case .submodules:
            return "Show Submodules"
        case .hooks:
            return "Show Git Hooks"
        case .cicd:
            return "Show CI/CD"
        }
    }
}

/// Xcode-style horizontal navigator tab button
struct XcodeSidebarNavigatorButton: View {
    let navigator: SidebarNavigator
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Image(systemName: navigator.icon)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundColor(iconColor)
                    .frame(width: 24, height: 22)

                if isSelected {
                    Rectangle()
                        .fill(AppTheme.accent)
                        .frame(height: 2)
                }
            }
            .frame(width: 26, height: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(navigator.tooltip)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    private var iconColor: Color {
        if isSelected {
            return AppTheme.accent
        }
        if isHovered {
            return AppTheme.textPrimary
        }
        return AppTheme.textSecondary
    }
}

/// Xcode-style horizontal navigator bar for sidebar
struct XcodeSidebarNavigatorBar: View {
    @Binding var selectedNavigator: SidebarNavigator

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(SidebarNavigator.allCases) { navigator in
                    XcodeSidebarNavigatorButton(
                        navigator: navigator,
                        isSelected: selectedNavigator == navigator,
                        action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedNavigator = navigator
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 2)
        }
        .frame(height: 28)
        .background(AppTheme.backgroundSecondary)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 0.5)
        }
    }
}

// MARK: - Preview

#Preview("Sidebar Navigators") {
    VStack(spacing: 0) {
        XcodeSidebarNavigatorBar(selectedNavigator: .constant(.branches))
            .frame(width: 260)
    }
}
