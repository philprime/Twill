/// Measures mounted children against intrinsic sizes or an explicitly requested fill axis.
@MainActor
extension ViewRenderer {
    /// Rebuild once per frame, after content and active branches have settled. These
    /// scalar summaries never retain nodes or schedule work between presentations.
    func prepareLayout() {
        for child in retainedChildren { child.prepareLayout() }
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
        default: return presentationChildren.contains { $0.hasLayoutContent }
        }
    }

    var layoutItems: [ViewRenderer] {
        switch description {
        case .drawing, .canvas, .textField, .textEditor:
            return [self]
        case .group(_, let layout) where layout is TableRowLayout:
            return [self]
        case .group(_, .some), .control, .styled, .border, .scroll, .dialog, .disclosure:
            return hasLayoutContent ? [self] : []
        case .tabs:
            return hasTabBar ? [self] : []
        case .tab where !tabState.isActive:
            return []
        case .sheet:
            return sheetBranch?.layoutItems ?? []
        default:
            return presentationChildren.flatMap(\.layoutItems)
        }
    }

    private var wantsFillWidth: Bool {
        if let traits = layoutState.traits { return traits.fillsWidth }
        if case .canvas = description { return true }
        if case .textEditor = description { return true }
        if case .group(_, let layout?) = description {
            switch layout.behavior.width {
            case .filling: return true
            case .intrinsic: return false
            case .inherited: break
            }
        }
        return presentationChildren.contains { $0.wantsFillWidth }
    }

    private var wantsFillHeight: Bool {
        if let traits = layoutState.traits { return traits.fillsHeight }
        if case .canvas = description { return true }
        if case .textEditor = description { return true }
        if case .scroll = description { return true }
        if case .group(_, let layout?) = description {
            switch layout.behavior.height {
            case .filling: return true
            case .intrinsic: return false
            case .inherited: break
            }
        }
        return presentationChildren.contains { $0.wantsFillHeight }
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
            let items = presentationChildren.flatMap(\.layoutItems)
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
        let items = layout is TableRowLayout ? retainedChildren : presentationChildren.flatMap(\.layoutItems)
        let result: LayoutResult
        if layout is TableRowLayout {
            // Shared table widths still use the specialized mounted path. Ordinary
            // layouts receive only measurement handles and own their child proposals.
            let sizes = measureTableRow(items)
            let size = layout.sizeThatFits(proposal, subviews: sizes)
            result = LayoutResult(size: size, placements: layout.placeSubviews(sizes, in: size))
        } else {
            let subviews = items.map { node in
                LayoutSubview(
                    fillsWidth: node.wantsFillWidth, fillsHeight: node.wantsFillHeight,
                    measure: { node.measure($0) })
            }
            result = layout.layout(proposal, subviews: subviews)
        }
        layoutState.placements = zip(items, result.placements).map { ($0, $1) }
        return result.size
    }

}
