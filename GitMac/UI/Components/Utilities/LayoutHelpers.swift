//
//  LayoutHelpers.swift
//  GitMac
//
//  Created on 28/12/2025.
//  Atomic Design System - Utilities: Layout Helper Components
//

import SwiftUI

// MARK: - DSHStack

/// HStack with Design System spacing by default
struct DSHStack<Content: View>: View {
    let alignment: VerticalAlignment
    let spacing: CGFloat?
    @ViewBuilder let content: () -> Content

    init(
        alignment: VerticalAlignment = .center,
        spacing: CGFloat? = DesignTokens.Spacing.md,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        HStack(alignment: alignment, spacing: spacing, content: content)
    }
}

// MARK: - DSVStack

/// VStack with Design System spacing by default
struct DSVStack<Content: View>: View {
    let alignment: HorizontalAlignment
    let spacing: CGFloat?
    @ViewBuilder let content: () -> Content

    init(
        alignment: HorizontalAlignment = .center,
        spacing: CGFloat? = DesignTokens.Spacing.md,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        VStack(alignment: alignment, spacing: spacing, content: content)
    }
}

// MARK: - DSScrollView

/// ScrollView with consistent configuration and indicators
struct DSScrollView<Content: View>: View {
    let axes: Axis.Set
    let showsIndicators: Bool
    let bounce: Bool
    @ViewBuilder let content: () -> Content

    init(
        _ axes: Axis.Set = .vertical,
        showsIndicators: Bool = true,
        bounce: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.axes = axes
        self.showsIndicators = showsIndicators
        self.bounce = bounce
        self.content = content
    }

    var body: some View {
        ScrollView(axes, showsIndicators: showsIndicators) {
            content()
        }
        .scrollBounceBehavior(bounce ? .automatic : .basedOnSize)
    }
}

// MARK: - DSLazyVStack

/// LazyVStack with Design System spacing by default
struct DSLazyVStack<Content: View>: View {
    let alignment: HorizontalAlignment
    let spacing: CGFloat?
    let pinnedViews: PinnedScrollableViews
    @ViewBuilder let content: () -> Content

    init(
        alignment: HorizontalAlignment = .center,
        spacing: CGFloat? = DesignTokens.Spacing.sm,
        pinnedViews: PinnedScrollableViews = [],
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.pinnedViews = pinnedViews
        self.content = content
    }

    var body: some View {
        LazyVStack(
            alignment: alignment,
            spacing: spacing,
            pinnedViews: pinnedViews,
            content: content
        )
    }
}

// MARK: - DSLazyHStack

/// LazyHStack with Design System spacing by default
struct DSLazyHStack<Content: View>: View {
    let alignment: VerticalAlignment
    let spacing: CGFloat?
    let pinnedViews: PinnedScrollableViews
    @ViewBuilder let content: () -> Content

    init(
        alignment: VerticalAlignment = .center,
        spacing: CGFloat? = DesignTokens.Spacing.sm,
        pinnedViews: PinnedScrollableViews = [],
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.pinnedViews = pinnedViews
        self.content = content
    }

    var body: some View {
        LazyHStack(
            alignment: alignment,
            spacing: spacing,
            pinnedViews: pinnedViews,
            content: content
        )
    }
}

// MARK: - DSGrid

/// Grid layout with Design System spacing
struct DSGrid<Content: View>: View {
    let columns: [GridItem]
    let alignment: HorizontalAlignment
    let spacing: CGFloat?
    @ViewBuilder let content: () -> Content

    init(
        columns: Int,
        alignment: HorizontalAlignment = .center,
        spacing: CGFloat? = DesignTokens.Spacing.md,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.columns = Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns)
        self.alignment = alignment
        self.spacing = spacing
        self.content = content
    }

    init(
        columns: [GridItem],
        alignment: HorizontalAlignment = .center,
        spacing: CGFloat? = DesignTokens.Spacing.md,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.columns = columns
        self.alignment = alignment
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        LazyVGrid(
            columns: columns,
            alignment: alignment,
            spacing: spacing,
            content: content
        )
    }
}

// MARK: - DSSection

/// Section container with consistent padding and background
struct DSSection<Content: View>: View {
    let title: String?
    let footer: String?
    let padding: CGFloat
    @ViewBuilder let content: () -> Content

    init(
        title: String? = nil,
        footer: String? = nil,
        padding: CGFloat = DesignTokens.Spacing.md,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.footer = footer
        self.padding = padding
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            if let title = title {
                Text(title)
                    .font(DesignTokens.Typography.headline)
                    .foregroundColor(AppTheme.textSecondary)
                    .padding(.horizontal, padding)
            }

            content()
                .padding(padding)
                .background(AppTheme.backgroundSecondary)
                .cornerRadius(DesignTokens.CornerRadius.lg)

            if let footer = footer {
                Text(footer)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.textMuted)
                    .padding(.horizontal, padding)
            }
        }
    }
}

// MARK: - DSContainer

/// Container with consistent padding and optional background
struct DSContainer<Content: View>: View {
    let maxWidth: CGFloat?
    let padding: CGFloat
    let background: Color?
    @ViewBuilder let content: () -> Content

