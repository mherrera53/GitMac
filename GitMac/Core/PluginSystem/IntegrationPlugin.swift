//
//  IntegrationPlugin.swift
//  GitMac
//
//  Created on 2025-12-28.
//  Plugin System - Protocol for integration plugins
//

import SwiftUI

/// Protocol that defines a GitMac integration plugin
///
/// Conform to this protocol to create a new integration that can be
/// registered with the PluginRegistry and used throughout the app.
///
/// Example:
/// ```swift
/// struct JiraPlugin: IntegrationPlugin {
///     let id = "jira"
///     let name = "Jira"
///     let icon = "checkmark.circle.fill"
///     let iconColor = Color.blue
///
///     func makeViewModel() -> JiraViewModel {
///         JiraViewModel()
///     }
///
///     func makeContentView(viewModel: JiraViewModel) -> some View {
///         JiraContentView(viewModel: viewModel)
///     }
/// }
/// ```
protocol IntegrationPlugin {
    /// Unique identifier for the plugin
    var id: String { get }

    /// Display name for the plugin
    var name: String { get }

    /// SF Symbol name for the plugin icon
    var icon: String { get }

    /// Color for the plugin icon
    var iconColor: Color { get }

    /// The ViewModel type for this plugin
    associatedtype ViewModel: IntegrationViewModel

    /// The ContentView type for this plugin
    associatedtype ContentView: View

    /// Factory method to create a new ViewModel instance
    @MainActor func makeViewModel() -> ViewModel

    /// Factory method to create a new ContentView instance
    /// - Parameter viewModel: The ViewModel to inject into the view
    func makeContentView(viewModel: ViewModel) -> ContentView
}
