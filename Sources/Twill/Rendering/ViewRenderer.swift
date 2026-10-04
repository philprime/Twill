import Foundation

/// A mounted node. Parents match children by structural position and concrete type,
/// retaining current inputs, cached content, and timeline state.
@MainActor
final class ViewRenderer {
    var onInvalidation: (() -> Void)?
    var caretPosition: CellPosition?

    private struct TimelineState {
        let schedule: PeriodicTimelineSchedule
        let date: Date
        let deadline: Date
    }

    private let viewType: ObjectIdentifier
    private let taskRegistry: MountedTaskRegistry
    private var viewTask: Task<Void, Never>?
    weak var parent: ViewRenderer?
    private var initialView: (any View)?
    private var mountedView: (any View)?
    private var stateLocations: [String: any StateLocation] = [:]
    private var isDirty = false
    private var hasDirtyDescendant = false
    var description: ViewDescription?
    var children: [ViewRenderer] = []
    private var keyedChildren: [AnyHashable: ViewRenderer] = [:]
    weak var focusedNode: ViewRenderer?
    weak var activePane: ViewRenderer?
    var scrollOffset = 0
    var scrollContentHeight = 0
    private var timeline: TimelineState?
    private var canvasDate: Date?
    var placements: [(node: ViewRenderer, bounds: CellRect)] = []
    var measuredSize = CellSize.zero
    private var nextUpdate: Date?

    private init(_ view: any View, taskRegistry: MountedTaskRegistry) {
        viewType = ObjectIdentifier(type(of: view))
        self.taskRegistry = taskRegistry
        initialView = view
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
        viewTask?.cancel()
        viewTask = nil
        for child in children { child.unmount() }
        children = []
        keyedChildren = [:]
    }

    private func removeChildren() {
        for child in children { child.unmount() }
        children = []
        keyedChildren = [:]
    }

    func render(
        _ date: Date, proposal: ProposedCellSize = .unspecified, centeredInViewport: Bool = false
    ) -> (grid: CellGrid?, nextUpdate: Date?) {
        refreshContent(at: date)
        return (drawFrame(proposal: proposal, centeredInViewport: centeredInViewport), nextUpdate)
    }

    func refreshContent(at date: Date) {
        if let initialView {
            update(initialView, at: date)
        } else {
            refresh(at: date)
        }
    }

    /// Layout and drawing never evaluate bodies or advance timeline deadlines.
    func drawFrame(proposal: ProposedCellSize, centeredInViewport: Bool = false) -> CellGrid? {
        let sheet = activeSheet()
        let content = sheet?.sheetBranch ?? self
        if let sheet { return drawOverlay(sheet: sheet, proposal: proposal) }
        guard !content.layoutItems.isEmpty else {
            caretPosition = nil
            return nil
        }
        let size = content.measure(proposal)
        let scope = sheet ?? self
        let focused = scope.focusTarget()
        let viewport =
            centeredInViewport
            ? CellSize(width: proposal.width ?? size.width, height: proposal.height ?? size.height) : size
        var context = DrawingContext(size: viewport)
        let origin = CellRect(
            column: max(0, (viewport.width - size.width) / 2),
            row: max(0, (viewport.height - size.height) / 2), width: size.width, height: size.height)
        content.revealFocus(focused)
        context.withRegion(origin) { content.draw(in: &$0, focused: focused) }
        caretPosition = context.caret
        return context.grid
    }

    var drawing: (any PrimitiveDrawing)? {
        switch description {
        case .drawing(let drawing): return drawing
        case .canvas(_, let render):
            return Canvas.Drawing(size: measuredSize, date: canvasDate ?? .now, render: render)
        case .textField(let field): return field.drawing
        default: return nil
        }
    }

    private static func describe<Content: View>(_ view: Content) -> ViewDescription {
        if let primitive = view as? any PrimitiveView { return primitive.makeDescription() }
        return .body(view.body)
    }

    private func bindState(from view: any View) {
        // Fresh view values carry fresh property-wrapper handles. Bind them to this
        // node's locations before evaluating body, so parent updates retain state.
        for property in Mirror(reflecting: view).children {
            guard let name = property.label, let state = property.value as? any MountedStateProperty else { continue }
            let location = stateLocations[name] ?? state.location
            state.bind(to: location)
            location.onChange = { [weak self] in self?.markDirty() }
            stateLocations[name] = location
        }
    }

    private func update(_ view: any View, at date: Date) {
        initialView = nil
        bindState(from: view)
        mountedView = view
        let previous = description
        let updated = Self.describe(view)
        description = updated
        switch updated {
        case .empty, .drawing, .textField:
            removeChildren()
        case .canvas(let interval, _):
            removeChildren()
            updateCanvas(interval: interval, at: date)
        case .body(let body):
            reconcile([body], at: date)
        case .group(let views, _):
            reconcile(views, at: date)
        case .keyed(let views):
            reconcileKeyed(views, at: date)
        case .scrollReader(let content, let proxy):
            if case .scrollReader(_, let previousProxy) = previous { previousProxy.renderer = nil }
            proxy.renderer = self
            reconcile([content], at: date)
        case .focusable(let content), .scroll(let content), .keyPress(let content, _), .styled(let content, _, _),
            .border(let content, _, _):
            reconcile([content], at: date)
        case .task, .sheet, .conditional, .timeline:
            updateDynamicContent(updated, previous: previous, at: date)
        }
        collectDeadlines()
    }

