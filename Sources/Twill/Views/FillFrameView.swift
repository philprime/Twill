/// Opts into occupying the proposed cell dimensions on selected axes.
public struct FillFrameView<Content: View>: View {
    public typealias Body = Never
    private let content: Content
    private let fillWidth: Bool
    private let fillHeight: Bool

    init(content: Content, fillWidth: Bool, fillHeight: Bool) {
        self.content = content
        self.fillWidth = fillWidth
        self.fillHeight = fillHeight
    }
}

extension View {
    public func frame(fillWidth: Bool = false, fillHeight: Bool = false) -> FillFrameView<Self> {
        FillFrameView(content: self, fillWidth: fillWidth, fillHeight: fillHeight)
    }
}

extension FillFrameView: PrimitiveView {
    func makeDescription() -> ViewDescription {
        .group(children: [content], layout: FillFrameLayout(fillWidth: fillWidth, fillHeight: fillHeight))
    }
}
