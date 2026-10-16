/// Keyboard routing is scoped to the active pane or topmost modal sheet.
@MainActor
extension ViewRenderer {
    func handle(_ key: KeyEvent) -> Bool {
        if let sheet = activeSheet() {
            if sheet.handleDialogKey(key) { return true }
            // An ignored key cannot escape the presented scope to the base or application.
            _ = sheet.handleInScope(key, modal: true)
            return true
        }
        return handleInScope(key, modal: false)
    }

    private func handleInScope(_ key: KeyEvent, modal: Bool) -> Bool {
        let panes = scrollPanes()
        guard let target = focusTarget() else {
            return route(
                key, from: modal ? sheetBranch ?? self : self, stoppingAt: modal ? self : nil,
                includeControls: false) == .handled
        }
        let pane = panes.first { $0.contains(target) }
        let targets = pane?.focusableNodes() ?? focusableNodes()
        if handleTabShortcut(key, from: target, stoppingAt: modal ? self : nil) { return true }
        if handleControl(key, at: target, stoppingAt: modal ? self : nil) { return true }
        if route(key, from: target, stoppingAt: modal ? self : nil) == .handled { return true }

        if let pane, key == .tab || key == .shiftTab {
            return switchPane(key, from: pane, in: panes)
        }
        if let pane, target === pane || key == .pageDown || key == .pageUp {
            return scrollViewer(key, pane: pane)
        }
        return moveFocus(key, from: target, in: targets, pane: pane)
    }

    private func handleControl(_ key: KeyEvent, at target: ViewRenderer, stoppingAt boundary: ViewRenderer?) -> Bool {
        switch target.description {
        case .textField(let field):
            if field.handle(key) == .handled { return true }
            return key == .enter && submit(from: target, stoppingAt: boundary)
        case .textEditor(let editor):
            return editor.handle(key, target.measuredSize.height) == .handled
        case .listSelection(_, _, let handle):
            if handle(key) == .handled { return true }
            return key == .enter && submit(from: target, stoppingAt: boundary)
        default:
            return false
        }
    }

    private func switchPane(_ key: KeyEvent, from pane: ViewRenderer, in panes: [ViewRenderer]) -> Bool {
        guard let index = panes.firstIndex(where: { $0 === pane }) else { return false }
        let next = index + (key == .tab ? 1 : -1)
        guard panes.indices.contains(next) else { return false }
        activePane = panes[next]
        presentFocus(panes[next].resolveFocus(in: panes[next].focusableNodes()))
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
        pane.scrollFollowsFocus = false
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
        let next = target.tabFocusDestination(fallingBackTo: targets[destination])
        if let pane {
            pane.focusedNode = next
            pane.scrollFollowsFocus = true
            pane.revealFocus(next)
        } else {
            focusedNode = next
        }
        presentFocus(next)
        // Redraw cached descriptions, not view bodies or timeline schedules.
        requestFocusPresentation()
        return true
    }

    func focusTarget() -> ViewRenderer? {
        let panes = scrollPanes()
        let target: ViewRenderer?
        if let requested = requestedFocus(excluding: presentedFocus) ?? requestedFocus() {
            clearedFocusBinding = nil
            let targets = requested.focusableNodes()
            if let pane = panes.first(where: { requested.contains($0) || $0.contains(requested) }) {
                activePane = pane
                let remembered = pane.focusedNode
                target =
                    remembered.flatMap { candidate in targets.contains { $0 === candidate } ? candidate : nil }
                    ?? targets.first
                pane.focusedNode = target
                if presentedFocus !== target { pane.scrollFollowsFocus = true }
            } else {
                target =
                    focusedNode.flatMap { candidate in targets.contains { $0 === candidate } ? candidate : nil }
                    ?? targets.first
                focusedNode = target
            }
        } else if let cleared = clearedBinding(from: presentedFocus) ?? clearedFocusBinding {
            clearedFocusBinding = cleared
            target = nil
        } else if let remembered = rememberedFocus(outside: panes) {
            target = remembered
        } else if let pane = resolvePane(in: panes) {
            target = pane.resolveFocus(in: pane.focusableNodes())
        } else {
            target = resolveFocus(in: focusableNodes())
        }
        presentFocus(target)
        return target
    }

    func restoreFocusAfterSheetDismissal() {
        // Modal bindings may share storage with the base screen. Their writes are
        // not explicit requests to clear the enclosing screen's remembered focus.
        var current: ViewRenderer? = self
        while let node = current {
            node.presentedFocus = nil
            node.clearedFocusBinding = nil
            current = node.parent
        }
    }

    func restoreFocusAfterTabChange(from previous: ViewRenderer?, to selected: ViewRenderer?) {
        guard let previous else { return }
        var ancestor: ViewRenderer? = self
        while let scope = ancestor {
            if let focused = scope.presentedFocus, previous.contains(focused) {
                let target = selected.flatMap { $0.resolveFocus(in: $0.focusableNodes()) } ?? self
                scope.focusedNode = target
                scope.activePane = selected?.activePane
                scope.clearedFocusBinding = nil
                scope.presentFocus(target)
            }
            ancestor = scope.parent
        }
    }

