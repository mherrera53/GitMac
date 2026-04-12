//
//  VisualEffectBlur.swift
//  GitMac
//
//  Created on 2025-12-29.
//  NSVisualEffectView wrapper using DesignTokens
//  NO hardcoded materials - all from tokens
//

import SwiftUI
import AppKit

/// NSVisualEffectView wrapper for macOS blur effects
/// Uses DesignTokens.Materials for all materials and blending modes
struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    let state: NSVisualEffectView.State

    /// Initialize with explicit material and blending mode
    /// - Parameters:
    ///   - material: The visual effect material
    ///   - blendingMode: How the blur blends with content
    ///   - state: The effect state (usually .active)
    init(
        material: NSVisualEffectView.Material,
        blendingMode: NSVisualEffectView.BlendingMode,
        state: NSVisualEffectView.State = DesignTokens.Materials.state
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.state = state
    }

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

// MARK: - Xcode-Style Convenience Initializers

extension VisualEffectBlur {
    /// Xcode-style toolbar blur (headerView + withinWindow)
    /// Uses DesignTokens.Materials.toolbar and toolbarBlending
    static var toolbar: VisualEffectBlur {
        VisualEffectBlur(
            material: DesignTokens.Materials.toolbar,
            blendingMode: DesignTokens.Materials.toolbarBlending
        )
    }

    /// Xcode-style bottom bar blur (titlebar + behindWindow)
    /// Uses DesignTokens.Materials.bottomBar and bottomBarBlending
    static var bottomBar: VisualEffectBlur {
        VisualEffectBlur(
            material: DesignTokens.Materials.bottomBar,
            blendingMode: DesignTokens.Materials.bottomBarBlending
        )
    }

    /// Xcode-style sidebar blur (sidebar + behindWindow)
    /// Uses DesignTokens.Materials.sidebar and sidebarBlending
    static var sidebar: VisualEffectBlur {
        VisualEffectBlur(
            material: DesignTokens.Materials.sidebar,
            blendingMode: DesignTokens.Materials.sidebarBlending
        )
    }

    /// Content background blur
    /// Uses DesignTokens.Materials.content
    static var content: VisualEffectBlur {
        VisualEffectBlur(
            material: DesignTokens.Materials.content,
            blendingMode: .withinWindow
        )
    }
}

// MARK: - Liquid Glass View Extension (macOS 26+ ready)

extension View {
    /// Apply glass effect on macOS 26+, falling back to material on older versions.
    /// Use this for toolbar, sidebar, and card backgrounds that should adopt Liquid Glass.
    ///
    /// - Parameters:
    ///   - cornerRadius: Corner radius for the glass shape
    ///   - fallbackMaterial: NSVisualEffectView material for pre-macOS 26
    ///   - fallbackBlending: Blending mode for the fallback
    /// Apply glass-style background. Uses NSVisualEffectView material.
    /// When macOS 26 SDK is available at compile time, will use native Liquid Glass.
    @ViewBuilder
    func glassBackground(
        cornerRadius: CGFloat = 0,
        fallbackMaterial: NSVisualEffectView.Material = DesignTokens.Materials.content,
        fallbackBlending: NSVisualEffectView.BlendingMode = .withinWindow
    ) -> some View {
        self.background(
            VisualEffectBlur(
                material: fallbackMaterial,
                blendingMode: fallbackBlending
            ).clipShape(.rect(cornerRadius: cornerRadius))
        )
    }

    /// Interactive glass effect for buttons and tappable elements.
    @ViewBuilder
    func interactiveGlass(
        in shape: some Shape = .rect(cornerRadius: 8),
        fallbackMaterial: NSVisualEffectView.Material = DesignTokens.Materials.content,
        fallbackBlending: NSVisualEffectView.BlendingMode = .withinWindow
    ) -> some View {
        self.background(
            VisualEffectBlur(
                material: fallbackMaterial,
                blendingMode: fallbackBlending
            ).clipShape(shape)
        )
    }
}

// MARK: - Preview

#Preview("Blur Materials") {
    VStack(spacing: 0) {
        Text("Toolbar Blur")
            .frame(height: DesignTokens.Toolbar.height)
            .frame(maxWidth: .infinity)
            .background(VisualEffectBlur.toolbar)

        Text("Bottom Bar Blur")
            .frame(height: DesignTokens.BottomBar.height)
            .frame(maxWidth: .infinity)
            .background(VisualEffectBlur.bottomBar)

        Text("Sidebar Blur")
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            .background(VisualEffectBlur.sidebar)

        Text("Content Blur")
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            .background(VisualEffectBlur.content)
    }
    .frame(width: 400)
}
