@MainActor
extension ViewRenderer {
    func handleKeyboardShortcut(_ key: KeyEvent, from target: ViewRenderer?) -> Bool {
        // Nearest enclosing content wins. Walking the mounted tree instead of
        // registering closures keeps branch lifetime and disabled state authoritative.
        var ancestor: ViewRenderer? = target ?? self
        while let scope = ancestor {
            if let button = scope.matchingShortcutButton(key) {
                button.activateButton()
                return true
            }
            if scope === self { break }
            ancestor = scope.parent
        }
        return false
    }

    private func matchingShortcutButton(_ key: KeyEvent) -> ViewRenderer? {
        guard isEnabled else { return nil }
        if case .button(let button) = description, button.shortcuts.contains(where: { $0.key == key }) { return self }
        if case .keyboardShortcut(_, let shortcuts) = description {
            if shortcuts.contains(where: { $0.key == key }), let button = shortcutButton() { return button }
        }
        for child in interactionChildren {
            if let button = child.matchingShortcutButton(key) { return button }
        }
        return nil
    }

    private func shortcutButton() -> ViewRenderer? {
        guard isEnabled else { return nil }
        if case .button = description { return self }
        // Modifiers can wrap the action, but a container of multiple controls
        // must not accidentally assign its shortcut to an arbitrary descendant.
        let children = interactionChildren
        guard children.count == 1 else { return nil }
        return children[0].shortcutButton()
    }
}
