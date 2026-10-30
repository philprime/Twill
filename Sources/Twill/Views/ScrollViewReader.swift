/// Provides programmatic access to scroll views in its content.
public struct ScrollViewReader<Content: View>: View {
    /// Primitive content rendered directly by the runtime rather than through a composed body.
    public typealias Body = Never
    private let content: Content
    private let proxy: ScrollViewProxy

    /// Builds a local target scope for ForEach keys and explicit `.id` descendants after layout.
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
