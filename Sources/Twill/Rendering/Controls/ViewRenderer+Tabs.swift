/// Tab contents stay mounted and scheduled. Only the active destination
/// participates in layout, focus discovery, modal presentation, and input.
@MainActor
extension ViewRenderer {
    var tabNodes: [ViewRenderer] {
        if case .tab = description { return [self] }
        if case .tabs = description { return [] }
        return descendantTabNodes
    }

    private var tabs: [ViewRenderer] { descendantTabNodes }

    var hasTabBar: Bool { !tabs.isEmpty }

    func tabNavigationKey(_ key: KeyEvent) -> KeyEvent {
        if case .tabs = description, key == .tab { return .arrowDown }
        return key
    }

    func tabFocusDestination(fallingBackTo candidate: ViewRenderer) -> ViewRenderer {
        guard case .tabs = description, let selectedTab = tabState.activeTab else { return candidate }
        let targets = selectedTab.focusableNodes()
        guard targets.contains(where: { $0 === candidate }) else { return candidate }
        return selectedTab.resolveFocus(in: targets) ?? candidate
    }

    func updateTabState() {
        // Selection restoration walks the updated tree. Discover structure first,
        // then apply selection without caching which destination is currently active.
        childStorage.collectTabDestinations()
        updateActiveTab()
    }

    private func updateActiveTab() {
        guard case .tabs(_, let selection) = description else { return }
        let tabs = tabs
        let previous = tabState.activeTab
        let selected =
            tabs.first { node in
                if case .tab(_, _, let value) = node.description { return value == selection.wrappedValue }
                return false
            } ?? tabs.first
        for tab in tabs { tab.tabState.isActive = tab === selected }
        tabState.activeTab = selected
        if previous !== selected { restoreFocusAfterTabChange(from: previous, to: selected) }
    }

    var tabBar: TextDrawing {
        TextDrawing(
            tabs.map { node in
                guard case .tab(_, let title, _) = node.description else { return "" }
                return node.tabState.isActive ? "[\(title)]" : title
            }.joined(separator: " "))
    }

    func measureTabs(_ proposal: ProposedCellSize, tableContext: TableLayoutContext?) -> CellSize {
        let content = retainedChildren.first
        let size = nodePresentation.sizeThatFits(proposal) { childProposal in
            let contentSize = content?.measure(childProposal, tableContext: tableContext) ?? .zero
            layoutState.placements =
                content.map {
                    [($0, CellRect(column: 0, row: 1, width: contentSize.width, height: contentSize.height))]
                } ?? []
            return contentSize
        }
        layoutState.size = size
        return size
    }

    func handleTabShortcut(_ key: KeyEvent, from target: ViewRenderer, stoppingAt boundary: ViewRenderer?) -> Bool {
        guard key == KeyEvent(.pageUp, modifiers: .control) || key == KeyEvent(.pageDown, modifiers: .control) else {
            return false
        }
        // Fields consume paging keys, so tab navigation runs before editing.
        // A modal boundary prevents switching a tab behind the active sheet.
        var ancestor: ViewRenderer? = target
        while let node = ancestor {
            if node.handleTabKey(key, focused: target) == .handled { return true }
            if node === boundary { break }
            ancestor = node.parent
        }
        return false
    }

    func handleTabKey(_ key: KeyEvent, focused: ViewRenderer) -> KeyPressResult {
        guard isEnabled, case .tabs(_, let selection) = description, hasTabBar else { return .ignored }
        let direction: Int
        switch key {
        case KeyEvent(.pageDown, modifiers: .control): direction = 1
        case KeyEvent(.pageUp, modifiers: .control): direction = -1
        case .arrowRight where focused === self: direction = 1
        case .arrowLeft where focused === self: direction = -1
        default: return .ignored
        }
        let tabs = tabs
        guard let index = tabs.firstIndex(where: \.tabState.isActive) else { return .handled }
        var next = index + direction
        while tabs.indices.contains(next), !tabs[next].isEnabled { next += direction }
        guard tabs.indices.contains(next) else { return .handled }
        if case .tab(_, _, let value) = tabs[next].description { selection.wrappedValue = value }
        return .handled
    }
}
