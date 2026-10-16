/// Explicitly supplies no presentation, for applications that only handle events.
public struct EmptyView: View {
    /// Primitive content rendered directly by the runtime rather than through a composed body.
    public typealias Body = Never

    /// Creates a view with no terminal content or layout extent.
    public init() {}
}

extension EmptyView: PrimitiveView {
    func makeDescription() -> ViewDescription {
        .empty
    }
}
