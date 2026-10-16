/// Lists share pane layout and scrolling, but reveal selection rather than focus.
extension ViewRenderer {
    struct ListReveal: Equatable {
        let selection: AnyHashable?
        let bounds: CellRect?
        let viewport: CellSize
    }

    func revealListSelection(focused: ViewRenderer?) -> Bool {
        guard let content = children.lazy.compactMap({ $0.selectionContent() }).first,
            case .listSelection(_, let selection, _) = content.description
        else { return false }
        // A table's headers share its pane. Reveal a focused header instead of
        // moving it out of view to reveal the independently selected row.
        if let focused, contains(focused), !content.contains(focused) {
            listReveal = nil
            return false
        }
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

    private func selectionContent() -> ViewRenderer? {
        if case .listSelection = description { return self }
        if case .scroll = description { return nil }
        return children.lazy.compactMap { $0.selectionContent() }.first
    }
}
