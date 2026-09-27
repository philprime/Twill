/// Fills only the axes requested by the view. Without a proposal it stays intrinsic.
struct FillFrameLayout: PrimitiveLayout {
    let fillWidth: Bool
    let fillHeight: Bool

    func sizeThatFits(_ proposal: ProposedCellSize, subviews: [CellSize]) -> CellSize {
        let content = HorizontalLayout(spacing: 0).sizeThatFits(.unspecified, subviews: subviews)
        return CellSize(
            width: fillWidth ? proposal.width ?? content.width : min(content.width, proposal.width ?? content.width),
            height: fillHeight
                ? proposal.height ?? content.height : min(content.height, proposal.height ?? content.height))
    }

    func placeSubviews(_ subviews: [CellSize]) -> [CellRect] {
        HorizontalLayout(spacing: 0).placeSubviews(subviews)
    }
}
