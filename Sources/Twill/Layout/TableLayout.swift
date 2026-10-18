/// The mounted table resolves column widths once for headers and all keyed rows.
struct TableLayout: PrimitiveLayout {
    let columnCount: Int
    static let spacing = 2

    var behavior: LayoutBehavior { LayoutBehavior(width: .filling) }

    func columnWidths(in proposedWidth: Int?, subviews: [CellSize]) -> [Int] {
        let naturalGrid = GridLayout(
            columns: Array(repeating: GridItem(.flexible()), count: columnCount), spacing: Self.spacing)
        let naturalWidth = naturalGrid.sizeThatFits(.unspecified, subviews: subviews).width
        let natural = naturalGrid.columnWidths(in: naturalWidth, subviews: subviews)
        guard let proposedWidth else { return natural }
        // Preserve content before sharing surplus space. When space is scarce,
        // cap short columns at their content width so longer columns can use it.
        let columns = natural.map { width in
            GridItem(
                .flexible(
                    minimum: proposedWidth >= naturalWidth ? width : 1,
                    maximum: proposedWidth >= naturalWidth ? .max : width))
        }
        return GridLayout(columns: columns, spacing: Self.spacing)
            .columnWidths(in: proposedWidth, subviews: subviews)
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
