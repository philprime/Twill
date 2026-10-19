struct FrameLayout: PrimitiveLayout {
    let horizontal: FrameAxisConstraints
    let vertical: FrameAxisConstraints
    let alignment: Alignment

    init(
        width: Int? = nil, height: Int? = nil, minWidth: Int? = nil, maxWidth: FrameLimit? = nil,
        minHeight: Int? = nil, maxHeight: FrameLimit? = nil, alignment: Alignment
    ) {
        horizontal = FrameAxisConstraints(fixed: width, minimum: minWidth, maximum: maxWidth)
        vertical = FrameAxisConstraints(fixed: height, minimum: minHeight, maximum: maxHeight)
        self.alignment = alignment
    }

    var behavior: LayoutBehavior { LayoutBehavior(width: horizontal.fill, height: vertical.fill) }

    @MainActor
    func measureSubviews(_ proposal: ProposedCellSize, subviews: [LayoutSubview]) -> [CellSize] {
        if subviews.count == 1 { return [subviews[0].sizeThatFits(childProposal(proposal))] }
        return subviews.map { $0.sizeThatFits(.unspecified) }
    }

    func childProposal(_ proposal: ProposedCellSize) -> ProposedCellSize {
        ProposedCellSize(
            width: horizontal.childProposal(proposal.width),
            height: vertical.childProposal(proposal.height))
    }

    func sizeThatFits(_ proposal: ProposedCellSize, subviews: [CellSize]) -> CellSize {
        let content = HorizontalLayout(spacing: 0).sizeThatFits(.unspecified, subviews: subviews)
        return CellSize(
            width: horizontal.dimension(content: content.width, proposed: proposal.width),
            height: vertical.dimension(content: content.height, proposed: proposal.height))
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
