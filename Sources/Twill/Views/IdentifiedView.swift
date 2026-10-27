/// Gives content an explicit identity within its structural position.
public struct IdentifiedView<Content: View, ID: Hashable>: View {
    /// Primitive content rendered directly by the runtime rather than through a composed body.
    public typealias Body = Never
    private let content: Content
    private let id: ID

    init(content: Content, id: ID) {
        self.content = content
        self.id = id
    }
}

extension View {
    /// Retains the content's mounted state while this ID is unchanged.
    /// Changing it replaces the subtree, resetting its state and cancelling owned tasks.
    /// Modifiers applied after this one remain outside the identified subtree.
    public func id<ID: Hashable>(_ id: ID) -> IdentifiedView<Self, ID> {
        IdentifiedView(content: self, id: id)
    }
}

extension IdentifiedView: PrimitiveView {
    func makeDescription() -> ViewDescription {
        .keyed(children: [(id: AnyHashable(id), view: content)])
    }
}
