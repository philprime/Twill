/// Provides programmatic access to scroll views in its content.
public struct ScrollViewReader<Content: View>: View {
    /// Primitive content rendered directly by the runtime rather than through a composed body.
    public typealias Body = Never
    private let content: Content
    private let proxy: ScrollViewProxy

    /// Builds content with a proxy that can scroll to keyed descendants after mounting.
    public init(@ViewBuilder content: (ScrollViewProxy) -> Content) {
        let proxy = ScrollViewProxy()
        self.proxy = proxy
        self.content = content(proxy)
    }
}

extension ScrollViewReader: PrimitiveView {
    func makeDescription() -> ViewDescription {
        .scrollReader(content, proxy)
    }
}

/// Moves a scroll view to a child identified by a `ForEach` key.
@MainActor
public final class ScrollViewProxy {
    /// The target edge to align with the scroll viewport.
    public enum Anchor {
        /// Aligns the target's top edge with the viewport's top edge.
        case top
        /// Aligns the target's bottom edge with the viewport's bottom edge.
        case bottom
    }

    weak var renderer: ViewRenderer?

    /// Scrolls the target's nearest scroll ancestor to the requested edge, clamping to its content bounds.
    /// Missing targets are ignored. Explicit scrolling does not move keyboard focus.
    public func scrollTo<ID: Hashable>(_ id: ID, anchor: Anchor = .top) {
        guard let renderer, let target = renderer.keyedNode(for: AnyHashable(id)) else { return }
        var ancestor = target.parent
        while let node = ancestor {
            if case .scroll = node.description {
                guard let bounds = node.bounds(of: target, column: 0, row: 0) else { return }
                let requested =
                    switch anchor {
                    case .top: bounds.row
                    case .bottom: bounds.row + bounds.height - node.layoutState.size.height
                    }
                // Explicit scrolling must survive redraws without moving keyboard focus.
                guard node.scrollState.scroll(to: requested, viewportHeight: node.layoutState.size.height) else {
                    return
                }
                node.requestFocusPresentation()
                return
            }
            if node === renderer { return }
            ancestor = node.parent
        }
    }
}
