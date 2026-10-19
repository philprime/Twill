/// Measurement and placement caches used to draw already-mounted descriptions.
/// Keeping them separate from content state lets resize redraw without reevaluating bodies
/// or shifting schedules. Scalar traits are invalidated each frame, while placements retain
/// descendants only. Caching the owning node here would create a self-retaining cycle.
@MainActor
struct MountedLayoutState {
    struct Traits {
        let hasContent: Bool
        let fillsWidth: Bool
        let fillsHeight: Bool
        let containsSpacer: Bool
    }

    weak var controlOwner: ViewRenderer?
    var controlStyle: (any ControlStyle)?
    var controlKind: ControlKind?
    var controlSelected = false
    var stackAxis: Axis?
    var scrollIndicators = ScrollIndicatorVisibility.hidden
    var attributes: TextAttributes = []
    var theme = Theme()
    var foreground: Color?
    var background: Color?
    var hasBackgroundStyle = false
    var size = CellSize.zero
    var placements: [(node: ViewRenderer, bounds: CellRect)] = []
    var traits: Traits?

    /// Traits are rebuilt bottom-up after content and active branches have settled.
    mutating func beginFrame() {
        traits = nil
    }
}
