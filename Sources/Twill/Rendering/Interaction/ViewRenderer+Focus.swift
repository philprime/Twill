/// Resolves focus requests against mounted identity and synchronizes focus bindings.
/// Remembered targets are weak and must still belong to the active scope before reuse.
@MainActor
extension ViewRenderer {
    func focusTarget() -> ViewRenderer? {
        let panes = scrollPanes()
        let target: ViewRenderer?
        if let requested = requestedFocus(excluding: focusState.presentedFocus) ?? requestedFocus() {
            focusState.clearedFocusBinding = nil
            let targets = requested.focusableNodes()
            if let pane = panes.first(where: { requested.contains($0) || $0.contains(requested) }) {
                focusState.activePane = pane
                let remembered = pane.focusState.focusedNode
                target =
                    remembered.flatMap { candidate in targets.contains { $0 === candidate } ? candidate : nil }
                    ?? targets.first
                pane.focusState.focusedNode = target
                if focusState.presentedFocus !== target { pane.scrollState.followFocus() }
            } else {
                target =
                    focusState.focusedNode.flatMap { candidate in
                        targets.contains { $0 === candidate } ? candidate : nil
                    }
                    ?? targets.first
                focusState.focusedNode = target
            }
        } else if let cleared = clearedBinding(from: focusState.presentedFocus) ?? focusState.clearedFocusBinding {
            focusState.clearedFocusBinding = cleared
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
        // Bindings on the current focus path report existing focus. A different
        // activated binding is a new request, even when it follows them in tree order.
        if case .focusBinding(_, let binding) = description, binding.isFocused() {
            if currentTarget.map({ !contains($0) }) ?? true { return self }
        }
        // Lazy compactMap followed by first re-evaluates a successful transform when
        // indexing it. Recursive searches multiply that work at every ancestor.
        for child in interactionChildren {
            if let requested = child.requestedFocus(excluding: currentTarget) { return requested }
        }
        return nil
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
        guard focusState.presentedFocus !== target else { return }
        focusState.presentedFocus?.description?.controlInteraction?.blur?()
        focusState.presentedFocus = target
        var ancestor = target
        while let node = ancestor {
            if case .tab = node.description { node.focusState.focusedNode = target }
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
        for child in retainedChildren { child.updateFocusBindings(target) }
    }

    private func rememberedFocus(outside panes: [ViewRenderer]) -> ViewRenderer? {
        guard let focusedNode = focusState.focusedNode,
            focusableNodes().contains(where: { $0 === focusedNode })
        else { return nil }
        return panes.contains(where: { $0.contains(focusedNode) }) ? nil : focusedNode
    }

    private func resolvePane(in panes: [ViewRenderer]) -> ViewRenderer? {
        if let activePane = focusState.activePane, panes.contains(where: { $0 === activePane }) { return activePane }
        focusState.activePane = panes.first
        return focusState.activePane
    }

    func scrollPanes() -> [ViewRenderer] {
        if case .scroll = description { return [self] }
        if case .textEditor = description { return [self] }
        return interactionChildren.flatMap { $0.scrollPanes() }
    }

    func requestFocusPresentation() {
        if let parent { parent.requestFocusPresentation() } else { onInvalidation?() }
    }

    func resolveFocus(in targets: [ViewRenderer]) -> ViewRenderer? {
        if let focusedNode = focusState.focusedNode, targets.contains(where: { $0 === focusedNode }) {
            return focusedNode
        }
        // Prefer cancellation on first presentation without changing the supplied
        // action order or using public focus state for an internal modal policy.
        let dialog = sheetBranch?.dialogScope() ?? dialogScope()
        focusState.focusedNode =
            dialog == nil ? targets.first : targets.first { $0.enclosingButton?.buttonRole == .cancel } ?? targets.first
        scrollState.followFocus()
        return focusState.focusedNode
    }

    func focusableNodes() -> [ViewRenderer] {
        let descendants = interactionChildren.flatMap { $0.focusableNodes() }
        switch description {
        case .listSelection: return [self]
        case .tabs: return hasTabBar ? [self] + descendants : []
        case .focusable, .control, .textField, .textEditor: return [self] + descendants
        case .scroll where descendants.isEmpty: return [self]
        default: return descendants
        }
    }
}
