/// Focus selection policy, with no ownership of nodes, bindings, or presentation resources.
///
/// Its input is a gathered request and its output is a transition. It does not traverse
/// changing tree structure or apply a partially resolved decision. Policy state remains
/// in mounted memories rather than coordinator instances. Keeping this value transient
/// avoids introducing another lifetime that could retain removed focus targets.
@MainActor
struct FocusCoordinator {
    /// Subtree selection is also used while returning to a pane or tab. It proposes
    /// memory changes without publishing focus in that subtree independently of its scope.
    struct Selection {
        let target: ViewRenderer?
        let effects: [FocusTransition.Effect]
    }

    func resolve(_ request: FocusRequest) -> FocusTransition {
        switch request.reason {
        case .explicit(let candidates, let remembered, let pane):
            let target =
                remembered.flatMap { candidate in candidates.contains { $0 === candidate } ? candidate : nil }
                ?? candidates.first
            var effects: [FocusTransition.Effect] = [.clearedBinding(scope: request.scope, binding: nil)]
            if let pane {
                effects.append(.activatePane(scope: request.scope, pane: pane))
                effects.append(.remember(scope: pane, target: target))
                if request.presented !== target { effects.append(.followFocus(pane: pane)) }
            } else {
                effects.append(.remember(scope: request.scope, target: target))
            }
            return FocusTransition(presentation: .target(target), effects: effects)
        case .cleared(let binding):
            return FocusTransition(
                presentation: .target(nil), effects: [.clearedBinding(scope: request.scope, binding: binding)])
        case .remembered(let target):
            return FocusTransition(presentation: .target(target))
        case .automatic(let candidates, let pane, let updatePane):
            let selection = select(candidates, rememberingIn: pane ?? request.scope)
            let paneEffects: [FocusTransition.Effect] =
                updatePane ? [.activatePane(scope: request.scope, pane: pane)] : []
            return FocusTransition(presentation: .target(selection.target), effects: paneEffects + selection.effects)
        }
    }

    /// Reusing a valid memory must leave manual scroll policy alone. Only choosing a
    /// replacement target resumes follow-focus, even when the candidate list is empty.
    func select(_ candidates: FocusRequest.Candidates, rememberingIn scope: ViewRenderer) -> Selection {
        if let remembered = candidates.remembered, candidates.nodes.contains(where: { $0 === remembered }) {
            return Selection(target: remembered, effects: [])
        }
        let target = candidates.preferred ?? candidates.nodes.first
        return Selection(
            target: target, effects: [.remember(scope: scope, target: target), .followFocus(pane: scope)])
    }
}
