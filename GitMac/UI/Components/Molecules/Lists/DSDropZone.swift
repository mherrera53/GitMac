//
//  DSDropZone.swift
//  GitMac
//
//  Created on 28/12/2025.
//  Atomic Design System - Level 3: Drop Zone Molecule
//

import SwiftUI
import UniformTypeIdentifiers

/// Drop zone component for drag & drop operations
struct DSDropZone: View {
    let title: String
    let subtitle: String?
    let icon: String
    let acceptedTypes: [UTType]
    let onDrop: ([NSItemProvider]) -> Bool

    @State private var isTargeted = false

    init(
        title: String,
        subtitle: String? = nil,
        icon: String = "arrow.down.doc",
        acceptedTypes: [UTType] = [.text, .fileURL],
        onDrop: @escaping ([NSItemProvider]) -> Bool
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.acceptedTypes = acceptedTypes
        self.onDrop = onDrop
    }

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            DSIcon(icon, size: .xl, color: iconColor)

            VStack(spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(AppTheme.textPrimary)
                    .fontWeight(.medium)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(DesignTokens.Spacing.xl)
        .background(backgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                .strokeBorder(borderColor, style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
        )
        .clipShape(.rect(cornerRadius: DesignTokens.CornerRadius.lg))
        .animation(DesignTokens.Animation.fastEasing, value: isTargeted)
        .onDrop(of: acceptedTypes, isTargeted: $isTargeted) { providers in
            onDrop(providers)
        }
    }

    private var backgroundColor: Color {
        if isTargeted {
            return AppTheme.accent.opacity(0.1)
        } else {
            return AppTheme.backgroundSecondary.opacity(0.5)
        }
    }

    private var borderColor: Color {
        if isTargeted {
            return AppTheme.accent
        } else {
            return AppTheme.border
        }
    }

    private var iconColor: Color {
        if isTargeted {
            return AppTheme.accent
        } else {
            return AppTheme.textMuted
        }
    }
}

// MARK: - Previews

#Preview("Drop Zone - Basic") {
    DSDropZone(
        title: "Drop files here",
        subtitle: "Drag and drop files to upload"
    ) { providers in
        Logger.debug("Dropped \(providers.count) items")
        return true
    }
    .frame(width: 400, height: 200)
    .padding()
    .background(AppTheme.background)
}

#Preview("Drop Zone - Git Files") {
    DSDropZone(
        title: "Stage Files",
        subtitle: "Drag files here to add them to the staging area",
        icon: "plus.square.dashed"
    ) { providers in
        Logger.debug("Staging \(providers.count) files")
        return true
    }
    .frame(width: 400, height: 200)
    .padding()
    .background(AppTheme.background)
}

#Preview("Drop Zone - Unstage") {
    DSDropZone(
        title: "Unstage Files",
        subtitle: "Drag files here to remove them from staging",
        icon: "minus.square.dashed"
    ) { providers in
        Logger.debug("Unstaging \(providers.count) files")
        return true
    }
    .frame(width: 400, height: 200)
    .padding()
    .background(AppTheme.background)
}

#Preview("Drop Zone - Upload") {
    DSDropZone(
        title: "Upload Documents",
        subtitle: "Supports PDF, DOC, TXT files",
        icon: "doc.badge.arrow.up"
    ) { providers in
        Logger.debug("Uploading \(providers.count) documents")
        return true
    }
    .frame(width: 400, height: 200)
    .padding()
    .background(AppTheme.background)
}

#Preview("Drop Zone - Variants") {
    VStack(spacing: DesignTokens.Spacing.lg) {
        DSDropZone(
            title: "Small Drop Zone",
            icon: "arrow.down.circle"
        ) { _ in true }
        .frame(height: 120)

        DSDropZone(
            title: "Medium Drop Zone",
            subtitle: "With subtitle",
            icon: "arrow.down.doc.fill"
        ) { _ in true }
        .frame(height: 160)

        DSDropZone(
            title: "Large Drop Zone",
            subtitle: "Drag and drop files here\nSupports multiple file types",
            icon: "square.and.arrow.down"
        ) { _ in true }
        .frame(height: 220)
    }
    .padding()
    .background(AppTheme.background)
}

#Preview("Drop Zone - Side by Side") {
    HStack(spacing: DesignTokens.Spacing.lg) {
        DSDropZone(
            title: "Workspace",
            subtitle: "Unstaged changes",
            icon: "folder"
        ) { providers in
            Logger.debug("Moved to workspace: \(providers.count) items")
            return true
        }

        DSDropZone(
            title: "Staging Area",
            subtitle: "Ready to commit",
            icon: "tray"
        ) { providers in
            Logger.debug("Moved to staging: \(providers.count) items")
            return true
        }
    }
    .frame(height: 250)
    .padding()
    .background(AppTheme.background)
}