    private func requestedFocus(excluding currentTarget: ViewRenderer? = nil) -> ViewRenderer? {
        if case .sheet = description { return sheetBranch?.requestedFocus(excluding: currentTarget) }
        // Bindings on the current focus path report existing focus. A different
        // activated binding is a new request, even when it follows them in tree order.
        if case .focusBinding(_, let binding) = description, binding.isFocused() {
            if currentTarget.map({ !contains($0) }) ?? true { return self }
        }
        return activeChildren.lazy.compactMap { $0.requestedFocus(excluding: currentTarget) }.first
    }

    private func clearedBinding(from target: ViewRenderer?) -> ViewRenderer? {
        var current = target
        while let node = current, node !== self {
            if case .focusBinding(_, let binding) = node.description, !binding.isFocused() { return node }
            current = node.parent
        }
        if case .focusBinding(_, let binding) = description, !binding.isFocused(), target != nil { return self }
        return nil
    }

    private func contains(_ node: ViewRenderer) -> Bool {
        var current: ViewRenderer? = node
        while let candidate = current {
            if candidate === self { return true }
            current = candidate.parent
        }
        return false
    }

    private func presentFocus(_ target: ViewRenderer?) {
        guard presentedFocus !== target else { return }
        if case .textField(let field) = presentedFocus?.description { field.blur() }
        presentedFocus = target
        var ancestor = target
        var pane: ViewRenderer?
        while let node = ancestor {
            if case .scroll = node.description { pane = node }
            if case .tab = node.description {
                node.focusedNode = target
                node.activePane = pane
            }
            ancestor = node.parent
        }
        // Shared ancestor and descendant bindings must settle once per focus transition,
        // not rewrite each other's values on every presentation.
        updateFocusBindings(target)
    }

    private func updateFocusBindings(_ target: ViewRenderer?) {
        if case .sheet = description {
            sheetBranch?.updateFocusBindings(target)
            return
        }
        if case .focusBinding(_, let binding) = description {
            binding.setFocused(target.map { contains($0) } ?? false)
        }
        for child in activeChildren { child.updateFocusBindings(target) }
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

    private func rememberedFocus(outside panes: [ViewRenderer]) -> ViewRenderer? {
        guard let focusedNode, focusableNodes().contains(where: { $0 === focusedNode }) else { return nil }
        return panes.contains(where: { $0.contains(focusedNode) }) ? nil : focusedNode
    }

    private func resolvePane(in panes: [ViewRenderer]) -> ViewRenderer? {
        if let activePane, panes.contains(where: { $0 === activePane }) { return activePane }
        activePane = panes.first
        return activePane
    }

    private func scrollPanes() -> [ViewRenderer] {
        if case .sheet = description { return sheetBranch?.scrollPanes() ?? [] }
        if case .scroll = description { return [self] }
        if case .textEditor = description { return [self] }
        return activeChildren.flatMap { $0.scrollPanes() }
    }

    func requestFocusPresentation() {
        if let parent { parent.requestFocusPresentation() } else { onInvalidation?() }
    }

    func resolveFocus(in targets: [ViewRenderer]) -> ViewRenderer? {
        if let focusedNode, targets.contains(where: { $0 === focusedNode }) { return focusedNode }
        // Prefer cancellation on first presentation without changing the supplied
        // action order or using public focus state for an internal modal policy.
        let dialog = sheetBranch?.dialogScope() ?? dialogScope()
        focusedNode =
            dialog == nil ? targets.first : targets.first { $0.enclosingButton?.buttonRole == .cancel } ?? targets.first
        scrollFollowsFocus = true
        return focusedNode
    }

    func focusableNodes() -> [ViewRenderer] {
        if case .sheet = description { return sheetBranch?.focusableNodes() ?? [] }
        let descendants = activeChildren.flatMap { $0.focusableNodes() }
        switch description {
        case .listSelection: return [self]
        case .tabs: return hasTabBar ? [self] + descendants : []
        case .focusable, .textField, .textEditor: return [self] + descendants
        case .scroll where descendants.isEmpty: return [self]
        default: return descendants
        }
    }

    private func handleEditingKey(_ key: KeyEvent, at target: ViewRenderer) -> KeyPressResult {
        switch target.description {
        case .textField(let field): return field.handle(key)
        case .textEditor(let editor): return editor.handle(key, target.measuredSize.height)
        default: return .ignored
        }
    }

    private func route(
        _ key: KeyEvent, from target: ViewRenderer, stoppingAt boundary: ViewRenderer? = nil,
        includeControls: Bool = true
    ) -> KeyPressResult {
        // A handler can wrap a focusable view or be wrapped by it. Follow only
        // the single-child modifier chain so sibling controls do not receive keys.
        var child = target
        while child.children.count == 1 {
            // List rows are presentation within one control, not a modifier chain
            // belonging to the focused control. Their count must not affect routing.
            if case .listSelection = child.description { break }
            if case .tabs = child.description { break }
            let descendant = child.children[0]
            if case .focusable = descendant.description { break }
            if case .keyPress(_, let action) = descendant.description, action(key) == .handled {
                return .handled
            }
            if includeControls, handleEditingKey(key, at: descendant) == .handled { return .handled }
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
