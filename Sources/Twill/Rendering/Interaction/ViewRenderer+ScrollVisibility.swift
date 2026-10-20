/// Visibility is resolved after measuring, using cached placements. List selection
/// can request reveal even when keyboard focus belongs to another pane.
extension ViewRenderer {
    func resumeFocusFollowing() {
        // Viewports own offsets independently of the pane containing the control.
        // Resume only its ancestor viewports, leaving sibling manual scrolling alone.
        var ancestor: ViewRenderer? = self
        while let node = ancestor {
            if case .scroll = node.description { node.scrollState.followFocus() }
            if case .sheet(let sheet) = node.description, sheet.isPresented.wrappedValue { break }
            ancestor = node.parent
        }
    }

    func revealFocus(_ focused: ViewRenderer?) {
        if case .scroll = description {
            let revealed = revealListSelection(focused: focused)
            if !revealed, scrollState.followsFocus, let focused, focused !== self { reveal(focused) }
        }
        for child in presentationChildren { child.revealFocus(focused) }
    }

    func reveal(_ focused: ViewRenderer) {
        guard let rect = bounds(of: focused, column: 0, row: 0) else { return }
        scrollState.reveal(rect, viewport: layoutState.size)
    }

    func bounds(of target: ViewRenderer, column: Int, row: Int, includingAllLayoutItems: Bool = false) -> CellRect? {
        var result: CellRect?
        for placement in layoutState.placements {
            let bounds = placement.bounds
            let originX = column + bounds.column
            let originY = row + bounds.row
            var ancestor: ViewRenderer? = placement.node
            var found: CellRect?
            while let node = ancestor {
                if node === target {
                    found = CellRect(column: originX, row: originY, width: bounds.width, height: bounds.height)
                    break
                }
                if node === self { break }
                ancestor = node.parent
            }
            if found == nil {
                found = placement.node.bounds(
                    of: target, column: originX, row: originY,
                    includingAllLayoutItems: includingAllLayoutItems)
            }
            if let found {
                if !includingAllLayoutItems { return found }
                result = result.map { $0.union(found) } ?? found
            }
        }
        return result
    }
}
