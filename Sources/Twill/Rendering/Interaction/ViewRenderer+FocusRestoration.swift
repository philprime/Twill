/// Repairs enclosing focus scopes before removed content can become unreachable.
/// Retained siblings keep their own focus and pane memories.
@MainActor
extension ViewRenderer {
    func restoreFocusBeforeDisclosureCollapse() {
        guard let content = children.dropFirst().first,
            let header = children.first?.focusableNodes().first
        else { return }
        // Redirect only focus owned by the disappearing branch. Updating every
        // enclosing scope also preserves pane and modal focus memories.
        var current: ViewRenderer? = self
        while let node = current {
            if let focused = node.focusedNode, content.contains(focused) { node.focusedNode = header }
            if let presented = node.presentedFocus, content.contains(presented) {
                node.focusedNode = header
                node.clearedFocusBinding = nil
                node.presentFocus(header)
            }
            if let pane = node.activePane, content.contains(pane) { node.activePane = nil }
            current = node.parent
        }
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
                scope.activePane = scope.scrollPanes().first { $0.contains(target) }
                scope.activePane?.focusedNode = target
                scope.clearedFocusBinding = nil
                scope.presentFocus(target)
            }
            ancestor = scope.parent
        }
    }
}
