/// Viewport memory stays mounted even though editor sizing and drawing use snapshots.
extension ViewRenderer {
    func updateEditorViewport(_ editor: TextEditorDescription) {
        let snapshot = editor.snapshot
        let layout = snapshot.layout(width: layoutState.size.width)
        editorState.reveal(
            caret: layout.position(at: snapshot.caret, upstream: snapshot.upstream), viewport: layoutState.size,
            content: CellSize(width: layout.width, height: layout.lines.count))
    }
}
