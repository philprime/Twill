/// The mounted table resolves column widths once for headers and all keyed rows.
struct TableLayout: PrimitiveLayout {
    let columnCount: Int
    static let spacing = 2

    var grid: GridLayout {
        GridLayout(columns: Array(repeating: GridItem(.flexible()), count: columnCount), spacing: Self.spacing)
    }

    func sizeThatFits(_ proposal: ProposedCellSize, subviews: [CellSize]) -> CellSize {
        HorizontalLayout(spacing: 0).sizeThatFits(proposal, subviews: subviews)
    }

    func placeSubviews(_ subviews: [CellSize], in size: CellSize) -> [CellRect] {
        HorizontalLayout(spacing: 0).placeSubviews(subviews, in: size)
    }
}

/// Marks rows whose cells use their enclosing table's resolved column widths.
struct TableRowLayout: PrimitiveLayout {
    func sizeThatFits(_ proposal: ProposedCellSize, subviews: [CellSize]) -> CellSize {
        let size = HorizontalLayout(spacing: TableLayout.spacing).sizeThatFits(proposal, subviews: subviews)
        return proposal.constrain(CellSize(width: size.width, height: max(1, size.height)))
    }

    func placeSubviews(_ subviews: [CellSize], in size: CellSize) -> [CellRect] {
        HorizontalLayout(spacing: TableLayout.spacing).placeSubviews(subviews, in: size)
    }
}
