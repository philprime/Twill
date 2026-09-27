struct FrameLayout: PrimitiveLayout {
    let maxWidth: Int

    func sizeThatFits(_ proposal: ProposedCellSize, subviews: [CellSize]) -> CellSize {
        let content = HorizontalLayout(spacing: 0).sizeThatFits(.unspecified, subviews: subviews)
        return CellSize(
            width: min(content.width, maxWidth, proposal.width ?? maxWidth),
            height: min(content.height, proposal.height ?? content.height))
    }

    func placeSubviews(_ subviews: [CellSize]) -> [CellRect] {
        HorizontalLayout(spacing: 0).placeSubviews(subviews)
    }
}
