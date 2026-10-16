/// Places children horizontally at their intrinsic cell widths.
/// Content that exceeds the available bounds is clipped rather than wrapped.
public struct HStack<Content: View>: View {
    /// Primitive content rendered directly by the runtime rather than through a composed body.
    public typealias Body = Never
    private let content: Content
    private let spacing: Int
    private let alignment: VerticalAlignment

    /// Arranges content horizontally with the specified vertical alignment and cell spacing.
    /// Spacing must be nonnegative.
    public init(alignment: VerticalAlignment = .center, spacing: Int = 1, @ViewBuilder content: () -> Content) {
        precondition(spacing >= 0, "Stack spacing must not be negative")
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }
}

extension HStack: PrimitiveView {
    func makeDescription() -> ViewDescription {
        .group(children: [content], layout: HorizontalLayout(spacing: spacing, alignment: alignment))
    }
}
