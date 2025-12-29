//
//  StateManagement.swift
//  GitMac
//
//  Created on 28/12/2025.
//  Atomic Design System - Utilities: State Management Helpers
//

import SwiftUI

// MARK: - Async State

/// Represents the state of an asynchronous operation
enum DSAsyncState<T> {
    case idle
    case loading
    case success(T)
    case failure(Error)

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var value: T? {
        if case .success(let value) = self { return value }
        return nil
    }

    var error: Error? {
        if case .failure(let error) = self { return error }
        return nil
    }
}

// MARK: - DSAsyncContent

/// Wrapper for async content with automatic loading/error/success states
struct DSAsyncContent<Content: View, LoadingView: View, ErrorView: View, EmptyView: View, T>: View {
    let state: DSAsyncState<T>
    let retry: (() async -> Void)?
    @ViewBuilder let content: (T) -> Content
    @ViewBuilder let loadingView: () -> LoadingView
    @ViewBuilder let errorView: (Error) -> ErrorView
    @ViewBuilder let emptyView: () -> EmptyView

    init(
        state: DSAsyncState<T>,
        retry: (() async -> Void)? = nil,
        @ViewBuilder content: @escaping (T) -> Content,
        @ViewBuilder loadingView: @escaping () -> LoadingView = { DSLoadingState(message: "Loading...") },
        @ViewBuilder errorView: @escaping (Error) -> ErrorView = { error in
            DSErrorState(
                message: error.localizedDescription,
                action: nil
            )
        },
        @ViewBuilder emptyView: @escaping () -> EmptyView = { DSEmptyState(message: "No data available") }
    ) where T: Collection {
        self.state = state
        self.retry = retry
        self.content = content
        self.loadingView = loadingView
        self.errorView = errorView
        self.emptyView = emptyView
    }

    init(
        state: DSAsyncState<T>,
        retry: (() async -> Void)? = nil,
        @ViewBuilder content: @escaping (T) -> Content,
        @ViewBuilder loadingView: @escaping () -> LoadingView = { DSLoadingState(message: "Loading...") },
        @ViewBuilder errorView: @escaping (Error) -> ErrorView = { error in
            DSErrorState(
                message: error.localizedDescription,
                action: nil
            )
        }
    ) where EmptyView == Never {
        self.state = state
        self.retry = retry
        self.content = content
        self.loadingView = loadingView
        self.errorView = errorView
        self.emptyView = { fatalError("Empty view not available for non-collection types") }
    }

    var body: some View {
        Group {
            switch state {
            case .idle:
                loadingView()

            case .loading:
                loadingView()

            case .success(let value):
                if let collection = value as? any Collection, collection.isEmpty {
                    emptyView()
                } else {
                    content(value)
                }

            case .failure(let error):
                if let retry = retry {
                    DSErrorState(
                        message: error.localizedDescription,
                        action: {
                            Task {
                                await retry()
                            }
                        }
                    ) as! ErrorView
                } else {
                    errorView(error)
                }
            }
        }
    }
}

// MARK: - DSStatefulView

/// View that handles loading, error, and success states
struct DSStatefulView<Content: View>: View {
    let isLoading: Bool
    let error: Error?
    let isEmpty: Bool
    let retry: (() async -> Void)?
    @ViewBuilder let content: () -> Content

