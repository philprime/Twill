import Foundation
import Testing

@testable import Twill

@Suite("Structural timeline identity")
@MainActor
struct SiblingTimelineTests {
    @Test("Sibling timelines update independently and static bodies stay cached")
    func independentSiblings() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var fast = 0
        var slow = 0
        var staticBodies = 0
        let root = HStack {
            TimelineView(.periodic(from: start, by: 0.05)) { _ -> Text in
                fast += 1
                return Text("F\(fast)")
            }
            TimelineView(.periodic(from: start, by: 1)) { _ -> Text in
                slow += 1
                return Text("S\(slow)")
            }
            StaticProbe { staticBodies += 1 }
        }
        let renderer = ViewRenderer.make(root)

        // -- Act --
        let initial = renderer.render(start)
        let fastOnly = renderer.render(start.addingTimeInterval(0.05))
        let slowBeforeDeadline = slow
        let shared = renderer.render(start.addingTimeInterval(1))

        // -- Assert --
        #expect(initial.grid?.snapshotText == "F1 S1 Static")
        #expect(fastOnly.grid?.snapshotText == "F2 S1 Static")
        #expect(slowBeforeDeadline == 1)
        #expect(shared.grid?.snapshotText == "F3 S2 Static")
        #expect(shared.nextUpdate == start.addingTimeInterval(1.05))
        #expect(staticBodies == 1)
    }

    @Test("Conditional removal drops deadlines and reinsertion mounts fresh content")
    func removalAndReinsertion() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var childDates: [Date] = []
        let root = TimelineView(.periodic(from: start, by: 0.1)) { parent in
            HStack {
                if parent.date < start.addingTimeInterval(0.1) || parent.date >= start.addingTimeInterval(0.2) {
                    TimelineView(.periodic(from: start, by: 0.05)) { child -> Text in
                        childDates.append(child.date)
                        return Text("Child")
                    }
                }
                Text("Static")
            }
        }
        let renderer = ViewRenderer.make(root)

        // -- Act --
        _ = renderer.render(start)
        _ = renderer.render(start.addingTimeInterval(0.05))
        let removed = renderer.render(start.addingTimeInterval(0.1))
        _ = renderer.render(start.addingTimeInterval(0.15))
        let countWhileRemoved = childDates.count
        let reinserted = renderer.render(start.addingTimeInterval(0.2))

        // -- Assert --
        #expect(removed.grid?.snapshotText == "Static")
        #expect(removed.nextUpdate == start.addingTimeInterval(0.2))
        #expect(countWhileRemoved == 2)
        #expect(childDates == [start, start.addingTimeInterval(0.05), start.addingTimeInterval(0.2)])
        #expect(reinserted.grid?.snapshotText == "Child Static")
        #expect(reinserted.nextUpdate == start.addingTimeInterval(0.25))
    }

    @Test("Different conditional branches have different identities even with matching view types")
    func branchIdentity() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var dates: [Date] = []
        let root = TimelineView(.periodic(from: start, by: 0.1)) { parent in
            HStack {
                if parent.date == start {
                    TimelineView(.periodic(from: start, by: 1)) { context -> Text in
                        dates.append(context.date)
                        return Text("First")
                    }
                } else {
                    TimelineView(.periodic(from: start, by: 1)) { context -> Text in
                        dates.append(context.date)
                        return Text("Second")
                    }
                }
            }
        }
        let renderer = ViewRenderer.make(root)

        // -- Act --
        _ = renderer.render(start)
        let frame = renderer.render(start.addingTimeInterval(0.1))

        // -- Assert --
        #expect(frame.grid?.snapshotText == "Second")
        #expect(dates == [start, start.addingTimeInterval(0.1)])
    }

    @Test("A changed concrete type at the same position discards the old node's deadline")
    func typeIdentity() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let root = TimelineView(.periodic(from: start, by: 0.1)) { context -> RuntimeContentSlot in
            if context.date == start {
                return RuntimeContentSlot(
                    content:
                        TimelineView(.periodic(from: start, by: 0.05)) { _ in Text("Timed") }
                )
            }
            return RuntimeContentSlot(content: Text("Static"))
        }
        let renderer = ViewRenderer.make(root)

        // -- Act --
        _ = renderer.render(start)
        let frame = renderer.render(start.addingTimeInterval(0.1))

        // -- Assert --
        #expect(frame.grid?.snapshotText == "Static")
        #expect(frame.nextUpdate == start.addingTimeInterval(0.2))
    }

    @Test("Unmounting releases objects captured by a removed timeline", arguments: [false, true])
    func releasesRemovedNode(replacement: Bool) {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        weak var retained: LifetimeProbe?
        let makeProbe = {
            let probe = LifetimeProbe()
            retained = probe
            return probe
        }
        let root = TimelineView(.periodic(from: start, by: 0.1)) { context in
            HStack {
                if context.date == start {
                    let probe = makeProbe()
                    TimelineView(.periodic(from: start, by: 1)) { [probe] _ in Text(probe.text) }
                } else if replacement {
                    Text("Removed")
                }
            }
        }
        let renderer = ViewRenderer.make(root)
        _ = renderer.render(start)
        let retainedWhileMounted = retained != nil

        // -- Act --
        _ = renderer.render(start.addingTimeInterval(0.1))

        // -- Assert --
        #expect(retainedWhileMounted)
        #expect(retained == nil)
    }

    @Test("An empty conditional retains the structural position of later siblings")
    func conditionalPosition() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var dates: [Date] = []
        let root = TimelineView(.periodic(from: start, by: 0.1)) { parent in
            HStack {
                if parent.date == start { Text("Prefix") }
                TimelineView(.periodic(from: start, by: 1)) { context -> Text in
                    dates.append(context.date)
                    return Text("Child")
                }
            }
        }
        let renderer = ViewRenderer.make(root)

        // -- Act --
        _ = renderer.render(start)
        let frame = renderer.render(start.addingTimeInterval(0.1))

        // -- Assert --
        #expect(frame.grid?.snapshotText == "Child")
        #expect(dates == [start, start])
    }

    @Test("Changed schedule values reconfigure a retained timeline")
    func scheduleChange() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var dates: [Date] = []
        let root = TimelineView(.periodic(from: start, by: 0.1)) { parent -> TimelineView<Text> in
            let interval = parent.date == start ? 1.0 : 0.25
            return TimelineView(.periodic(from: start, by: interval)) { context -> Text in
                dates.append(context.date)
                return Text("Child")
            }
        }
        let renderer = ViewRenderer.make(root)

        // -- Act --
        _ = renderer.render(start)
        _ = renderer.render(start.addingTimeInterval(0.1))
        let beforeChildDeadline = renderer.render(start.addingTimeInterval(0.2))
        _ = renderer.render(start.addingTimeInterval(0.25))

        // -- Assert --
        #expect(beforeChildDeadline.nextUpdate == start.addingTimeInterval(0.25))
        #expect(
            dates == [
                start, start.addingTimeInterval(0.1), start.addingTimeInterval(0.1), start.addingTimeInterval(0.25),
            ])
    }
}

/// Exercises concrete-type replacement directly at the erased runtime boundary.
private struct RuntimeContentSlot: View, PrimitiveView {
    typealias Body = Never
    let content: any View

    func makeDescription() -> ViewDescription { .body(content) }
}

private final class LifetimeProbe {
    let text = "Mounted"
}

private struct StaticProbe: View {
    let onBody: () -> Void

    var body: some View {
        onBody()
        return Text("Static")
    }
}
