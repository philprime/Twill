/// Visibility is resolved after measuring, using cached placements. List selection
/// can request reveal even when keyboard focus belongs to another pane.
extension ViewRenderer {
    func revealFocus(_ focused: ViewRenderer?) {
        if case .scroll = description {
            let revealed = revealListSelection(focused: focused)
            if !revealed, scrollFollowsFocus, let focused, focused !== self { reveal(focused) }
        }
        for child in activeChildren { child.revealFocus(focused) }
    }

    func reveal(_ focused: ViewRenderer) {
        guard let rect = bounds(of: focused, column: 0, row: 0) else { return }
        if rect.row < scrollOffset {
            scrollOffset = rect.row
        } else if rect.row + rect.height > scrollOffset + measuredSize.height {
            scrollOffset = rect.row + rect.height - measuredSize.height
        }
        scrollOffset = min(max(0, scrollOffset), max(0, scrollContentHeight - measuredSize.height))
    }

    func bounds(of target: ViewRenderer, column: Int, row: Int) -> CellRect? {
        for placement in placements {
            let bounds = placement.bounds
            let originX = column + bounds.column
            let originY = row + bounds.row
            var ancestor: ViewRenderer? = placement.node
            while let node = ancestor {
                if node === target {
                    return CellRect(column: originX, row: originY, width: bounds.width, height: bounds.height)
                }
                if node === self { break }
                ancestor = node.parent
            }
            if let found = placement.node.bounds(of: target, column: originX, row: originY) { return found }
        }
        return nil
    }
}
