/// An exact terminal key event and its human-readable display hint.
public struct KeyboardShortcut: Sendable {
    /// The key identity and terminal-reported modifiers required for activation.
    public let key: KeyEvent
    /// Generated key text, or the explicit hint supplied by the caller.
    public let hint: String

    /// Creates shortcut metadata shared by action modifiers, menus, and help text.
    /// Hints preserve character case and do not change how the key is matched.
    public init(_ key: KeyEvent, hint: String? = nil) {
        self.key = key
        self.hint = hint ?? key.shortcutHint
    }
}
