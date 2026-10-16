/// Places children vertically at their intrinsic cell heights.
/// Content that exceeds the available bounds is clipped rather than compressed.
public struct VStack<Content: View>: View {
    /// Primitive content rendered directly by the runtime rather than through a composed body.
    public typealias Body = Never
    private let content: Content
    private let spacing: Int
    private let alignment: HorizontalAlignment

    /// Arranges content vertically with the specified horizontal alignment and row spacing.
    /// Spacing must be nonnegative.
    public init(alignment: HorizontalAlignment = .center, spacing: Int = 0, @ViewBuilder content: () -> Content) {
        precondition(spacing >= 0, "Stack spacing must not be negative")
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }
}

extension VStack: PrimitiveView {
    func makeDescription() -> ViewDescription {
        .group(children: [content], layout: VerticalLayout(spacing: spacing, alignment: alignment))
    }
}
