struct FrameLayout: PrimitiveLayout {
    let width: Int?
    let height: Int?
    let maxWidth: FrameLimit?
    let maxHeight: FrameLimit?
    let alignment: Alignment

    var fillsWidth: Bool {
        if case .infinity = maxWidth { return true }
        return false
    }

    var fillsHeight: Bool {
        if case .infinity = maxHeight { return true }
        return false
    }

    func childProposal(_ proposal: ProposedCellSize) -> ProposedCellSize {
        ProposedCellSize(
            width: constrained(proposal.width, fixed: width, maximum: maxWidth),
            height: constrained(proposal.height, fixed: height, maximum: maxHeight))
    }

    private func constrained(_ proposed: Int?, fixed: Int?, maximum: FrameLimit?) -> Int? {
        if let fixed { return min(fixed, proposed ?? fixed) }
        if case .cells(let limit) = maximum { return min(limit, proposed ?? limit) }
        return proposed
    }

    func sizeThatFits(_ proposal: ProposedCellSize, subviews: [CellSize]) -> CellSize {
        let content = HorizontalLayout(spacing: 0).sizeThatFits(.unspecified, subviews: subviews)
        return CellSize(
            width: min(
                desired(content.width, proposed: proposal.width, fixed: width, maximum: maxWidth),
                proposal.width ?? Int.max),
            height: min(
                desired(content.height, proposed: proposal.height, fixed: height, maximum: maxHeight),
                proposal.height ?? Int.max))
    }

    private func desired(_ content: Int, proposed: Int?, fixed: Int?, maximum: FrameLimit?) -> Int {
        if let fixed { return fixed }
        switch maximum {
        case .infinity: return proposed ?? content
        case .cells(let limit): return min(max(content, proposed ?? content), limit)
        case nil: return content
        }
    }

    func placeSubviews(_ subviews: [CellSize], in size: CellSize) -> [CellRect] {
        let content = HorizontalLayout(spacing: 0).sizeThatFits(.unspecified, subviews: subviews)
        let column = offset(available: size.width, occupied: content.width, horizontal: alignment.horizontal)
        let row = offset(available: size.height, occupied: content.height, vertical: alignment.vertical)
        return HorizontalLayout(spacing: 0).placeSubviews(subviews, in: content).map {
            CellRect(column: column + $0.column, row: row + $0.row, width: $0.width, height: $0.height)
        }
    }

    private func offset(available: Int, occupied: Int, horizontal: HorizontalAlignment) -> Int {
        switch horizontal {
        case .leading: return 0
        case .center: return max(0, (available - occupied) / 2)
        case .trailing: return max(0, available - occupied)
        }
    }

    private func offset(available: Int, occupied: Int, vertical: VerticalAlignment) -> Int {
        switch vertical {
        case .top: return 0
        case .center: return max(0, (available - occupied) / 2)
        case .bottom: return max(0, available - occupied)
        }
    }
}
