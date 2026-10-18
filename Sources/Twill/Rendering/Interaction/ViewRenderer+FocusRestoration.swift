/// Repairs enclosing focus scopes before removed content can become unreachable.
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
            if let focused = node.focusState.focusedNode, content.contains(focused) {
                node.focusState.focusedNode = header
            }
            if let presented = node.focusState.presentedFocus, content.contains(presented) {
                node.focusState.focusedNode = header
                node.focusState.clearedFocusBinding = nil
                node.presentFocus(header)
            }
            if let pane = node.focusState.activePane, content.contains(pane) { node.focusState.activePane = nil }
            current = node.parent
        }
    }

    func restoreFocusAfterSheetDismissal() {
        // Modal bindings may share storage with the base screen. Their writes are
        // not explicit requests to clear the enclosing screen's remembered focus.
        var current: ViewRenderer? = self
        while let node = current {
            node.focusState.presentedFocus = nil
            node.focusState.clearedFocusBinding = nil
            current = node.parent
        }
    }

    func restoreFocusAfterTabChange(from previous: ViewRenderer?, to selected: ViewRenderer?) {
        guard let previous else { return }
        var ancestor: ViewRenderer? = self
        while let scope = ancestor {
            if let focused = scope.focusState.presentedFocus, previous.contains(focused) {
                let target = selected.flatMap { $0.resolveFocus(in: $0.focusableNodes()) } ?? self
                scope.focusState.focusedNode = target
                scope.focusState.activePane = scope.scrollPanes().first { $0.contains(target) }
                scope.focusState.activePane?.focusState.focusedNode = target
                scope.focusState.clearedFocusBinding = nil
                scope.presentFocus(target)
            }
            ancestor = scope.parent
        }
    }
}
