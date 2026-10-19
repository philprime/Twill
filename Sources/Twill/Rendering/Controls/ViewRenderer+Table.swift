/// Column discovery stays with the mounted tree; row sizing uses only pass-local geometry.
extension ViewRenderer {
    func resolveTableContext(
        _ proposal: ProposedCellSize, inherited: TableLayoutContext?
    ) -> TableLayoutContext? {
        guard case .table(_, let layout) = description else { return inherited }
        // Scan natural cell sizes before constraining rows. A cell containing a nested
        // table resolves that table independently, rather than inheriting these widths.
        let sizes = retainedChildren.flatMap { $0.tableRows() }.flatMap { row in
            row.retainedChildren.map { $0.measure(.unspecified) }
        }
        let width = proposal.width.map { max(0, $0 - layoutState.scrollIndicators.reservedColumns) }
        return TableLayoutContext(columnWidths: layout.columnWidths(in: width, subviews: sizes))
    }

    private func tableRows() -> [ViewRenderer] {
        if case .tableRow = description { return [self] }
        // A nested table is one outer cell and owns the widths of its own rows.
        if case .table = description { return [] }
        return retainedChildren.flatMap { $0.tableRows() }
    }
}
