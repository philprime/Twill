struct TextFieldDescription {
    let drawing: TextDrawing
    let caretColumn: Int?
    let handle: @MainActor (KeyEvent) -> KeyPressResult
    let blur: @MainActor () -> Void
}
