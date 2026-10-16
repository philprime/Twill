import Foundation

/// Owns structural and keyed child identity, plus bottom-up tab discovery.
@MainActor
struct MountedChildren {
    var nodes: [ViewRenderer] = []
    private var keyedNodes: [AnyHashable: ViewRenderer] = [:]
    // Store descendants only: caching [self] on a Tab would retain the node forever.
    private(set) var tabDestinations: [ViewRenderer] = []

    func keyedNode(for id: AnyHashable) -> ViewRenderer? { keyedNodes[id] }

    // Return new storage instead of mutating through child updates. Focus restoration
    // can walk back into the parent during an update and must see its previous tree,
    // without overlapping an exclusive mutation of this value.
    func reconciling(
        _ views: [any View], parent: ViewRenderer, at date: Date
    ) -> Self {
        let previous = nodes
        var updated = self
        updated.nodes = views.enumerated().map { index, view in
            let node: ViewRenderer
            if index < previous.count, previous[index].matches(view) {
                node = previous[index]
            } else {
                if index < previous.count { previous[index].unmount() }
                node = parent.makeChild(view)
            }
            // Parent updates may change child inputs even before the child's own deadline.
            node.parent = parent
            node.update(view, at: date)
            return node
        }
        for child in previous.dropFirst(views.count) { child.unmount() }
        // Removed nodes have no independent timers. Releasing them also removes their
        // deadlines from the aggregate that drives the host's single wake-up timer.
        return updated
    }

    func reconcilingKeyed(
        _ views: [(id: AnyHashable, view: any View)], parent: ViewRenderer, at date: Date
    ) -> Self {
        let previous = keyedNodes
        var updated = self
        var retained: [AnyHashable: ViewRenderer] = [:]
        updated.nodes = views.map { id, view in
            let node: ViewRenderer
            if let existing = previous[id], existing.matches(view) {
                node = existing
            } else {
                previous[id]?.unmount()
                node = parent.makeChild(view)
            }
            node.parent = parent
            node.update(view, at: date)
            retained[id] = node
            return node
        }
        for (id, child) in previous where retained[id] == nil { child.unmount() }
        updated.keyedNodes = retained
        return updated
    }

    mutating func collectTabDestinations() {
        // Structural discovery belongs to mounting, not repeated layout and key walks.
        // Each child supplies its cached nearest destinations, stopping at nested TabViews.
        tabDestinations = nodes.flatMap(\.tabNodes)
    }

    mutating func unmount() {
        for child in nodes { child.unmount() }
        nodes = []
        tabDestinations = []
        keyedNodes = [:]
    }
}
