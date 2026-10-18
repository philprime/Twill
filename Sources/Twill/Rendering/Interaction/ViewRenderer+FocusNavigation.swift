/// Fallback navigation changes mounted focus and scroll memory, not view state.
/// It requests a redraw of cached descriptions without reevaluating view bodies.
@MainActor
extension ViewRenderer {
    func navigate(_ event: KeyEvent, from target: ViewRenderer) -> Bool {
        let panes = scrollPanes()
        let pane = panes.first { $0.contains(target) }
        let targets = pane?.focusableNodes() ?? focusableNodes()
        if focusTabBar(event, from: target, pane: pane) { return true }
        let key = target.tabNavigationKey(event)
        if let pane, key == .tab || key == .shiftTab {
            return switchPane(key, from: pane, in: panes)
        }
        if let pane, target === pane || key == .pageDown || key == .pageUp {
            return scrollViewer(key, pane: pane)
        }
        return moveFocus(key, from: target, in: targets, pane: pane)
    }

    private func focusTabBar(_ key: KeyEvent, from target: ViewRenderer, pane: ViewRenderer?) -> Bool {
        guard key == .shiftTab, let bar = target.enclosingTabView else { return false }
        if let pane, bar.contains(pane), pane !== bar.scrollPanes().first { return false }
        pane?.focusState.focusedNode = bar
        focusState.focusedNode = bar
        presentFocus(bar)
        requestFocusPresentation()
        return true
    }

    private func switchPane(_ key: KeyEvent, from pane: ViewRenderer, in panes: [ViewRenderer]) -> Bool {
        guard let index = panes.firstIndex(where: { $0 === pane }) else { return false }
        let next = index + (key == .tab ? 1 : -1)
        guard panes.indices.contains(next) else { return false }
        focusState.activePane = panes[next]
        presentFocus(panes[next].resolveFocus(in: panes[next].focusableNodes()))
        requestFocusPresentation()
        return true
    }

    private func scrollViewer(_ key: KeyEvent, pane: ViewRenderer) -> Bool {
        let distance: Int
        switch key {
        case .arrowDown: distance = 1
        case .arrowUp: distance = -1
        case .pageDown: distance = max(1, pane.layoutState.size.height)
        case .pageUp: distance = -max(1, pane.layoutState.size.height)
        default: return false
        }
        guard pane.scrollState.scroll(by: distance, viewportHeight: pane.layoutState.size.height) else { return false }
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
            pane.focusState.focusedNode = next
            pane.scrollState.followFocus()
            pane.revealFocus(next)
        } else {
            focusState.focusedNode = next
            if let destination = scrollPanes().first(where: { $0.contains(next) }) {
                focusState.activePane = destination
                destination.focusState.focusedNode = next
            }
        }
        presentFocus(next)
        // Redraw cached descriptions, not view bodies or timeline schedules.
        requestFocusPresentation()
        return true
    }
}
