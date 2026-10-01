/// Adds blank cells around content before enclosing modifiers are applied.
public struct PaddingView<Content: View>: View {
    public typealias Body = Never
    private let content: Content
    private let insets: EdgeInsets

    init(content: Content, insets: EdgeInsets) {
        self.content = content
        self.insets = insets
    }
}

extension View {
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

    public func padding(_ length: Int) -> PaddingView<Self> {
        padding(.all, length)
    }

    public func padding(_ insets: EdgeInsets) -> PaddingView<Self> {
        PaddingView(content: self, insets: insets)
    }
}

extension PaddingView: PrimitiveView {
    func makeDescription() -> ViewDescription {
        .group(children: [content], layout: PaddingLayout(insets: insets))
    }
}
