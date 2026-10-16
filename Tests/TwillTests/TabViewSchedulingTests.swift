import Foundation
import Testing

@testable import Twill

@Suite("Tab view scheduling")
@MainActor
struct TabViewSchedulingTests {
    private struct Fixture: View {
        @State private var selection = 0
        let start: Date
        let capture: (Binding<Int>) -> Void
        let firstTick: (Date) -> Void
        let secondTick: (Date) -> Void

        var body: some View {
            capture($selection)
            return TabView(selection: $selection) {
                Tab("First", value: 0) {
                    TimelineView(.periodic(from: start, by: 2)) { context in
                        firstTick(context.date)
                        return Text("A\(Int(context.date.timeIntervalSinceReferenceDate))")
                    }
                }
                Tab("Second", value: 1) {
                    TimelineView(.periodic(from: start, by: 3)) { context in
                        secondTick(context.date)
                        return Text("B\(Int(context.date.timeIntervalSinceReferenceDate))")
                    }
                }
            }
        }
    }

    @Test("Tab switches preserve independent timeline phases and hidden ticks leave output unchanged")
    func independentTimelines() throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var selection: Binding<Int>?
        var firstDates: [Date] = []
        var secondDates: [Date] = []
        let renderer = ViewRenderer.make(
            Fixture(
                start: start, capture: { selection = $0 }, firstTick: { firstDates.append($0) },
                secondTick: { secondDates.append($0) }))
        let initial = renderer.render(start)

        // -- Act --
        selection?.wrappedValue = 1
        let switched = renderer.render(start.addingTimeInterval(1))
        let hiddenTick = renderer.render(start.addingTimeInterval(2))
        selection?.wrappedValue = 0
        let restored = renderer.render(start.addingTimeInterval(2.5))

        // -- Assert --
        #expect(initial.nextUpdate == start.addingTimeInterval(2))
        #expect(switched.nextUpdate == start.addingTimeInterval(2))
        #expect(hiddenTick.nextUpdate == start.addingTimeInterval(3))
        #expect(hiddenTick.grid?.snapshotText == switched.grid?.snapshotText)
        #expect(try #require(restored.grid).snapshotText.contains("A102"))
        #expect(restored.nextUpdate == start.addingTimeInterval(3))
        #expect(Set(firstDates) == Set([start, start.addingTimeInterval(2)]))
        #expect(Set(secondDates) == Set([start]))
    }

    @Test("Static tabs remain unscheduled")
    func staticTabs() throws {
        // -- Arrange --
        let runLoop = RecordingRunLoop()
        var selection = 0
        let host = ViewHost(
            rootView: TabView(selection: Binding(get: { selection }, set: { selection = $0 })) {
                Tab("One", value: 0) { Text("A") }
                Tab("Two", value: 1) { Text("B") }
            }, runLoop: runLoop, output: RecordingTerminalOutput())

        // -- Act --
        try host.start()
        host.stop()

        // -- Assert --
        #expect(runLoop.timers.isEmpty)
    }
}
