//
//  DSResizablePanel.swift
//  GitMac
//
//  Created on 2025-12-28.
//  Atomic Design System - Organism: Resizable Panel
//

import SwiftUI

/// Resizable panel organism with drag handle
/// Uses UniversalResizer for smooth resize interaction
struct DSResizablePanel<Content: View>: View {
    let title: String?
    @Binding var height: CGFloat
    let minHeight: CGFloat
    let maxHeight: CGFloat
    let showDivider: Bool
    let resizePosition: ResizePosition
    @ViewBuilder let content: () -> Content

    enum ResizePosition {
        case top
        case bottom
    }

    init(
        title: String? = nil,
        height: Binding<CGFloat>,
        minHeight: CGFloat = 100,
        maxHeight: CGFloat = 600,
        showDivider: Bool = true,
        resizePosition: ResizePosition = .bottom,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self._height = height
        self.minHeight = minHeight
        self.maxHeight = maxHeight
        self.showDivider = showDivider
        self.resizePosition = resizePosition
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top resizer
            if resizePosition == .top {
                UniversalResizer(
                    dimension: $height,
                    minDimension: minHeight,
                    maxDimension: maxHeight,
                    orientation: .vertical
                )
            }

            // Panel content
            VStack(spacing: 0) {
                // Header
                if let title = title {
                    HStack {
                        Text(title)
                            .font(DesignTokens.Typography.headline)
                            .foregroundColor(AppTheme.textPrimary)

                        Spacer()

                        // Height indicator
                        Text("\(Int(height))px")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(AppTheme.textMuted)
                            .monospacedDigit()
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
            .frame(height: height)
            .background(AppTheme.background)
            .cornerRadius(DesignTokens.CornerRadius.lg)

            // Bottom resizer
            if resizePosition == .bottom {
                UniversalResizer(
                    dimension: $height,
                    minDimension: minHeight,
                    maxDimension: maxHeight,
                    orientation: .vertical
                )
            }
        }
    }
}

// MARK: - Previews

#Preview("DSResizablePanel Basic") {
    struct ResizableDemo: View {
        @State private var panelHeight: CGFloat = 250

        var body: some View {
            VStack {
                Spacer()

                DSResizablePanel(
                    title: "Resizable Panel",
                    height: $panelHeight,
                    minHeight: 150,
                    maxHeight: 500
                ) {
                    VStack(spacing: DesignTokens.Spacing.md) {
                        Text("Drag the handle to resize")
                            .foregroundColor(AppTheme.textSecondary)

                        ScrollView {
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                                ForEach(1...20, id: \.self) { i in
                                    HStack {
                                        DSIcon("doc.text", size: .sm, color: AppTheme.accent)
                                        Text("Item \(i)")
                                            .font(DesignTokens.Typography.body)
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                    .padding()
                }
                .frame(width: 400)
            }
            .frame(height: 700)
            .padding()
            .background(AppTheme.background)
        }
    }

    return ResizableDemo()
}

#Preview("DSResizablePanel Top Resize") {
    struct TopResizeDemo: View {
        @State private var panelHeight: CGFloat = 200

        var body: some View {
            VStack {
                DSResizablePanel(
                    title: "Top Resize Panel",
                    height: $panelHeight,
                    minHeight: 100,
                    maxHeight: 400,
                    resizePosition: .top
                ) {
                    VStack(spacing: DesignTokens.Spacing.md) {
                        Text("Resize from top")
                            .foregroundColor(AppTheme.textPrimary)

                        HStack(spacing: DesignTokens.Spacing.lg) {
                            VStack {
                                DSIcon("arrow.up", size: .lg, color: AppTheme.accent)
                                Text("Drag up")
                                    .font(DesignTokens.Typography.caption)
                            }
                            VStack {
                                DSIcon("arrow.down", size: .lg, color: AppTheme.accent)
                                Text("Drag down")
                                    .font(DesignTokens.Typography.caption)
                            }
                        }
                        .foregroundColor(AppTheme.textSecondary)
                    }
                    .padding()
                }
                .frame(width: 400)

                Spacer()
            }
            .frame(height: 600)
            .padding()
            .background(AppTheme.background)
        }
    }

    return TopResizeDemo()
}

#Preview("DSResizablePanel Animated") {
    @Previewable @State var panelHeight: CGFloat = 200
    @Previewable @State var itemCount = 5

    VStack {
        Spacer()

        DSResizablePanel(
            title: "Dynamic Content Panel",
            height: $panelHeight,
            minHeight: 150,
            maxHeight: 600
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    ForEach(0..<itemCount, id: \.self) { index in
                        HStack {
                            DSIcon("checkmark.circle.fill", size: .sm, color: AppTheme.success)
                            Text("Item \(index + 1)")
                                .font(DesignTokens.Typography.body)
                            Spacer()
                            Text("Details")
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(AppTheme.textMuted)
                        }
                        .padding(.vertical, DesignTokens.Spacing.xxs)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding()
                .animation(DesignTokens.Animation.spring, value: itemCount)
            }
        }
        .frame(width: 450)

        // Controls
        HStack(spacing: DesignTokens.Spacing.md) {
            Button("Reset Size") {
                withAnimation(DesignTokens.Animation.spring) {
                    panelHeight = 200
                }
            }
            .buttonStyle(.bordered)

            Button("Add Item") {
                withAnimation(DesignTokens.Animation.spring) {
                    itemCount = min(itemCount + 1, 20)
                }
            }
            .buttonStyle(.borderedProminent)

            Button("Remove Item") {
                withAnimation(DesignTokens.Animation.spring) {
                    itemCount = max(itemCount - 1, 1)
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
    .frame(height: 800)
    .padding()
    .background(AppTheme.background)
}
