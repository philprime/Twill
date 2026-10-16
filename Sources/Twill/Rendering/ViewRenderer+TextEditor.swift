/// Editor viewport state belongs to the mounted control, not its view value.
extension ViewRenderer {
    func measureTextEditor(_ editor: TextEditorDescription, proposal: ProposedCellSize) -> CellSize {
        measuredSize = CellSize(
            width: proposal.width ?? editor.content.width,
            height: proposal.height ?? editor.content.lines.count)
        editorOffset = CellPosition(
            column: revealedEditorOffset(
                editorOffset.column, caret: editor.caret.column, viewport: measuredSize.width,
                extent: editor.content.width),
            row: revealedEditorOffset(
                editorOffset.row, caret: editor.caret.row, viewport: measuredSize.height,
                extent: editor.content.lines.count))
        return measuredSize
    }

    private func revealedEditorOffset(_ current: Int, caret: Int, viewport: Int, extent: Int) -> Int {
        let requested = min(caret, max(current, caret - max(1, viewport) + 1))
        return min(max(0, extent - viewport), max(0, requested))
    }

    func drawTextEditor(_ editor: TextEditorDescription, in context: inout DrawingContext, active: Bool) {
        guard measuredSize.width > 0, measuredSize.height > 0 else { return }
        context.withRegion(CellRect(origin: .zero, size: measuredSize)) { viewport in
            viewport.withFocus(active) { region in
                let end = min(editor.content.lines.count, editorOffset.row + measuredSize.height)
                for row in editorOffset.row..<end {
                    region.withRegion(
                        CellRect(
                            column: -editorOffset.column, row: row - editorOffset.row,
                            width: editor.content.width, height: 1)
                    ) { editor.content.lines[row].drawing.draw(in: &$0) }
                }
            }
            if active {
                viewport.placeCaret(
                    column: editor.caret.column - editorOffset.column, row: editor.caret.row - editorOffset.row)
            }
        }
    }
}
