//
//  DSGenericIntegrationPanel+Examples.swift
//  GitMac
//
//  Created on 2025-12-29.
//  Examples and documentation for using DSGenericIntegrationPanel
//

import SwiftUI

// MARK: - Usage Examples

/// Example 1: Using DSGenericIntegrationPanel with Jira
///
/// Replace the existing JiraPanel.swift with:
///
/// ```swift
/// struct JiraPanel: View {
///     @Binding var height: CGFloat
///     let onClose: () -> Void
///
///     var body: some View {
///         DSGenericIntegrationPanel(
///             plugin: JiraPlugin(),
///             height: $height,
///             onClose: onClose,
///             loginPrompt: { viewModel in
///                 JiraLoginPrompt(viewModel: viewModel)
///             },
///             settingsContent: { viewModel in
///                 JiraSettingsContent(viewModel: viewModel)
///             }
///         )
///     }
/// }
/// ```
///
/// Then extract the settings content from JiraSettingsSheet into a standalone view:
///
/// ```swift
/// struct JiraSettingsContent: View {
///     @ObservedObject var viewModel: JiraViewModel
///     @Environment(\.dismiss) private var dismiss
///
///     var body: some View {
///         VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
///             if viewModel.isAuthenticated {
///                 HStack {
///                     Image(systemName: "checkmark.circle.fill")
///                         .foregroundColor(AppTheme.success)
///                     Text("Connected to Jira")
///                         .font(DesignTokens.Typography.body)
///                         .foregroundColor(AppTheme.textPrimary)
///                 }
///
///                 Button("Disconnect") {
///                     viewModel.logout()
///                     dismiss()
///                 }
///                 .foregroundColor(AppTheme.error)
///             } else {
///                 Text("Not connected to Jira")
///                     .font(DesignTokens.Typography.body)
///                     .foregroundColor(AppTheme.textSecondary)
///             }
///
///             Spacer()
///         }
///         .padding(DesignTokens.Spacing.lg)
///     }
/// }
/// ```

// MARK: - Before and After Comparison

/// BEFORE: Each integration had 3 files with duplicate code
/// - JiraPanel.swift (170+ lines)
/// - LinearPanel.swift (170+ lines)
/// - NotionPanel.swift (170+ lines)
/// - TaigaPanel.swift (170+ lines)
/// - PlannerTasksPanel.swift (170+ lines)
///
/// Common duplicated code:
/// - UniversalResizer setup
/// - Header with icon, title, buttons
/// - State management (loading, error, authenticated)
/// - Settings sheet structure
///
/// AFTER: Using DSGenericIntegrationPanel
/// - Each integration now needs only ~15-20 lines to create a panel
/// - Login prompt and settings content can be reused from existing code
/// - All state management and UI structure is centralized
/// - Easier to maintain and update consistently

// MARK: - Migration Checklist

/// To migrate an existing panel to use DSGenericIntegrationPanel:
///
/// 1. Ensure your integration has a Plugin implementation (e.g., JiraPlugin)
/// 2. Ensure your ViewModel conforms to IntegrationViewModel
/// 3. Extract the login prompt into a standalone view if needed
/// 4. Extract the settings sheet content into a standalone view
/// 5. Replace the panel implementation with DSGenericIntegrationPanel
/// 6. Keep the ContentView (e.g., JiraContentView) as-is
/// 7. Test that all functionality works (login, refresh, settings, content display)

// MARK: - Benefits

/// Benefits of using DSGenericIntegrationPanel:
///
/// 1. **Consistency**: All integration panels have the same structure and behavior
/// 2. **DRY Principle**: No more duplicated code across panels
/// 3. **Maintainability**: Bug fixes and improvements apply to all integrations
/// 4. **Design System**: Fully integrated with the Atomic Design System
/// 5. **Type Safety**: Leverages Swift generics for compile-time safety
/// 6. **Flexibility**: Custom login prompts and settings for each integration
/// 7. **Less Code**: ~85% reduction in panel implementation code

// MARK: - Advanced Usage

/// Example 2: Panel with default settings (no custom settings content)
///
/// ```swift
/// struct SimpleIntegrationPanel: View {
///     @Binding var height: CGFloat
///     let onClose: () -> Void
///
///     var body: some View {
///         DSGenericIntegrationPanel(
///             plugin: SimplePlugin(),
///             height: $height,
///             onClose: onClose,
///             loginPrompt: { viewModel in
///                 SimpleLoginPrompt(viewModel: viewModel)
///             }
///             // settingsContent omitted - will use default
///         )
///     }
/// }
/// ```

// MARK: - Testing Notes

/// To test the generic panel:
///
/// 1. Build the project to ensure no compilation errors
/// 2. Update one panel (e.g., Jira) to use the generic implementation
/// 3. Verify all functionality:
///    - Panel opens and closes correctly
///    - Resizer works as expected
///    - Login flow functions properly
///    - Content displays when authenticated
///    - Refresh button works
///    - Settings sheet opens and closes
///    - Error states display correctly
///    - Loading states work as expected
/// 4. If successful, migrate other panels one by one
/// 5. Remove old panel files after migration is complete
