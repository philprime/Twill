import Foundation
import Testing

@testable import Twill

@Suite("Disclosure group scheduling")
@MainActor
struct DisclosureGroupSchedulingTests {
    @MainActor private final class Model {
        var expanded = false
        var childDates: [Date] = []
        var siblingDates: [Date] = []
        var binding: Binding<Bool> { Binding(get: { self.expanded }, set: { self.expanded = $0 }) }
    }

    @Test("Collapsed content loses its deadlines while sibling schedules retain their phase")
    func collapseDeadlines() {
        // -- Arrange --
        let model = Model()
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let renderer = ViewRenderer.make(
            TimelineView(.periodic(from: start, by: 1)) { _ in
                VStack {
                    DisclosureGroup("Details", isExpanded: model.binding) {
                        TimelineView(.periodic(from: start, by: 0.25)) { context -> Text in
                            model.childDates.append(context.date)
                            return Text("Child")
                        }
                    }
                    TimelineView(.periodic(from: start, by: 60)) { context -> Text in
                        model.siblingDates.append(context.date)
                        return Text("Sibling")
                    }
                }
            })
        let collapsed = renderer.render(start)

        // -- Act --
        model.expanded = true
        let expanded = renderer.render(start.addingTimeInterval(1))
        model.expanded = false
        let removed = renderer.render(start.addingTimeInterval(2))
        let idle = renderer.render(start.addingTimeInterval(2.5))

        // -- Assert --
        #expect(collapsed.nextUpdate == start.addingTimeInterval(1))
        #expect(expanded.nextUpdate == start.addingTimeInterval(1.25))
        #expect(removed.nextUpdate == start.addingTimeInterval(3))
        #expect(idle.nextUpdate == removed.nextUpdate)
        #expect(model.childDates == [start.addingTimeInterval(1)])
        #expect(model.siblingDates == [start, start, start])
    }

    @Test("Unchanged parent updates do not advance a disclosed child's timeline")
    func parentUpdates() {
        // -- Arrange --
        let model = Model()
        model.expanded = true
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let renderer = ViewRenderer.make(
            TimelineView(.periodic(from: start, by: 0.1)) { _ in
                DisclosureGroup("Details", isExpanded: model.binding) {
                    TimelineView(.periodic(from: start, by: 0.25)) { context -> Text in
                        model.childDates.append(context.date)
                        return Text("Static")
                    }
                }
            })
        let initial = renderer.render(start)

        // -- Act --
        let parent = renderer.render(start.addingTimeInterval(0.1))
        let child = renderer.render(start.addingTimeInterval(0.25))

        // -- Assert --
        #expect(parent.grid == initial.grid)
        #expect(child.grid == initial.grid)
        #expect(model.childDates == [start, start, start.addingTimeInterval(0.25)])
    }
}
