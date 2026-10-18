/// Measures mounted children against intrinsic sizes or an explicitly requested fill axis.
@MainActor
extension ViewRenderer {
    /// Rebuild once per frame, after content and active branches have settled. These
    /// scalar summaries never retain nodes or schedule work between presentations.
    func prepareLayout() {
        for child in children { child.prepareLayout() }
        layoutState.beginFrame()
        layoutState.traits = MountedLayoutState.Traits(
            hasContent: hasLayoutContent, fillsWidth: wantsFillWidth, fillsHeight: wantsFillHeight)
    }

    private var hasLayoutContent: Bool {
        if let traits = layoutState.traits { return traits.hasContent }
        switch description {
        case .drawing, .canvas, .textField, .textEditor: return true
        case .group(_, let layout) where layout is TableRowLayout: return true
        case .tabs: return hasTabBar
        case .tab where !tabState.isActive: return false
        case .sheet: return sheetBranch?.hasLayoutContent ?? false
        default: return activeChildren.contains { $0.hasLayoutContent }
        }
    }

    var layoutItems: [ViewRenderer] {
        switch description {
        case .drawing, .canvas, .textField, .textEditor:
            return [self]
        case .group(_, let layout) where layout is TableRowLayout:
            return [self]
        case .group(_, .some), .styled, .border, .scroll, .dialog, .disclosure:
            return hasLayoutContent ? [self] : []
        case .tabs:
            return hasTabBar ? [self] : []
        case .tab where !tabState.isActive:
            return []
        case .sheet:
            return sheetBranch?.layoutItems ?? []
        default:
            return activeChildren.flatMap(\.layoutItems)
        }
    }

    private var wantsFillWidth: Bool {
        if let traits = layoutState.traits { return traits.fillsWidth }
        if case .canvas = description { return true }
        if case .textEditor = description { return true }
        if case .group(_, let layout) = description, layout is GridLayout || layout is TableLayout { return true }
        if case .group(_, let frame as FrameLayout) = description {
            if frame.width != nil { return false }
            if case .cells = frame.maxWidth { return false }
            if frame.fillsWidth { return true }
        }
        return activeChildren.contains { $0.wantsFillWidth }
    }

    private var wantsFillHeight: Bool {
        if let traits = layoutState.traits { return traits.fillsHeight }
        if case .canvas = description { return true }
        if case .textEditor = description { return true }
        if case .scroll = description { return true }
        if case .group(_, let frame as FrameLayout) = description {
            if frame.height != nil { return false }
            if case .cells = frame.maxHeight { return false }
            if frame.fillsHeight { return true }
        }
        return activeChildren.contains { $0.wantsFillHeight }
    }

    func measure(_ proposal: ProposedCellSize) -> CellSize {
        if case .tabs = description { return measureTabs(proposal) }
        if case .group(_, let layout as TableLayout) = description {
            resolveTableColumns(layout, proposal: proposal)
        }
        if case .textEditor(let editor) = description {
            return measureTextEditor(editor, proposal: proposal)
        }
        if let drawing {
            layoutState.size = drawing.sizeThatFits(proposal)
            return layoutState.size
        }
        if case .scroll = description {
            let items = activeChildren.flatMap(\.layoutItems)
            let contentSize = items.first?.measure(ProposedCellSize(width: proposal.width)) ?? .zero
            layoutState.size = proposal.constrain(contentSize)
            scrollState.updateContent(
                height: contentSize.height, viewportHeight: proposal.height.map { _ in layoutState.size.height })
            layoutState.placements = items.map {
                ($0, CellRect(column: 0, row: 0, width: contentSize.width, height: contentSize.height))
            }
            return layoutState.size
        }
        if case .border(_, _, _, let title) = description {
            let inner = ProposedCellSize(
                width: proposal.width.map { max(0, $0 - 2) },
                height: proposal.height.map { max(0, $0 - 2) })
            let size = measureChildren(inner)
            let titleWidth = title.map { $0.sizeThatFits(.unspecified).width + 3 } ?? 0
            layoutState.size = proposal.constrain(
                CellSize(width: max(size.width + 2, titleWidth), height: size.height + 2))
            return layoutState.size
        }
        layoutState.size = measureChildren(proposal)
        return layoutState.size
    }

    private func measureChildren(_ proposal: ProposedCellSize) -> CellSize {
        let layout: any PrimitiveLayout
        switch description {
        case .group(_, let groupLayout?):
            layout = groupLayout
        case .dialog, .disclosure:
            layout = VerticalLayout(spacing: 0, alignment: .leading)
        default:
            layout = HorizontalLayout(spacing: 0)
        }
        // Every table cell occupies a slot, including cells whose content is empty.
        let items = layout is TableRowLayout ? children : activeChildren.flatMap(\.layoutItems)
        let sizes: [CellSize]
        if layout is TableRowLayout {
            sizes = measureTableRow(items)
        } else if let horizontal = layout as? HorizontalLayout {
            sizes = measureHorizontal(items, proposal: proposal, spacing: horizontal.spacing)
        } else if let vertical = layout as? VerticalLayout {
            sizes = measureVertical(items, proposal: proposal, spacing: vertical.spacing)
        } else if let grid = layout as? GridLayout {
            sizes = measureGrid(items, proposal: proposal, layout: grid)
        } else if let frame = layout as? FrameLayout, items.count == 1 {
            sizes = [items[0].measure(frame.childProposal(proposal))]
        } else if let padding = layout as? PaddingLayout {
            let inner = padding.childProposal(proposal)
            sizes =
                items.count == 1
                ? [items[0].measure(inner)] : measureHorizontal(items, proposal: inner, spacing: 0)
        } else if items.count == 1 {
            sizes = [items[0].measure(proposal)]
        } else {
            sizes = items.map { $0.measure(.unspecified) }
        }
        let size = layout.sizeThatFits(proposal, subviews: sizes)
        layoutState.placements = zip(items, layout.placeSubviews(sizes, in: size)).map { ($0, $1) }
        return size
    }

    private func measureGrid(
        _ items: [ViewRenderer], proposal: ProposedCellSize, layout: GridLayout
    ) -> [CellSize] {
        let natural = items.map { $0.measure(.unspecified) }
        let size = layout.sizeThatFits(proposal, subviews: natural)
        let widths = layout.columnWidths(in: size.width, subviews: natural)
        return items.enumerated().map { index, item in
            item.measure(ProposedCellSize(width: widths[index % widths.count]))
        }
    }

    private func measureSingleStack(_ items: [ViewRenderer], proposal: ProposedCellSize) -> CellSize? {
        guard items.count == 1 else { return nil }
        // There is no sibling space to distribute. A natural-size pass followed
        // by a constrained pass would repeatedly measure the entire subtree.
        let item = items[0]
        return item.measure(
            ProposedCellSize(
                width: item.wantsFillWidth ? proposal.width : nil,
                height: item.wantsFillHeight ? proposal.height : nil))
    }

    private func measureHorizontal(_ items: [ViewRenderer], proposal: ProposedCellSize, spacing: Int) -> [CellSize] {
        if let size = measureSingleStack(items, proposal: proposal) { return [size] }
        // Flexible children have a known final width after sibling space is
        // deducted. Their natural width is unused and can require a full tree walk.
        let natural = items.map {
            proposal.width != nil && $0.wantsFillWidth ? .zero : $0.measure(.unspecified)
        }
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
        if let size = measureSingleStack(items, proposal: proposal) { return [size] }
        let natural = items.map {
            proposal.height != nil && $0.wantsFillHeight ? .zero : $0.measure(.unspecified)
        }
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
