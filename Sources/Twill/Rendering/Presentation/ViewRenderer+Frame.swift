extension ViewRenderer {
    /// Layout and drawing never evaluate bodies or advance timeline deadlines.
    func drawFrame(proposal: ProposedCellSize, centeredInViewport: Bool = false) -> CellGrid? {
        prepareLayout()
        let sheet = activeModalScope()
        let content = sheet?.sheetBranch ?? self
        if let sheet { return drawOverlay(sheet: sheet, proposal: proposal) }
        guard !content.layoutItems.isEmpty else {
            caretPosition = nil
            return nil
        }
        let size = content.measure(proposal)
        let focused = focusTarget()
        let viewport =
            centeredInViewport
            ? CellSize(width: proposal.width ?? size.width, height: proposal.height ?? size.height) : size
        var context = DrawingContext(size: viewport)
        let origin = CellRect(
            column: max(0, (viewport.width - size.width) / 2),
            row: max(0, (viewport.height - size.height) / 2), width: size.width, height: size.height)
        content.revealFocus(focused)
        context.withRegion(origin) { content.draw(in: &$0, focused: focused) }
        caretPosition = context.caret
        return context.grid
    }

}
