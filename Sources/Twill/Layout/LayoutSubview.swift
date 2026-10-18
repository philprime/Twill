/// A child measurement capability valid only for the current synchronous layout pass.
///
/// Layouts receive fill intent and a sizing operation rather than mounted nodes, so they
/// cannot reconcile children, change focus, or own scheduling. The closure retains its
/// mounted child while measuring. Do not cache a handle or capture it in deferred work:
/// persistent placements contain geometry and descendant identity, not these closures.
@MainActor
struct LayoutSubview {
    let fillsWidth: Bool
    let fillsHeight: Bool
    private let measure: @MainActor (ProposedCellSize) -> CellSize

    init(
        fillsWidth: Bool, fillsHeight: Bool,
        measure: @escaping @MainActor (ProposedCellSize) -> CellSize
    ) {
        self.fillsWidth = fillsWidth
        self.fillsHeight = fillsHeight
        self.measure = measure
    }

    func sizeThatFits(_ proposal: ProposedCellSize) -> CellSize {
        measure(proposal)
    }
}
