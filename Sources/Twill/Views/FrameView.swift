/// Caps a view's measured width without changing its mounted identity or child content.
public struct FrameView<Content: View>: View {
    public typealias Body = Never
    private let content: Content
    private let maxWidth: Int?
    private let width: Int?

    init(content: Content, maxWidth: Int) {
        precondition(maxWidth >= 0, "Maximum frame width must not be negative")
        self.content = content
        self.maxWidth = maxWidth
        width = nil
    }

    init(content: Content, width: Int) {
        precondition(width >= 0, "Frame width must not be negative")
        self.content = content
        maxWidth = nil
        self.width = width
    }
}

extension View {
    public func frame(maxWidth: Int) -> FrameView<Self> {
        FrameView(content: self, maxWidth: maxWidth)
    }

    public func frame(width: Int) -> FrameView<Self> {
        FrameView(content: self, width: width)
    }
}

extension FrameView: PrimitiveView {
    func makeDescription() -> ViewDescription {
        .group(children: [content], layout: FrameLayout(width: width, maxWidth: maxWidth))
    }
}
