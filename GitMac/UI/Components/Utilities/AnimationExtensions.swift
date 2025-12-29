//
//  AnimationExtensions.swift
//  GitMac
//
//  Created on 28/12/2025.
//  Atomic Design System - Utilities: Animation Extensions and Presets
//

import SwiftUI

// MARK: - Animation Presets

extension Animation {
    /// Design System animation presets
    enum DSPreset {
        case instant, fast, normal, slow
        case spring, bouncy, smooth
        case easeIn, easeOut, easeInOut

        var animation: Animation {
            switch self {
            case .instant:
                return .easeInOut(duration: DesignTokens.Animation.instant)
            case .fast:
                return .easeInOut(duration: DesignTokens.Animation.fast)
            case .normal:
                return .easeInOut(duration: DesignTokens.Animation.normal)
            case .slow:
                return .easeInOut(duration: DesignTokens.Animation.slow)
            case .spring:
                return DesignTokens.Animation.spring
            case .bouncy:
                return .spring(response: 0.4, dampingFraction: 0.6)
            case .smooth:
                return .spring(response: 0.5, dampingFraction: 0.8)
            case .easeIn:
                return .easeIn(duration: DesignTokens.Animation.normal)
            case .easeOut:
                return .easeOut(duration: DesignTokens.Animation.normal)
            case .easeInOut:
                return .easeInOut(duration: DesignTokens.Animation.normal)
            }
        }
    }

    /// Quick access to Design System preset
    static func ds(_ preset: DSPreset) -> Animation {
        preset.animation
    }
}

// MARK: - Transition Presets

extension AnyTransition {
    /// Fade in transition
    static var fadeIn: AnyTransition {
        .opacity
    }

    /// Fade out transition
    static var fadeOut: AnyTransition {
        .opacity
    }

    /// Slide in from edge
    static func slideIn(from edge: Edge) -> AnyTransition {
        .move(edge: edge)
    }

    /// Slide out to edge
    static func slideOut(to edge: Edge) -> AnyTransition {
        .move(edge: edge)
    }

    /// Scale in transition
    static var scaleIn: AnyTransition {
        .scale(scale: 0.8).combined(with: .opacity)
    }

    /// Scale out transition
    static var scaleOut: AnyTransition {
        .scale(scale: 1.2).combined(with: .opacity)
    }

    /// Pop transition (scale + fade)
    static var pop: AnyTransition {
        .scale(scale: 0.5, anchor: .center).combined(with: .opacity)
    }

    /// Push transition (scale from edge + fade)
    static func push(from edge: Edge) -> AnyTransition {
        let offset: CGSize
        switch edge {
        case .top: offset = CGSize(width: 0, height: -100)
        case .bottom: offset = CGSize(width: 0, height: 100)
        case .leading: offset = CGSize(width: -100, height: 0)
        case .trailing: offset = CGSize(width: 100, height: 0)
        }

        return .offset(offset).combined(with: .opacity)
    }

    /// Asymmetric slide transition (slide in from one edge, slide out to another)
    static func slide(from: Edge, to: Edge) -> AnyTransition {
        .asymmetric(
            insertion: .move(edge: from).combined(with: .opacity),
            removal: .move(edge: to).combined(with: .opacity)
        )
    }

    /// Blur transition
    static var blur: AnyTransition {
        .modifier(
            active: BlurModifier(radius: 10),
            identity: BlurModifier(radius: 0)
        )
    }
}

// MARK: - View Animation Extensions

extension View {
    /// Fade in with default animation
    func fadeIn(duration: Double = DesignTokens.Animation.normal) -> some View {
        self
            .opacity(1)
            .transition(.fadeIn)
            .animation(.easeInOut(duration: duration), value: UUID())
    }

    /// Slide in from edge
    func slideIn(
        from edge: Edge = .bottom,
        duration: Double = DesignTokens.Animation.normal
    ) -> some View {
        self
            .transition(.slideIn(from: edge))
            .animation(.easeInOut(duration: duration), value: UUID())
    }

