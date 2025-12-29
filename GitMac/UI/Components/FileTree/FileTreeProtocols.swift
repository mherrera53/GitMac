import SwiftUI

// MARK: - File Tree Protocols

/// Protocol for data that can be displayed in a tree structure
protocol TreeNodeData: Identifiable {
    var name: String { get }
    var path: String { get }
    var isFolder: Bool { get }
    var children: [Self] { get set }
}

/// Protocol for tree node actions
protocol TreeNodeActionProvider {
    associatedtype NodeData: TreeNodeData

    func primaryAction(for node: NodeData) -> (() -> Void)?
    func secondaryActions(for node: NodeData) -> [TreeAction]
}

/// Represents an action that can be performed on a tree node
struct TreeAction: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let isDestructive: Bool
    let action: () -> Void

    init(title: String, icon: String, isDestructive: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isDestructive = isDestructive
        self.action = action
    }
}

/// Protocol for custom tree node rendering
protocol TreeNodeRenderer {
    associatedtype NodeData: TreeNodeData

    func render(
        node: NodeData,
        isSelected: Bool,
        isHovered: Bool,
        isExpanded: Bool
    ) -> AnyView
}
