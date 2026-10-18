/// Lists share pane layout and scrolling, but reveal selection rather than focus.
extension ViewRenderer {
    func revealListSelection(focused: ViewRenderer?) -> Bool {
        var selectedContent: ViewRenderer?
        for child in children {
            if let content = child.selectionContent() {
                selectedContent = content
                break
            }
        }
        guard let content = selectedContent,
            case .listSelection(_, let selection, _) = content.description
        else { return false }
        // A table's headers share its pane. Reveal a focused header instead of
        // moving it out of view to reveal the independently selected row.
        if let focused, contains(focused), !content.contains(focused) {
            scrollState.listReveal = nil
            return false
        }
        let row = selection.flatMap { content.keyedNode(for: $0) }
        let updated = MountedScrollState.ListReveal(
            selection: selection,
            bounds: row.flatMap { bounds(of: $0, column: 0, row: 0) },
            viewport: layoutState.size)
        // Manual scrolling persists until selection or layout changes. Selection
        // changes still reveal the row when keyboard focus is in another pane.
        if let row, scrollState.listReveal != updated { reveal(row) }
        scrollState.listReveal = updated
        return true
    }

    private func selectionContent() -> ViewRenderer? {
        if case .listSelection = description { return self }
        if case .scroll = description { return nil }
        for child in children {
            if let content = child.selectionContent() { return content }
        }
        return nil
    }
}
