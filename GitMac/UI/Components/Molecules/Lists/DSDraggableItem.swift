//
//  DSDraggableItem.swift
//  GitMac
//
//  Created on 28/12/2025.
//  Atomic Design System - Level 3: Draggable List Item Molecule
//

import SwiftUI
import UniformTypeIdentifiers

/// Draggable list item component with drag handle
struct DSDraggableItem<Content: View>: View {
    let id: String
    let title: String
    let subtitle: String?
    @ViewBuilder let content: () -> Content
    let onMove: ((String) -> Void)?

    @State private var isHovered = false
    @State private var isDragging = false

    init(
        id: String,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: @escaping () -> Content = { EmptyView() },
        onMove: ((String) -> Void)? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.content = content
        self.onMove = onMove
    }

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // Drag Handle
            VStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { _ in
                    Capsule()
                        .fill(isHovered ? AppTheme.textSecondary : AppTheme.textMuted)
                        .frame(width: 12, height: 2)
                }
            }
            .opacity(isHovered ? 1.0 : 0.5)

            // Content
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(AppTheme.textPrimary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }

                content()
            }

            Spacer()
        }
        .padding(DesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                .strokeBorder(borderColor, lineWidth: 1)
        )
        .opacity(isDragging ? 0.5 : 1.0)
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.fastEasing) {
                isHovered = hovering
            }
        }
        .onDrag {
            isDragging = true
            return NSItemProvider(object: id as NSString)
        }
        .onDrop(of: [UTType.text], delegate: DragDropDelegate(
            item: id,
            isDragging: $isDragging,
            onMove: onMove
        ))
    }

    private var backgroundColor: Color {
        if isDragging {
            return AppTheme.backgroundSecondary.opacity(0.5)
        } else if isHovered {
            return AppTheme.backgroundSecondary
        } else {
            return Color.clear
        }
    }

    private var borderColor: Color {
        if isDragging {
            return AppTheme.accent
        } else if isHovered {
            return AppTheme.border
        } else {
            return Color.clear
        }
    }
}

// MARK: - Drag & Drop Delegate

private struct DragDropDelegate: DropDelegate {
    let item: String
    @Binding var isDragging: Bool
    let onMove: ((String) -> Void)?

    func performDrop(info: DropInfo) -> Bool {
        isDragging = false

        if let itemProvider = info.itemProviders(for: [UTType.text]).first {
            itemProvider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { data, _ in
                if let data = data as? Data,
                   let draggedId = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        onMove?(draggedId)
                    }
                }
            }
            return true
        }
        return false
    }

    func dropEntered(info: DropInfo) {
        // Visual feedback when dragging over
    }

    func dropExited(info: DropInfo) {
        // Reset visual feedback
    }

    func validateDrop(info: DropInfo) -> Bool {
        return info.hasItemsConforming(to: [UTType.text])
    }
}

// MARK: - Previews

#Preview("Draggable Item - Basic") {
    VStack(spacing: DesignTokens.Spacing.sm) {
        DSDraggableItem(
            id: "1",
            title: "First Item",
            subtitle: "Drag to reorder"
        )

        DSDraggableItem(
            id: "2",
            title: "Second Item",
            subtitle: "Drag to reorder"
        )

        DSDraggableItem(
            id: "3",
            title: "Third Item",
            subtitle: "Drag to reorder"
        )
    }
    .padding()
    .background(AppTheme.background)
}

#Preview("Draggable Item - With Content") {
    VStack(spacing: DesignTokens.Spacing.sm) {
        DSDraggableItem(
            id: "1",
            title: "Pick: Initial commit",
            subtitle: "a3f5b2c - John Doe"
        ) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                DSStatusBadge("pick", variant: .success, size: .sm)
                Text("+12 -5")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.textMuted)
            }
        }

        DSDraggableItem(
            id: "2",
            title: "Squash: Fix typo",
            subtitle: "d8e91fc - Jane Smith"
        ) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                DSStatusBadge("squash", variant: .primary, size: .sm)
                Text("+2 -1")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.textMuted)
            }
        }

        DSDraggableItem(
            id: "3",
            title: "Reword: Update documentation",
            subtitle: "c2d4a1b - Bob Johnson"
        ) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                DSStatusBadge("reword", variant: .info, size: .sm)
                Text("+45 -3")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.textMuted)
            }
        }
    }
    .padding()
    .background(AppTheme.background)
}

#Preview("Draggable Item - Tasks") {
    VStack(spacing: DesignTokens.Spacing.sm) {
        DSDraggableItem(
            id: "task1",
            title: "Implement authentication",
            subtitle: "High priority"
        ) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                DSStatusBadge("In Progress", variant: .warning, size: .sm)
                DSIcon("flame.fill", size: .sm, color: AppTheme.error)
            }
        } onMove: { id in
            print("Moved: \(id)")
        }

        DSDraggableItem(
            id: "task2",
            title: "Update dependencies",
            subtitle: "Medium priority"
        ) {
            DSStatusBadge("Todo", variant: .neutral, size: .sm)
        } onMove: { id in
            print("Moved: \(id)")
        }

        DSDraggableItem(
            id: "task3",
            title: "Write tests",
            subtitle: "Low priority"
        ) {
            DSStatusBadge("Todo", variant: .neutral, size: .sm)
        } onMove: { id in
            print("Moved: \(id)")
        }
    }
    .padding()
    .background(AppTheme.background)
}

#Preview("Draggable Item - Files") {
    ScrollView {
        VStack(spacing: DesignTokens.Spacing.sm) {
            ForEach(1..<10) { i in
                DSDraggableItem(
                    id: "file\(i)",
                    title: "File\(i).swift",
                    subtitle: "Modified 2 hours ago"
                ) {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        DSIcon("doc.text.fill", size: .sm, color: AppTheme.fileSwift)
                        Text("+\(i * 3) -\(i)")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(AppTheme.textMuted)
                    }
                } onMove: { id in
                    print("Reordered: \(id)")
                }
            }
        }
        .padding()
    }
    .frame(height: 400)
    .background(AppTheme.background)
}
