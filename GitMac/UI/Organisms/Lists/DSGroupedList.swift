//
//  DSGroupedList.swift
//  GitMac
//
//  Created on 28/12/2025.
//  Atomic Design System - Organism: Grouped List
//

import SwiftUI

/// Lista con secciones agrupadas
/// Ideal para mostrar datos categorizados (branches por remote, commits por fecha, etc.)
struct DSGroupedList<
    SectionID: Hashable,
    Item: Identifiable,
    SectionHeader: View,
    Content: View
>: View {
    let sections: [DSListSection<SectionID, Item>]
    @ViewBuilder let header: (DSListSection<SectionID, Item>) -> SectionHeader
    @ViewBuilder let content: (Item) -> Content

    /// Estilo de las secciones
    var sectionSpacing: CGFloat = DesignTokens.Spacing.lg
    var itemSpacing: CGFloat = DesignTokens.Spacing.xs
    var collapsible: Bool = false

    @State private var collapsedSections: Set<SectionID> = []

    var body: some View {
        ScrollView {
            LazyVStack(spacing: sectionSpacing, pinnedViews: .sectionHeaders) {
                ForEach(sections, id: \.id) { section in
                    Section {
                        if !isCollapsed(section.id) {
                            LazyVStack(spacing: itemSpacing) {
                                ForEach(section.items) { item in
                                    content(item)
                                }
                            }
                        }
                    } header: {
                        if collapsible {
                            Button {
                                toggleSection(section.id)
                            } label: {
                                HStack {
                                    header(section)

                                    Spacer()

                                    Image(systemName: isCollapsed(section.id) ? "chevron.right" : "chevron.down")
                                        .font(.system(size: DesignTokens.Size.iconXS))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())
                        } else {
                            header(section)
                        }
                    }
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
        }
    }

    // MARK: - Helpers

    private func isCollapsed(_ sectionId: SectionID) -> Bool {
        collapsible && collapsedSections.contains(sectionId)
    }

    private func toggleSection(_ sectionId: SectionID) {
        withAnimation(DesignTokens.Animation.spring) {
            if collapsedSections.contains(sectionId) {
                collapsedSections.remove(sectionId)
            } else {
                collapsedSections.insert(sectionId)
            }
        }
    }
}

// MARK: - Section Model

struct DSListSection<SectionID: Hashable, Item: Identifiable>: Identifiable {
    let id: SectionID
    let items: [Item]

    // Metadata opcional
    var title: String?
    var count: Int { items.count }
}

// MARK: - Preview

#Preview("Grouped List - Branches by Remote") {
    struct PreviewBranch: Identifiable {
        let id = UUID()
        let name: String
        let lastCommit: String
    }

    struct GroupedPreview: View {
        let sections = [
            DSListSection(
                id: "origin",
                items: [
                    PreviewBranch(name: "main", lastCommit: "2 hours ago"),
                    PreviewBranch(name: "develop", lastCommit: "1 day ago"),
                    PreviewBranch(name: "staging", lastCommit: "3 days ago")
                ],
                title: "origin"
            ),
            DSListSection(
                id: "upstream",
                items: [
                    PreviewBranch(name: "main", lastCommit: "5 hours ago"),
                    PreviewBranch(name: "release/v2.0", lastCommit: "2 weeks ago")
                ],
                title: "upstream"
            ),
            DSListSection(
                id: "local",
                items: [
                    PreviewBranch(name: "feature/grouped-lists", lastCommit: "Just now"),
                    PreviewBranch(name: "feature/terminal-ai", lastCommit: "Yesterday"),
                    PreviewBranch(name: "hotfix/urgent-fix", lastCommit: "3 hours ago")
                ],
                title: "local"
            )
        ]

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                Text("Branches")
                    .font(DesignTokens.Typography.headline)
                    .padding(DesignTokens.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.controlBackgroundColor))

                Divider()

                // Grouped list
                DSGroupedList(
                    sections: sections,
                    header: { section in
                        HStack {
                            Image(systemName: section.id == "local" ? "laptopcomputer" : "arrow.triangle.branch")
                                .font(.system(size: DesignTokens.Size.iconSM))
                                .foregroundColor(.secondary)

                            Text(section.title ?? "Unknown")
                                .font(DesignTokens.Typography.callout)
                                .fontWeight(.semibold)

                            Text("(\(section.count))")
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, DesignTokens.Spacing.sm)
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.windowBackgroundColor))
                    },
                    content: { branch in
                        HStack {
                            Image(systemName: "arrow.branch")
                                .font(.system(size: DesignTokens.Size.iconSM))
                                .foregroundColor(.blue)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(branch.name)
                                    .font(DesignTokens.Typography.body)

                                Text(branch.lastCommit)
                                    .font(DesignTokens.Typography.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                        .padding(.vertical, DesignTokens.Spacing.sm)
                        .padding(.horizontal, DesignTokens.Spacing.md)
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(DesignTokens.CornerRadius.md)
                    }
                )
                .collapsible(true)
            }
            .frame(width: 400, height: 600)
            .background(Color(.windowBackgroundColor))
        }
    }

    return GroupedPreview()
}

#Preview("Grouped List - Commits by Date") {
    struct PreviewCommit: Identifiable {
        let id = UUID()
        let hash: String
        let message: String
        let author: String
    }

    struct DateGroupedPreview: View {
        let sections = [
            DSListSection(
                id: "today",
                items: [
                    PreviewCommit(hash: "a1b2c3d", message: "feat: add grouped lists", author: "Alice"),
                    PreviewCommit(hash: "e4f5g6h", message: "fix: resolve crash", author: "Bob")
                ],
                title: "Today"
            ),
            DSListSection(
                id: "yesterday",
                items: [
                    PreviewCommit(hash: "i7j8k9l", message: "refactor: improve performance", author: "Charlie"),
                    PreviewCommit(hash: "m0n1o2p", message: "docs: update README", author: "Diana")
                ],
                title: "Yesterday"
            ),
            DSListSection(
                id: "this-week",
                items: [
                    PreviewCommit(hash: "q3r4s5t", message: "feat: terminal integration", author: "Alice"),
                    PreviewCommit(hash: "u6v7w8x", message: "test: add unit tests", author: "Bob"),
                    PreviewCommit(hash: "y9z0a1b", message: "chore: update dependencies", author: "Charlie")
                ],
                title: "This Week"
            )
        ]

        var body: some View {
            DSGroupedList(
                sections: sections,
                header: { section in
                    Text(section.title ?? "")
                        .font(DesignTokens.Typography.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .padding(.vertical, DesignTokens.Spacing.xs)
                },
                content: { commit in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(commit.message)
                                .font(DesignTokens.Typography.body)

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

                        Spacer()
                    }
                    .padding(DesignTokens.Spacing.sm)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(DesignTokens.CornerRadius.md)
                }
            )
            .frame(width: 400, height: 500)
            .background(Color(.windowBackgroundColor))
        }
    }

    return DateGroupedPreview()
}

// MARK: - View Modifiers

extension DSGroupedList {
    /// Habilita/deshabilita secciones colapsables
    func collapsible(_ enabled: Bool) -> Self {
        var copy = self
        copy.collapsible = enabled
        return copy
    }

    /// Configura el espaciado entre secciones
    func sectionSpacing(_ spacing: CGFloat) -> Self {
        var copy = self
        copy.sectionSpacing = spacing
        return copy
    }

    /// Configura el espaciado entre items
    func itemSpacing(_ spacing: CGFloat) -> Self {
        var copy = self
        copy.itemSpacing = spacing
        return copy
    }
}
