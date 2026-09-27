/// Caps a view's measured width without changing its mounted identity or child content.
public struct FrameView<Content: View>: View {
    public typealias Body = Never
    private let content: Content
    private let maxWidth: Int

    init(content: Content, maxWidth: Int) {
        precondition(maxWidth >= 0, "Maximum frame width must not be negative")
        self.content = content
        self.maxWidth = maxWidth
    }
}

extension View {
    public func frame(maxWidth: Int) -> FrameView<Self> {
        FrameView(content: self, maxWidth: maxWidth)
    }
}

extension FrameView: PrimitiveView {
    func makeDescription() -> ViewDescription {
        .group(children: [content], layout: FrameLayout(maxWidth: maxWidth))
    }
}
