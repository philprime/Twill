/// Provides programmatic access to scroll views in its content.
public struct ScrollViewReader<Content: View>: View {
    public typealias Body = Never
    private let content: Content
    private let proxy: ScrollViewProxy

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
    public enum Anchor {
        case top
        case bottom
    }

    weak var renderer: ViewRenderer?

    public func scrollTo<ID: Hashable>(_ id: ID, anchor: Anchor = .top) {
        guard let renderer, let target = renderer.keyedNode(for: AnyHashable(id)) else { return }
        var ancestor = target.parent
        while let node = ancestor {
            if case .scroll = node.description {
                guard let bounds = node.bounds(of: target, column: 0, row: 0) else { return }
                let requested =
                    switch anchor {
                    case .top: bounds.row
                    case .bottom: bounds.row + bounds.height - node.measuredSize.height
                    }
                let offset = min(max(0, requested), max(0, node.scrollContentHeight - node.measuredSize.height))
                guard offset != node.scrollOffset else { return }
                node.scrollOffset = offset
                node.requestFocusPresentation()
                return
            }
            if node === renderer { return }
            ancestor = node.parent
        }
    }
}
