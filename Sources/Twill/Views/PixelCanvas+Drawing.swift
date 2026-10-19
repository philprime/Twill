extension PixelCanvas {
    struct Drawing: PrimitiveDrawing {
        let pixelsPerCell: PixelSize
        let render: @MainActor (Context, PixelSize) -> Void

        func sizeThatFits(_ proposal: ProposedCellSize) -> CellSize {
            CellSize(width: proposal.width ?? 0, height: proposal.height ?? 0)
        }

        func draw(in context: inout DrawingContext) {
            let cells = context.regionSize
            guard cells.width > 0 && cells.height > 0 else { return }
            let size = PixelSize(
                width: cells.width * pixelsPerCell.width, height: cells.height * pixelsPerCell.height)
            // The callback can copy drawing state but cannot replace this destination.
            let data = MainActor.assumeIsolated {
                let surface = PixelSurface(size: size)
                render(Context(surface: surface), size)
                return surface.rgbaData
            }
            context.drawImage(data, size: cells, format: .rgba(width: size.width, height: size.height))
        }
    }
}
