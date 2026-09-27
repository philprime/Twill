/// Intrinsic-height, leading-aligned placement. Constrained bounds clip rows.
struct VerticalLayout: PrimitiveLayout {
    let spacing: Int

    func sizeThatFits(_ proposal: ProposedCellSize, subviews: [CellSize]) -> CellSize {
        let height = subviews.reduce(0) { $0 + $1.height } + max(0, subviews.count - 1) * spacing
        let width = subviews.map(\.width).max() ?? 0
        return proposal.constrain(CellSize(width: width, height: height))
    }

    func placeSubviews(_ subviews: [CellSize]) -> [CellRect] {
        var row = 0
        return subviews.map { size in
            defer { row += size.height + spacing }
            return CellRect(column: 0, row: row, width: size.width, height: size.height)
        }
    }
}
