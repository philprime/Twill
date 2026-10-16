/// Column sizing happens after mounting so cell bodies and state stay in the runtime.
extension ViewRenderer {
    func resolveTableColumns(_ layout: TableLayout, proposal: ProposedCellSize) {
        let sizes = children.flatMap { $0.tableRows() }.flatMap { row in
            row.children.map { $0.measure(.unspecified) }
        }
        let width = layout.grid.sizeThatFits(proposal, subviews: sizes).width
        tableColumnWidths = layout.grid.columnWidths(in: width, subviews: sizes)
    }

    func measureTableRow(_ items: [ViewRenderer]) -> [CellSize] {
        var ancestor = parent
        while let node = ancestor {
            if case .group(_, let layout) = node.description, layout is TableLayout {
                return zip(items, node.tableColumnWidths).map { item, width in
                    let size = item.measure(ProposedCellSize(width: width))
                    return CellSize(width: width, height: size.height)
                }
            }
            ancestor = node.parent
        }
        preconditionFailure("A table row must be mounted inside a table")
    }

    private func tableRows() -> [ViewRenderer] {
        if case .group(_, let layout) = description {
            if layout is TableRowLayout { return [self] }
            // Nested tables resolve their own columns and are one cell here.
            if layout is TableLayout { return [] }
        }
        return children.flatMap { $0.tableRows() }
    }
}