    /// Scale in with fade
    func scaleIn(duration: Double = DesignTokens.Animation.normal) -> some View {
        self
            .transition(.scaleIn)
            .animation(.spring(response: duration, dampingFraction: 0.7), value: UUID())
    }

    /// Pop in animation
    func popIn(duration: Double = DesignTokens.Animation.fast) -> some View {
        self
            .transition(.pop)
            .animation(.spring(response: duration, dampingFraction: 0.6), value: UUID())
    }

    /// Animated appearance
    func animatedAppearance(
        delay: Double = 0,
        duration: Double = DesignTokens.Animation.normal
    ) -> some View {
        self
            .opacity(1)
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
            .animation(
                .easeInOut(duration: duration).delay(delay),
                value: UUID()
            )
    }

    /// Shake animation for errors
    func shake(offset: CGFloat = 10) -> some View {
        modifier(ShakeEffect(offset: offset))
    }

    /// Pulse animation
    func pulse(scale: CGFloat = 1.1, duration: Double = 1.0) -> some View {
        modifier(PulseEffect(scale: scale, duration: duration))
    }

    /// Wiggle animation
    func wiggle(angle: Double = 5, duration: Double = 0.5) -> some View {
        modifier(WiggleEffect(angle: angle, duration: duration))
    }

    /// Bounce animation
    func bounce(height: CGFloat = 20, duration: Double = 0.6) -> some View {
        modifier(BounceEffect(height: height, duration: duration))
    }

    /// Rotate continuously
    func rotateInfinitely(duration: Double = 2.0) -> some View {
        modifier(RotateEffect(duration: duration))
    }
}

// MARK: - Animation Effect Modifiers

struct ShakeEffect: ViewModifier {
    let offset: CGFloat
    @State private var shakeOffset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: shakeOffset)
            .onAppear {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.2)) {
                    shakeOffset = offset
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.2)) {
                        shakeOffset = -offset
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                        shakeOffset = 0
                    }
                }
            }
    }
}

struct PulseEffect: ViewModifier {
    let scale: CGFloat
    let duration: Double
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? scale : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

struct WiggleEffect: ViewModifier {
    let angle: Double
    let duration: Double
    @State private var isWiggling = false

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(isWiggling ? angle : -angle))
            .onAppear {
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    isWiggling = true
                }
            }
    }
}

struct BounceEffect: ViewModifier {
    let height: CGFloat
    let duration: Double
    @State private var offset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(y: offset)
            .onAppear {
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    offset = -height
                }
            }
    }
}

struct RotateEffect: ViewModifier {
    let duration: Double
    @State private var rotation: Double = 0

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

struct BlurModifier: ViewModifier {
    let radius: CGFloat

    func body(content: Content) -> some View {
        content.blur(radius: radius)
    }
}

// MARK: - Staggered Animation Helper

extension View {
    /// Applies staggered animation to children
    func staggeredAnimation(
        index: Int,
        total: Int,
        delay: Double = 0.1,
        duration: Double = DesignTokens.Animation.normal
    ) -> some View {
        let calculatedDelay = Double(index) * delay
        return self
            .opacity(1)
            .transition(.opacity.combined(with: .move(edge: .top)))
            .animation(
                .easeInOut(duration: duration).delay(calculatedDelay),
                value: UUID()
            )
    }
}

// MARK: - Conditional Animation Helper

extension View {
    /// Applies animation only when condition is true
    func animate(
        if condition: Bool,
        using animation: Animation = .default,
        value: some Equatable
    ) -> some View {
        self.animation(condition ? animation : nil, value: value)
    }
}

// MARK: - Previews

#Preview("Animation Presets") {
    AnimationPresetsPreview()
}

private struct AnimationPresetsPreview: View {
    @State private var showBoxes = false

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            DSButton(variant: .primary) {
                withAnimation {
                    showBoxes.toggle()
                }
            } label: {
                Text(showBoxes ? "Hide" : "Show")
            }

