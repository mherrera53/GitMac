//
//  DSInfiniteList.swift
//  GitMac
//
//  Created on 28/12/2025.
//  Atomic Design System - Organism: Infinite Scroll List
//

import SwiftUI

/// Lista con infinite scroll para cargar contenido paginado
/// Detecta cuando el usuario llega cerca del final y dispara loadMore
/// Performance optimizado con LazyVStack
struct DSInfiniteList<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let isLoading: Bool
    let hasMore: Bool
    let loadMore: () async -> Void
    @ViewBuilder let content: (Item) -> Content

    /// Threshold: cuántos items antes del final disparar loadMore
    var threshold: Int = 3

    var body: some View {
        ScrollView {
            LazyVStack(spacing: DesignTokens.Spacing.xs) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    content(item)
                        .onAppear {
                            // Trigger loadMore cuando estamos cerca del final
                            if shouldLoadMore(currentIndex: index) {
                                Task {
                                    await loadMore()
                                }
                            }
                        }
                }

                // Loading indicator
                if isLoading {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.8)

                        Text("Loading more...")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignTokens.Spacing.md)
                }

                // End of list message
                if !hasMore && !isLoading && !items.isEmpty {
                    Text("No more items")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignTokens.Spacing.md)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
        }
    }

    // MARK: - Helpers

    private func shouldLoadMore(currentIndex: Int) -> Bool {
        guard hasMore && !isLoading else { return false }

        // Load more when we're within threshold items from the end
        let triggerIndex = max(0, items.count - threshold)
        return currentIndex >= triggerIndex
    }
}

// MARK: - Preview

#Preview("Infinite List - Commits") {
    struct PreviewCommit: Identifiable {
        let id = UUID()
        let hash: String
        let message: String
        let author: String
    }

    struct InfinitePreview: View {
        @State private var commits: [PreviewCommit] = []
        @State private var isLoading = false
        @State private var hasMore = true
        @State private var page = 0

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Text("Commit History")
                        .font(DesignTokens.Typography.headline)

                    Spacer()

                    Text("\(commits.count) commits")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(.secondary)
                }
                .padding(DesignTokens.Spacing.md)
                .background(Color(.controlBackgroundColor))

                Divider()

                // Infinite list
                DSInfiniteList(
                    items: commits,
                    isLoading: isLoading,
                    hasMore: hasMore,
                    loadMore: loadMoreCommits
                ) { commit in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(commit.message)
                            .font(DesignTokens.Typography.body)
                            .lineLimit(2)

                        HStack {
                            Text(commit.hash)
                                .font(DesignTokens.Typography.commitHash)
                                .foregroundColor(.secondary)

                            Text("•")
                                .foregroundStyle(.tertiary)

                            Text(commit.author)
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(DesignTokens.CornerRadius.md)
                }
            }
            .frame(width: 400, height: 500)
            .background(Color(.windowBackgroundColor))
            .onAppear {
                // Initial load
                Task {
                    await loadMoreCommits()
                }
            }
        }

        func loadMoreCommits() async {
            guard !isLoading else { return }

            isLoading = true

            // Simulate API delay
            try? await Task.sleep(nanoseconds: 1_000_000_000)

            // Generate mock commits
            let newCommits = (0..<20).map { i in
                let num = page * 20 + i
                return PreviewCommit(
                    hash: String(format: "%07x", num * 12345),
                    message: "feat: implement feature #\(num)",
                    author: ["Alice", "Bob", "Charlie", "Diana"].randomElement()!
                )
            }

            commits.append(contentsOf: newCommits)
            page += 1

            // Stop after 100 commits
            if commits.count >= 100 {
                hasMore = false
            }

            isLoading = false
        }
    }

    return InfinitePreview()
}

#Preview("Infinite List - Simple") {
    struct SimpleItem: Identifiable {
        let id = UUID()
        let number: Int
    }

    struct SimplePreview: View {
        @State private var items: [SimpleItem] = []
        @State private var isLoading = false
        @State private var page = 0

        var body: some View {
            DSInfiniteList(
                items: items,
                isLoading: isLoading,
                hasMore: true,
                loadMore: loadMore
            ) { item in
                Text("Item #\(item.number)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DesignTokens.Spacing.sm)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(DesignTokens.CornerRadius.sm)
            }
            .frame(width: 300, height: 400)
            .onAppear {
                Task { await loadMore() }
            }
        }

        func loadMore() async {
            guard !isLoading else { return }
            isLoading = true
            try? await Task.sleep(nanoseconds: 500_000_000)

            let newItems = (0..<10).map { i in
                SimpleItem(number: page * 10 + i + 1)
            }
            items.append(contentsOf: newItems)
            page += 1

            isLoading = false
        }
    }

    return SimplePreview()
}
