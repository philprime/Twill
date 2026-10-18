/// Remembers participation and the selected destination for a mounted tab scope.
/// Hidden destinations remain mounted and scheduled, so inactivity is not removal. The
/// destination reference is weak because the mounted child storage, not selection memory,
/// owns its lifetime. Reconciliation can replace a destination without retaining an old tree.
@MainActor
struct MountedTabState {
    var isActive = true
    weak var activeTab: ViewRenderer?
}
