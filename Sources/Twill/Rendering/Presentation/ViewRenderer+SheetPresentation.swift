/// Draws the retained page and each modal sheet into one viewport-sized frame.
@MainActor
extension ViewRenderer {
    func drawOverlay(sheet: ViewRenderer, proposal: ProposedCellSize) -> CellGrid? {
        // Collect every active ancestor rather than jumping to the deepest sheet.
        // Nested bases occupy their normal slots in the enclosing presented layer.
        var base: ViewRenderer?
        var layers: [ViewRenderer] = []
        var ancestor: ViewRenderer? = sheet
        while let current = ancestor {
            if case .sheet(let sheet) = current.description, sheet.isPresented.wrappedValue {
                base = current.retainedChildren.first
                if let content = current.retainedChildren.dropFirst().first { layers.append(content) }
            }
            ancestor = current.parent
        }
        guard let base else { return nil }
        let baseSize = base.measure(proposal)
        let overlays = layers.reversed().map { ($0, $0.measure(.unspecified)) }
        let size = CellSize(
            width: proposal.width ?? max(baseSize.width, overlays.map { $0.1.width }.max() ?? 0),
            height: proposal.height ?? max(baseSize.height, overlays.map { $0.1.height }.max() ?? 0)
        )
        var context = DrawingContext(size: size)
        base.draw(in: &context, focused: nil)
        let focused = sheet.focusTarget()
        for (layer, layerSize) in overlays {
            let position = CellRect(
                column: max(0, (size.width - layerSize.width) / 2),
                row: max(0, (size.height - layerSize.height) / 2),
                width: layerSize.width, height: layerSize.height
            )
            layer.revealFocus(focused)
            context.withRegion(position) { layer.draw(in: &$0, focused: focused) }
        }
        caretPosition = context.caret
        return context.grid
    }
}
