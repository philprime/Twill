import Foundation

/// Coordinates one mounted node. Content, child identity, and logical scheduling have
/// separate owners, while presentation and interaction operate on the cached tree.
@MainActor
final class ViewRenderer {
    var onInvalidation: (() -> Void)?
    var caretPosition: CellPosition?

    private let viewType: ObjectIdentifier
    private let taskRegistry: MountedTaskRegistry
    private var viewTask: Task<Void, Never>?
    weak var parent: ViewRenderer?
    var content: MountedContent
    var childStorage = MountedChildren()
    var schedule = MountedSchedule()
    var description: ViewDescription?
    var descendantTabNodes: [ViewRenderer] { childStorage.tabDestinations }
    var nextUpdate: Date? { schedule.nextUpdate }

    var focusState = MountedFocusState()
    var tabState = MountedTabState()
    var editorState = MountedEditorState()
    var scrollState = MountedScrollState()
    var layoutState = MountedLayoutState()
    var sheetState = MountedSheetState()

    private init(_ view: any View, taskRegistry: MountedTaskRegistry) {
        viewType = ObjectIdentifier(type(of: view))
        self.taskRegistry = taskRegistry
        content = MountedContent(view)
    }

    static func make<Content: View>(
        _ view: Content, taskRegistry: MountedTaskRegistry = MountedTaskRegistry()
    ) -> ViewRenderer {
        ViewRenderer(view, taskRegistry: taskRegistry)
    }

    func unmount() {
        if case .scrollReader(_, let proxy) = description { proxy.renderer = nil }
        parent = nil
        onInvalidation = nil
        // Cancellation belongs to the node, but joining belongs to the host's registry.
        // A removed node must not discard the only handle to unfinished cleanup work.
        viewTask?.cancel()
        viewTask = nil
        let onDismiss = sheetState.end()
        childStorage.unmount()
        onDismiss?()
    }

    func matches(_ view: any View) -> Bool {
        viewType == ObjectIdentifier(type(of: view))
    }

    func makeChild(_ view: any View) -> ViewRenderer {
        Self.make(view, taskRegistry: taskRegistry)
    }

    func reconcile(_ views: [any View], at date: Date) {
        childStorage = childStorage.reconciling(views, parent: self, at: date)
    }

    func reconcileKeyed(_ views: [(id: AnyHashable, view: any View)], at date: Date) {
        childStorage = childStorage.reconcilingKeyed(views, parent: self, at: date)
    }

    func removeChildren() {
        childStorage.unmount()
    }

    func keyedNode(for id: AnyHashable) -> ViewRenderer? {
        if let node = childStorage.keyedNode(for: id) { return node }
        for child in retainedChildren {
            if let node = child.keyedNode(for: id) { return node }
        }
        return nil
    }

    func render(
        _ date: Date, proposal: ProposedCellSize = .unspecified, centeredInViewport: Bool = false
    ) -> (grid: CellGrid?, nextUpdate: Date?) {
        refreshContent(at: date)
        return (drawFrame(proposal: proposal, centeredInViewport: centeredInViewport), nextUpdate)
    }

    func refreshContent(at date: Date) {
        if let initialView = content.initialView {
            update(initialView, at: date)
        } else {
            refresh(at: date)
        }
    }

    func markDirty() {
        content.markDirty()
        if let parent { parent.markDescendantDirty() } else { onInvalidation?() }
    }

    private func markDescendantDirty() {
        // Wake ancestors without re-evaluating their bodies or shifting an
        // unrelated timeline's phase.
        content.markDescendantDirty()
        if let parent { parent.markDescendantDirty() } else { onInvalidation?() }
    }

    private func refresh(at date: Date) {
        if let mountedView = content.consumeDirtyView() {
            update(mountedView, at: date)
            return
        }
        guard content.hasDirtyDescendant || nextUpdate.map({ date >= $0 }) == true else { return }
        content.consumeDescendantInvalidation()
        if schedule.isDue(at: date) {
            switch description {
            case .timeline(let timelineSchedule, let body):
                let contextDate = schedule.advance(timelineSchedule, at: date)
                reconcile([body(contextDate)], at: date)
            case .canvas(let interval?, _):
                schedule.advanceCanvas(interval: interval, at: date)
            default:
                break
            }
        } else {
            for child in retainedChildren { child.refresh(at: date) }
        }
        if case .dialog(_, _, let kind) = description { updateDialogFallback(kind: kind, at: date) }
        // Children must settle before selection/focus restoration and deadline aggregation.
        // Those operations may inspect a descendant's freshly reconciled identity.
        updateTabState()
        schedule.collectDeadlines(retainedChildren.lazy.map(\.nextUpdate))
    }

    func updateTask(
        _ content: any View, priority: TaskPriority, action: @escaping @MainActor @Sendable () async -> Void,
        at date: Date
    ) {
        reconcile([content], at: date)
        if viewTask == nil { viewTask = taskRegistry.start(priority: priority, action: action) }
    }
}
