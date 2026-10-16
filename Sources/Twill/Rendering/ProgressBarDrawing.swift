struct ProgressBarDrawing: PrimitiveDrawing {
    let fraction: Double
    private static let intrinsicWidth = 20

    func sizeThatFits(_ proposal: ProposedCellSize) -> CellSize {
        proposal.constrain(CellSize(width: proposal.width ?? Self.intrinsicWidth, height: 1))
    }

    func draw(in context: inout DrawingContext) {
        let width = context.regionSize.width
        let filled = Int(Double(width) * fraction)
        for column in 0..<width {
            context.draw(column < filled ? "━" : "─", width: 1, column: column, row: 0)
        }
    }
}
