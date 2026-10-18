/// Frame caches contain descendant placements, never the owning node itself.
@MainActor
struct MountedLayoutState {
    struct Traits {
        let hasContent: Bool
        let fillsWidth: Bool
        let fillsHeight: Bool
    }

    var size = CellSize.zero
    var placements: [(node: ViewRenderer, bounds: CellRect)] = []
    var traits: Traits?

    /// Traits are rebuilt bottom-up after content and active branches have settled.
    mutating func beginFrame() {
        traits = nil
    }
}
