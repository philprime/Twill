/// A key and its display hint. Menu shortcuts are active only while the menu is open.
/// Enter and Escape retain their activation and dismissal behavior.
public struct MenuShortcut: Sendable {
    public let key: KeyEvent
    public let hint: String

    public init(_ key: KeyEvent, hint: String) {
        self.key = key
        self.hint = hint
    }
}
