struct DividerDrawing: PrimitiveDrawing {
    let axis: Axis

    func sizeThatFits(_ proposal: ProposedCellSize) -> CellSize {
        proposal.constrain(
            axis == .horizontal
                ? CellSize(width: proposal.width ?? 1, height: 1)
                : CellSize(width: 1, height: proposal.height ?? 1))
    }

    func draw(in context: inout DrawingContext) {
        let length = axis == .horizontal ? context.regionSize.width : context.regionSize.height
        for offset in 0..<length {
            context.draw(
                axis == .horizontal ? "─" : "│", width: 1,
                column: axis == .horizontal ? offset : 0, row: axis == .vertical ? offset : 0)
        }
    }
}
