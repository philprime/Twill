/// Owns a mounted view's state locations and pending invalidation, independently of layout.
@MainActor
struct MountedContent {
    private(set) var initialView: (any View)?
    private var mountedView: (any View)?
    private var stateLocations: [String: any StateLocation] = [:]
    private var isDirty = false
    private(set) var hasDirtyDescendant = false

    init(_ view: any View) {
        initialView = view
    }

    mutating func prepare(_ view: any View, onChange: @escaping () -> Void) {
        initialView = nil
        // Fresh view values carry fresh property-wrapper handles. Bind them to this
        // node's locations before evaluating body, so parent updates retain state.
        for property in Mirror(reflecting: view).children {
            guard let name = property.label, let state = property.value as? any MountedStateProperty else { continue }
            let location = stateLocations[name] ?? state.location
            state.bind(to: location)
            location.onChange = onChange
            stateLocations[name] = location
        }
        mountedView = view
    }

    mutating func markDirty() {
        isDirty = true
    }

    mutating func markDescendantDirty() {
        hasDirtyDescendant = true
    }

    mutating func consumeDirtyView() -> (any View)? {
        guard isDirty, let mountedView else { return nil }
        // Clear readiness before evaluating a body. A write during evaluation must
        // remain visible as new work rather than being consumed by this update.
        isDirty = false
        hasDirtyDescendant = false
        return mountedView
    }

    mutating func consumeDescendantInvalidation() {
        hasDirtyDescendant = false
    }
}
