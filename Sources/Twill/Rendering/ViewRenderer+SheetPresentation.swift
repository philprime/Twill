/// Draws the retained page and each modal sheet into one viewport-sized frame.
@MainActor
extension ViewRenderer {
    var sheetBranch: ViewRenderer? {
        guard case .sheet(_, let isPresented, _) = description else { return nil }
        return isPresented.wrappedValue ? children.dropFirst().first : children.first
    }

    func activeSheet() -> ViewRenderer? {
        if case .sheet(_, let isPresented, _) = description {
            guard let branch = sheetBranch else { return nil }
            return branch.activeSheet() ?? (isPresented.wrappedValue ? self : nil)
        }
        for child in children.reversed() {
            if let sheet = child.activeSheet() { return sheet }
        }
        return nil
    }

    func drawOverlay(sheet: ViewRenderer, proposal: ProposedCellSize) -> CellGrid? {
        // Walk from the outermost modal layer so nested sheets retain their
        // enclosing presentation underneath the active keyboard scope.
        var outer = sheet
        var ancestor = sheet.parent
        while let current = ancestor {
            if case .sheet(_, let presented, _) = current.description, presented.wrappedValue {
                outer = current
            }
            ancestor = current.parent
        }
        var layers: [ViewRenderer] = []
        var current: ViewRenderer? = outer
        while let sheet = current, let base = sheet.children.first {
            layers.append(base)
            guard let presented = sheet.children.dropFirst().first else { break }
            layers.append(presented)
            if let nested = presented.activeSheet(), nested !== sheet {
                current = nested
            } else {
                break
            }
        }
        guard let base = layers.first else { return nil }
        let baseSize = base.measure(proposal)
        let overlays = layers.dropFirst().map { ($0, $0.measure(.unspecified)) }
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
