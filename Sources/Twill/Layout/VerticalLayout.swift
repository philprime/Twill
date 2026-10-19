/// Intrinsic-height placement with finite width offered to every child.
/// Constrained height clips rows without changing their content.
struct VerticalLayout: PrimitiveLayout {
    let spacing: Int
    var alignment: HorizontalAlignment = .leading
    var behavior: LayoutBehavior { LayoutBehavior(stackAxis: .vertical) }

    @MainActor
    func measureSubviews(_ proposal: ProposedCellSize, subviews: [LayoutSubview]) -> [CellSize] {
        if let size = singleSubviewSize(proposal, subviews: subviews) { return [size] }
        let natural = subviews.map {
            proposal.height != nil && $0.fillsHeight && !$0.preservesIntrinsicMinimum
                ? .zero : $0.sizeThatFits(ProposedCellSize(width: proposal.width))
        }
        let flexible = subviews.indices.filter { subviews[$0].fillsHeight }
        let occupied = natural.reduce(0) { $0 + $1.height }
        let remaining = max(0, (proposal.height ?? 0) - occupied - max(0, subviews.count - 1) * spacing)
        let measured = subviews.indices.map { index in
            let height =
                proposal.height != nil && subviews[index].fillsHeight
                ? natural[index].height + remaining / max(1, flexible.count)
                    + (index == flexible.last ? remaining % flexible.count : 0) : nil
            return height != nil
                ? subviews[index].sizeThatFits(ProposedCellSize(width: proposal.width, height: height)) : natural[index]
        }
        guard proposal.width == nil else { return measured }
        let width = measured.map(\.width).max() ?? 0
        return subviews.indices.map { index in
            subviews[index].fillsWidth || subviews[index].preservesIntrinsicMinimum
                ? subviews[index].sizeThatFits(ProposedCellSize(width: width, height: measured[index].height))
                : measured[index]
        }
    }

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
