/// Places children vertically at their intrinsic cell heights, with leading alignment.
/// Content that exceeds the available bounds is clipped rather than compressed.
public struct VStack<Content: View>: View {
    public typealias Body = Never
    private let content: Content
    private let spacing: Int

    public init(spacing: Int = 0, @ViewBuilder content: () -> Content) {
        precondition(spacing >= 0, "Stack spacing must not be negative")
        self.spacing = spacing
        self.content = content()
    }
}

extension VStack: PrimitiveView {
    func makeDescription() -> ViewDescription {
        .group(children: [content], layout: VerticalLayout(spacing: spacing))
    }
}
