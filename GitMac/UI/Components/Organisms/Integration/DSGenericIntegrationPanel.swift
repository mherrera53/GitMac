//
//  DSGenericIntegrationPanel.swift
//  GitMac
//
//  Created on 2025-12-29.
//  Atomic Design System - Generic Integration Panel Organism
//

import SwiftUI
import Combine

/// Generic integration panel that works with any IntegrationPlugin
///
/// This component provides a standardized layout for all integration panels:
/// - UniversalResizer for height adjustment
/// - Header with plugin icon, name, and action buttons
/// - Content area with state management (login, loading, error, content)
/// - Settings sheet
///
/// The panel requires two custom views to be provided:
/// - `loginPrompt`: View shown when user is not authenticated
/// - `settingsContent`: Optional custom settings view
///
/// Usage:
/// ```swift
/// DSGenericIntegrationPanel(
///     plugin: JiraPlugin(),
///     height: $panelHeight,
///     onClose: { closePanelAction() },
///     loginPrompt: { viewModel in
///         JiraLoginPrompt(viewModel: viewModel)
///     },
///     settingsContent: { viewModel in
///         JiraSettingsContent(viewModel: viewModel)
///     }
/// )
/// ```
struct DSGenericIntegrationPanel<Plugin: IntegrationPlugin, LoginPrompt: View, SettingsContent: View>: View {
    let plugin: Plugin
    @Binding var height: CGFloat
    let onClose: () -> Void
    let loginPrompt: (Plugin.ViewModel) -> LoginPrompt
    let settingsContent: ((Plugin.ViewModel) -> SettingsContent)?

    @StateObject private var viewModel: AnyIntegrationViewModel<Plugin.ViewModel>
    @State private var showSettings = false

    init(
        plugin: Plugin,
        height: Binding<CGFloat>,
        onClose: @escaping () -> Void,
        @ViewBuilder loginPrompt: @escaping (Plugin.ViewModel) -> LoginPrompt,
        @ViewBuilder settingsContent: ((Plugin.ViewModel) -> SettingsContent)? = nil
    ) {
        self.plugin = plugin
        self._height = height
        self.onClose = onClose
        self.loginPrompt = loginPrompt
        self.settingsContent = settingsContent

        // Create ViewModel via the plugin's factory method
        let vm = plugin.makeViewModel()
        self._viewModel = StateObject(wrappedValue: AnyIntegrationViewModel(vm))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Resizer handle
            UniversalResizer(
                dimension: $height,
                minDimension: 150,
                maxDimension: 500,
                orientation: .vertical
            )

            // Panel content
            VStack(spacing: 0) {
                // Header
                headerView

                DSDivider()

                // Content area with state management
                contentArea
            }
            .background(AppTheme.background)
        }
        .frame(height: height)
        .sheet(isPresented: $showSettings) {
            settingsSheet
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // Plugin icon and name
            DSIcon(plugin.icon, size: .md, color: plugin.iconColor)

            Text(plugin.name)
                .font(DesignTokens.Typography.headline)
                .foregroundColor(AppTheme.textPrimary)

            Spacer()

            // Refresh button
            DSIconButton(
                iconName: "arrow.clockwise",
                variant: .ghost,
                size: .sm
            ) {
                try? await viewModel.refresh()
            }
            .disabled(viewModel.isLoading)

            // Settings button
            DSIconButton(
                iconName: "gear",
                variant: .ghost,
                size: .sm
            ) {
                showSettings = true
            }

            // Close button
            DSCloseButton {
                onClose()
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(AppTheme.backgroundSecondary)
    }

    // MARK: - Content Area

    @ViewBuilder
    private var contentArea: some View {
        if viewModel.isLoading && !viewModel.isAuthenticated {
            DSLoadingState(message: "Loading...")
        } else if let error = viewModel.error {
            DSErrorState(
                message: error,
                onRetry: {
                    try? await viewModel.refresh()
                }
            )
        } else if !viewModel.isAuthenticated {
            // Show custom login prompt provided by the integration
            loginPrompt(viewModel.base)
        } else {
            // Show the plugin's content view
            AnyView(plugin.makeContentView(viewModel: viewModel.base))
        }
    }

    // MARK: - Settings Sheet

    @ViewBuilder
    private var settingsSheet: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("\(plugin.name) Settings")
                    .font(DesignTokens.Typography.headline)
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()

                Button {
                    showSettings = false
                } label: {
                    Image(systemName: "xmark")
                        .font(DesignTokens.Typography.callout)
                        .foregroundColor(AppTheme.textMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(DesignTokens.Spacing.lg)
            .background(AppTheme.toolbar)

            Rectangle().fill(AppTheme.border).frame(height: 1)

            // Custom settings content if provided, otherwise show default
            if let settingsContent = settingsContent {
                settingsContent(viewModel.base)
            } else {
                defaultSettingsContent
            }
        }
        .frame(width: 350, height: 200)
        .background(AppTheme.panel)
    }

    // MARK: - Default Settings Content

    private var defaultSettingsContent: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            if viewModel.isAuthenticated {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppTheme.success)
                    Text("Connected to \(plugin.name)")
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(AppTheme.textPrimary)
                }
            } else {
                Text("Not connected to \(plugin.name)")
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()
        }
        .padding(DesignTokens.Spacing.lg)
    }
}

// MARK: - ViewModel Type Eraser

/// Type-erased wrapper for IntegrationViewModel to work with SwiftUI
///
/// This allows us to use @StateObject with the generic ViewModel type
/// while maintaining ObservableObject conformance.
@MainActor
class AnyIntegrationViewModel<Base: IntegrationViewModel>: ObservableObject {
    let base: Base

    // Published properties mirror the protocol requirements
    @Published var isAuthenticated: Bool
    @Published var isLoading: Bool
    @Published var error: String?

    private var cancellables = Set<AnyCancellable>()

    init(_ base: Base) {
        self.base = base
        self.isAuthenticated = base.isAuthenticated
        self.isLoading = base.isLoading
        self.error = base.error

        // Set up bindings to keep wrapper in sync with base
        // Note: This requires the base ViewModel to use @Published properties
        base.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
            self?.isAuthenticated = base.isAuthenticated
            self?.isLoading = base.isLoading
            self?.error = base.error
        }
        .store(in: &cancellables)
    }

    func authenticate() async throws {
        try await base.authenticate()
    }

    func refresh() async throws {
        try await base.refresh()
    }
}

// MARK: - Previews
// Note: Previews require full integration setup with ViewModels and Services
