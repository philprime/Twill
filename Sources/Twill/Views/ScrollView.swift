/// A vertically scrollable viewport. The proposed height fixes the visible area;
/// content retains its intrinsic height and mounted state outside that area.
/// Controls inside and outside the viewport participate in Tab navigation automatically.
public struct ScrollView<Content: View>: View {
    /// Primitive content rendered directly by the runtime rather than through a composed body.
    public typealias Body = Never
    private let content: Content

    /// Creates a vertically scrolling viewport for the built content.
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
}

extension ScrollView: PrimitiveView {
    func makeDescription() -> ViewDescription {
        .scroll(content)
    }
}
