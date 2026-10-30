/// Sizes and positions content within fixed or flexible cell dimensions.
public struct FrameView<Content: View>: View {
    /// Primitive content rendered directly by the runtime rather than through a composed body.
    public typealias Body = Never
    private let content: Content
    private let layout: FrameLayout

    init(content: Content, layout: FrameLayout) {
        self.content = content
        self.layout = layout
    }
}

extension View {
    /// Combines fixed and flexible dimensions, minimums, and alignment in one frame.
    /// Values must be nonnegative and ordered within each axis. Fixed dimensions
    /// must lie inside any supplied bounds. Undersized parents still clip the frame.
    /// Use `.cells(value)` for runtime integer maximums and `.infinity` to fill proposals.
    public func frame(
        width: Int? = nil, height: Int? = nil, minWidth: Int? = nil, maxWidth: FrameLimit? = nil,
        minHeight: Int? = nil, maxHeight: FrameLimit? = nil, alignment: Alignment = .center
    ) -> FrameView<Self> {
        FrameView(
            content: self,
            layout: FrameLayout(
                width: width, height: height,
                minWidth: minWidth, maxWidth: maxWidth, minHeight: minHeight, maxHeight: maxHeight, alignment: alignment
            ))
    }
}

extension FrameView: PrimitiveView {
    func makeDescription() -> ViewDescription { .group(children: [content], layout: layout) }
}
