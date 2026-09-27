import Foundation
import Testing

@testable import Twill

@Suite("Mounted timeline scheduling")
@MainActor
struct MountedTimelineTests {
    @Test("A fast nested timeline does not re-evaluate its slow parent")
    func nestedDeadlines() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var outerDates: [Date] = []
        var innerDates: [Date] = []
        let root = TimelineView(.periodic(from: start, by: 1)) { outer -> TimelineView<Text> in
            outerDates.append(outer.date)
            return TimelineView(.periodic(from: start, by: 0.05)) { inner -> Text in
                innerDates.append(inner.date)
                return Text("Tick")
            }
        }
        let renderer = ViewRenderer.make(root)

        // -- Act --
        _ = renderer.render(start)
        let frame = renderer.render(start.addingTimeInterval(0.05))

        // -- Assert --
        #expect(outerDates == [start])
        #expect(innerDates == [start, start.addingTimeInterval(0.05)])
        #expect(frame.nextUpdate == start.addingTimeInterval(0.10))
    }

    @Test("Parent-driven content updates preserve the child's timeline context")
    func parentUpdate() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var outerUpdates = 0
        var innerDates: [Date] = []
        let root = TimelineView(.periodic(from: start, by: 0.05)) { _ -> TimelineView<Text> in
            outerUpdates += 1
            let label = "Parent \(outerUpdates)"
            return TimelineView(.periodic(from: start, by: 1)) { context -> Text in
                innerDates.append(context.date)
                return Text(label)
            }
        }
        let renderer = ViewRenderer.make(root)

        // -- Act --
        _ = renderer.render(start)
        let frame = renderer.render(start.addingTimeInterval(0.05))

        // -- Assert --
        #expect(frame.text == "Parent 2")
        #expect(innerDates == [start, start])
    }
}
