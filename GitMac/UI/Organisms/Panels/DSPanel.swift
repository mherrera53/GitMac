//
//  DSPanel.swift
//  GitMac
//
//  Created on 2025-12-28.
//  Atomic Design System - Organism: Generic Panel Container
//

import SwiftUI

/// Generic panel container organism
/// Combines molecules and atoms to create a reusable panel structure
struct DSPanel<Content: View>: View {
    let title: String?
    let showDivider: Bool
    let backgroundColor: Color?
    @ViewBuilder let content: () -> Content

    init(
        title: String? = nil,
        showDivider: Bool = true,
        backgroundColor: Color? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.showDivider = showDivider
        self.backgroundColor = backgroundColor
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            if let title = title {
                HStack {
                    Text(title)
                        .font(DesignTokens.Typography.headline)
                        .foregroundColor(AppTheme.textPrimary)

                    Spacer()
                }
                .padding(DesignTokens.Spacing.md)
                .background(AppTheme.backgroundSecondary)

                if showDivider {
                    DSDivider()
                }
            }

            // Content
            content()
        }
        .background(backgroundColor ?? AppTheme.background)
        .cornerRadius(DesignTokens.CornerRadius.lg)
    }
}

// MARK: - Previews

#Preview("DSPanel Basic") {
    DSPanel(title: "Settings") {
        VStack(spacing: DesignTokens.Spacing.md) {
            Text("Panel content goes here")
                .foregroundColor(AppTheme.textPrimary)
            Text("More content")
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding()
    }
    .frame(width: 400, height: 300)
    .padding()
    .background(AppTheme.background)
}

#Preview("DSPanel No Title") {
    DSPanel {
        VStack(spacing: DesignTokens.Spacing.md) {
            Text("Panel without title")
                .foregroundColor(AppTheme.textPrimary)
            Text("Clean and minimal")
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding()
    }
    .frame(width: 400, height: 200)
    .padding()
    .background(AppTheme.background)
}

#Preview("DSPanel Animated") {
    struct AnimatedPanelDemo: View {
        @State private var itemCount = 1

        var body: some View {
            VStack {
                DSPanel(title: "Dynamic Content") {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        ForEach(0..<itemCount, id: \.self) { index in
                            HStack {
                                DSIcon("checkmark.circle.fill", size: .sm, color: AppTheme.success)
                                Text("Item \(index + 1)")
                                    .font(DesignTokens.Typography.body)
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding()
                    .animation(DesignTokens.Animation.spring, value: itemCount)
                }
                .frame(width: 400, height: 250)

                // Controls
                HStack(spacing: DesignTokens.Spacing.md) {
                    Button("Add Item") {
                        withAnimation(DesignTokens.Animation.spring) {
                            itemCount = min(itemCount + 1, 10)
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Remove Item") {
                        withAnimation(DesignTokens.Animation.spring) {
                            itemCount = max(itemCount - 1, 0)
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
            .padding()
            .background(AppTheme.background)
        }
    }

    return AnimatedPanelDemo()
}
