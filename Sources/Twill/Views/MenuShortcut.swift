/// A key and its display hint. Menu shortcuts are active only while the menu is open.
/// Enter and Escape retain their activation and dismissal behavior.
public struct MenuShortcut: Sendable {
    /// The key event that invokes the associated menu action.
    public let key: KeyEvent
    /// The human-readable shortcut hint displayed beside the action.
    public let hint: String

    /// Pairs an exact key event with its display hint.
    public init(_ key: KeyEvent, hint: String) {
        self.key = key
        self.hint = hint
    }
}
