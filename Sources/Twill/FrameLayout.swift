struct FrameLayout: PrimitiveLayout {
    let maxWidth: Int

    func sizeThatFits(_ proposal: ProposedCellSize, subviews: [CellSize]) -> CellSize {
        let content = subviews.first ?? .zero
        return CellSize(
            width: min(content.width, maxWidth, proposal.width ?? maxWidth),
            height: min(content.height, proposal.height ?? content.height))
    }

    func placeSubviews(_ subviews: [CellSize]) -> [CellRect] {
        subviews.map { CellRect(column: 0, row: 0, width: $0.width, height: $0.height) }
    }
}
