/// Editor viewport state belongs to the mounted control, not its view value.
extension ViewRenderer {
    func measureTextEditor(_ editor: TextEditorDescription, proposal: ProposedCellSize) -> CellSize {
        layoutState.size = CellSize(
            width: proposal.width ?? editor.content.width,
            height: proposal.height ?? editor.content.lines.count)
        editorState.reveal(
            caret: editor.caret, viewport: layoutState.size,
            content: CellSize(width: editor.content.width, height: editor.content.lines.count))
        return layoutState.size
    }

    func drawTextEditor(_ editor: TextEditorDescription, in context: inout DrawingContext, active: Bool) {
        guard layoutState.size.width > 0, layoutState.size.height > 0 else { return }
        context.withRegion(CellRect(origin: .zero, size: layoutState.size)) { viewport in
            viewport.withFocus(active) { region in
                let end = min(editor.content.lines.count, editorState.offset.row + layoutState.size.height)
                for row in editorState.offset.row..<end {
                    region.withRegion(
                        CellRect(
                            column: -editorState.offset.column, row: row - editorState.offset.row,
                            width: editor.content.width, height: 1)
                    ) { editor.content.lines[row].drawing.draw(in: &$0) }
                }
            }
            if active {
                viewport.placeCaret(
                    column: editor.caret.column - editorState.offset.column,
                    row: editor.caret.row - editorState.offset.row)
            }
        }
    }
}
