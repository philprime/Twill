/// Control behavior is independent of key traversal and receives mounted bounds explicitly.
@MainActor
struct ControlInteraction {
    let handleFocusedKey: @MainActor (KeyEvent, CellSize) -> KeyPressResult
    let handleDescendantKey: (@MainActor (KeyEvent, CellSize) -> KeyPressResult)?
    let blur: (@MainActor () -> Void)?
    let submitsOnEnter: Bool

    init(
        handleFocusedKey: @escaping @MainActor (KeyEvent, CellSize) -> KeyPressResult,
        handleDescendantKey: (@MainActor (KeyEvent, CellSize) -> KeyPressResult)? = nil,
        blur: (@MainActor () -> Void)? = nil,
        submitsOnEnter: Bool = false
    ) {
        self.handleFocusedKey = handleFocusedKey
        self.handleDescendantKey = handleDescendantKey
        self.blur = blur
        self.submitsOnEnter = submitsOnEnter
    }
}
