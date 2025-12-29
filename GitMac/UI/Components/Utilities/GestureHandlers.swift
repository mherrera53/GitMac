//
//  GestureHandlers.swift
//  GitMac
//
//  Created on 28/12/2025.
//  Atomic Design System - Utilities: Gesture Handler Components
//

import SwiftUI

// MARK: - Draggable Modifier

/// Makes a view draggable with visual feedback
struct DSDraggable<Data>: ViewModifier where Data: Transferable {
    let data: Data
    let preview: AnyView?
    @State private var isDragging = false

    init(data: Data, preview: AnyView? = nil) {
        self.data = data
        self.preview = preview
    }

    func body(content: Content) -> some View {
        content
            .opacity(isDragging ? 0.5 : 1.0)
            .onDrag {
                isDragging = true
                return NSItemProvider(object: data as! NSItemProviderWriting)
            } preview: {
                if let preview = preview {
                    preview
                } else {
                    content
                        .padding(DesignTokens.Spacing.sm)
                        .background(AppTheme.backgroundSecondary)
                        .cornerRadius(DesignTokens.CornerRadius.md)
                }
            }
            .onChange(of: isDragging) { _, newValue in
                if !newValue {
                    withAnimation(DesignTokens.Animation.fastEasing) {
                        isDragging = false
                    }
                }
            }
    }
}

// MARK: - Drop Target Modifier

/// Makes a view a drop target with visual feedback
struct DSDropTarget<Data>: ViewModifier where Data: Transferable {
    let onDrop: (Data) -> Bool
    @State private var isTargeted = false

    func body(content: Content) -> some View {
        content
            .background(
                isTargeted ?
                AppTheme.accent.opacity(0.1) :
                Color.clear
            )
            .overlay(
                isTargeted ?
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                    .stroke(AppTheme.accent, lineWidth: 2)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                : nil
            )
            .onDrop(of: [.text], isTargeted: $isTargeted) { providers in
                // Handle drop
                return false
            }
    }
}

// MARK: - Double Tap Modifier

/// Adds double tap gesture with haptic feedback
struct DSDoubleTappable: ViewModifier {
    let action: () -> Void
    let hapticFeedback: Bool
    @State private var lastTapTime: Date = .distantPast

    init(action: @escaping () -> Void, hapticFeedback: Bool = true) {
        self.action = action
        self.hapticFeedback = hapticFeedback
    }

    func body(content: Content) -> some View {
        content
            .onTapGesture(count: 2) {
                if hapticFeedback {
                    NSHapticFeedbackManager.defaultPerformer.perform(
                        .alignment,
                        performanceTime: .default
                    )
                }
                action()
            }
    }
}

// MARK: - Long Press Modifier

/// Adds long press gesture with visual feedback
struct DSLongPressable: ViewModifier {
    let minimumDuration: Double
    let action: () -> Void
    @State private var isPressing = false

    init(
        minimumDuration: Double = 0.5,
        action: @escaping () -> Void
    ) {
        self.minimumDuration = minimumDuration
        self.action = action
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressing ? 0.95 : 1.0)
            .gesture(
                LongPressGesture(minimumDuration: minimumDuration)
                    .onChanged { _ in
                        withAnimation(DesignTokens.Animation.fastEasing) {
                            isPressing = true
                        }
                    }
                    .onEnded { _ in
                        withAnimation(DesignTokens.Animation.fastEasing) {
                            isPressing = false
                        }
                        NSHapticFeedbackManager.defaultPerformer.perform(
                            .levelChange,
                            performanceTime: .default
                        )
                        action()
                    }
            )
    }
}

// MARK: - Swipeable Modifier

/// Makes a view swipeable with actions
struct DSSwipeable: ViewModifier {
    let leadingActions: [SwipeAction]
    let trailingActions: [SwipeAction]
    @State private var offset: CGFloat = 0
    @State private var isDragging = false

    struct SwipeAction: Identifiable {
        let id = UUID()
        let icon: String
        let color: Color
        let action: () -> Void
    }

    func body(content: Content) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background actions
                if offset > 0 {
                    // Leading actions
                    HStack(spacing: 0) {
                        ForEach(leadingActions) { action in
                            Button {
                                action.action()
                                withAnimation(DesignTokens.Animation.spring) {
                                    offset = 0
                                }
                            } label: {
                                DSIcon(action.icon, size: .md, color: .white)
                                    .frame(width: 60)
                            }
                            .frame(height: geometry.size.height)
                            .background(action.color)
                        }
                    }
                } else if offset < 0 {
                    // Trailing actions
                    HStack(spacing: 0) {
                        ForEach(trailingActions) { action in
                            Button {
                                action.action()
                                withAnimation(DesignTokens.Animation.spring) {
                                    offset = 0
                                }
                            } label: {
                                DSIcon(action.icon, size: .md, color: .white)
                                    .frame(width: 60)
                            }
                            .frame(height: geometry.size.height)
                            .background(action.color)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }

                // Main content
                content
                    .offset(x: offset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDragging = true
                                let translation = value.translation.width

                                // Limit offset based on available actions
                                if translation > 0 && !leadingActions.isEmpty {
                                    offset = min(translation, CGFloat(leadingActions.count * 60))
                                } else if translation < 0 && !trailingActions.isEmpty {
                                    offset = max(translation, -CGFloat(trailingActions.count * 60))
                                }
                            }
                            .onEnded { value in
                                isDragging = false
                                let velocity = value.predictedEndTranslation.width

                                withAnimation(DesignTokens.Animation.spring) {
                                    // Snap to actions or close
                                    if abs(offset) > 30 {
                                        // Keep open
                                        if offset > 0 {
                                            offset = CGFloat(leadingActions.count * 60)
                                        } else {
                                            offset = -CGFloat(trailingActions.count * 60)
                                        }
                                    } else {
                                        // Close
                                        offset = 0
                                    }
                                }
                            }
                    )
            }
        }
    }
}

