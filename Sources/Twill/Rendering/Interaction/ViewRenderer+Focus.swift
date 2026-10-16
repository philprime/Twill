/// Resolves focus requests against mounted identity and synchronizes focus bindings.
/// Remembered targets are weak and must still belong to the active scope before reuse.
@MainActor
extension ViewRenderer {
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

    func contains(_ node: ViewRenderer) -> Bool {
        var current: ViewRenderer? = node
        while let candidate = current {
            if candidate === self { return true }
            current = candidate.parent
        }
        return false
    }

    func presentFocus(_ target: ViewRenderer?) {
        guard presentedFocus !== target else { return }
        if case .textField(let field) = presentedFocus?.description { field.blur() }
        presentedFocus = target
        var ancestor = target
        while let node = ancestor {
            if case .tab = node.description { node.focusedNode = target }
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
        // Inactive destinations cannot request focus, but their bindings must
        // still observe losing it so they do not become stale future requests.
        for child in children { child.updateFocusBindings(target) }
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

    func scrollPanes() -> [ViewRenderer] {
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
}
