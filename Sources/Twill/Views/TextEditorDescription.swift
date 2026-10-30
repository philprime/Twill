struct TextEditorDescription {
    let snapshot: TextEditorSnapshot
    let handle: @MainActor (KeyEvent, CellSize) -> KeyPressResult
}
