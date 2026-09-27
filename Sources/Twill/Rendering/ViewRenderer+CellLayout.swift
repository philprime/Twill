/// Measures mounted children against intrinsic sizes or an explicitly requested fill axis.
@MainActor
extension ViewRenderer {
    var layoutItems: [ViewRenderer] {
        switch description {
        case .drawing, .canvas, .textField:
            return [self]
        case .group(_, .some), .styled, .border:
            return children.flatMap(\.layoutItems).isEmpty ? [] : [self]
        case .sheet:
            return sheetBranch?.layoutItems ?? []
        default:
            return children.flatMap(\.layoutItems)
        }
    }

    private var wantsFillWidth: Bool {
        if case .canvas = description { return true }
        if case .group(_, let fill as FillFrameLayout) = description, fill.fillWidth { return true }
        if case .group(_, let frame as FrameLayout) = description, frame.width != nil { return false }
        return children.contains { $0.wantsFillWidth }
    }

    private var wantsFillHeight: Bool {
        if case .canvas = description { return true }
        if case .group(_, let fill as FillFrameLayout) = description, fill.fillHeight { return true }
        return children.contains { $0.wantsFillHeight }
    }

    func measure(_ proposal: ProposedCellSize) -> CellSize {
        if let drawing {
            measuredSize = drawing.sizeThatFits(proposal)
            return measuredSize
        }
        if case .border = description {
            let inner = ProposedCellSize(
                width: proposal.width.map { max(0, $0 - 2) },
                height: proposal.height.map { max(0, $0 - 2) })
            let size = measureChildren(inner)
            measuredSize = proposal.constrain(CellSize(width: size.width + 2, height: size.height + 2))
            return measuredSize
        }
        measuredSize = measureChildren(proposal)
        return measuredSize
    }

    private func measureChildren(_ proposal: ProposedCellSize) -> CellSize {
        let items = children.flatMap(\.layoutItems)
        let layout: any PrimitiveLayout
        if case .group(_, let groupLayout?) = description {
            layout = groupLayout
        } else {
            layout = HorizontalLayout(spacing: 0)
        }
        let sizes: [CellSize]
        if let horizontal = layout as? HorizontalLayout {
            sizes = measureHorizontal(items, proposal: proposal, spacing: horizontal.spacing)
        } else if let vertical = layout as? VerticalLayout {
            sizes = measureVertical(items, proposal: proposal, spacing: vertical.spacing)
        } else if let frame = layout as? FrameLayout, items.count == 1 {
            sizes = [
                items[0].measure(
                    ProposedCellSize(
                        width: min(frame.width ?? frame.maxWidth ?? proposal.width ?? 0, proposal.width ?? Int.max),
                        height: proposal.height))
            ]
        } else if items.count == 1 {
            sizes = [items[0].measure(proposal)]
        } else {
            sizes = items.map { $0.measure(.unspecified) }
        }
        placements = zip(items, layout.placeSubviews(sizes)).map { ($0, $1) }
        return layout.sizeThatFits(proposal, subviews: sizes)
    }

    private func measureHorizontal(_ items: [ViewRenderer], proposal: ProposedCellSize, spacing: Int) -> [CellSize] {
        let natural = items.map { $0.measure(.unspecified) }
        let flexible = items.indices.filter { items[$0].wantsFillWidth }
        let occupied = items.indices.filter { !items[$0].wantsFillWidth }.reduce(0) { $0 + natural[$1].width }
        let remaining = max(0, (proposal.width ?? 0) - occupied - max(0, items.count - 1) * spacing)
        return items.indices.map { index in
            let width =
                proposal.width != nil && items[index].wantsFillWidth
                ? remaining / max(1, flexible.count) + (index == flexible.last ? remaining % flexible.count : 0)
                : nil
            let height = items[index].wantsFillHeight ? proposal.height : nil
            return width != nil || height != nil
                ? items[index].measure(ProposedCellSize(width: width, height: height)) : natural[index]
        }
    }

    private func measureVertical(_ items: [ViewRenderer], proposal: ProposedCellSize, spacing: Int) -> [CellSize] {
        let natural = items.map { $0.measure(.unspecified) }
        let flexible = items.indices.filter { items[$0].wantsFillHeight }
        let occupied = items.indices.filter { !items[$0].wantsFillHeight }.reduce(0) { $0 + natural[$1].height }
        let remaining = max(0, (proposal.height ?? 0) - occupied - max(0, items.count - 1) * spacing)
        return items.indices.map { index in
            let width = items[index].wantsFillWidth ? proposal.width : nil
            let height =
                proposal.height != nil && items[index].wantsFillHeight
                ? remaining / max(1, flexible.count) + (index == flexible.last ? remaining % flexible.count : 0)
                : nil
            return width != nil || height != nil
                ? items[index].measure(ProposedCellSize(width: width, height: height)) : natural[index]
        }
    }
}
