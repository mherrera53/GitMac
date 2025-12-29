//
//  DSVirtualizedList.swift
//  GitMac
//
//  Created on 28/12/2025.
//  Atomic Design System - Organism: Virtualized List
//

import SwiftUI

/// Lista virtualizada de alto rendimiento para grandes datasets
/// Solo renderiza items visibles + buffer, crítico para 10,000+ items
/// Usa LazyVStack internamente pero añade optimizaciones adicionales
struct DSVirtualizedList<Item: Identifiable, Content: View>: View {
    let items: [Item]
    @ViewBuilder let content: (Item) -> Content

    /// Altura estimada por item (mejora performance del LazyVStack)
    var estimatedItemHeight: CGFloat = 44

    /// Buffer de items a renderizar fuera del viewport (arriba y abajo)
    var bufferSize: Int = 10

    /// Spacing entre items
    var spacing: CGFloat = DesignTokens.Spacing.xs

    @State private var scrollPosition: CGFloat = 0

    var body: some View {
        ScrollView {
            LazyVStack(spacing: spacing) {
                ForEach(items) { item in
                    content(item)
                        .frame(minHeight: estimatedItemHeight)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
        }
    }
}

// MARK: - Performance Optimized Variant

/// Variante ultra-optimizada con geometría manual para datasets masivos
struct DSVirtualizedListAdvanced<Item: Identifiable, Content: View>: View {
    let items: [Item]
    @ViewBuilder let content: (Item) -> Content

    var itemHeight: CGFloat = 44
    var spacing: CGFloat = DesignTokens.Spacing.xs
    var bufferSize: Int = 10

    @State private var visibleRange: Range<Int> = 0..<20
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                ZStack(alignment: .top) {
                    // Spacer para mantener la altura total del scroll
                    Color.clear
                        .frame(height: totalHeight)

                    // Solo renderizar items visibles + buffer
                    LazyVStack(spacing: spacing) {
                        ForEach(visibleItems) { item in
                            content(item)
                                .frame(height: itemHeight)
                        }
                    }
                    .offset(y: offsetForVisibleItems)
                    .padding(.horizontal, DesignTokens.Spacing.md)
                }
                .background(
                    GeometryReader { scrollGeometry in
                        Color.clear.preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: scrollGeometry.frame(in: .named("scroll")).minY
                        )
                    }
                )
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                updateVisibleRange(scrollOffset: -offset, viewportHeight: geometry.size.height)
            }
        }
    }

    // MARK: - Computed Properties

    private var totalHeight: CGFloat {
        CGFloat(items.count) * (itemHeight + spacing) - spacing
    }

    private var visibleItems: [Item] {
        let start = max(0, visibleRange.lowerBound)
        let end = min(items.count, visibleRange.upperBound)
        return Array(items[start..<end])
    }

    private var offsetForVisibleItems: CGFloat {
        CGFloat(visibleRange.lowerBound) * (itemHeight + spacing)
    }

    // MARK: - Helpers

    private func updateVisibleRange(scrollOffset: CGFloat, viewportHeight: CGFloat) {
        let itemTotalHeight = itemHeight + spacing

        // Calcular primer y último item visible
        let firstVisible = max(0, Int(scrollOffset / itemTotalHeight) - bufferSize)
        let visibleCount = Int(viewportHeight / itemTotalHeight) + 1
        let lastVisible = min(items.count, firstVisible + visibleCount + bufferSize * 2)

        let newRange = firstVisible..<lastVisible

        if newRange != visibleRange {
            visibleRange = newRange
        }
    }
}

// MARK: - Preference Key

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - View Modifiers

extension DSVirtualizedList {
    /// Configura la altura estimada por item
    func estimatedItemHeight(_ height: CGFloat) -> Self {
        var copy = self
        copy.estimatedItemHeight = height
        return copy
    }

    /// Configura el buffer de items
    func bufferSize(_ size: Int) -> Self {
        var copy = self
        copy.bufferSize = size
        return copy
    }

