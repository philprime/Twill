/// Viewport memory for one mounted editor, separate from the edited value and caret state.
/// Recreating a description must not reset which cells are visible. Measurement reveals the
/// current caret against new bounds, while replacing mounted identity starts with fresh memory.
struct MountedEditorState {
    private(set) var offset = CellPosition.zero

    mutating func reveal(caret: CellPosition, viewport: CellSize, content: CellSize) {
        offset = CellPosition(
            column: revealedOffset(offset.column, caret: caret.column, viewport: viewport.width, extent: content.width),
            row: revealedOffset(offset.row, caret: caret.row, viewport: viewport.height, extent: content.height))
    }

    private func revealedOffset(_ current: Int, caret: Int, viewport: Int, extent: Int) -> Int {
        let requested = min(caret, max(current, caret - max(1, viewport) + 1))
        return min(max(0, extent - viewport), max(0, requested))
    }
}
