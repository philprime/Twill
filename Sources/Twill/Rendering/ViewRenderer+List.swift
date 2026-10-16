/// Lists share pane layout and scrolling, but reveal selection rather than focus.
extension ViewRenderer {
    struct ListReveal: Equatable {
        let selection: AnyHashable?
        let bounds: CellRect?
        let viewport: CellSize
    }

    func revealListSelection() -> Bool {
        guard let content = children.first,
            case .listSelection(_, let selection, _) = content.description
        else { return false }
        let row = selection.flatMap { content.keyedNode(for: $0) }
        let updated = ListReveal(
            selection: selection,
            bounds: row.flatMap { bounds(of: $0, column: 0, row: 0) },
            viewport: measuredSize)
        // Manual scrolling persists until selection or layout changes. Selection
        // changes still reveal the row when keyboard focus is in another pane.
        if let row, listReveal != updated { reveal(row) }
        listReveal = updated
        return true
    }
}
