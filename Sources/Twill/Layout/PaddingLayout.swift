struct PaddingLayout: PrimitiveLayout {
    let insets: EdgeInsets

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
