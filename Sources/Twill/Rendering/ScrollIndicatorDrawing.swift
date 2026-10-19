/// Integer geometry has no timers or mutable viewport ownership.
struct ScrollIndicatorDrawing {
    let offset: Int
    let contentHeight: Int

    func draw(in context: inout DrawingContext, size: CellSize) {
        guard size.width > 0, size.height > 0 else { return }
        let height = size.height
        let thumbHeight = contentHeight > height ? max(1, height * height / contentHeight) : height
        let travel = height - thumbHeight
        let range = max(0, contentHeight - height)
        let start = range > 0 ? min(max(0, offset), range) * travel / range : 0
        for row in 0..<height {
            let thumb = row >= start && row < start + thumbHeight
            context.draw(
                thumb ? "█" : "│", width: ScrollIndicatorVisibility.columnWidth,
                column: size.width - ScrollIndicatorVisibility.columnWidth, row: row)
        }
    }
}
