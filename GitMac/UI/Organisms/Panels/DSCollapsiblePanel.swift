//
//  DSCollapsiblePanel.swift
//  GitMac
//
//  Created on 2025-12-28.
//  Atomic Design System - Organism: Collapsible Panel
//

import SwiftUI

/// Collapsible panel organism with animated expansion
/// Features header with chevron icon that rotates on toggle
struct DSCollapsiblePanel<Content: View>: View {
    let title: String
    let icon: String?
    @Binding var isExpanded: Bool
    let backgroundColor: Color?
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        icon: String? = nil,
        isExpanded: Binding<Bool>,
        backgroundColor: Color? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.icon = icon
        self._isExpanded = isExpanded
        self.backgroundColor = backgroundColor
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: DesignTokens.Spacing.sm) {
                // Chevron indicator
                DSIcon(
                    "chevron.right",
                    size: .sm,
                    color: AppTheme.textSecondary
                )
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .animation(DesignTokens.Animation.spring, value: isExpanded)

                // Optional icon
                if let icon = icon {
                    DSIcon(icon, size: .md, color: AppTheme.accent)
                }

                // Title
                Text(title)
                    .font(DesignTokens.Typography.headline)
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()

                // Expand/collapse hint
                Text(isExpanded ? "Collapse" : "Expand")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.textMuted)
                    .opacity(0)
                    .animation(DesignTokens.Animation.spring, value: isExpanded)
            }
            .padding(DesignTokens.Spacing.md)
            .background(AppTheme.backgroundSecondary)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(DesignTokens.Animation.spring) {
                    isExpanded.toggle()
                }
            }
            .onHover { hovering in
                // Could add hover state here
            }

            // Content with animation
            if isExpanded {
                DSDivider()

                content()
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity
                        )
                    )
            }
        }
        .background(backgroundColor ?? AppTheme.background)
        .cornerRadius(DesignTokens.CornerRadius.lg)
        .animation(DesignTokens.Animation.spring, value: isExpanded)
    }
}

// MARK: - Previews

#Preview("DSCollapsiblePanel Basic") {
    struct CollapsibleDemo: View {
        @State private var isExpanded = true

        var body: some View {
            DSCollapsiblePanel(
                title: "Collapsible Settings",
                icon: "gearshape.fill",
                isExpanded: $isExpanded
            ) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    Text("Setting 1")
                    Text("Setting 2")
                    Text("Setting 3")
                }
                .padding()
            }
            .frame(width: 400)
            .padding()
            .background(AppTheme.background)
        }
    }

    return CollapsibleDemo()
}

#Preview("DSCollapsiblePanel Multiple") {
    struct MultiplePanelsDemo: View {
        @State private var panel1Expanded = true
        @State private var panel2Expanded = false
        @State private var panel3Expanded = false

        var body: some View {
            VStack(spacing: DesignTokens.Spacing.md) {
                DSCollapsiblePanel(
                    title: "General",
                    icon: "gear",
                    isExpanded: $panel1Expanded
                ) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        ForEach(1...3, id: \.self) { i in
                            HStack {
                                DSIcon("checkmark.circle", size: .sm, color: AppTheme.success)
                                Text("General setting \(i)")
                                    .font(DesignTokens.Typography.body)
                            }
                        }
                    }
                    .padding()
                }

                DSCollapsiblePanel(
                    title: "Advanced",
                    icon: "slider.horizontal.3",
                    isExpanded: $panel2Expanded
                ) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        ForEach(1...4, id: \.self) { i in
                            HStack {
                                DSIcon("wrench.fill", size: .sm, color: AppTheme.warning)
                                Text("Advanced setting \(i)")
                                    .font(DesignTokens.Typography.body)
                            }
                        }
                    }
                    .padding()
                }

                DSCollapsiblePanel(
                    title: "About",
                    icon: "info.circle",
                    isExpanded: $panel3Expanded
                ) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Text("Version: 1.0.0")
                        Text("Build: 2025-12-28")
                        Text("Author: GitMac Team")
                    }
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(AppTheme.textSecondary)
                    .padding()
                }
            }
            .frame(width: 400)
            .padding()
            .background(AppTheme.background)
        }
    }

    return MultiplePanelsDemo()
}

#Preview("DSCollapsiblePanel Animated") {
    struct AnimatedDemo: View {
        @State private var isExpanded = false
        @State private var itemCount = 5

        var body: some View {
            VStack {
                DSCollapsiblePanel(
                    title: "Dynamic Content (\(itemCount) items)",
                    icon: "list.bullet",
                    isExpanded: $isExpanded
                ) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        ForEach(0..<itemCount, id: \.self) { index in
                            HStack {
                                DSIcon("star.fill", size: .sm, color: .yellow)
                                Text("Item \(index + 1)")
                                    .font(DesignTokens.Typography.body)
                                Spacer()
                            }
                            .transition(.opacity.combined(with: .move(edge: .leading)))
                        }
                    }
                    .padding()
                }
                .frame(width: 400)

                // Controls
                HStack(spacing: DesignTokens.Spacing.md) {
                    Button(isExpanded ? "Collapse" : "Expand") {
                        withAnimation(DesignTokens.Animation.spring) {
                            isExpanded.toggle()
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Add Item") {
                        withAnimation(DesignTokens.Animation.spring) {
                            itemCount = min(itemCount + 1, 10)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(!isExpanded)

                    Button("Remove Item") {
                        withAnimation(DesignTokens.Animation.spring) {
                            itemCount = max(itemCount - 1, 1)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(!isExpanded)
                }
                .padding()
            }
            .padding()
            .background(AppTheme.background)
        }
    }

    return AnimatedDemo()
}
