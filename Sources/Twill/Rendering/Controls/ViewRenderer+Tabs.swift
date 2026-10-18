/// Tab contents stay mounted and scheduled. Only the active destination
/// participates in layout, focus discovery, modal presentation, and input.
@MainActor
extension ViewRenderer {
    var activeChildren: [ViewRenderer] {
        if case .tab = description, !tabState.isActive { return [] }
        guard !descendantTabNodes.isEmpty else { return children }
        // A modifier outside a Tab belongs to that destination too. Exclude
        // the whole branch so its focus binding or modal cannot become active.
        return children.filter { child in
            let destinations = child.tabNodes
            return destinations.isEmpty || destinations.contains(where: \.tabState.isActive)
        }
    }

    var tabNodes: [ViewRenderer] {
        if case .tab = description { return [self] }
        if case .tabs = description { return [] }
        return descendantTabNodes
    }

    private var tabs: [ViewRenderer] { descendantTabNodes }

    var hasTabBar: Bool { !tabs.isEmpty }

    var enclosingTabView: ViewRenderer? {
        var ancestor = parent
        while let node = ancestor {
            if case .tabs = node.description { return node }
            if case .sheet(_, let presented, _) = node.description, presented.wrappedValue { return nil }
            ancestor = node.parent
        }
        return nil
    }

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

    private var tabBar: TextDrawing {
        TextDrawing(
            tabs.map { node in
                guard case .tab(_, let title, _) = node.description else { return "" }
                return node.tabState.isActive ? "[\(title)]" : title
            }.joined(separator: " "))
    }

    func measureTabs(_ proposal: ProposedCellSize) -> CellSize {
        let bar = tabBar.sizeThatFits(.unspecified)
        let content = children.first
        let size =
            content?.measure(
                ProposedCellSize(width: proposal.width, height: proposal.height.map { max(0, $0 - 1) })) ?? .zero
        layoutState.size = proposal.constrain(CellSize(width: max(bar.width, size.width), height: 1 + size.height))
        layoutState.placements =
            content.map { [($0, CellRect(column: 0, row: 1, width: size.width, height: size.height))] } ?? []
        return layoutState.size
    }

    func drawTabBar(in context: inout DrawingContext, focused: ViewRenderer?) {
        context.withRegion(CellRect(column: 0, row: 0, width: layoutState.size.width, height: 1)) { bar in
            bar.withFocus(focused === self) { tabBar.draw(in: &$0) }
        }
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
        guard case .tabs(_, let selection) = description, hasTabBar else { return .ignored }
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
        let next = index + direction
        guard tabs.indices.contains(next) else { return .handled }
        if case .tab(_, _, let value) = tabs[next].description { selection.wrappedValue = value }
        return .handled
    }
}
