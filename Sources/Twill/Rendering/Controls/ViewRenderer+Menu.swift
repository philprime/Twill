@MainActor
extension ViewRenderer {
    /// An opener's base branch passes its own sheet, but never an unrelated modal.
    var menuAncestor: ViewRenderer? {
        var ancestor = parent
        var crossesOpenerSheet = isMenuOpener
        while let node = ancestor {
            if case .menu = node.description { return node }
            if case .menuOpener = node.description { crossesOpenerSheet = true }
            if case .sheet = node.description {
                guard crossesOpenerSheet else { return nil }
                crossesOpenerSheet = false
            }
            ancestor = node.parent
        }
        return nil
    }

    private var isMenuOpener: Bool {
        var ancestor: ViewRenderer? = self
        while let node = ancestor {
            if case .menuOpener = node.description { return true }
            if case .sheet = node.description { return false }
            if case .menu = node.description { return false }
            ancestor = node.parent
        }
        return false
    }

    var menuButtonSuffix: String? {
        guard case .button(let button) = description, let scope = menuAncestor else { return nil }
        var shortcuts = button.shortcuts
        var ancestor = parent
        while let node = ancestor, node !== scope {
            if case .keyboardShortcut(_, let alternatives) = node.description {
                if node.shortcutButton(requiringEnabled: false) === self { shortcuts += alternatives }
            }
            ancestor = node.parent
        }
        let hints = shortcuts.map(\.hint).joined(separator: "/")
        return (hints.isEmpty ? "" : "  [\(hints)]") + (isMenuOpener ? "  ▸" : "") + (isEnabled ? "" : " (disabled)")
    }

    func openSubmenu(_ key: KeyEvent) -> Bool {
        guard key == .arrowRight, isEnabled, case .menuOpener = description, menuAncestor != nil,
            let button = shortcutButton()
        else { return false }
        button.activateButton()
        return true
    }
}