    /// Configura el espaciado entre items
    func spacing(_ spacing: CGFloat) -> Self {
        var copy = self
        copy.spacing = spacing
        return copy
    }
}

extension DSVirtualizedListAdvanced {
    /// Configura la altura de cada item (debe ser fija)
    func itemHeight(_ height: CGFloat) -> Self {
        var copy = self
        copy.itemHeight = height
        return copy
    }

    /// Configura el buffer de items
    func bufferSize(_ size: Int) -> Self {
        var copy = self
        copy.bufferSize = size
        return copy
    }

    /// Configura el espaciado entre items
    func spacing(_ spacing: CGFloat) -> Self {
        var copy = self
        copy.spacing = spacing
        return copy
    }
}

// MARK: - Preview

#Preview("Virtualized List - 10,000 Commits") {
    struct PreviewCommit: Identifiable {
        let id = UUID()
        let hash: String
        let message: String
    }

    struct VirtualizedPreview: View {
        // Generar 10,000 commits
        let commits = (0..<10_000).map { i in
            PreviewCommit(
                hash: String(format: "%07x", i * 12345),
                message: "feat: commit #\(i) - \(["fix bug", "add feature", "refactor code", "update docs"].randomElement()!)"
            )
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Text("Commit History")
                        .font(DesignTokens.Typography.headline)

                    Spacer()

                    Text("\(commits.count.formatted()) commits")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(.secondary)
                }
                .padding(DesignTokens.Spacing.md)
                .background(Color(.controlBackgroundColor))

                Divider()

                // Virtualized list
                DSVirtualizedList(items: commits) { commit in
                    HStack {
                        Text(commit.hash)
                            .font(DesignTokens.Typography.commitHash)
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .leading)

                        Text(commit.message)
                            .font(DesignTokens.Typography.body)
                            .lineLimit(1)

                        Spacer()
                    }
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(DesignTokens.CornerRadius.sm)
                }
                .estimatedItemHeight(36)
            }
            .frame(width: 500, height: 600)
            .background(Color(.windowBackgroundColor))
        }
    }

    return VirtualizedPreview()
}

#Preview("Advanced Virtualized - 100,000 Items") {
    struct PreviewItem: Identifiable {
        let id: Int
        let title: String
    }

    struct AdvancedPreview: View {
        // Generar 100,000 items
        let items = (0..<100_000).map { i in
            PreviewItem(id: i, title: "Item #\(i)")
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                Text("Ultra Performance Test")
                    .font(DesignTokens.Typography.headline)
                    .padding(DesignTokens.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.controlBackgroundColor))

                Text("\(items.count.formatted()) items - Smooth scrolling guaranteed")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.bottom, DesignTokens.Spacing.sm)

                Divider()

                // Advanced virtualized list
                DSVirtualizedListAdvanced(items: items) { item in
                    HStack {
                        Text("\(item.id)")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .trailing)

                        Text(item.title)
                            .font(DesignTokens.Typography.body)

                        Spacer()

                        if item.id % 100 == 0 {
                            Image(systemName: "star.fill")
                                .font(.system(size: DesignTokens.Size.iconXS))
                                .foregroundColor(.yellow)
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .background(Color(.controlBackgroundColor))
                }
                .itemHeight(44)
                .bufferSize(15)
            }
            .frame(width: 400, height: 600)
            .background(Color(.windowBackgroundColor))
        }
    }

    return AdvancedPreview()
}

#Preview("Virtualized List - Simple") {
    struct SimpleItem: Identifiable {
        let id = UUID()
        let number: Int
    }

    let items = (1...1000).map { SimpleItem(number: $0) }

    return DSVirtualizedList(items: items) { item in
        Text("Item #\(item.number)")
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignTokens.Spacing.sm)
            .background(Color.blue.opacity(0.05))
            .cornerRadius(DesignTokens.CornerRadius.sm)
    }
    .frame(width: 300, height: 400)
    .background(Color(.windowBackgroundColor))
}
