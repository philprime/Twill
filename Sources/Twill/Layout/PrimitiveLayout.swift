/// Internal layout behavior: choose child proposals, then size and place their results.
///
/// Child measurement is part of the contract, not a renderer decision based on layout
/// type. Pure sizing/placement functions are also reusable by shared-column calculations
/// without mounting another tree. This is an internal extension seam, not a public layout API.
protocol PrimitiveLayout {
    var behavior: LayoutBehavior { get }
    @MainActor func measureSubviews(_ proposal: ProposedCellSize, subviews: [LayoutSubview]) -> [CellSize]
    func sizeThatFits(_ proposal: ProposedCellSize, subviews: [CellSize]) -> CellSize
    func placeSubviews(_ subviews: [CellSize], in size: CellSize) -> [CellRect]
}

extension PrimitiveLayout {
    var behavior: LayoutBehavior { LayoutBehavior() }

    /// A single child can accept the proposal directly. Multiple intrinsic children
    /// need unconstrained sizes unless the layout defines a distribution policy.
    @MainActor
    func measureSubviews(_ proposal: ProposedCellSize, subviews: [LayoutSubview]) -> [CellSize] {
        if subviews.count == 1 { return [subviews[0].sizeThatFits(proposal)] }
        return subviews.map { $0.sizeThatFits(.unspecified) }
    }

    @MainActor
    func layout(_ proposal: ProposedCellSize, subviews: [LayoutSubview]) -> LayoutResult {
        let sizes = measureSubviews(proposal, subviews: subviews)
        let size = sizeThatFits(proposal, subviews: sizes)
        return LayoutResult(size: size, placements: placeSubviews(sizes, in: size))
    }

    @MainActor
    func singleSubviewSize(_ proposal: ProposedCellSize, subviews: [LayoutSubview]) -> CellSize? {
        guard subviews.count == 1 else { return nil }
        // There is no sibling space to distribute. A natural-size pass followed
        // by a constrained pass would repeatedly measure the entire subtree.
        let child = subviews[0]
        return child.sizeThatFits(
            ProposedCellSize(
                width: child.fillsWidth ? proposal.width : nil,
                height: child.fillsHeight ? proposal.height : nil))
    }
}
