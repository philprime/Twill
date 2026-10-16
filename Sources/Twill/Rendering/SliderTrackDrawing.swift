struct SliderTrackDrawing: PrimitiveDrawing {
    let fraction: Double
    private static let intrinsicWidth = 20

    func sizeThatFits(_ proposal: ProposedCellSize) -> CellSize {
        proposal.constrain(CellSize(width: proposal.width ?? Self.intrinsicWidth, height: 1))
    }

    func draw(in context: inout DrawingContext) {
        let width = context.regionSize.width
        guard width > 0 else { return }
        let thumb = Int((Double(width - 1) * fraction).rounded())
        for column in 0..<width {
            let glyph: Character = column == thumb ? "●" : (column < thumb ? "━" : "─")
            context.draw(glyph, width: 1, column: column, row: 0)
        }
    }
}
