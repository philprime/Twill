/// The only application boundary for focus memory, blur, and binding synchronization.
///
/// Effects run before publication so callbacks observe the updated pane/target memories.
/// Publication may synchronously write mounted state through bindings, so it is skipped
/// when the target is unchanged. This avoids redundant invalidation on static frames and
/// keeps callbacks out of request gathering and target selection.
@MainActor
extension ViewRenderer {
    func applyFocusTransition(_ transition: FocusTransition) {
        applyFocusEffects(transition.effects)
        switch transition.presentation {
        case .unchanged:
            break
        case .reset:
            focusState.resetPresentation()
        case .target(let target):
            if focusState.presentedFocus !== target {
                focusState.presentedFocus?.description?.controlInteraction?.blur?()
                focusState.present(target)
                var ancestor = target
                while let node = ancestor {
                    if case .tab = node.description { node.focusState.remember(target) }
                    ancestor = node.parent
                }
                // Shared bindings settle once per transition, not on unchanged frames.
                updateFocusBindings(target)
            }
        }
        if transition.requestsPresentation { requestFocusPresentation() }
    }

    func applyFocusEffects(_ effects: [FocusTransition.Effect]) {
        for effect in effects {
            switch effect {
            case .remember(let scope, let target): scope.focusState.remember(target)
            case .activatePane(let scope, let pane): scope.focusState.activatePane(pane)
            case .clearedBinding(let scope, let binding): scope.focusState.recordClearedBinding(binding)
            case .followFocus(let pane): pane.scrollState.followFocus()
            case .reveal(let pane, let target): pane.revealFocus(target)
            }
        }
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
}
