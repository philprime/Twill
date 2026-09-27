/// Groups views without adding layout or spacing.
public struct Group<Content: View>: View {
    public typealias Body = Never
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
}

extension Group: PrimitiveView {
    func makeDescription() -> ViewDescription {
        .group(children: [content], layout: nil)
    }
}