// MARK: - Magnification Modifier

/// Adds pinch-to-zoom magnification gesture
struct DSMagnifiable: ViewModifier {
    @Binding var scale: CGFloat
    let minScale: CGFloat
    let maxScale: CGFloat

    init(
        scale: Binding<CGFloat>,
        minScale: CGFloat = 0.5,
        maxScale: CGFloat = 3.0
    ) {
        self._scale = scale
        self.minScale = minScale
        self.maxScale = maxScale
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = min(max(value, minScale), maxScale)
                    }
            )
    }
}

// MARK: - View Extensions

extension View {
    /// Makes the view draggable
    func draggable<Data: Transferable>(
        _ data: Data,
        preview: AnyView? = nil
    ) -> some View {
        modifier(DSDraggable(data: data, preview: preview))
    }

    /// Makes the view a drop target
    func dropTarget<Data: Transferable>(
        onDrop: @escaping (Data) -> Bool
    ) -> some View {
        modifier(DSDropTarget(onDrop: onDrop))
    }

    /// Adds double tap gesture
    func onDoubleTap(
        hapticFeedback: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        modifier(DSDoubleTappable(action: action, hapticFeedback: hapticFeedback))
    }

    /// Adds long press gesture
    func onLongPress(
        minimumDuration: Double = 0.5,
        action: @escaping () -> Void
    ) -> some View {
        modifier(DSLongPressable(minimumDuration: minimumDuration, action: action))
    }

    /// Makes the view swipeable with actions
    func swipeable(
        leading: [DSSwipeable.SwipeAction] = [],
        trailing: [DSSwipeable.SwipeAction] = []
    ) -> some View {
        modifier(DSSwipeable(leadingActions: leading, trailingActions: trailing))
    }

    /// Adds magnification gesture
    func magnifiable(
        scale: Binding<CGFloat>,
        minScale: CGFloat = 0.5,
        maxScale: CGFloat = 3.0
    ) -> some View {
        modifier(DSMagnifiable(scale: scale, minScale: minScale, maxScale: maxScale))
    }
}

// MARK: - Previews

#Preview("Double Tap") {
    DoubleTapPreview()
}

private struct DoubleTapPreview: View {
    @State private var tapCount = 0

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            Text("Double Tap Me!")
                .font(DesignTokens.Typography.headline)
                .foregroundColor(AppTheme.textPrimary)
                .padding(DesignTokens.Spacing.xl)
                .background(AppTheme.accent.opacity(0.2))
                .cornerRadius(DesignTokens.CornerRadius.lg)
                .onDoubleTap {
                    tapCount += 1
                }

            Text("Tapped \(tapCount) times")
                .font(DesignTokens.Typography.body)
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding()
        .background(AppTheme.background)
    }
}

#Preview("Long Press") {
    LongPressPreview()
}

private struct LongPressPreview: View {
    @State private var pressCount = 0
    @State private var isPressing = false

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            Text("Long Press Me!")
                .font(DesignTokens.Typography.headline)
                .foregroundColor(AppTheme.textPrimary)
                .padding(DesignTokens.Spacing.xl)
                .background(isPressing ? AppTheme.warning.opacity(0.3) : AppTheme.success.opacity(0.2))
                .cornerRadius(DesignTokens.CornerRadius.lg)
                .onLongPress(minimumDuration: 0.5) {
                    pressCount += 1
                }

            Text("Pressed \(pressCount) times")
                .font(DesignTokens.Typography.body)
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding()
        .background(AppTheme.background)
    }
}

#Preview("Swipeable") {
    SwipeablePreview()
}

private struct SwipeablePreview: View {
    @State private var items = ["Item 1", "Item 2", "Item 3", "Item 4"]

    var body: some View {
        DSScrollView {
            DSVStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(items, id: \.self) { item in
                    HStack {
                        Text(item)
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(AppTheme.textPrimary)

                        Spacer()
                    }
                    .padding()
                    .background(AppTheme.backgroundSecondary)
                    .cornerRadius(DesignTokens.CornerRadius.md)
                    .swipeable(
                        leading: [
                            .init(icon: "checkmark.circle.fill", color: AppTheme.success) {
                                print("Mark as done: \(item)")
                            }
                        ],
                        trailing: [
                            .init(icon: "trash.fill", color: AppTheme.error) {
                                withAnimation {
                                    items.removeAll { $0 == item }
                                }
                            }
                        ]
                    )
                }
            }
            .padding()
        }
        .frame(height: 400)
        .background(AppTheme.background)
    }
}

#Preview("Magnifiable") {
    MagnifiablePreview()
}

private struct MagnifiablePreview: View {
    @State private var scale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                .fill(
                    LinearGradient(
                        colors: [AppTheme.accent, AppTheme.success],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 200, height: 200)
                .overlay(
                    VStack {
                        DSIcon("photo.fill", size: .xl, color: .white)
                        Text("Pinch to Zoom")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(.white)
                    }
                )
                .magnifiable(scale: $scale)

            HStack(spacing: DesignTokens.Spacing.md) {
                Text("Scale: \(String(format: "%.1f", scale))x")
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(AppTheme.textSecondary)

                DSButton(variant: .secondary, size: .sm) {
                    withAnimation(DesignTokens.Animation.spring) {
                        scale = 1.0
                    }
                } label: {
                    Text("Reset")
                }
            }
        }
        .padding()
        .background(AppTheme.background)
    }
}
