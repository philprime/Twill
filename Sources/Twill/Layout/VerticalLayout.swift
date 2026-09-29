/// Intrinsic-height placement. Constrained bounds clip rows.
struct VerticalLayout: PrimitiveLayout {
    let spacing: Int
    var alignment: HorizontalAlignment = .leading

    func sizeThatFits(_ proposal: ProposedCellSize, subviews: [CellSize]) -> CellSize {
        let height = subviews.reduce(0) { $0 + $1.height } + max(0, subviews.count - 1) * spacing
        let width = subviews.map(\.width).max() ?? 0
        return proposal.constrain(CellSize(width: width, height: height))
    }

    func placeSubviews(_ subviews: [CellSize], in size: CellSize) -> [CellRect] {
        let width = size.width
        var row = 0
        return subviews.map { size in
            defer { row += size.height + spacing }
            let column: Int
            switch alignment {
            case .leading: column = 0
            case .center: column = (width - size.width) / 2
            case .trailing: column = width - size.width
            }
            return CellRect(column: column, row: row, width: size.width, height: size.height)
        }
    }
}
