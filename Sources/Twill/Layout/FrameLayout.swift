struct FrameLayout: PrimitiveLayout {
    let width: Int?
    let maxWidth: Int?

    func sizeThatFits(_ proposal: ProposedCellSize, subviews: [CellSize]) -> CellSize {
        let content = HorizontalLayout(spacing: 0).sizeThatFits(.unspecified, subviews: subviews)
        let desiredWidth = width ?? min(content.width, maxWidth ?? content.width)
        return CellSize(
            width: min(desiredWidth, proposal.width ?? desiredWidth),
            height: min(content.height, proposal.height ?? content.height))
    }

    func placeSubviews(_ subviews: [CellSize]) -> [CellRect] {
        HorizontalLayout(spacing: 0).placeSubviews(subviews)
    }
}
