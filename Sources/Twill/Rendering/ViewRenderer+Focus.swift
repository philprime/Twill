/// Keyboard routing is scoped to the active pane or topmost modal sheet.
@MainActor
extension ViewRenderer {
    func handle(_ key: KeyEvent) -> Bool {
        if let sheet = activeSheet() {
            // An ignored key cannot escape the presented scope to the base or application.
            _ = sheet.handleInScope(key, modal: true)
            return true
        }
        return handleInScope(key, modal: false)
    }

    private func handleInScope(_ key: KeyEvent, modal: Bool) -> Bool {
        let panes = scrollPanes()
        let pane = panes.isEmpty ? nil : resolvePane(in: panes)
        let targets = pane?.focusableNodes() ?? focusableNodes()
        guard let target = pane?.resolveFocus(in: targets) ?? resolveFocus(in: targets) else {
            return route(key, from: modal ? sheetBranch ?? self : self, stoppingAt: modal ? self : nil) == .handled
        }
        if case .textField(let field) = target.description, field.handle(key) == .handled { return true }
        if route(key, from: target, stoppingAt: modal ? self : nil) == .handled { return true }

        if let pane, key == .tab || key == .shiftTab {
            return switchPane(key, from: pane, in: panes)
        }
        if let pane, target === pane {
            return scrollViewer(key, pane: pane)
        }
        return moveFocus(key, from: target, in: targets, pane: pane)
    }

    private func switchPane(_ key: KeyEvent, from pane: ViewRenderer, in panes: [ViewRenderer]) -> Bool {
        guard let index = panes.firstIndex(where: { $0 === pane }) else { return false }
        let next = index + (key == .tab ? 1 : -1)
        guard panes.indices.contains(next) else { return false }
        activePane = panes[next]
        requestFocusPresentation()
        return true
    }

    private func scrollViewer(_ key: KeyEvent, pane: ViewRenderer) -> Bool {
        let distance: Int
        switch key {
        case .arrowDown: distance = 1
        case .arrowUp: distance = -1
        case .pageDown: distance = max(1, pane.measuredSize.height)
        case .pageUp: distance = -max(1, pane.measuredSize.height)
        default: return false
        }
        let offset = min(
            max(0, pane.scrollOffset + distance), max(0, pane.scrollContentHeight - pane.measuredSize.height))
        guard offset != pane.scrollOffset else { return false }
        pane.scrollOffset = offset
        requestFocusPresentation()
        return true
    }

    private func moveFocus(
        _ key: KeyEvent, from target: ViewRenderer, in targets: [ViewRenderer], pane: ViewRenderer?
    ) -> Bool {
        guard let index = targets.firstIndex(where: { $0 === target }) else { return false }
        let destination: Int
        switch key {
        case .arrowDown, .arrowRight: destination = index + 1
        case .arrowUp, .arrowLeft: destination = index - 1
        default: return false
        }
        guard targets.indices.contains(destination) else { return false }
        if let pane {
            pane.focusedNode = targets[destination]
            pane.revealFocus(targets[destination])
        } else {
            focusedNode = targets[destination]
        }
        // Redraw cached descriptions, not view bodies or timeline schedules.
        requestFocusPresentation()
        return true
    }

    func focusTarget() -> ViewRenderer? {
        let panes = scrollPanes()
        if let pane = resolvePane(in: panes) {
            return pane.resolveFocus(in: pane.focusableNodes())
        }
        return resolveFocus(in: focusableNodes())
    }

    private func resolvePane(in panes: [ViewRenderer]) -> ViewRenderer? {
        if let activePane, panes.contains(where: { $0 === activePane }) { return activePane }
        activePane = panes.first
        return activePane
    }

    private func scrollPanes() -> [ViewRenderer] {
        if case .sheet = description { return sheetBranch?.scrollPanes() ?? [] }
        if case .scroll = description { return [self] }
        return children.flatMap { $0.scrollPanes() }
    }

    func requestFocusPresentation() {
        if let parent { parent.requestFocusPresentation() } else { onInvalidation?() }
    }

    func resolveFocus(in targets: [ViewRenderer]) -> ViewRenderer? {
        if let focusedNode, targets.contains(where: { $0 === focusedNode }) { return focusedNode }
        focusedNode = targets.first
        return focusedNode
    }

    func focusableNodes() -> [ViewRenderer] {
        if case .sheet = description { return sheetBranch?.focusableNodes() ?? [] }
        let descendants = children.flatMap { $0.focusableNodes() }
        switch description {
        case .focusable, .textField: return [self] + descendants
        case .scroll where descendants.isEmpty: return [self]
        default: return descendants
        }
    }

    private func route(
        _ key: KeyEvent, from target: ViewRenderer, stoppingAt boundary: ViewRenderer? = nil
    ) -> KeyPressResult {
        // A handler can wrap a focusable view or be wrapped by it. Follow only
        // the single-child modifier chain so sibling controls do not receive keys.
        var child = target
        while child.children.count == 1 {
            let descendant = child.children[0]
            if case .focusable = descendant.description { break }
            if case .keyPress(_, let action) = descendant.description, action(key) == .handled {
                return .handled
            }
            if case .textField(let field) = descendant.description, field.handle(key) == .handled {
                return .handled
            }
            child = descendant
        }

        var node: ViewRenderer? = target
        while let current = node {
            if case .keyPress(_, let action) = current.description, action(key) == .handled {
                return .handled
            }
            if current === boundary { break }
            node = current.parent
        }
        return .ignored
    }
}
