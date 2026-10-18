/// Scope-local focus memories never extend a mounted node's lifetime.
@MainActor
struct MountedFocusState {
    weak var focusedNode: ViewRenderer?
    weak var activePane: ViewRenderer?
    weak var presentedFocus: ViewRenderer?
    weak var clearedFocusBinding: ViewRenderer?
}
