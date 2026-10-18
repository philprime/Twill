/// The mounted-tree side of focus resolution: binding reads and structural queries stay here.
/// A request captures their result before policy chooses a transition. This keeps tree walking
/// separate from publication, which may synchronously invalidate content through binding writes.
@MainActor
extension ViewRenderer {
    func focusTarget() -> ViewRenderer? {
        let transition = FocusCoordinator().resolve(focusRequest())
        applyFocusTransition(transition)
        return transition.target
    }

    /// Queries preserve the established precedence and stop once a reason is found.
    /// In particular, a still-active binding on the current path is not a new request,
    /// and inactive destinations cannot introduce requests into the active scope.
    func focusRequest() -> FocusRequest {
        let panes = keyboardStops()
        let reason: FocusRequest.Reason
        let requested = requestedFocus(excluding: focusState.presentedFocus) ?? requestedFocus()
        if let requested {
            let targets = requested.focusableNodes()
            let remembered = requested.focusState.focusedNode
            let target = remembered.flatMap { memory in targets.first { $0 === memory } } ?? targets.first
            let pane = target.flatMap { target in panes.first { $0.ownsKeyboardFocus(target) } }
            reason = .explicit(candidates: targets, remembered: remembered, pane: pane)
        } else if let cleared = clearedBinding(from: focusState.presentedFocus) ?? focusState.clearedFocusBinding {
            reason = .cleared(cleared)
        } else if let remembered = rememberedFocus() {
            reason = .remembered(remembered)
        } else {
            let validPane = focusState.activePane.flatMap { candidate in
                panes.contains { $0 === candidate } ? candidate : nil
            }
            let preferred = focusCandidates(in: focusableNodes()).preferred
            let preferredPane = preferred.flatMap { target in panes.first { $0.ownsKeyboardFocus(target) } }
            let pane = validPane ?? preferredPane ?? panes.first
            let owner = pane ?? self
            reason = .automatic(
                candidates: owner.focusCandidates(in: owner.keyboardCandidates()), pane: pane,
                updatePane: validPane == nil)
        }
        return FocusRequest(scope: self, presented: focusState.presentedFocus, reason: reason)
    }

    func contains(_ node: ViewRenderer) -> Bool {
        var current: ViewRenderer? = node
        while let candidate = current {
            if candidate === self { return true }
            current = candidate.parent
        }
        return false
    }

    func keyboardStops() -> [ViewRenderer] {
        switch description {
        case .pane, .textEditor, .textField, .control, .focusable:
            return [self]
        case .tabs:
            return hasTabBar ? [self] + interactionChildren.flatMap { $0.keyboardStops() } : []
        default:
            let descendants = interactionChildren.flatMap { $0.keyboardStops() }
            if case .scroll = description, descendants.isEmpty { return [self] }
            return descendants
        }
    }

    func ownsKeyboardFocus(_ target: ViewRenderer) -> Bool {
        if case .tabs = description { return self === target }
        return contains(target)
    }

    func keyboardCandidates() -> [ViewRenderer] {
        if case .tabs = description { return hasTabBar ? [self] : [] }
        return focusableNodes()
    }

    func requestFocusPresentation() {
        if let parent { parent.requestFocusPresentation() } else { onInvalidation?() }
    }

    func focusSelection(in targets: [ViewRenderer]) -> FocusCoordinator.Selection {
        FocusCoordinator().select(focusCandidates(in: targets), rememberingIn: self)
    }

    func resolveFocus(in targets: [ViewRenderer]) -> ViewRenderer? {
        let selection = focusSelection(in: targets)
        applyFocusEffects(selection.effects)
        return selection.target
    }

    func focusableNodes() -> [ViewRenderer] {
        let descendants = interactionChildren.flatMap { $0.focusableNodes() }
        switch description {
        case .listSelection: return [self]
        case .tabs: return hasTabBar ? [self] + descendants : []
        case .focusable, .control, .textField, .textEditor: return [self] + descendants
        case .scroll where descendants.isEmpty, .pane where descendants.isEmpty: return [self]
        default: return descendants
        }
    }

    private func focusCandidates(in targets: [ViewRenderer]) -> FocusRequest.Candidates {
        let remembered = focusState.focusedNode
        var preferred: ViewRenderer?
        if !targets.contains(where: { $0 === remembered }) {
            // Prefer cancellation without changing action order or using public focus
            // state for an internal modal policy. Reused memories need no dialog walk.
            let dialog = sheetBranch?.dialogScope() ?? dialogScope()
            if dialog != nil { preferred = targets.first { $0.enclosingButton?.buttonRole == .cancel } }
        }
        return FocusRequest.Candidates(nodes: targets, remembered: remembered, preferred: preferred)
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

    private func rememberedFocus() -> ViewRenderer? {
        let candidates = focusableNodes()
        // A modal's retained base keeps its own memory while the enclosing scope
        // presents a different target. Returning must not select the first control.
        for memory in [focusState.focusedNode, sheetBranch?.focusState.focusedNode] {
            if let memory, candidates.contains(where: { $0 === memory }) { return memory }
        }
        return nil
    }
}