    init(
        isLoading: Bool,
        error: Error? = nil,
        isEmpty: Bool = false,
        retry: (() async -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isLoading = isLoading
        self.error = error
        self.isEmpty = isEmpty
        self.retry = retry
        self.content = content
    }

    var body: some View {
        Group {
            if isLoading {
                DSLoadingState(message: "Loading...")
            } else if let error = error {
                DSErrorState(
                    message: error.localizedDescription,
                    action: retry.map { retryAction in
                        {
                            Task {
                                await retryAction()
                            }
                        }
                    }
                )
            } else if isEmpty {
                DSEmptyState(message: "No data available")
            } else {
                content()
            }
        }
    }
}

// MARK: - DSLoadableViewModel Protocol

/// Protocol for ViewModels that handle async loading states
@MainActor
protocol DSLoadableViewModel: ObservableObject {
    associatedtype DataType
    var loadingState: DSAsyncState<DataType> { get set }
    func load() async
}

extension DSLoadableViewModel {
    /// Performs async load and updates state automatically
    func performLoad(_ operation: () async throws -> DataType) async {
        loadingState = .loading

        do {
            let result = try await operation()
            loadingState = .success(result)
        } catch {
            loadingState = .failure(error)
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Wraps content in async state handler
    func asyncContent<T>(
        state: DSAsyncState<T>,
        retry: (() async -> Void)? = nil
    ) -> some View where Self == AnyView {
        DSAsyncContent(state: state, retry: retry) { value in
            self
        }
    }

    /// Wraps content in stateful view handler
    func stateful(
        isLoading: Bool,
        error: Error? = nil,
        isEmpty: Bool = false,
        retry: (() async -> Void)? = nil
    ) -> some View {
        DSStatefulView(
            isLoading: isLoading,
            error: error,
            isEmpty: isEmpty,
            retry: retry
        ) {
            self
        }
    }
}

// MARK: - Task State Manager

/// Manages the state of an async task with automatic retry
@MainActor
class DSTaskStateManager<T>: ObservableObject {
    @Published private(set) var state: DSAsyncState<T> = .idle

    private var task: Task<Void, Never>?

    /// Executes the operation and updates state
    func execute(_ operation: @escaping () async throws -> T) {
        task?.cancel()

        task = Task {
            state = .loading

            do {
                let result = try await operation()
                if !Task.isCancelled {
                    state = .success(result)
                }
            } catch {
                if !Task.isCancelled {
                    state = .failure(error)
                }
            }
        }
    }

    /// Retries the last operation
    func retry(_ operation: @escaping () async throws -> T) {
        execute(operation)
    }

    /// Cancels the current task
    func cancel() {
        task?.cancel()
        state = .idle
    }

    /// Resets to idle state
    func reset() {
        task?.cancel()
        state = .idle
    }

    deinit {
        task?.cancel()
    }
}

// MARK: - Previews

#Preview("Async Content - Success") {
    AsyncContentSuccessPreview()
}

private struct AsyncContentSuccessPreview: View {
    @State private var state: DSAsyncState<[String]> = .success(["Item 1", "Item 2", "Item 3"])

    var body: some View {
        DSAsyncContent(state: state) { items in
            DSVStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(AppTheme.textPrimary)
                        .padding()
                        .background(AppTheme.backgroundSecondary)
                        .cornerRadius(DesignTokens.CornerRadius.md)
                }
            }
            .padding()
        }
        .background(AppTheme.background)
    }
}

#Preview("Async Content - Loading") {
    AsyncContentLoadingPreview()
}

private struct AsyncContentLoadingPreview: View {
    @State private var state: DSAsyncState<[String]> = .loading

    var body: some View {
        DSAsyncContent(state: state) { items in
            DSVStack {
                ForEach(items, id: \.self) { item in
                    Text(item)
                }
            }
        }
        .frame(width: 400, height: 300)
        .background(AppTheme.background)
    }
}

#Preview("Async Content - Error") {
    AsyncContentErrorPreview()
}

private struct AsyncContentErrorPreview: View {
    @State private var state: DSAsyncState<[String]> = .failure(NSError(
        domain: "TestError",
        code: 404,
        userInfo: [NSLocalizedDescriptionKey: "Failed to load data"]
    ))

    var body: some View {
        DSAsyncContent(
            state: state,
            retry: {
                state = .loading
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                state = .success(["Item 1", "Item 2"])
            }
        ) { items in
            DSVStack {
                ForEach(items, id: \.self) { item in
                    Text(item)
                }
            }
        }
        .frame(width: 400, height: 300)
        .background(AppTheme.background)
    }
}

