protocol PrimitiveLayout {
    func sizeThatFits(_ proposal: ProposedCellSize, subviews: [CellSize]) -> CellSize
    func placeSubviews(_ subviews: [CellSize]) -> [CellRect]
}

/// Intrinsic-width, top-aligned placement. Constrained bounds clip content rather
/// than compressing or wrapping text. Transparent view lists use zero spacing.
struct HorizontalLayout: PrimitiveLayout {
    let spacing: Int

    func sizeThatFits(_ proposal: ProposedCellSize, subviews: [CellSize]) -> CellSize {
        let width = subviews.reduce(0) { $0 + $1.width } + max(0, subviews.count - 1) * spacing
        return proposal.constrain(CellSize(width: width, height: subviews.map(\.height).max() ?? 0))
    }

    func placeSubviews(_ subviews: [CellSize]) -> [CellRect] {
        var column = 0
        return subviews.map { size in
            defer { column += size.width + spacing }
            return CellRect(column: column, row: 0, width: size.width, height: size.height)
        }
    }
}
