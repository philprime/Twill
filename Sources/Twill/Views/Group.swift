/// Groups views without adding layout or spacing.
public struct Group<Content: View>: View {
    /// Primitive content rendered directly by the runtime rather than through a composed body.
    public typealias Body = Never
    private let content: Content

    /// Groups built content without introducing a separate layout arrangement.
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
}

extension Group: PrimitiveView {
    func makeDescription() -> ViewDescription {
        .group(children: [content], layout: nil)
    }
}
