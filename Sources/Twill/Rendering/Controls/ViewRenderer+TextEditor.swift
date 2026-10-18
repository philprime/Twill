/// Viewport memory stays mounted even though editor sizing and drawing use snapshots.
extension ViewRenderer {
    func updateEditorViewport(_ editor: TextEditorDescription) {
        editorState.reveal(
            caret: editor.caret, viewport: layoutState.size,
            content: CellSize(width: editor.content.width, height: editor.content.lines.count))
    }
}
