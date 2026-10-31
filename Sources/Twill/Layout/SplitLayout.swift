/// Pane presence is pass-local geometry, never a source of focus or mounting policy.
struct SplitLayout: PrimitiveLayout {
    let columns: [GridItem]
    let spacing: Int
    var behavior: LayoutBehavior { LayoutBehavior(width: .filling, stackAxis: .horizontal) }

    @MainActor
    func measureSubviews(_ proposal: ProposedCellSize, subviews: [LayoutSubview]) -> [CellSize] {
        let active = subviews.indices.filter { subviews[$0].hasContent }
        guard !active.isEmpty else { return subviews.map { _ in .zero } }
        // Finite allocations depend on declared policies, not accidental natural widths.
        let natural = proposal.width == nil ? active.map { subviews[$0].sizeThatFits(.unspecified) } : []
        let grid = GridLayout(columns: active.map { columns[$0] }, rowSpacing: 0, columnSpacing: spacing)
        let width = proposal.width ?? grid.sizeThatFits(.unspecified, subviews: natural).width
        var widths = grid.columnWidths(in: proposal.width == nil ? width : 0, subviews: natural)
        if proposal.width != nil {
            let flexible = active.indices.filter {
                if case .flexible = columns[active[$0]].size { return true }
                return false
            }
            let occupied = widths.reduce(0, +) + max(0, active.count - 1) * spacing
            let remaining = max(0, width - occupied)
            for index in flexible {
                widths[index] += remaining / flexible.count + (index == flexible.last ? remaining % flexible.count : 0)
            }
        }
        var measured = subviews.map { _ in CellSize.zero }
        for (position, index) in active.enumerated() {
            measured[index] = subviews[index].sizeThatFits(.init(width: widths[position], height: proposal.height))
        }
        guard proposal.height == nil else { return measured }
        let height = measured.map(\.height).max() ?? 0
        for (position, index) in active.enumerated() {
            measured[index] = subviews[index].sizeThatFits(.init(width: widths[position], height: height))
        }
        return measured
    }

    func sizeThatFits(_ proposal: ProposedCellSize, subviews: [CellSize]) -> CellSize {
        let active = subviews.filter { $0 != .zero }
        let gap = active.count > 1 ? spacing : 0
        return proposal.constrain(
            CellSize(
                width: active.reduce(0) { $0 + $1.width } + gap,
                height: active.map(\.height).max() ?? 0))
    }

    func placeSubviews(_ subviews: [CellSize], in size: CellSize) -> [CellRect] {
        let active = subviews.indices.filter { subviews[$0] != .zero }
        var column = 0
        return subviews.indices.map { index in
            let child = subviews[index]
            let origin = column
            if child != .zero { column += child.width + (index == active.last ? 0 : spacing) }
            return CellRect(column: origin, row: 0, width: child.width, height: child.height)
        }
    }
}
