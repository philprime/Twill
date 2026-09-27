import Foundation

/// A mounted node. Parents match children by structural position and concrete type,
/// retaining cached content and timeline state without retaining old view values.
@MainActor
final class ViewRenderer {
    private struct TimelineState {
        let schedule: PeriodicTimelineSchedule
        let date: Date
        let deadline: Date
    }

    private let viewType: ObjectIdentifier
    private var initialView: (any View)?
    private var description: ViewDescription?
    private var children: [ViewRenderer] = []
    private var timeline: TimelineState?
    private var textParts: [String] = []
    private var nextUpdate: Date?

    private init(_ view: any View) {
        viewType = ObjectIdentifier(type(of: view))
        initialView = view
    }

    static func make<Content: View>(_ view: Content) -> ViewRenderer {
        ViewRenderer(view)
    }

    func render(_ date: Date) -> (text: String?, nextUpdate: Date?) {
        if let initialView {
            update(initialView, at: date)
        } else {
            refresh(at: date)
        }
        // No presentation (EmptyView) is distinct from a Text containing an empty line.
        return (textParts.isEmpty ? nil : textParts.joined(), nextUpdate)
    }

    private static func describe<Content: View>(_ view: Content) -> ViewDescription {
        if let primitive = view as? any PrimitiveView { return primitive.makeDescription() }
        return .body(view.body)
    }

    private func update(_ view: any View, at date: Date) {
        initialView = nil
        let previous = description
        let updated = Self.describe(view)
        description = updated
        switch updated {
        case .text:
            children = []
        case .body(let body):
            reconcile([body], at: date)
        case .group(let views, _):
            reconcile(views, at: date)
        case .conditional(let first, let content):
            if case .conditional(let wasFirst, _) = previous, first != wasFirst {
                children = []
            }
            reconcile([content], at: date)
        case .timeline(let schedule, let content):
            let contextDate = advanceTimeline(schedule, at: date)
            reconcile([content(contextDate)], at: date)
        }
        collectPresentation()
    }

    private func advanceTimeline(_ schedule: PeriodicTimelineSchedule, at date: Date) -> Date {
        if let timeline, timeline.schedule == schedule, date < timeline.deadline {
            return timeline.date
        }
        timeline = TimelineState(schedule: schedule, date: date, deadline: schedule.nextUpdate(after: date))
        return date
    }

    private func reconcile(_ views: [any View], at date: Date) {
        children = views.enumerated().map { index, view in
            let node: ViewRenderer
            if index < children.count, children[index].viewType == ObjectIdentifier(type(of: view)) {
                node = children[index]
            } else {
                node = Self.make(view)
            }
            // Parent updates may change child inputs even before the child's own deadline.
            node.update(view, at: date)
            return node
        }
        // Removed nodes have no independent timers. Releasing them also removes their
        // deadlines from the aggregate that drives the host's single wake-up timer.
    }

    private func refresh(at date: Date) {
        guard let nextUpdate, date >= nextUpdate else { return }
        let timelineIsDue = timeline.map { date >= $0.deadline } ?? false
        if timelineIsDue, case .timeline(let schedule, let content) = description {
            let contextDate = advanceTimeline(schedule, at: date)
            reconcile([content(contextDate)], at: date)
        } else {
            for child in children { child.refresh(at: date) }
        }
        collectPresentation()
    }

    private func collectPresentation() {
        if case .text(let text) = description {
            textParts = text.map { [$0] } ?? []
        } else {
            let parts = children.flatMap(\.textParts)
            if case .group(_, let separator?) = description {
                textParts = parts.isEmpty ? [] : [parts.joined(separator: separator)]
            } else {
                textParts = parts
            }
        }
        nextUpdate = timeline?.deadline
        for child in children {
            if let deadline = child.nextUpdate {
                nextUpdate = min(nextUpdate ?? deadline, deadline)
            }
        }
    }
}
