/// A vertically scrollable viewport. The proposed height fixes the visible area;
/// content retains its intrinsic height and mounted state outside that area.
public struct ScrollView<Content: View>: View {
    public typealias Body = Never
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
}

extension ScrollView: PrimitiveView {
    func makeDescription() -> ViewDescription {
        .scroll(content)
    }
}
