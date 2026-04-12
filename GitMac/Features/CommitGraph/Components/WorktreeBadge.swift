//
//  WorktreeBadge.swift
//  GitMac
//
//  Badge indicating a branch has an active worktree
//

import SwiftUI

/// Badge indicating a branch has an active worktree
struct WorktreeBadge: View {
    let worktreeName: String
    let isMain: Bool
    let isLocked: Bool
    var onOpen: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    private var badgeColor: Color {
        isMain ? AppTheme.info : AppTheme.accentPurple
    }

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xxs) {
            Image(systemName: isMain ? "house.fill" : "folder.badge.gearshape")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(badgeColor)

            if isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 7))
                    .foregroundStyle(AppTheme.warning)
            }

            Text(worktreeName)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(textColor)
                .lineLimit(1)
        }
        .padding(.horizontal, DesignTokens.Spacing.xs)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 3)
                .fill(badgeColor.opacity(colorScheme == .dark ? 0.25 : 0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(badgeColor.opacity(0.5), lineWidth: 0.5)
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .onHover { isHovered = $0 }
        .onTapGesture {
            onOpen?()
        }
        .help("Worktree: \(worktreeName)\(isLocked ? " (locked)" : "")")
    }

    private var textColor: Color {
        colorScheme == .dark ? badgeColor : Color(nsColor: .labelColor)
    }
}

/// Compact worktree indicator (just icon)
struct WorktreeIndicator: View {
    let isMain: Bool
    let isLocked: Bool

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(systemName: isMain ? "house.fill" : "folder.fill")
                .font(.system(size: 10))
                .foregroundStyle(isMain ? AppTheme.info : AppTheme.accentPurple)

            if isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 6))
                    .foregroundStyle(AppTheme.warning)
                    .offset(x: 2, y: 2)
            }
        }
        .help(isMain ? "Main worktree" : "Linked worktree\(isLocked ? " (locked)" : "")")
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        HStack(spacing: 8) {
            WorktreeBadge(worktreeName: "feature-work", isMain: false, isLocked: false)
            WorktreeBadge(worktreeName: "main-repo", isMain: true, isLocked: false)
            WorktreeBadge(worktreeName: "locked-work", isMain: false, isLocked: true)
        }

        HStack(spacing: 8) {
            WorktreeIndicator(isMain: false, isLocked: false)
            WorktreeIndicator(isMain: true, isLocked: false)
            WorktreeIndicator(isMain: false, isLocked: true)
        }
    }
    .padding()
    .background(Color(nsColor: .windowBackgroundColor))
}