    private func updateDynamicContent(_ description: ViewDescription, previous: ViewDescription?, at date: Date) {
        switch description {
        case .task(let content, let priority, let action):
            updateTask(content, priority: priority, action: action, at: date)
        case .sheet(let base, let isPresented, let content):
            reconcile(isPresented.wrappedValue ? [base, content()] : [base], at: date)
        case .conditional(let first, let content):
            updateConditional(first: first, content: content, previous: previous, at: date)
        case .timeline(let schedule, let content):
            let contextDate = advanceTimeline(schedule, at: date)
            reconcile([content(contextDate)], at: date)
        default:
            break
        }
    }

    private func updateCanvas(interval: TimeInterval?, at date: Date) {
        guard let interval else {
            timeline = nil
            canvasDate = date
            return
        }
        let start = timeline?.schedule.interval == interval ? timeline!.schedule.start : date
        canvasDate = advanceTimeline(.periodic(from: start, by: interval), at: date)
    }

    private func advanceTimeline(_ schedule: PeriodicTimelineSchedule, at date: Date) -> Date {
        if let timeline, timeline.schedule == schedule, date < timeline.deadline {
            return timeline.date
        }
        timeline = TimelineState(schedule: schedule, date: date, deadline: schedule.nextUpdate(after: date))
        return date
    }

    private func reconcile(_ views: [any View], at date: Date) {
        let previous = children
        children = views.enumerated().map { index, view in
            let node: ViewRenderer
            if index < previous.count, previous[index].viewType == ObjectIdentifier(type(of: view)) {
                node = previous[index]
            } else {
                if index < previous.count { previous[index].unmount() }
                node = Self.make(view, taskRegistry: taskRegistry)
            }
            // Parent updates may change child inputs even before the child's own deadline.
            node.parent = self
            node.update(view, at: date)
            return node
        }
        for child in previous.dropFirst(views.count) { child.unmount() }
        // Removed nodes have no independent timers. Releasing them also removes their
        // deadlines from the aggregate that drives the host's single wake-up timer.
    }

    private func reconcileKeyed(_ views: [(id: AnyHashable, view: any View)], at date: Date) {
        let previous = keyedChildren
        var retained: [AnyHashable: ViewRenderer] = [:]
        children = views.map { id, view in
            let node: ViewRenderer
            if let existing = previous[id], existing.viewType == ObjectIdentifier(type(of: view)) {
                node = existing
            } else {
                previous[id]?.unmount()
                node = Self.make(view, taskRegistry: taskRegistry)
            }
            node.parent = self
            node.update(view, at: date)
            retained[id] = node
            return node
        }
        for (id, child) in previous where retained[id] == nil { child.unmount() }
        keyedChildren = retained
    }

    private func markDirty() {
        isDirty = true
        if let parent { parent.markDescendantDirty() } else { onInvalidation?() }
    }

    private func markDescendantDirty() {
        // Wake ancestors without re-evaluating their bodies or shifting an
        // unrelated timeline's phase.
        hasDirtyDescendant = true
        if let parent { parent.markDescendantDirty() } else { onInvalidation?() }
    }

    private func refresh(at date: Date) {
        if isDirty, let mountedView {
            isDirty = false
            hasDirtyDescendant = false
            update(mountedView, at: date)
            return
        }
        guard hasDirtyDescendant || nextUpdate.map({ date >= $0 }) == true else { return }
        hasDirtyDescendant = false
        let timelineIsDue = timeline.map { date >= $0.deadline } ?? false
        if timelineIsDue {
            switch description {
            case .timeline(let schedule, let content):
                let contextDate = advanceTimeline(schedule, at: date)
                reconcile([content(contextDate)], at: date)
            case .canvas(let interval?, _):
                let start = timeline!.schedule.start
                canvasDate = advanceTimeline(.periodic(from: start, by: interval), at: date)
            default:
                break
            }
        } else {
            for child in children { child.refresh(at: date) }
        }
        collectDeadlines()
    }

    private func collectDeadlines() {
        nextUpdate = timeline?.deadline
        for child in children {
            if let deadline = child.nextUpdate {
                nextUpdate = min(nextUpdate ?? deadline, deadline)
            }
        }
    }
}

extension ViewRenderer {
    func keyedNode(for id: AnyHashable) -> ViewRenderer? {
        if let node = keyedChildren[id] { return node }
        for child in children {
            if let node = child.keyedNode(for: id) { return node }
        }
        return nil
    }

    private func updateTask(
        _ content: any View, priority: TaskPriority, action: @escaping @MainActor @Sendable () async -> Void,
        at date: Date
    ) {
        reconcile([content], at: date)
        if viewTask == nil { viewTask = taskRegistry.start(priority: priority, action: action) }
    }

    private func updateConditional(first: Bool, content: any View, previous: ViewDescription?, at date: Date) {
        if case .conditional(let wasFirst, _) = previous, first != wasFirst {
            removeChildren()
        }
        reconcile([content], at: date)
    }

}
