import SwiftUI

// MARK: - Unified Scroll Container (The Source of Truth)

struct UnifiedDiffScrollView<Content: View>: View {
    @Binding var scrollOffset: CGFloat
    @Binding var viewportHeight: CGFloat
    var viewportWidth: Binding<CGFloat>? = nil
    var contentHeight: Binding<CGFloat>? = nil
    var id: String = "DiffScrollView"
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            ZStack(alignment: .top) {
                // Reliable Scroll Tracker
                GeometryReader { geo in
                    SwiftUI.Color.clear
                        .preference(key: DiffScrollOffsetKey.self, value: -geo.frame(in: .named(id)).minY)
                }
                .frame(height: 1)

                // Content
                content()
            }
            .background(
                GeometryReader { geo in
                    SwiftUI.Color.clear
                        .onAppear { contentHeight?.wrappedValue = geo.size.height }
                        .onChange(of: geo.size.height) { _, new in contentHeight?.wrappedValue = new }
                }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .coordinateSpace(name: id)
        .background(
            GeometryReader { geo in
                SwiftUI.Color.clear
                    .onAppear {
                        viewportHeight = geo.size.height
                        viewportWidth?.wrappedValue = geo.size.width
                    }
                    .onChange(of: geo.size.height) { _, new in viewportHeight = new }
                    .onChange(of: geo.size.width) { _, new in viewportWidth?.wrappedValue = new }
            }
        )
        .onPreferenceChange(DiffScrollOffsetKey.self) { val in
            scrollOffset = max(0, val)
        }
    }
}

// MARK: - Helper Structures

struct DiffPair: Identifiable {
    let id: Int
    let left: DiffLine?
    let right: DiffLine?
    let hunkHeader: String?
}

struct IdentifiedDiffLine: Identifiable {
    let id: Int
    let line: DiffLine?
    let hunkHeader: String?
}
