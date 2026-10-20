/// An eager vertical grid that mounts every child and arranges content into rows.
/// Clipping limits drawing, not mounted state or child schedules.
public struct VGrid<Content: View>: View {
    /// Primitive content rendered directly by the runtime.
    public typealias Body = Never
    private let content: Content
    private let columns: [GridItem]
    private let rowSpacing: Int
    private let columnSpacing: Int

    /// Creates an eager grid with independent nonnegative terminal-cell gaps.
    /// An adaptive description must be the only column description.
    public init(
        columns: [GridItem], rowSpacing: Int = 1, columnSpacing: Int = 1, @ViewBuilder content: () -> Content
    ) {
        precondition(!columns.isEmpty, "A grid requires at least one column")
        precondition(
            columns.count == 1 || !columns.contains { if case .adaptive = $0.size { true } else { false } },
            "An adaptive grid requires a single column description")
        precondition(rowSpacing >= 0 && columnSpacing >= 0, "Grid spacing must not be negative")
        self.columns = columns
        self.rowSpacing = rowSpacing
        self.columnSpacing = columnSpacing
        self.content = content()
    }
}

extension VGrid: PrimitiveView {
    func makeDescription() -> ViewDescription {
        .group(
            children: [content],
            layout: GridLayout(columns: columns, rowSpacing: rowSpacing, columnSpacing: columnSpacing))
    }
}
