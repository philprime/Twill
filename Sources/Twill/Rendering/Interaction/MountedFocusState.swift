/// Scope-local focus memories never extend a mounted node's lifetime.
///
/// Private setters keep presentation updates on the transition application path rather
/// than letting navigation and branch restoration independently publish focus. Remembered
/// focus, the active pane, and the last presented target are distinct: losing a modal or
/// hiding a tab must not erase the underlying scope's valid return destination.
@MainActor
struct MountedFocusState {
    private(set) weak var focusedNode: ViewRenderer?
    private(set) weak var activePane: ViewRenderer?
    private(set) weak var presentedFocus: ViewRenderer?
    private(set) weak var clearedFocusBinding: ViewRenderer?

    mutating func remember(_ target: ViewRenderer?) {
        focusedNode = target
    }

    mutating func activatePane(_ pane: ViewRenderer?) {
        activePane = pane
    }

    mutating func recordClearedBinding(_ binding: ViewRenderer?) {
        clearedFocusBinding = binding
    }

    mutating func present(_ target: ViewRenderer?) {
        presentedFocus = target
    }

    mutating func resetPresentation() {
        presentedFocus = nil
        clearedFocusBinding = nil
    }
}
