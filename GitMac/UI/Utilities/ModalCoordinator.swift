import SwiftUI

/// Generic modal coordinator that replaces multiple @State modal flags
/// Centralizes modal presentation state management
@MainActor
class ModalCoordinator<State: Hashable>: ObservableObject {
    @Published var activeModal: State?

    /// Show a specific modal
    func show(_ modal: State) {
        activeModal = modal
    }

    /// Dismiss the currently active modal
    func dismiss() {
        activeModal = nil
    }

    /// Check if a specific modal is currently showing
    func isShowing(_ modal: State) -> Bool {
        activeModal == modal
    }

    /// Toggle a modal (show if dismissed, dismiss if showing)
    func toggle(_ modal: State) {
        if isShowing(modal) {
            dismiss()
        } else {
            show(modal)
        }
    }
}

// MARK: - View Extensions for Easy Modal Presentation

extension View {
    /// Present a sheet based on ModalCoordinator state for a specific modal
    /// Usage:
    /// .modalSheet(coordinator: modalCoordinator, for: .newBranch) {
    ///     NewBranchSheet()
    /// }
    func modalSheet<State: Hashable, Content: View>(
        coordinator: ModalCoordinator<State>,
        for state: State,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        sheet(isPresented: Binding(
            get: { coordinator.isShowing(state) },
            set: { if !$0 { coordinator.dismiss() } }
        )) {
            content()
        }
    }

    /// Present an alert based on ModalCoordinator state
    func modalAlert<State: Hashable>(
        coordinator: ModalCoordinator<State>,
        for state: State,
        title: String,
        @ViewBuilder actions: @escaping () -> some View,
        @ViewBuilder message: @escaping () -> some View = { EmptyView() }
    ) -> some View {
        alert(
            title,
            isPresented: Binding(
                get: { coordinator.isShowing(state) },
                set: { if !$0 { coordinator.dismiss() } }
            ),
            actions: actions,
            message: message
        )
    }

    /// Present a confirmation dialog based on ModalCoordinator state
    func modalConfirmationDialog<State: Hashable>(
        coordinator: ModalCoordinator<State>,
        for state: State,
        title: String,
        @ViewBuilder actions: @escaping () -> some View,
        @ViewBuilder message: @escaping () -> some View = { EmptyView() }
    ) -> some View {
        confirmationDialog(
            title,
            isPresented: Binding(
                get: { coordinator.isShowing(state) },
                set: { if !$0 { coordinator.dismiss() } }
            ),
            titleVisibility: .visible,
            actions: actions,
            message: message
        )
    }
}

// MARK: - Common Modal State Types

/// Example modal states for different features
/// Each feature can define its own modal state enum

enum BranchListModal: Hashable {
    case newBranch
    case merge(Branch)
    case rebase(Branch)
    case delete(Branch)
    case createPR(Branch)
    case rename(Branch)
}

enum StashListModal: Hashable {
    case apply(Stash)
    case drop(Stash)
    case details(Stash)
}

enum CommitModal: Hashable {
    case revert([Commit])
    case cherryPick(Commit)
    case details(Commit)
    case tag(Commit)
}

// MARK: - Example Usage

#if DEBUG
struct ModalCoordinatorExample: View {
    @StateObject private var modalCoordinator = ModalCoordinator<ExampleModal>()

    enum ExampleModal: Hashable {
        case settings
        case about
        case deleteConfirm
    }

    var body: some View {
        VStack(spacing: 20) {
            Button("Show Settings") {
                modalCoordinator.show(.settings)
            }

            Button("Show About") {
                modalCoordinator.show(.about)
            }

            Button("Show Delete Confirmation") {
                modalCoordinator.show(.deleteConfirm)
            }
        }
        .modalSheet(coordinator: modalCoordinator, for: .settings) {
            Text("Settings Sheet")
                .frame(width: 300, height: 200)
        }
        .modalSheet(coordinator: modalCoordinator, for: .about) {
            Text("About Sheet")
                .frame(width: 300, height: 200)
        }
        .modalAlert(
            coordinator: modalCoordinator,
            for: .deleteConfirm,
            title: "Delete Item"
        ) {
            Button("Delete", role: .destructive) {
                modalCoordinator.dismiss()
            }
            Button("Cancel", role: .cancel) {
                modalCoordinator.dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this item?")
        }
    }
}
#endif
