/// Cell geometry is resolved before host-owned graphics encoding.
struct ImageDrawing: PrimitiveDrawing {
    let image: Image
    let size: CellSize
    let contentMode: ImageContentMode
    let cellHeightToWidth: Double

    func sizeThatFits(_ proposal: ProposedCellSize) -> CellSize { proposal.constrain(size) }

    func draw(in context: inout DrawingContext) {
        let bounds = CellSize(
            width: min(size.width, context.regionSize.width),
            height: min(size.height, context.regionSize.height))
        guard bounds.width > 0, bounds.height > 0 else { return }
        let fitted = fittedSize(in: bounds)
        let rect = CellRect(
            column: (bounds.width - fitted.width) / 2, row: (bounds.height - fitted.height) / 2,
            width: fitted.width, height: fitted.height)
        context.withRegion(rect) { $0.drawImage(image.data, size: fitted) }
    }

    private func fittedSize(in bounds: CellSize) -> CellSize {
        if case .stretch = contentMode { return bounds }
        let height = Double(bounds.width) * Double(image.pixelHeight) / Double(image.pixelWidth) / cellHeightToWidth
        if height <= Double(bounds.height) {
            let rows = height >= Double(bounds.height) ? bounds.height : max(1, Int(height))
            return CellSize(width: bounds.width, height: rows)
        }
        let width = Double(bounds.height) * cellHeightToWidth * Double(image.pixelWidth) / Double(image.pixelHeight)
        let columns = width >= Double(bounds.width) ? bounds.width : max(1, Int(width))
        return CellSize(width: columns, height: bounds.height)
    }
}
