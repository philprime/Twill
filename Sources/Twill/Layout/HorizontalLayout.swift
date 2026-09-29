protocol PrimitiveLayout {
    func sizeThatFits(_ proposal: ProposedCellSize, subviews: [CellSize]) -> CellSize
    func placeSubviews(_ subviews: [CellSize], in size: CellSize) -> [CellRect]
}

/// Intrinsic-width placement. Constrained bounds clip content rather than
/// compressing or wrapping text. Transparent view lists use zero spacing.
struct HorizontalLayout: PrimitiveLayout {
    let spacing: Int
    var alignment: VerticalAlignment = .top

    func sizeThatFits(_ proposal: ProposedCellSize, subviews: [CellSize]) -> CellSize {
        let width = subviews.reduce(0) { $0 + $1.width } + max(0, subviews.count - 1) * spacing
        return proposal.constrain(CellSize(width: width, height: subviews.map(\.height).max() ?? 0))
    }

    func placeSubviews(_ subviews: [CellSize], in size: CellSize) -> [CellRect] {
        let height = size.height
        var column = 0
        return subviews.map { size in
            defer { column += size.width + spacing }
            let row: Int
            switch alignment {
            case .top: row = 0
            case .center: row = (height - size.height) / 2
            case .bottom: row = height - size.height
            }
            return CellRect(column: column, row: row, width: size.width, height: size.height)
        }
    }
}
