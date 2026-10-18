/// Keyboard routing is scoped to the active pane or topmost modal sheet.
/// Controls and handlers get first refusal, before navigation changes focus.
@MainActor
extension ViewRenderer {
    func handle(_ key: KeyEvent) -> Bool {
        if let sheet = activeModalScope() {
            if sheet.handleDialogKey(key) { return true }
            // An ignored key cannot escape the presented scope to the base or application.
            _ = sheet.handleInScope(key, modal: true)
            return true
        }
        return handleInScope(key, modal: false)
    }

    private func handleInScope(_ key: KeyEvent, modal: Bool) -> Bool {
        guard let target = focusTarget() else {
            return route(
                key, from: modal ? sheetBranch ?? self : self, stoppingAt: modal ? self : nil,
                includeControls: false) == .handled
        }
        if handleTabShortcut(key, from: target, stoppingAt: modal ? self : nil) { return true }
        if handleControl(key, at: target, stoppingAt: modal ? self : nil) { return true }
        if route(key, from: target, stoppingAt: modal ? self : nil) == .handled { return true }
        return navigate(key, from: target)
    }

    private func handleControl(_ key: KeyEvent, at target: ViewRenderer, stoppingAt boundary: ViewRenderer?) -> Bool {
        guard let interaction = target.description?.controlInteraction else { return false }
        if interaction.handleFocusedKey(key, target.layoutState.size) == .handled { return true }
        return interaction.submitsOnEnter && key == .enter && submit(from: target, stoppingAt: boundary)
    }

    private func submit(from target: ViewRenderer, stoppingAt boundary: ViewRenderer?) -> Bool {
        var current: ViewRenderer? = target
        while let node = current {
            if case .submit(_, let action) = node.description {
                action()
                return true
            }
            if node === boundary { break }
            current = node.parent
        }
        return false
    }

    private func handleDescendantKey(_ key: KeyEvent, at target: ViewRenderer) -> KeyPressResult {
        target.description?.controlInteraction?.handleDescendantKey?(key, target.layoutState.size) ?? .ignored
    }

    private func route(
        _ key: KeyEvent, from target: ViewRenderer, stoppingAt boundary: ViewRenderer? = nil,
        includeControls: Bool = true
    ) -> KeyPressResult {
        // A handler can wrap a focusable view or be wrapped by it. Follow only
        // the single-child modifier chain so sibling controls do not receive keys.
        var child = target
        while child.retainedChildren.count == 1 {
            // List rows are presentation within one control, not a modifier chain
            // belonging to the focused control. Their count must not affect routing.
            if case .listSelection = child.description { break }
            if case .tabs = child.description { break }
            let descendant = child.retainedChildren[0]
            if case .focusable = descendant.description { break }
            if case .keyPress(_, let action) = descendant.description, action(key) == .handled {
                return .handled
            }
            if includeControls, handleDescendantKey(key, at: descendant) == .handled { return .handled }
            child = descendant
        }

        var node: ViewRenderer? = target
        while let current = node {
            if current.handleTabKey(key, focused: target) == .handled { return .handled }
            if case .keyPress(_, let action) = current.description, action(key) == .handled {
                return .handled
            }
            if current === boundary { break }
            node = current.parent
        }
        return .ignored
    }
}
