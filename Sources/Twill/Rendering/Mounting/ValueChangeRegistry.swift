/// Pending nodes are weak, so delivery never extends a removed subtree's lifetime.
@MainActor
final class ValueChangeRegistry {
    private struct Pending {
        weak var node: ViewRenderer?
    }
    private var pending: [Pending] = []

    func enqueue(_ node: ViewRenderer, observer: any AnyValueChangeObserver) {
        guard observer.hasPendingChange, !observer.isQueued else { return }
        observer.isQueued = true
        pending.append(Pending(node: node))
    }

    func deliverPending() {
        // Reentrant writes and registrations belong to a future mounted pass.
        let delivery = pending
        pending.removeAll(keepingCapacity: true)
        for reference in delivery {
            guard let node = reference.node, let observer = node.changeObserver, observer.isMounted else { continue }
            guard node.isObservationActive else {
                pending.append(reference)
                continue
            }
            observer.deliver()
        }
    }
}

@MainActor
extension ViewRenderer {
    var isObservationActive: Bool {
        var node = self
        if case .tab = node.description, !node.tabState.isActive { return false }
        while let parent = node.parent {
            let children: [ViewRenderer]
            if case .sheet = parent.description {
                // Both sheet layers are visible, although only the base participates in inline layout.
                children = parent.retainedChildren
            } else {
                children = parent.presentationChildren
            }
            guard children.contains(where: { $0 === node }) else { return false }
            node = parent
        }
        return true
    }
}
