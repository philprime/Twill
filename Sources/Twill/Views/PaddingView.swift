/// Adds blank cells around content before enclosing modifiers are applied.
public struct PaddingView<Content: View>: View {
    /// Primitive content rendered directly by the runtime rather than through a composed body.
    public typealias Body = Never
    private let content: Content
    private let insets: EdgeInsets

    init(content: Content, insets: EdgeInsets) {
        self.content = content
        self.insets = insets
    }
}

extension View {
    /// Adds nonnegative padding to the selected edges, using one cell when no length is supplied.
    public func padding(_ edges: Edge.Set = .all, _ length: Int? = nil) -> PaddingView<Self> {
        let length = length ?? 1
        precondition(length >= 0, "Padding must not be negative")
        return padding(
            EdgeInsets(
                top: edges.contains(.top) ? length : 0,
                leading: edges.contains(.leading) ? length : 0,
                bottom: edges.contains(.bottom) ? length : 0,
                trailing: edges.contains(.trailing) ? length : 0))
    }

    /// Adds the same nonnegative number of blank cells on every edge.
    public func padding(_ length: Int) -> PaddingView<Self> {
        padding(.all, length)
    }

    /// Adds the specified per-edge blank-cell insets around the content.
    public func padding(_ insets: EdgeInsets) -> PaddingView<Self> {
        PaddingView(content: self, insets: insets)
    }
}

extension PaddingView: PrimitiveView {
    func makeDescription() -> ViewDescription {
        .group(children: [content], layout: PaddingLayout(insets: insets))
    }
}
