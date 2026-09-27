/// Explicitly supplies no presentation, for applications that only handle events.
public struct EmptyView: View {
    public typealias Body = Never

    public init() {}
}

extension EmptyView: PrimitiveView {
    func makeDescription() -> ViewDescription {
        .empty
    }
}