            if showBoxes {
                HStack(spacing: DesignTokens.Spacing.md) {
                    AnimationBox(title: "Fade", transition: .fadeIn)
                    AnimationBox(title: "Scale", transition: .scaleIn)
                    AnimationBox(title: "Slide", transition: .slideIn(from: .bottom))
                    AnimationBox(title: "Pop", transition: .pop)
                }
            }
        }
        .padding()
        .background(AppTheme.background)
    }
}

private struct AnimationBox: View {
    let title: String
    let transition: AnyTransition

    var body: some View {
        Text(title)
            .font(DesignTokens.Typography.caption)
            .foregroundColor(AppTheme.textPrimary)
            .padding()
            .frame(width: 80, height: 80)
            .background(AppTheme.accent.opacity(0.2))
            .cornerRadius(DesignTokens.CornerRadius.md)
            .transition(transition)
    }
}

#Preview("Shake Effect") {
    ShakeEffectPreview()
}

private struct ShakeEffectPreview: View {
    @State private var shouldShake = false

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                .fill(AppTheme.error.opacity(0.2))
                .frame(width: 200, height: 100)
                .overlay(
                    Text("Error!")
                        .font(DesignTokens.Typography.headline)
                        .foregroundColor(AppTheme.error)
                )
                .shake(offset: shouldShake ? 10 : 0)

            DSButton(variant: .danger) {
                shouldShake.toggle()
            } label: {
                Text("Shake!")
            }
        }
        .padding()
        .background(AppTheme.background)
    }
}

#Preview("Pulse Effect") {
    PulseEffectPreview()
}

private struct PulseEffectPreview: View {
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            Circle()
                .fill(AppTheme.success)
                .frame(width: 60, height: 60)
                .pulse(scale: 1.2, duration: 1.0)

            Text("Pulsing Animation")
                .font(DesignTokens.Typography.body)
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding()
        .background(AppTheme.background)
    }
}

#Preview("Wiggle Effect") {
    WiggleEffectPreview()
}

private struct WiggleEffectPreview: View {
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            DSIcon("bell.fill", size: .xl, color: AppTheme.warning)
                .wiggle(angle: 15, duration: 0.3)

            Text("Wiggling Notification")
                .font(DesignTokens.Typography.body)
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding()
        .background(AppTheme.background)
    }
}

#Preview("Bounce Effect") {
    BounceEffectPreview()
}

private struct BounceEffectPreview: View {
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                .fill(AppTheme.accent)
                .frame(width: 80, height: 80)
                .bounce(height: 30, duration: 0.8)

            Text("Bouncing Box")
                .font(DesignTokens.Typography.body)
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding()
        .frame(height: 300)
        .background(AppTheme.background)
    }
}

#Preview("Rotate Effect") {
    RotateEffectPreview()
}

private struct RotateEffectPreview: View {
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            DSIcon("arrow.clockwise", size: .xl, color: AppTheme.info)
                .rotateInfinitely(duration: 2.0)

            Text("Rotating Icon")
                .font(DesignTokens.Typography.body)
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding()
        .background(AppTheme.background)
    }
}

#Preview("Staggered Animation") {
    StaggeredAnimationPreview()
}

private struct StaggeredAnimationPreview: View {
    @State private var showItems = false

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            DSButton(variant: .primary) {
                withAnimation {
                    showItems.toggle()
                }
            } label: {
                Text(showItems ? "Hide Items" : "Show Items")
            }

            if showItems {
                DSVStack(spacing: DesignTokens.Spacing.md) {
                    ForEach(0..<5) { index in
                        HStack {
                            Text("Item \(index + 1)")
                                .font(DesignTokens.Typography.body)
                                .foregroundColor(AppTheme.textPrimary)

                            Spacer()

                            DSIcon("checkmark.circle.fill", size: .md, color: AppTheme.success)
                        }
                        .padding()
                        .background(AppTheme.backgroundSecondary)
                        .cornerRadius(DesignTokens.CornerRadius.md)
                        .staggeredAnimation(index: index, total: 5)
                    }
                }
            }
        }
        .padding()
        .frame(height: 500)
        .background(AppTheme.background)
    }
}
