struct SpacerDrawing: PrimitiveDrawing {
    let axis: Axis?
    let minimum: Int

    func sizeThatFits(_ proposal: ProposedCellSize) -> CellSize {
        CellSize(
            width: axis == .vertical ? (proposal.width ?? 0) : max(minimum, proposal.width ?? minimum),
            height: axis == .horizontal ? (proposal.height ?? 0) : max(minimum, proposal.height ?? minimum))
    }

    func draw(in context: inout DrawingContext) {}
}
