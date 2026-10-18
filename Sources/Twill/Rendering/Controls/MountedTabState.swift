/// Selection participation and destination memory survive updates with the same identity.
@MainActor
struct MountedTabState {
    var isActive = true
    weak var activeTab: ViewRenderer?
}