#Preview("Async Content - Empty") {
    AsyncContentEmptyPreview()
}

private struct AsyncContentEmptyPreview: View {
    @State private var state: DSAsyncState<[String]> = .success([])

    var body: some View {
        DSAsyncContent(state: state) { items in
            DSVStack {
                ForEach(items, id: \.self) { item in
                    Text(item)
                }
            }
        }
        .frame(width: 400, height: 300)
        .background(AppTheme.background)
    }
}

#Preview("Stateful View - Interactive") {
    StatefulViewInteractivePreview()
}

private struct StatefulViewInteractivePreview: View {
    @State private var currentState: Int = 0 // 0: loading, 1: error, 2: empty, 3: success

    private var stateNames: [String] {
        ["Loading", "Error", "Empty", "Success"]
    }

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            // State selector
            HStack(spacing: DesignTokens.Spacing.md) {
                ForEach(0..<4) { index in
                    DSButton(
                        variant: currentState == index ? .primary : .secondary,
                        size: .sm
                    ) {
                        currentState = index
                    } label: {
                        Text(stateNames[index])
                    }
                }
            }

            // Stateful content
            DSStatefulView(
                isLoading: currentState == 0,
                error: currentState == 1 ? NSError(
                    domain: "TestError",
                    code: 500,
                    userInfo: [NSLocalizedDescriptionKey: "Something went wrong"]
                ) : nil,
                isEmpty: currentState == 2,
                retry: {
                    currentState = 3
                }
            ) {
                VStack(spacing: DesignTokens.Spacing.md) {
                    Text("Success! Here's your content")
                        .font(DesignTokens.Typography.headline)
                        .foregroundColor(AppTheme.success)

                    ForEach(0..<5) { index in
                        HStack {
                            Text("Data item \(index + 1)")
                                .font(DesignTokens.Typography.body)
                                .foregroundColor(AppTheme.textPrimary)

                            Spacer()

                            DSIcon("checkmark.circle.fill", size: .md, color: AppTheme.success)
                        }
                        .padding()
                        .background(AppTheme.backgroundSecondary)
                        .cornerRadius(DesignTokens.CornerRadius.md)
                    }
                }
            }
        }
        .padding()
        .frame(width: 500, height: 500)
        .background(AppTheme.background)
    }
}

#Preview("Task State Manager") {
    TaskStateManagerPreview()
}

private struct TaskStateManagerPreview: View {
    @StateObject private var taskManager = DSTaskStateManager<[String]>()

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            DSAsyncContent(state: taskManager.state, retry: {
                await loadData()
            }) { items in
                DSVStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    ForEach(items, id: \.self) { item in
                        Text(item)
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(AppTheme.textPrimary)
                            .padding()
                            .background(AppTheme.backgroundSecondary)
                            .cornerRadius(DesignTokens.CornerRadius.md)
                    }
                }
            }

            HStack(spacing: DesignTokens.Spacing.md) {
                DSButton(variant: .primary) {
                    await loadData()
                } label: {
                    Text("Load Success")
                }

                DSButton(variant: .danger) {
                    await loadError()
                } label: {
                    Text("Load Error")
                }

                DSButton(variant: .secondary) {
                    taskManager.reset()
                } label: {
                    Text("Reset")
                }
            }
        }
        .padding()
        .frame(width: 500, height: 400)
        .background(AppTheme.background)
    }

    private func loadData() async {
        taskManager.execute {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            return ["Item 1", "Item 2", "Item 3", "Item 4"]
        }
    }

    private func loadError() async {
        taskManager.execute {
            try await Task.sleep(nanoseconds: 500_000_000)
            throw NSError(
                domain: "TestError",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "Failed to load data"]
            )
        }
    }
}
