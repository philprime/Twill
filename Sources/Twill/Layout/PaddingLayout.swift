struct PaddingLayout: PrimitiveLayout {
    let insets: EdgeInsets

    @MainActor
    func measureSubviews(_ proposal: ProposedCellSize, subviews: [LayoutSubview]) -> [CellSize] {
        let inner = childProposal(proposal)
        return subviews.count == 1
            ? [subviews[0].sizeThatFits(inner)]
            : HorizontalLayout(spacing: 0).measureSubviews(inner, subviews: subviews)
    }

    func childProposal(_ proposal: ProposedCellSize) -> ProposedCellSize {
        ProposedCellSize(
            width: proposal.width.map { max(0, $0 - insets.leading - insets.trailing) },
            height: proposal.height.map { max(0, $0 - insets.top - insets.bottom) })
    }

    func sizeThatFits(_ proposal: ProposedCellSize, subviews: [CellSize]) -> CellSize {
        let content = HorizontalLayout(spacing: 0).sizeThatFits(.unspecified, subviews: subviews)
        return proposal.constrain(
            CellSize(
                width: content.width + insets.leading + insets.trailing,
                height: content.height + insets.top + insets.bottom))
    }

    func placeSubviews(_ subviews: [CellSize], in size: CellSize) -> [CellRect] {
        let content = CellSize(
            width: max(0, size.width - insets.leading - insets.trailing),
            height: max(0, size.height - insets.top - insets.bottom))
        return HorizontalLayout(spacing: 0).placeSubviews(subviews, in: content).map {
            CellRect(
                column: insets.leading + $0.column, row: insets.top + $0.row,
                width: $0.width, height: $0.height)
        }
    }
}
