/// Arranges views in rows using the supplied column descriptions.
public struct LazyVGrid<Content: View>: View {
    public typealias Body = Never
    private let content: Content
    private let columns: [GridItem]
    private let spacing: Int

    /// Creates a vertical grid whose columns share the available terminal width.
    /// Content outside the proposed bounds is clipped. The current runtime mounts all
    /// children when the description is evaluated rather than deferring offscreen cells.
    public init(columns: [GridItem], spacing: Int = 1, @ViewBuilder content: () -> Content) {
        precondition(!columns.isEmpty, "A grid requires at least one column")
        precondition(
            columns.count == 1 || !columns.contains { if case .adaptive = $0.size { true } else { false } },
            "An adaptive grid requires a single column description")
        precondition(spacing >= 0, "Grid spacing must not be negative")
        self.columns = columns
        self.spacing = spacing
        self.content = content()
    }
}

extension LazyVGrid: PrimitiveView {
    func makeDescription() -> ViewDescription {
        .group(children: [content], layout: GridLayout(columns: columns, spacing: spacing))
    }
}
