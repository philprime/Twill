/// Repairs enclosing scopes before removed content can become unreachable.
/// Retained siblings keep their own focus and pane memories.
@MainActor
extension ViewRenderer {
    func restoreFocusBeforeDisclosureCollapse() {
        guard let content = retainedChildren.dropFirst().first,
            let header = retainedChildren.first?.focusableNodes().first
        else { return }
        // Redirect only focus owned by the disappearing branch. Updating every
        // enclosing scope also preserves pane and modal focus memories.
        var current: ViewRenderer? = self
        while let node = current {
            var transition = FocusTransition()
            if let focused = node.focusState.focusedNode, content.contains(focused) {
                transition.effects.append(.remember(scope: node, target: header))
            }
            if let presented = node.focusState.presentedFocus, content.contains(presented) {
                transition.effects.append(.remember(scope: node, target: header))
                transition.effects.append(.clearedBinding(scope: node, binding: nil))
                transition.presentation = .target(header)
            }
            node.applyFocusTransition(transition)
            if let pane = node.focusState.activePane, content.contains(pane) {
                node.applyFocusTransition(FocusTransition(effects: [.activatePane(scope: node, pane: nil)]))
            }
            current = node.parent
        }
    }

    func restoreFocusAfterSheetDismissal() {
        // Modal bindings may share storage with the base screen. Their writes are
        // not explicit requests to clear the enclosing screen's remembered focus.
        var current: ViewRenderer? = self
        while let node = current {
            node.applyFocusTransition(FocusTransition(presentation: .reset))
            current = node.parent
        }
    }

    func restoreFocusAfterTabChange(from previous: ViewRenderer?, to selected: ViewRenderer?) {
        guard let previous else { return }
        var ancestor: ViewRenderer? = self
        while let scope = ancestor {
            if let focused = scope.focusState.presentedFocus, previous.contains(focused) {
                let target = selected.flatMap { $0.resolveFocus(in: $0.focusableNodes()) } ?? self
                let pane = scope.keyboardStops().first { $0.ownsKeyboardFocus(target) }
                var effects: [FocusTransition.Effect] = [
                    .remember(scope: scope, target: target), .activatePane(scope: scope, pane: pane),
                ]
                if let pane { effects.append(.remember(scope: pane, target: target)) }
                effects.append(.clearedBinding(scope: scope, binding: nil))
                scope.applyFocusTransition(FocusTransition(presentation: .target(target), effects: effects))
            }
            ancestor = scope.parent
        }
    }
}
