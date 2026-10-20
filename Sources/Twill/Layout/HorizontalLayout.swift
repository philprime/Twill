/// Intrinsic-width sibling placement. Constrained bounds clip natural-width
/// siblings; single-child composition forwards proposals without a distribution pass.
struct HorizontalLayout: PrimitiveLayout {
    let spacing: Int
    var alignment: VerticalAlignment = .top

    @MainActor
    func measureSubviews(_ proposal: ProposedCellSize, subviews: [LayoutSubview]) -> [CellSize] {
        if let size = singleSubviewSize(proposal, subviews: subviews) { return [size] }
        // Flexible children have a known final width after sibling space is
        // deducted. Their natural width is unused and can require a full tree walk.
        let natural = subviews.map {
            proposal.width != nil && $0.fillsWidth ? .zero : $0.sizeThatFits(.unspecified)
        }
        let flexible = subviews.indices.filter { subviews[$0].fillsWidth }
        let occupied = subviews.indices.filter { !subviews[$0].fillsWidth }.reduce(0) { $0 + natural[$1].width }
        let remaining = max(0, (proposal.width ?? 0) - occupied - max(0, subviews.count - 1) * spacing)
        return subviews.indices.map { index in
            let width =
                proposal.width != nil && subviews[index].fillsWidth
                ? remaining / max(1, flexible.count) + (index == flexible.last ? remaining % flexible.count : 0)
                : nil
            let height = subviews[index].fillsHeight ? proposal.height : nil
            return width != nil || height != nil
                ? subviews[index].sizeThatFits(ProposedCellSize(width: width, height: height)) : natural[index]
        }
    }

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
