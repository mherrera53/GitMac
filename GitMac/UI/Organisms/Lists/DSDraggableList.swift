//
//  DSDraggableList.swift
//  GitMac
//
//  Created on 28/12/2025.
//  Atomic Design System - Organism: Draggable List
//

import SwiftUI

/// Lista con capacidad de reordenamiento mediante drag & drop
/// Performance optimizado para listas de hasta 1,000 items
struct DSDraggableList<Item: Identifiable & Equatable, Content: View>: View {
    @Binding var items: [Item]
    @ViewBuilder let content: (Item) -> Content

    @State private var draggedItem: Item?
    @State private var isDragging = false

    var body: some View {
        LazyVStack(spacing: DesignTokens.Spacing.xs) {
            ForEach(items) { item in
                content(item)
                    .opacity(draggedItem?.id == item.id ? DesignTokens.Opacity.disabled : 1.0)
                    .onDrag {
                        self.draggedItem = item
                        self.isDragging = true
                        return NSItemProvider(object: "\(item.id)" as NSString)
                    }
                    .onDrop(
                        of: [.text],
                        delegate: DraggableListDropDelegate(
                            item: item,
                            items: $items,
                            draggedItem: $draggedItem,
                            isDragging: $isDragging
                        )
                    )
            }
        }
    }
}

// MARK: - Drop Delegate

struct DraggableListDropDelegate<Item: Identifiable & Equatable>: DropDelegate {
    let item: Item
    @Binding var items: [Item]
    @Binding var draggedItem: Item?
    @Binding var isDragging: Bool

    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        isDragging = false
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggedItem = draggedItem,
              draggedItem.id != item.id,
              let from = items.firstIndex(where: { $0.id == draggedItem.id }),
              let to = items.firstIndex(where: { $0.id == item.id })
        else { return }

        // Animate reorder
        withAnimation(DesignTokens.Animation.spring) {
            items.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

// MARK: - Preview

#Preview("Draggable List - Git Branches") {
    struct PreviewBranch: Identifiable, Equatable {
        let id = UUID()
        let name: String
        let commits: Int

        static func == (lhs: PreviewBranch, rhs: PreviewBranch) -> Bool {
            lhs.id == rhs.id
        }
    }

    struct PreviewWrapper: View {
        @State private var branches = [
            PreviewBranch(name: "main", commits: 1247),
            PreviewBranch(name: "develop", commits: 892),
            PreviewBranch(name: "feature/draggable-lists", commits: 45),
            PreviewBranch(name: "feature/terminal-ai", commits: 23),
            PreviewBranch(name: "hotfix/avatar-crash", commits: 3)
        ]

        var body: some View {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                Text("Reorder Branches")
                    .font(DesignTokens.Typography.headline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, DesignTokens.Spacing.md)

                ScrollView {
                    DSDraggableList(items: $branches) { branch in
                        HStack {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: DesignTokens.Size.iconSM))
                                .foregroundColor(.secondary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(branch.name)
                                    .font(DesignTokens.Typography.body)

                                Text("\(branch.commits) commits")
                                    .font(DesignTokens.Typography.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: DesignTokens.Size.iconXS))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, DesignTokens.Spacing.md)
                        .padding(.vertical, DesignTokens.Spacing.sm)
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(DesignTokens.CornerRadius.md)
                        .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)
                    }
                    .padding(.horizontal, DesignTokens.Spacing.md)
                }
            }
            .frame(width: 350, height: 400)
            .background(Color(.windowBackgroundColor))
        }
    }

    return PreviewWrapper()
}

#Preview("Draggable List - Simple Items") {
    struct PreviewItem: Identifiable, Equatable {
        let id = UUID()
        let title: String
    }

    struct SimplePreview: View {
        @State private var items = [
            PreviewItem(title: "First Item"),
            PreviewItem(title: "Second Item"),
            PreviewItem(title: "Third Item"),
            PreviewItem(title: "Fourth Item")
        ]

        var body: some View {
            DSDraggableList(items: $items) { item in
                Text(item.title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DesignTokens.Spacing.sm)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(DesignTokens.CornerRadius.sm)
            }
            .padding()
            .frame(width: 300, height: 250)
        }
    }

    return SimplePreview()
}
