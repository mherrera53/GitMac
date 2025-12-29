# GitMac Plugin Template

**30-Minute Quick Start Guide to Create a New Integration Plugin**

Version: 1.0
Last Updated: December 28, 2025

---

## Table of Contents

1. [Introduction](#introduction)
2. [30-Minute Quick Start](#30-minute-quick-start)
3. [Plugin Architecture Overview](#plugin-architecture-overview)
4. [Step-by-Step Implementation Guide](#step-by-step-implementation-guide)
5. [Complete Plugin Example](#complete-plugin-example)
6. [Best Practices](#best-practices)
7. [Testing Your Plugin](#testing-your-plugin)
8. [Troubleshooting](#troubleshooting)
9. [Advanced Topics](#advanced-topics)

---

## Introduction

The GitMac Plugin System enables you to create new integrations (GitHub, GitLab, Jira, Linear, etc.) in under 30 minutes using a standardized, type-safe architecture.

### What You'll Build

A fully functional integration plugin with:
- Authentication flow with persistent credentials
- Data loading and refresh capabilities
- Consistent UI using the Design System
- Error handling and loading states
- Settings panel

### Prerequisites

- Basic knowledge of Swift and SwiftUI
- Familiarity with async/await patterns
- Understanding of MVVM architecture
- Access to the API documentation for your integration service

---

## 30-Minute Quick Start

**Time Breakdown:**
- 5 min: Create plugin structure files
- 10 min: Implement ViewModel with API calls
- 10 min: Build ContentView UI
- 5 min: Register plugin and test

### Quick Checklist

```
□ Create 4 files in GitMac/Features/YourService/
   □ YourServicePlugin.swift
   □ YourServiceViewModel.swift
   □ YourServiceContentView.swift
   □ YourServiceModels.swift

□ Implement IntegrationPlugin protocol
□ Implement IntegrationViewModel protocol
□ Build UI using DSIntegrationPanel
□ Register plugin in GitMacApp.swift
□ Test authentication and data loading
```

---

## Plugin Architecture Overview

### Core Components

```
GitMac/
├── Core/
│   └── PluginSystem/
│       ├── IntegrationPlugin.swift      # Protocol for plugins
│       ├── IntegrationViewModel.swift   # Protocol for ViewModels
│       └── PluginRegistry.swift         # Central registry
├── Features/
│   └── YourService/
│       ├── YourServicePlugin.swift      # Plugin implementation
│       ├── YourServiceViewModel.swift   # ViewModel (data + logic)
│       ├── YourServiceContentView.swift # UI view
│       └── YourServiceModels.swift      # Data models
└── UI/
    └── Components/
        └── Organisms/
            └── Integration/
                ├── DSIntegrationPanel.swift  # Generic panel UI
                ├── DSLoginPrompt.swift       # Generic login form
                └── DSSettingsSheet.swift     # Generic settings
```

### Protocol-Driven Design

```swift
// 1. IntegrationPlugin - Factory for creating plugin instances
protocol IntegrationPlugin {
    var id: String { get }
    var name: String { get }
    var icon: String { get }
    var iconColor: Color { get }

    associatedtype ViewModel: IntegrationViewModel
    associatedtype ContentView: View

    func makeViewModel() -> ViewModel
    func makeContentView(viewModel: ViewModel) -> ContentView
}

// 2. IntegrationViewModel - Data and business logic
@MainActor
protocol IntegrationViewModel: ObservableObject {
    var isAuthenticated: Bool { get }
    var isLoading: Bool { get }
    var error: String? { get }

    func authenticate() async throws
    func refresh() async throws
}
```

### Benefits

- **Consistency:** All plugins use the same UI patterns
- **Type Safety:** Compile-time guarantees via protocols
- **Decoupled:** Plugins are independent and composable
- **Testable:** ViewModels can be mocked easily
- **Fast:** Create new integration in 30 minutes

---

## Step-by-Step Implementation Guide

### Step 1: Create Plugin Structure (5 minutes)

#### 1.1 Create Directory

```bash
mkdir -p GitMac/Features/YourService
```

#### 1.2 Create Required Files

Create these 4 files:

1. **YourServicePlugin.swift** - Plugin definition
2. **YourServiceViewModel.swift** - Business logic
3. **YourServiceContentView.swift** - UI
4. **YourServiceModels.swift** - Data models

---

### Step 2: Define Data Models (5 minutes)

**File:** `GitMac/Features/YourService/YourServiceModels.swift`

```swift
//
//  YourServiceModels.swift
//  GitMac
//
//  Created on 2025-12-28.
//  Data models for YourService integration
//

import Foundation

// MARK: - Your Service Models

/// Example: Issue/Ticket/Task model
struct YourServiceItem: Identifiable, Codable {
    let id: String
    let title: String
    let description: String?
    let status: String?
    let priority: Int?
    let url: String?
    let createdAt: Date?
    let updatedAt: Date?
}

/// Example: Project/Repository model
struct YourServiceProject: Identifiable, Codable {
    let id: String
    let name: String
    let key: String
}

// MARK: - API Response Models

struct YourServiceAPIResponse: Codable {
    let items: [YourServiceItem]
    let total: Int
}
```

**Tips:**
- Make models `Identifiable` for SwiftUI lists
- Make models `Codable` for JSON parsing
- Use optional properties for fields that might be missing
- Add helper computed properties for UI logic

---

### Step 3: Implement ViewModel (10 minutes)

**File:** `GitMac/Features/YourService/YourServiceViewModel.swift`

```swift
//
//  YourServiceViewModel.swift
//  GitMac
//
//  Created on 2025-12-28.
//  ViewModel for YourService integration
//

import Foundation

@MainActor
class YourServiceViewModel: ObservableObject, IntegrationViewModel {

    // MARK: - IntegrationViewModel Protocol Requirements

    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var error: String?

    // MARK: - Service-Specific State

    @Published var items: [YourServiceItem] = []
    @Published var projects: [YourServiceProject] = []
    @Published var selectedProjectId: String?

    // MARK: - Private Properties

    private let apiBaseURL = "https://api.yourservice.com"
    private var accessToken: String?

    // MARK: - Initialization

    init() {
        // Check if user is already authenticated
        Task { [weak self] in
            guard let self = self else { return }

            // Try to load stored credentials
            if let token = try? await KeychainManager.shared.getYourServiceToken() {
                self.accessToken = token
                await MainActor.run { [weak self] in
                    self?.isAuthenticated = true
                }

                // Auto-load initial data
                try? await self.refresh()
            }
        }
    }

    // MARK: - IntegrationViewModel Protocol Implementation

    func authenticate() async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }

        // TODO: Implement your authentication flow
        // Example: OAuth, API key, username/password, etc.

        // For this example, we'll assume token is set externally
        // and we just need to validate it
        guard let token = accessToken else {
            throw YourServiceError.noCredentials
        }

        // Validate credentials by making a test API call
        let url = URL(string: "\(apiBaseURL)/user")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw YourServiceError.authenticationFailed
        }

        // Save credentials
        try await KeychainManager.shared.setYourServiceToken(token)

        isAuthenticated = true

        // Load initial data
        try await refresh()
    }

    func refresh() async throws {
        guard isAuthenticated else { return }

        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            // Load projects first
            try await loadProjects()

            // Load items for selected project
            if let projectId = selectedProjectId {
                try await loadItems(projectId: projectId)
            } else {
                try await loadAllItems()
            }
        } catch {
            self.error = error.localizedDescription
            throw error
        }
    }

    // MARK: - Service-Specific Methods

    func loadProjects() async throws {
        guard let token = accessToken else {
            throw YourServiceError.noCredentials
        }

        let url = URL(string: "\(apiBaseURL)/projects")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let decoder = JSONDecoder()
        projects = try decoder.decode([YourServiceProject].self, from: data)
    }

    func loadItems(projectId: String) async throws {
        guard let token = accessToken else {
            throw YourServiceError.noCredentials
        }

        let url = URL(string: "\(apiBaseURL)/projects/\(projectId)/items")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(YourServiceAPIResponse.self, from: data)
        items = response.items
    }

    func loadAllItems() async throws {
        guard let token = accessToken else {
            throw YourServiceError.noCredentials
        }

        let url = URL(string: "\(apiBaseURL)/items")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(YourServiceAPIResponse.self, from: data)
        items = response.items
    }

    func login(apiKey: String) async throws {
        self.accessToken = apiKey
        try await authenticate()
    }

    func logout() {
        Task { [weak self] in
            try? await KeychainManager.shared.deleteYourServiceToken()
        }
        isAuthenticated = false
        accessToken = nil
        items = []
        projects = []
    }
}

// MARK: - Errors

enum YourServiceError: LocalizedError {
    case noCredentials
    case authenticationFailed
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .noCredentials:
            return "No credentials found. Please log in."
        case .authenticationFailed:
            return "Authentication failed. Please check your credentials."
        case .invalidResponse:
            return "Invalid response from server."
        }
    }
}
```

**Key Points:**
- Always use `@MainActor` for ViewModels that publish to UI
- Use `[weak self]` in Task closures to prevent retain cycles
- Handle errors gracefully and set `error` property
- Store credentials securely in Keychain
- Auto-load data after successful authentication

---

### Step 4: Build ContentView (10 minutes)

**File:** `GitMac/Features/YourService/YourServiceContentView.swift`

```swift
//
//  YourServiceContentView.swift
//  GitMac
//
//  Created on 2025-12-28.
//  Content View for YourService integration
//

import SwiftUI

/// Content view for YourService integration
/// Displays project selector and items list
struct YourServiceContentView: View {
    @ObservedObject var viewModel: YourServiceViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Project selector (if applicable)
            if !viewModel.projects.isEmpty {
                HStack(spacing: DesignTokens.Spacing.md) {
                    DSIcon("folder.fill", size: .sm, color: AppTheme.textSecondary)

                    Picker("", selection: $viewModel.selectedProjectId) {
                        Text("All Projects").tag(nil as String?)
                        ForEach(viewModel.projects) { project in
                            Text(project.name).tag(project.id as String?)
                        }
                    }
                    .labelsHidden()
                }
                .padding(DesignTokens.Spacing.md)
                .background(AppTheme.backgroundSecondary)

                DSDivider()
            }

            // Content states
            if viewModel.isLoading {
                DSLoadingState(message: "Loading items...")
            } else if viewModel.items.isEmpty {
                DSEmptyState(
                    icon: "tray",
                    title: "No Items",
                    description: "No items found for this project"
                )
            } else {
                YourServiceItemsList(items: viewModel.items)
            }
        }
        .onChange(of: viewModel.selectedProjectId) { _, newId in
            Task {
                if let id = newId {
                    try? await viewModel.loadItems(projectId: id)
                } else {
                    try? await viewModel.loadAllItems()
                }
            }
        }
    }
}

// MARK: - Items List

struct YourServiceItemsList: View {
    let items: [YourServiceItem]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(items) { item in
                    YourServiceItemRow(item: item)
                }
            }
            .padding(8)
        }
    }
}

// MARK: - Item Row

struct YourServiceItemRow: View {
    let item: YourServiceItem

    var body: some View {
        PanelIssueRow(
            identifier: item.id,
            title: item.title,
            leadingIcon: {
                // Custom icon based on priority or status
                Circle()
                    .fill(priorityColor)
                    .frame(width: 8, height: 8)
            },
            statusBadge: {
                if let status = item.status {
                    StatusBadge(text: status, color: statusColor(status))
                }
            },
            metadata: {
                if let url = item.url {
                    Link(destination: URL(string: url)!) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textMuted)
                    }
                    .help("Open in YourService")
                }
            },
            onInsert: {
                // Insert reference to commit message
                NotificationCenter.default.post(
                    name: .insertYourServiceRef,
                    object: nil,
                    userInfo: ["id": item.id, "title": item.title]
                )
            }
        )
    }

    private var priorityColor: Color {
        switch item.priority {
        case 1: return AppTheme.error      // Highest
        case 2: return AppTheme.warning    // High
        case 3: return Color.yellow        // Medium
        case 4: return AppTheme.accent     // Low
        default: return AppTheme.textSecondary
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "done", "closed": return AppTheme.success
        case "in progress", "active": return AppTheme.accent
        case "blocked": return AppTheme.error
        default: return AppTheme.textSecondary
        }
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let insertYourServiceRef = Notification.Name("insertYourServiceRef")
}
```

**Design System Components Used:**
- `DSIcon` - Icons with standard sizes
- `DSDivider` - Horizontal divider
- `DSLoadingState` - Loading spinner with message
- `DSEmptyState` - Empty state with icon, title, description
- `PanelIssueRow` - Standard row for issues/tasks
- `StatusBadge` - Status badge with color
- `AppTheme.*` - Theme colors (NEVER hardcode colors)
- `DesignTokens.Spacing.*` - Standard spacing (NEVER hardcode padding)

---

### Step 5: Create Plugin Definition (3 minutes)

**File:** `GitMac/Features/YourService/YourServicePlugin.swift`

```swift
//
//  YourServicePlugin.swift
//  GitMac
//
//  Created on 2025-12-28.
//  Plugin System - YourService Integration Plugin
//

import SwiftUI

/// YourService integration plugin
/// Provides access to YourService projects and items
struct YourServicePlugin: IntegrationPlugin {
    let id = "yourservice"
    let name = "YourService"
    let icon = "star.fill"  // Use appropriate SF Symbol
    let iconColor = Color.blue  // Use your service's brand color

    typealias ViewModel = YourServiceViewModel
    typealias ContentView = YourServiceContentView

    func makeViewModel() -> YourServiceViewModel {
        YourServiceViewModel()
    }

    func makeContentView(viewModel: YourServiceViewModel) -> YourServiceContentView {
        YourServiceContentView(viewModel: viewModel)
    }
}
```

**Tips:**
- Use a unique `id` (lowercase, no spaces)
- Choose an appropriate SF Symbol for `icon`
- Use your service's brand color for `iconColor`
- Keep it simple - this is just a factory

---

### Step 6: Register Plugin (2 minutes)

**File:** `GitMac/App/GitMacApp.swift`

Add your plugin registration in the app's `onAppear`:

```swift
import SwiftUI

@main
struct GitMacApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    registerPlugins()
                }
        }
    }

    private func registerPlugins() {
        // Existing plugins
        PluginRegistry.shared.register(NotionPlugin())
        PluginRegistry.shared.register(LinearPlugin())
        PluginRegistry.shared.register(JiraPlugin())

        // Your new plugin
        PluginRegistry.shared.register(YourServicePlugin())
    }
}
```

---

### Step 7: Add Keychain Support (5 minutes)

**File:** Add extension to `KeychainManager.swift`

```swift
// MARK: - YourService Credentials

extension KeychainManager {
    private let yourServiceTokenKey = "yourservice_token"

    func setYourServiceToken(_ token: String) async throws {
        try await set(token, forKey: yourServiceTokenKey)
    }

    func getYourServiceToken() async throws -> String? {
        try await get(forKey: yourServiceTokenKey)
    }

    func deleteYourServiceToken() async throws {
        try await delete(forKey: yourServiceTokenKey)
    }
}
```

---

## Complete Plugin Example

Here's a complete, minimal working example for a fictional "TaskTracker" service:

### TaskTrackerPlugin.swift

```swift
import SwiftUI

struct TaskTrackerPlugin: IntegrationPlugin {
    let id = "tasktracker"
    let name = "TaskTracker"
    let icon = "checklist"
    let iconColor = Color.green

    func makeViewModel() -> TaskTrackerViewModel {
        TaskTrackerViewModel()
    }

    func makeContentView(viewModel: TaskTrackerViewModel) -> TaskTrackerContentView {
        TaskTrackerContentView(viewModel: viewModel)
    }
}
```

### TaskTrackerViewModel.swift

```swift
import Foundation

@MainActor
class TaskTrackerViewModel: ObservableObject, IntegrationViewModel {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var error: String?
    @Published var tasks: [Task] = []

    private var apiKey: String?

    func authenticate() async throws {
        isLoading = true
        defer { isLoading = false }

        guard let key = apiKey else {
            throw TaskTrackerError.noCredentials
        }

        // Validate API key
        let url = URL(string: "https://api.tasktracker.com/validate")!
        var request = URLRequest(url: url)
        request.setValue(key, forHTTPHeaderField: "X-API-Key")

        let (_, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw TaskTrackerError.invalidCredentials
        }

        try await KeychainManager.shared.setTaskTrackerKey(key)
        isAuthenticated = true
        try await refresh()
    }

    func refresh() async throws {
        isLoading = true
        defer { isLoading = false }

        let url = URL(string: "https://api.tasktracker.com/tasks")!
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        let (data, _) = try await URLSession.shared.data(for: request)
        tasks = try JSONDecoder().decode([Task].self, from: data)
    }

    func login(apiKey: String) async throws {
        self.apiKey = apiKey
        try await authenticate()
    }
}

struct Task: Identifiable, Codable {
    let id: String
    let title: String
    let status: String
}

enum TaskTrackerError: LocalizedError {
    case noCredentials
    case invalidCredentials

    var errorDescription: String? {
        switch self {
        case .noCredentials: return "No API key provided"
        case .invalidCredentials: return "Invalid API key"
        }
    }
}
```

### TaskTrackerContentView.swift

```swift
import SwiftUI

struct TaskTrackerContentView: View {
    @ObservedObject var viewModel: TaskTrackerViewModel

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                DSLoadingState(message: "Loading tasks...")
            } else if viewModel.tasks.isEmpty {
                DSEmptyState(
                    icon: "tray",
                    title: "No Tasks",
                    description: "You have no tasks"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(viewModel.tasks) { task in
                            TaskRow(task: task)
                        }
                    }
                    .padding(8)
                }
            }
        }
    }
}

struct TaskRow: View {
    let task: Task

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Circle()
                .fill(AppTheme.accent)
                .frame(width: 8, height: 8)

            Text(task.title)
                .font(DesignTokens.Typography.body)
                .foregroundColor(AppTheme.textPrimary)

            Spacer()

            StatusBadge(text: task.status, color: AppTheme.success)
        }
        .padding(DesignTokens.Spacing.sm)
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(DesignTokens.CornerRadius.md)
    }
}
```

**This complete example demonstrates:**
- Protocol conformance
- API authentication
- Data loading
- Error handling
- UI with Design System components

---

## Best Practices

### 1. Always Use Design System Components

**✅ DO:**
```swift
Text("Hello")
    .font(DesignTokens.Typography.body)
    .padding(DesignTokens.Spacing.md)
    .foregroundColor(AppTheme.textPrimary)
```

**❌ DON'T:**
```swift
Text("Hello")
    .font(.system(size: 13))  // Hardcoded
    .padding(12)              // Hardcoded
    .foregroundColor(.blue)   // Hardcoded
```

### 2. Use @MainActor for ViewModels

**✅ DO:**
```swift
@MainActor
class MyViewModel: ObservableObject, IntegrationViewModel {
    @Published var items: [Item] = []
}
```

**❌ DON'T:**
```swift
class MyViewModel: ObservableObject {
    @Published var items: [Item] = []  // Will cause race conditions
}
```

### 3. Use [weak self] in Task Closures

**✅ DO:**
```swift
Task { [weak self] in
    guard let self = self else { return }
    await self.loadData()
}
```

**❌ DON'T:**
```swift
Task {
    await self.loadData()  // Memory leak
}
```

### 4. Store Credentials Securely

**✅ DO:**
```swift
try await KeychainManager.shared.setYourServiceToken(token)
```

**❌ DON'T:**
```swift
UserDefaults.standard.set(token, forKey: "token")  // Insecure!
```

### 5. Handle Errors Gracefully

**✅ DO:**
```swift
func refresh() async throws {
    isLoading = true
    error = nil
    defer { isLoading = false }

    do {
        items = try await loadItems()
    } catch {
        self.error = error.localizedDescription
        throw error
    }
}
```

**❌ DON'T:**
```swift
func refresh() async throws {
    items = try await loadItems()  // Crash on error
}
```

### 6. Use Semantic Naming

**✅ DO:**
```swift
struct JiraPlugin: IntegrationPlugin {
    let id = "jira"
    let name = "Jira"
}
```

**❌ DON'T:**
```swift
struct JiraPlugin: IntegrationPlugin {
    let id = "jp"
    let name = "J"
}
```

### 7. Provide Empty States

**✅ DO:**
```swift
if items.isEmpty {
    DSEmptyState(
        icon: "tray",
        title: "No Items",
        description: "Create your first item to get started"
    )
}
```

**❌ DON'T:**
```swift
if items.isEmpty {
    Text("Empty")  // Poor UX
}
```

### 8. Use Lazy Loading for Lists

**✅ DO:**
```swift
ScrollView {
    LazyVStack(spacing: 4) {
        ForEach(items) { item in
            ItemRow(item: item)
        }
    }
}
```

**❌ DON'T:**
```swift
ScrollView {
    VStack {  // Loads all items at once
        ForEach(items) { item in
            ItemRow(item: item)
        }
    }
}
```

---

## Testing Your Plugin

### Manual Testing Checklist

```
Authentication:
□ Fresh install - login works
□ Invalid credentials show error
□ Logout clears credentials
□ App restart remembers authentication

Data Loading:
□ Initial load works
□ Refresh button works
□ Empty state shows when no data
□ Loading state shows during fetch
□ Error state shows on network failure

UI:
□ All text uses DesignTokens.Typography.*
□ All spacing uses DesignTokens.Spacing.*
□ All colors use AppTheme.*
□ Dark mode works correctly
□ Light mode works correctly
□ No UI freezes or stutters

Performance:
□ Large lists scroll at 60fps
□ No memory leaks (check Instruments)
□ No retain cycles
```

### Unit Testing Example

```swift
import XCTest
@testable import GitMac

@MainActor
class YourServiceViewModelTests: XCTestCase {
    var viewModel: YourServiceViewModel!

    override func setUp() {
        super.setUp()
        viewModel = YourServiceViewModel()
    }

    func testInitialState() {
        XCTAssertFalse(viewModel.isAuthenticated)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
        XCTAssertTrue(viewModel.items.isEmpty)
    }

    func testAuthenticationSuccess() async throws {
        await viewModel.login(apiKey: "valid-key")
        XCTAssertTrue(viewModel.isAuthenticated)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testAuthenticationFailure() async {
        do {
            try await viewModel.login(apiKey: "invalid-key")
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertFalse(viewModel.isAuthenticated)
            XCTAssertNotNil(viewModel.error)
        }
    }

    func testRefreshLoadsData() async throws {
        viewModel.isAuthenticated = true
        try await viewModel.refresh()
        XCTAssertFalse(viewModel.items.isEmpty)
    }
}
```

---

## Troubleshooting

### Common Issues and Solutions

#### 1. "Protocol conformance error"

**Problem:** ViewModel doesn't conform to IntegrationViewModel

**Solution:**
```swift
@MainActor  // Don't forget this!
class MyViewModel: ObservableObject, IntegrationViewModel {
    @Published var isAuthenticated = false  // Required
    @Published var isLoading = false        // Required
    @Published var error: String?           // Required

    func authenticate() async throws { }    // Required
    func refresh() async throws { }         // Required
}
```

#### 2. "Type mismatch in makeContentView"

**Problem:** ContentView generic type doesn't match ViewModel

**Solution:**
```swift
struct MyPlugin: IntegrationPlugin {
    typealias ViewModel = MyViewModel      // Must match
    typealias ContentView = MyContentView  // Must match

    func makeViewModel() -> MyViewModel {  // Return type matches
        MyViewModel()
    }

    func makeContentView(viewModel: MyViewModel) -> MyContentView {
        MyContentView(viewModel: viewModel)  // Parameter type matches
    }
}
```

#### 3. "UI not updating when data changes"

**Problem:** Forgot `@MainActor` or `@Published`

**Solution:**
```swift
@MainActor  // This is required!
class MyViewModel: ObservableObject {
    @Published var items: [Item] = []  // @Published is required!
}
```

#### 4. "Keychain errors"

**Problem:** KeychainManager extension not added

**Solution:**
```swift
// Add to KeychainManager.swift
extension KeychainManager {
    func setMyServiceToken(_ token: String) async throws {
        try await set(token, forKey: "myservice_token")
    }

    func getMyServiceToken() async throws -> String? {
        try await get(forKey: "myservice_token")
    }
}
```

#### 5. "Plugin not appearing in app"

**Problem:** Plugin not registered

**Solution:**
```swift
// In GitMacApp.swift onAppear:
PluginRegistry.shared.register(MyPlugin())
```

#### 6. "Memory leak warnings"

**Problem:** Strong reference cycle in Task closure

**Solution:**
```swift
// ❌ Wrong:
Task {
    await self.loadData()
}

// ✅ Correct:
Task { [weak self] in
    guard let self = self else { return }
    await self.loadData()
}
```

#### 7. "Dark mode colors wrong"

**Problem:** Hardcoded colors instead of AppTheme

**Solution:**
```swift
// ❌ Wrong:
.foregroundColor(.blue)

// ✅ Correct:
.foregroundColor(AppTheme.accent)
```

---

## Advanced Topics

### Custom Login Prompt

If your service needs a custom login form (beyond simple API key):

```swift
struct YourServiceLoginPrompt: View {
    @ObservedObject var viewModel: YourServiceViewModel
    @State private var username = ""
    @State private var password = ""

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            DSIcon("lock.fill", size: .xl, color: AppTheme.accent)

            DSText("Login to YourService", style: .headline)

            DSTextField(
                text: $username,
                placeholder: "Username",
                icon: "person.fill"
            )

            DSSecureField(
                text: $password,
                placeholder: "Password"
            )

            DSButton(
                title: "Login",
                variant: .primary,
                isLoading: viewModel.isLoading
            ) {
                await viewModel.login(username: username, password: password)
            }
        }
        .padding(DesignTokens.Spacing.xl)
    }
}
```

### Pagination Support

For APIs with pagination:

```swift
@MainActor
class MyViewModel: ObservableObject, IntegrationViewModel {
    @Published var items: [Item] = []
    @Published var hasMore = true
    private var currentPage = 1

    func loadMore() async throws {
        guard hasMore, !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        let newItems = try await loadItems(page: currentPage)
        items.append(contentsOf: newItems)

        hasMore = !newItems.isEmpty
        currentPage += 1
    }

    func refresh() async throws {
        currentPage = 1
        hasMore = true
        items = []
        try await loadMore()
    }
}
```

### Real-time Updates

For services with webhooks or SSE:

```swift
@MainActor
class MyViewModel: ObservableObject, IntegrationViewModel {
    private var webSocketTask: URLSessionWebSocketTask?

    func startRealTimeUpdates() {
        let url = URL(string: "wss://api.yourservice.com/updates")!
        webSocketTask = URLSession.shared.webSocketTask(with: url)
        webSocketTask?.resume()
        receiveMessages()
    }

    private func receiveMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                self.handleMessage(message)
                self.receiveMessages()  // Continue listening
            case .failure(let error):
                print("WebSocket error: \(error)")
            }
        }
    }
}
```

### Settings Panel

Custom settings for your plugin:

```swift
struct YourServiceSettingsView: View {
    @ObservedObject var viewModel: YourServiceViewModel
    @State private var apiEndpoint = "https://api.yourservice.com"
    @State private var syncInterval = 60

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            DSText("Settings", style: .headline)

            DSLabeledField(
                label: "API Endpoint",
                text: $apiEndpoint
            )

            HStack {
                DSText("Sync Interval (seconds)", style: .callout)
                Spacer()
                Picker("", selection: $syncInterval) {
                    Text("30s").tag(30)
                    Text("60s").tag(60)
                    Text("120s").tag(120)
                }
                .pickerStyle(.menu)
            }

            Spacer()

            DSButton(
                title: "Logout",
                variant: .destructive
            ) {
                viewModel.logout()
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .frame(width: 400, height: 300)
    }
}
```

---

## Resources

### Documentation

- **`DESIGN_SYSTEM.md`** - Complete Design System guide
- **`STANDARDS.md`** - Development standards and anti-patterns
- **`GitMac/Core/PluginSystem/`** - Plugin system implementation

### Example Plugins to Study

1. **NotionPlugin** - Simple API key authentication
   - `GitMac/Features/Notion/`
   - Database selector pattern
   - Task list UI

2. **LinearPlugin** - OAuth authentication
   - `GitMac/Features/Linear/`
   - Team/filter selector pattern
   - Priority indicators

3. **JiraPlugin** - Complex authentication (Cloud + Server)
   - `GitMac/Features/Jira/`
   - Project selector
   - Custom login form

### Design System Components

**Location:** `GitMac/UI/Components/`

**Atoms:**
- Buttons: `DSButton`, `DSIconButton`, `DSCloseButton`
- Inputs: `DSTextField`, `DSSecureField`, `DSSearchField`
- Display: `DSIcon`, `DSText`, `DSBadge`, `DSDivider`
- Feedback: `DSLoadingState`, `DSEmptyState`, `DSErrorState`

**Molecules:**
- `DSLabeledField` - Label + Input
- `DSSearchBar` - Search with filters
- `DSStatusBadge` - Status indicator

**Organisms:**
- `DSIntegrationPanel` - Main panel wrapper
- `DSLoginPrompt` - Generic login UI
- `DSSettingsSheet` - Settings modal

### API Reference

```swift
// Plugin Protocol
protocol IntegrationPlugin {
    var id: String { get }
    var name: String { get }
    var icon: String { get }
    var iconColor: Color { get }

    associatedtype ViewModel: IntegrationViewModel
    associatedtype ContentView: View

    func makeViewModel() -> ViewModel
    func makeContentView(viewModel: ViewModel) -> ContentView
}

// ViewModel Protocol
@MainActor
protocol IntegrationViewModel: ObservableObject {
    var isAuthenticated: Bool { get }
    var isLoading: Bool { get }
    var error: String? { get }

    func authenticate() async throws
    func refresh() async throws
}

// Registry
@MainActor
class PluginRegistry {
    static let shared: PluginRegistry

    func register(_ plugin: any IntegrationPlugin)
    func plugin(withId id: String) -> (any IntegrationPlugin)?
    func allPlugins() -> [any IntegrationPlugin]
}
```

---

## Checklist: Ready to Ship

Before submitting your plugin for review:

```
Code Quality:
□ All files have header comments
□ No compiler warnings
□ No force unwraps (!) except where safe
□ No hardcoded values (fonts, colors, spacing)
□ All async methods use [weak self]
□ ViewModel has @MainActor

Functionality:
□ Authentication works
□ Logout clears credentials
□ Refresh loads data
□ Error handling works
□ Empty states display correctly
□ Loading states display correctly

Design System Compliance:
□ Uses DesignTokens.Typography.* for fonts
□ Uses DesignTokens.Spacing.* for padding/spacing
□ Uses AppTheme.* for all colors
□ Uses DesignTokens.CornerRadius.* for rounded corners
□ Uses DS* components (DSButton, DSIcon, etc.)

Testing:
□ Tested in Light mode
□ Tested in Dark mode
□ Tested with empty data
□ Tested with errors
□ Tested with slow network
□ No memory leaks (checked with Instruments)
□ Smooth scrolling (60fps on large lists)

Documentation:
□ Added KeychainManager extension
□ Registered in GitMacApp.swift
□ Updated this document if needed
```

---

## Summary

Creating a GitMac plugin in 30 minutes:

1. **Create 4 files** - Plugin, ViewModel, ContentView, Models
2. **Implement protocols** - IntegrationPlugin, IntegrationViewModel
3. **Use Design System** - DS components, DesignTokens, AppTheme
4. **Add Keychain support** - Secure credential storage
5. **Register plugin** - Add to PluginRegistry in GitMacApp
6. **Test thoroughly** - Auth, loading, errors, UI states

**Key Rules:**
- NEVER hardcode values (fonts, colors, spacing)
- ALWAYS use @MainActor on ViewModels
- ALWAYS use [weak self] in Task closures
- ALWAYS store credentials in Keychain
- ALWAYS use Design System components

---

**Questions or issues?** Check `STANDARDS.md` or reference existing plugins in `GitMac/Features/`.

**Last Updated:** December 28, 2025
**Version:** 1.0
