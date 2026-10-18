/// Behavior supplied by a control description, without giving the control access to key traversal.
///
/// The mounted runtime supplies measured bounds and enforces modal boundaries and handler
/// precedence. Callbacks capture the control's bindings or mounted state locations, not a
/// second owner for its value. Ordinary composed controls use this contract, while structural
/// primitives still integrate explicitly with mounting, scheduling, and focus discovery.
@MainActor
struct ControlInteraction {
    let handleFocusedKey: @MainActor (KeyEvent, CellSize) -> KeyPressResult
    // A focusable modifier may wrap an editor. Only controls that opt in receive keys
    // along that single-child chain, so unrelated descendants do not handle focused input.
    let handleDescendantKey: (@MainActor (KeyEvent, CellSize) -> KeyPressResult)?
    let blur: (@MainActor () -> Void)?
    // Submission is router-owned fallback after a control ignores Enter. Multiline
    // editing and selection controls do not share the same submission policy.
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
