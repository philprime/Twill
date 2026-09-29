/// Sizes and positions content within fixed or flexible cell dimensions.
public struct FrameView<Content: View>: View {
    public typealias Body = Never
    private let content: Content
    private let width: Int?
    private let height: Int?
    private let maxWidth: FrameLimit?
    private let maxHeight: FrameLimit?
    private let alignment: Alignment

    init(
        content: Content, width: Int? = nil, height: Int? = nil,
        maxWidth: FrameLimit? = nil, maxHeight: FrameLimit? = nil, alignment: Alignment
    ) {
        precondition((width ?? 0) >= 0 && (height ?? 0) >= 0, "Frame dimensions must not be negative")
        if case .cells(let limit) = maxWidth {
            precondition(limit >= 0, "Maximum frame width must not be negative")
        }
        if case .cells(let limit) = maxHeight {
            precondition(limit >= 0, "Maximum frame height must not be negative")
        }
        self.content = content
        self.width = width
        self.height = height
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
        self.alignment = alignment
    }
}

extension View {
    public func frame(
        maxWidth: FrameLimit? = nil, maxHeight: FrameLimit? = nil, alignment: Alignment = .center
    ) -> FrameView<Self> {
        FrameView(content: self, maxWidth: maxWidth, maxHeight: maxHeight, alignment: alignment)
    }

    public func frame(width: Int? = nil, height: Int? = nil, alignment: Alignment = .center) -> FrameView<Self> {
        FrameView(content: self, width: width, height: height, alignment: alignment)
    }
}

extension FrameView: PrimitiveView {
    func makeDescription() -> ViewDescription {
        .group(
            children: [content],
            layout: FrameLayout(
                width: width, height: height, maxWidth: maxWidth, maxHeight: maxHeight, alignment: alignment))
    }
}
