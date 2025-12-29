//
//  IntegrationViewModel.swift
//  GitMac
//
//  Created on 2025-12-28.
//  Plugin System - Base protocol for integration ViewModels
//

import Foundation

/// Protocol that defines the base requirements for integration ViewModels
///
/// All plugin ViewModels must conform to this protocol to ensure
/// consistent authentication and state management patterns.
///
/// Example:
/// ```swift
/// @MainActor
/// class JiraViewModel: ObservableObject, IntegrationViewModel {
///     @Published var isAuthenticated = false
///     @Published var isLoading = false
///     @Published var error: String?
///
///     @Published var tickets: [Ticket] = []
///
///     func authenticate() async throws {
///         isLoading = true
///         defer { isLoading = false }
///         // Implement authentication logic
///         isAuthenticated = true
///     }
///
///     func refresh() async throws {
///         isLoading = true
///         defer { isLoading = false }
///         // Fetch tickets from API
///         tickets = try await fetchTickets()
///     }
/// }
/// ```
@MainActor
protocol IntegrationViewModel: ObservableObject {
    /// Whether the user is authenticated with this integration
    var isAuthenticated: Bool { get }

    /// Whether the integration is currently loading data
    var isLoading: Bool { get }

    /// Current error message, if any
    var error: String? { get }

    /// Authenticate the user with this integration
    /// - Throws: Authentication errors
    func authenticate() async throws

    /// Refresh data from the integration
    /// - Throws: Network or API errors
    func refresh() async throws
}
