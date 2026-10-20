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
        case .keyHints(let hints): return isEnabled && hints.contains(where: \.hasContent)
        case .tableRow: return true
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
        case .keyHints:
            return hasLayoutContent ? [self] : []
        case .tableRow:
            return [self]
        case .group(_, .some), .table, .control, .styled, .border, .scroll, .dialog, .disclosure:
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

    private var containerBehavior: LayoutBehavior? {
        switch description {
        case .group(_, let layout?): return layout.behavior
        case .table(_, let layout): return layout.behavior
        default: return nil
        }
    }

    private var wantsFillWidth: Bool {
        if let traits = layoutState.traits { return traits.fillsWidth }
        if case .canvas = description { return true }
        if case .textEditor = description { return true }
        if let behavior = containerBehavior {
            switch behavior.width {
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
        if let behavior = containerBehavior {
            switch behavior.height {
            case .filling: return true
            case .intrinsic: return false
            case .inherited: break
            }
        }
        return presentationChildren.contains { $0.wantsFillHeight }
    }

    func measure(_ proposal: ProposedCellSize, tableContext inherited: TableLayoutContext? = nil) -> CellSize {
        let tableContext = resolveTableContext(proposal, inherited: inherited)
        if case .tabs = description { return measureTabs(proposal, tableContext: tableContext) }
        // Measure before mutating cached size: child callbacks may inspect the mounted
        // tree, and must not run during an exclusive mutation of its layout storage.
        let size = nodePresentation.sizeThatFits(proposal) { childProposal in
            if case .scroll = description {
                return measureScrollContent(childProposal, tableContext: tableContext)
            }
            return measureChildren(childProposal, tableContext: tableContext)
        }
        layoutState.size = size
        if case .scroll = description {
            scrollState.updateContent(
                height: scrollState.contentHeight, viewportHeight: proposal.height.map { _ in size.height })
        }
        if case .textEditor(let editor) = description { updateEditorViewport(editor) }
        return size
    }

    private func measureScrollContent(
        _ proposal: ProposedCellSize, tableContext: TableLayoutContext?
    ) -> CellSize {
        let items = presentationChildren.flatMap(\.layoutItems)
        let contentSize = items.first?.measure(proposal, tableContext: tableContext) ?? .zero
        scrollState.updateContent(height: contentSize.height, viewportHeight: nil)
        layoutState.placements = items.map {
            ($0, CellRect(column: 0, row: 0, width: contentSize.width, height: contentSize.height))
        }
        return contentSize
    }

    private func measureChildren(_ proposal: ProposedCellSize, tableContext: TableLayoutContext?) -> CellSize {
        let layout: any PrimitiveLayout
        switch description {
        case .group(_, let groupLayout?):
            layout = groupLayout
        case .table(_, let tableLayout):
            layout = tableLayout
        case .tableRow:
            guard let tableContext else { preconditionFailure("A table row must be mounted inside a table") }
            layout = TableRowLayout(context: tableContext)
        case .dialog, .disclosure:
            layout = VerticalLayout(spacing: 0, alignment: .leading)
        default:
            layout = HorizontalLayout(spacing: 0)
        }
        // Every table cell occupies a slot, including cells whose content is empty.
        let items: [ViewRenderer]
        if case .tableRow = description {
            items = retainedChildren
        } else {
            items = presentationChildren.flatMap(\.layoutItems)
        }
        let subviews = items.map { node in
            LayoutSubview(
                fillsWidth: node.wantsFillWidth, fillsHeight: node.wantsFillHeight,
                measure: { node.measure($0, tableContext: tableContext) })
        }
        let result = layout.layout(proposal, subviews: subviews)
        layoutState.placements = zip(items, result.placements).map { ($0, $1) }
        return result.size
    }

}
