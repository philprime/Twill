/// Transient traversal context. Mounted caches keep only a weak owner reference,
/// so a control's own presentation metadata cannot create a retain cycle.
@MainActor
struct ControlEnvironment {
    var style: (any ControlStyle)?
    var owner: ViewRenderer?
    var kind: ControlKind?
    var selected = false
    var rowSelected = false
}
