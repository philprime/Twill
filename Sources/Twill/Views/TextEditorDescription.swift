struct TextEditorDescription {
    let content: TextEditorContent
    let caret: CellPosition
    let handle: @MainActor (KeyEvent, Int) -> KeyPressResult
}