    init(
        maxWidth: CGFloat? = nil,
        padding: CGFloat = DesignTokens.Spacing.lg,
        background: Color? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.maxWidth = maxWidth
        self.padding = padding
        self.background = background
        self.content = content
    }

    var body: some View {
        content()
            .frame(maxWidth: maxWidth)
            .padding(padding)
            .background(background)
    }
}

// MARK: - DSSpacer

/// Flexible or fixed spacer with Design System values
struct DSSpacer: View {
    let size: CGFloat?

    init(size: CGFloat? = nil) {
        self.size = size
    }

    var body: some View {
        if let size = size {
            Spacer()
                .frame(width: size, height: size)
        } else {
            Spacer()
        }
    }
}

// MARK: - DSFlexibleSpacer

/// Spacer that grows to fill available space with min/max constraints
struct DSFlexibleSpacer: View {
    let minLength: CGFloat?
    let maxLength: CGFloat?

    init(minLength: CGFloat? = nil, maxLength: CGFloat? = nil) {
        self.minLength = minLength
        self.maxLength = maxLength
    }

    var body: some View {
        Spacer(minLength: minLength ?? 0)
            .frame(maxHeight: maxLength)
    }
}

// MARK: - View Extensions

extension View {
    /// Wraps the view in a DSContainer
    func container(
        maxWidth: CGFloat? = nil,
        padding: CGFloat = DesignTokens.Spacing.lg,
        background: Color? = nil
    ) -> some View {
        DSContainer(maxWidth: maxWidth, padding: padding, background: background) {
            self
        }
    }

    /// Wraps the view in a DSSection
    func section(
        title: String? = nil,
        footer: String? = nil,
        padding: CGFloat = DesignTokens.Spacing.md
    ) -> some View {
        DSSection(title: title, footer: footer, padding: padding) {
            self
        }
    }
}

// MARK: - Previews

#Preview("Layout Helpers - Stacks") {
    VStack(spacing: DesignTokens.Spacing.xl) {
        DSVStack(spacing: DesignTokens.Spacing.sm) {
            Text("VStack with")
            Text("Design System")
            Text("Spacing")
        }
        .padding()
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(DesignTokens.CornerRadius.md)

        DSHStack(spacing: DesignTokens.Spacing.md) {
            Text("HStack")
            Text("with")
            Text("spacing")
        }
        .padding()
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(DesignTokens.CornerRadius.md)
    }
    .padding()
    .background(AppTheme.background)
}

#Preview("Layout Helpers - Grid") {
    DSScrollView {
        DSGrid(columns: 3, spacing: DesignTokens.Spacing.md) {
            ForEach(0..<12) { index in
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                    .fill(AppTheme.accent.opacity(0.2))
                    .frame(height: 100)
                    .overlay(
                        Text("\(index + 1)")
                            .font(DesignTokens.Typography.headline)
                            .foregroundColor(AppTheme.textPrimary)
                    )
            }
        }
        .padding()
    }
    .frame(height: 400)
    .background(AppTheme.background)
}

#Preview("Layout Helpers - Section") {
    DSScrollView {
        VStack(spacing: DesignTokens.Spacing.lg) {
            DSSection(
                title: "User Settings",
                footer: "These settings apply to your user account"
            ) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    Text("Name: John Doe")
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(AppTheme.textPrimary)

                    Text("Email: john@example.com")
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(AppTheme.textPrimary)

                    Text("Role: Developer")
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(AppTheme.textPrimary)
                }
            }

            DSSection(title: "Notifications") {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    HStack {
                        Text("Email Notifications")
                        Spacer()
                        Text("Enabled")
                            .foregroundColor(AppTheme.success)
                    }

                    HStack {
                        Text("Push Notifications")
                        Spacer()
                        Text("Disabled")
                            .foregroundColor(AppTheme.textMuted)
                    }
                }
            }

            DSSection {
                Text("Section without title or footer")
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(AppTheme.textPrimary)
            }
        }
        .padding()
    }
    .frame(height: 500)
    .background(AppTheme.background)
}

#Preview("Layout Helpers - Container") {
    DSContainer(maxWidth: 600, background: AppTheme.backgroundSecondary) {
        VStack(spacing: DesignTokens.Spacing.md) {
            Text("Centered Container")
                .font(DesignTokens.Typography.title2)
                .foregroundColor(AppTheme.textPrimary)

            Text("This container has a max width of 600 and will center itself")
                .font(DesignTokens.Typography.body)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)

            DSButton(variant: .primary) {
                print("Button clicked")
            } label: {
                Text("Action Button")
            }
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(AppTheme.background)
}

#Preview("Layout Helpers - Lazy Stacks") {
    DSScrollView {
        DSLazyVStack(spacing: DesignTokens.Spacing.sm) {
            ForEach(0..<50) { index in
                HStack {
                    Text("Item \(index)")
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(AppTheme.textPrimary)

                    Spacer()

                    DSBadge(
                        text: "\(index)",
                        style: .primary
                    )
                }
                .padding(DesignTokens.Spacing.md)
                .background(AppTheme.backgroundSecondary)
                .cornerRadius(DesignTokens.CornerRadius.md)
            }
        }
        .padding()
    }
    .frame(height: 400)
    .background(AppTheme.background)
}
