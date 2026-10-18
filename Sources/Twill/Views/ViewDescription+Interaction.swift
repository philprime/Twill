extension ViewDescription {
    /// Existing primitives adapt here so the router has no concrete editing-control knowledge.
    var controlInteraction: ControlInteraction? {
        switch self {
        case .control(_, let interaction):
            return interaction
        case .textField(let field):
            let handle: @MainActor (KeyEvent, CellSize) -> KeyPressResult = { key, _ in field.handle(key) }
            return ControlInteraction(
                handleFocusedKey: handle, handleDescendantKey: handle,
                blur: field.blur, submitsOnEnter: true)
        case .textEditor(let editor):
            let handle: @MainActor (KeyEvent, CellSize) -> KeyPressResult = { key, size in
                editor.handle(key, size.height)
            }
            return ControlInteraction(handleFocusedKey: handle, handleDescendantKey: handle)
        case .listSelection(_, _, let handle):
            return ControlInteraction(handleFocusedKey: { key, _ in handle(key) }, submitsOnEnter: true)
        default:
            return nil
        }
    }
}
