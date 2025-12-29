//
//  PluginRegistry.swift
//  GitMac
//
//  Created on 2025-12-28.
//  Plugin System - Central registry for integration plugins
//

import SwiftUI

/// Central registry for managing integration plugins
///
/// The PluginRegistry is a singleton that maintains a collection of all
/// registered plugins and provides methods to access them.
///
/// Usage:
/// ```swift
/// // Register a plugin (typically in App.onAppear)
/// PluginRegistry.shared.register(JiraPlugin())
///
/// // Get a specific plugin
/// if let plugin = PluginRegistry.shared.plugin(withId: "jira") {
///     let viewModel = plugin.makeViewModel()
///     let view = plugin.makeContentView(viewModel: viewModel)
/// }
///
/// // Get all plugins
/// let allPlugins = PluginRegistry.shared.allPlugins()
/// ```
@MainActor
class PluginRegistry: ObservableObject {
    /// Shared singleton instance
    static let shared = PluginRegistry()

    /// All registered plugins
    @Published private(set) var plugins: [any IntegrationPlugin] = []

    /// Private initializer to enforce singleton pattern
    private init() {}

    /// Register a new plugin
    /// - Parameter plugin: The plugin to register
    ///
    /// Note: If a plugin with the same ID is already registered, it will not be replaced.
    /// Duplicate registration is silently ignored.
    func register(_ plugin: any IntegrationPlugin) {
        // Prevent duplicate registration
        guard !plugins.contains(where: { $0.id == plugin.id }) else {
            print("⚠️ Plugin '\(plugin.id)' is already registered")
            return
        }

        plugins.append(plugin)
        print("✅ Registered plugin: \(plugin.name) (\(plugin.id))")
    }

    /// Get a plugin by its ID
    /// - Parameter id: The unique identifier of the plugin
    /// - Returns: The plugin if found, nil otherwise
    func plugin(withId id: String) -> (any IntegrationPlugin)? {
        plugins.first { $0.id == id }
    }

    /// Get all registered plugins
    /// - Returns: Array of all registered plugins
    func allPlugins() -> [any IntegrationPlugin] {
        plugins
    }

    /// Unregister a plugin by ID
    /// - Parameter id: The unique identifier of the plugin to remove
    /// - Returns: True if the plugin was found and removed, false otherwise
    @discardableResult
    func unregister(pluginWithId id: String) -> Bool {
        if let index = plugins.firstIndex(where: { $0.id == id }) {
            let plugin = plugins.remove(at: index)
            print("🗑️ Unregistered plugin: \(plugin.name) (\(plugin.id))")
            return true
        }
        return false
    }

    /// Clear all registered plugins
    ///
    /// Useful for testing or resetting the app state
    func clearAll() {
        let count = plugins.count
        plugins.removeAll()
        print("🧹 Cleared all \(count) plugins")
    }
}
