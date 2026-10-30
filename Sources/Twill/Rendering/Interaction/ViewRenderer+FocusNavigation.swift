/// Fallback navigation changes mounted focus and scroll memory, not view state.
/// It requests a redraw of cached descriptions without reevaluating view bodies.
@MainActor
extension ViewRenderer {
    func navigate(_ event: KeyEvent, from target: ViewRenderer) -> Bool {
        let panes = keyboardStops()
        let pane = panes.first { $0.ownsKeyboardFocus(target) }
        let targets: [ViewRenderer]
        if let pane, case .pane = pane.description {
            targets = pane.focusableNodes()
        } else {
            targets = focusableNodes()
        }
        let key = target.tabNavigationKey(event)
        if let pane, key == .tab || key == .shiftTab {
            return switchPane(key, from: pane, in: panes)
        }
        if key == .pageDown || key == .pageUp {
            return enclosingViewport(of: target).map { scrollViewer(key, viewport: $0) } ?? false
        }
        if case .scroll = target.description, key == .arrowDown || key == .arrowUp {
            return scrollViewer(key, viewport: target)
        }
        return moveFocus(key, from: target, in: targets, pane: pane)
    }

    private func enclosingViewport(of target: ViewRenderer) -> ViewRenderer? {
        var ancestor: ViewRenderer? = target
        while let node = ancestor {
            if case .scroll = node.description { return node }
            if node === self { break }
            ancestor = node.parent
        }
        return nil
    }

    private func switchPane(_ key: KeyEvent, from pane: ViewRenderer, in panes: [ViewRenderer]) -> Bool {
        guard let index = panes.firstIndex(where: { $0 === pane }) else { return false }
        let next = index + (key == .tab ? 1 : -1)
        guard panes.indices.contains(next) else { return false }
        let destination = panes[next]
        let selection = destination.focusSelection(in: destination.keyboardCandidates())
        var effects: [FocusTransition.Effect] = [.activatePane(scope: self, pane: destination)] + selection.effects
        if let target = selection.target {
            effects += [.followFocus(target: target), .reveal(pane: self, target: target)]
        }
        applyFocusTransition(
            FocusTransition(
                presentation: .target(selection.target), effects: effects, requestsPresentation: true))
        return true
    }

    private func scrollViewer(_ key: KeyEvent, viewport: ViewRenderer) -> Bool {
        let distance: Int
        switch key {
        case .arrowDown: distance = 1
        case .arrowUp: distance = -1
        case .pageDown: distance = max(1, viewport.layoutState.size.height)
        case .pageUp: distance = -max(1, viewport.layoutState.size.height)
        default: return false
        }
        guard viewport.scrollState.scroll(by: distance, viewportHeight: viewport.layoutState.size.height) else {
            return false
        }
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
        let destinationPane = keyboardStops().first { $0.ownsKeyboardFocus(next) }
        var effects: [FocusTransition.Effect] = [
            .remember(scope: self, target: next), .activatePane(scope: self, pane: destinationPane),
            .followFocus(target: next), .reveal(pane: pane ?? self, target: next),
        ]
        if let destinationPane { effects.append(.remember(scope: destinationPane, target: next)) }
        // Redraw cached descriptions, not view bodies or timeline schedules.
        applyFocusTransition(FocusTransition(presentation: .target(next), effects: effects, requestsPresentation: true))
        return true
    }
}
