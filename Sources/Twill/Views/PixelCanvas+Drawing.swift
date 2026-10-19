extension PixelCanvas {
    struct Drawing: PrimitiveDrawing {
        let pixelsPerCell: PixelSize
        let render: @MainActor (inout Context, PixelSize) -> Void

        func sizeThatFits(_ proposal: ProposedCellSize) -> CellSize {
            CellSize(width: proposal.width ?? 0, height: proposal.height ?? 0)
        }

        func draw(in context: inout DrawingContext) {
            let cells = context.regionSize
            guard cells.width > 0 && cells.height > 0 else { return }
            let size = PixelSize(
                width: cells.width * pixelsPerCell.width, height: cells.height * pixelsPerCell.height)
            var bitmap = Context(size: size)
            // Primitive drawing is synchronous on the UI actor, just like cell Canvas drawing.
            MainActor.assumeIsolated { render(&bitmap, size) }
            context.drawImage(bitmap.rgbaData, size: cells, format: .rgba(width: size.width, height: size.height))
        }
    }
}
