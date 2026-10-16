/// Builder-produced content that forwards its children without adding layout of its own.
public struct ViewList<each Content: View>: View {
    /// Primitive content rendered directly by the runtime rather than through a composed body.
    public typealias Body = Never
    let children: (repeat each Content)
}

extension ViewList: PrimitiveView {
    func makeDescription() -> ViewDescription {
        // Erase only when handing descriptions to the heterogeneous mounted tree.
        var views: [any View] = []
        for child in repeat each children {
            views.append(child)
        }
        return .group(children: views, layout: nil)
    }
}
