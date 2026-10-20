/// Associates a terminal shortcut with the wrapped button's existing action.
public struct KeyboardShortcutView<Content: View>: View {
    /// Primitive content rendered directly by the runtime rather than through a composed body.
    public typealias Body = Never
    private let content: Content
    private let shortcuts: [KeyboardShortcut]

    init(content: Content, shortcuts: [KeyboardShortcut]) {
        self.content = content
        self.shortcuts = shortcuts
    }
}

extension View {
    /// Invokes this button's action when its exact key event is unhandled.
    /// Apply to a button or its modifiers. Labels are not changed automatically.
    public func keyboardShortcut(_ key: KeyEvent) -> KeyboardShortcutView<Self> {
        keyboardShortcut(KeyboardShortcut(key))
    }

    /// Attaches shortcut metadata that can also supply a menu or help-text hint.
    public func keyboardShortcut(_ shortcut: KeyboardShortcut) -> KeyboardShortcutView<Self> {
        keyboardShortcut([shortcut])
    }

    /// Associates alternative keys with the same button action. A matching event
    /// invokes the action once, even when the array contains duplicate keys.
    public func keyboardShortcut(_ shortcuts: [KeyboardShortcut]) -> KeyboardShortcutView<Self> {
        KeyboardShortcutView(content: self, shortcuts: shortcuts)
    }
}

extension KeyboardShortcutView: PrimitiveView {
    func makeDescription() -> ViewDescription { .keyboardShortcut(content, shortcuts) }
}
