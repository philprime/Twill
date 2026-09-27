/// Builder-produced content that forwards its children without adding layout of its own.
public struct ViewList<each Content: View>: View {
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
        return .group(children: views, separator: nil)
    }
}
