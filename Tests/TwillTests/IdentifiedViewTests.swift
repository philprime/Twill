import Foundation
import Testing

@testable import Twill

@Suite("Explicit mounted identity")
@MainActor
struct IdentifiedViewTests {
    private struct Counter: View {
        let title: String
        @State private var count = 0

        var body: some View {
            Button("\(title):\(count)") { count += 1 }
        }
    }

    @Test("Equal IDs preserve state while updating the content's inputs")
    func equalIdentity() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(Counter(title: "First").id(1))
        _ = renderer.render(.now)
        _ = renderer.handle(.enter)
        _ = renderer.render(.now)

        // -- Act --
        renderer.update(Counter(title: "Updated").id(1), at: .now)
        let frame = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(frame.snapshotText == "Updated:1")
    }

    @Test("Changing an ID resets state and returning to an old ID mounts fresh state")
    func changedIdentity() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(Counter(title: "Count").id(1))
        _ = renderer.render(.now)
        _ = renderer.handle(.enter)
        _ = renderer.render(.now)

        // -- Act --
        renderer.update(Counter(title: "Count").id(2), at: .now)
        let changed = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.enter)
        _ = renderer.render(.now)
        renderer.update(Counter(title: "Count").id(1), at: .now)
        let returned = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(changed.snapshotText == "Count:0")
        #expect(returned.snapshotText == "Count:0")
    }

    @Test("Replacing identified content does not reset a structural sibling")
    func siblingState() throws {
        // -- Arrange --
        func content(id: Int) -> some View {
            HStack {
                Counter(title: "A").id(id)
                Counter(title: "B")
            }
        }
        let renderer = ViewRenderer.make(content(id: 1))
        _ = renderer.render(.now)
        _ = renderer.handle(.enter)
        _ = renderer.handle(.arrowRight)
        _ = renderer.handle(.enter)
        _ = renderer.render(.now)

        // -- Act --
        renderer.update(content(id: 2), at: .now)
        let frame = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(frame.snapshotText == "A:0 B:1")
        #expect(frame.isFocused(column: 4, row: 0))
    }

    @Test("Focus and viewport memory follow the identified subtree's lifetime")
    func focusAndScroll() throws {
        // -- Arrange --
        func pane(id: Int) -> some View {
            ScrollView {
                VStack(alignment: .leading) {
                    Button("First") {}
                    Button("Second") {}
                    Button("Third") {}
                }
            }
            .frame(height: 1)
            .id(id)
        }
        let renderer = ViewRenderer.make(pane(id: 1))
        _ = renderer.render(.now)
        _ = renderer.handle(.arrowDown)
        let moved = try #require(renderer.render(.now).grid)

        // -- Act --
        renderer.update(pane(id: 1), at: .now)
        let retained = try #require(renderer.render(.now).grid)
        renderer.update(pane(id: 2), at: .now)
        let replaced = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(moved.snapshotText == "Second")
        #expect(retained.snapshotText == "Second")
        #expect(retained.isFocused(column: 0, row: 0))
        #expect(replaced.snapshotText == "First ")
        #expect(replaced.isFocused(column: 0, row: 0))
    }

    @Test("Equal identity preserves deadlines and replacement leaves sibling schedules unchanged")
    func timelineLifetime() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var childDates: [Date] = []
        var siblingDates: [Date] = []
        func content(id: Int) -> some View {
            HStack {
                TimelineView(.periodic(from: start, by: 10)) { context in
                    childDates.append(context.date)
                    return Text("Child")
                }.id(id)
                TimelineView(.periodic(from: start, by: 20)) { context in
                    siblingDates.append(context.date)
                    return Text("Sibling")
                }
            }
        }
        let renderer = ViewRenderer.make(content(id: 1))
        _ = renderer.render(start)

        // -- Act --
        renderer.update(content(id: 1), at: start.addingTimeInterval(1))
        let retained = renderer.render(start.addingTimeInterval(1))
        renderer.update(content(id: 2), at: start.addingTimeInterval(2))
        let replaced = renderer.render(start.addingTimeInterval(2))

        // -- Assert --
        #expect(childDates == [start, start, start.addingTimeInterval(2)])
        #expect(siblingDates == [start, start, start])
        #expect(retained.nextUpdate == start.addingTimeInterval(10))
        #expect(replaced.nextUpdate == start.addingTimeInterval(10))
        #expect(retained.grid?.snapshotText == "Child Sibling")
        #expect(replaced.grid?.snapshotText == "Child Sibling")
    }

    @Test("Equal and replaced identity with unchanged output do not emit another frame")
    func unchangedOutput() throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var now = start
        let runLoop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        let host = ViewHost(
            rootView: TimelineView(.periodic(from: start, by: 1)) { context in
                Text("Static").id(context.date < start.addingTimeInterval(2) ? "first" : "second")
            },
            runLoop: runLoop, output: output, now: { now })
        try host.start()
        defer { host.stop() }
        let firstTimer = try #require(runLoop.timers.first)

        // -- Act --
        now = start.addingTimeInterval(1)
        firstTimer.action()
        let secondTimer = try #require(runLoop.timers.last)
        now = start.addingTimeInterval(2)
        secondTimer.action()

        // -- Assert --
        #expect(output.writes == ["\r\u{1B}[2KStatic"])
    }

    @Test("A static identified subtree does not schedule work")
    func staticIdentity() {
        // -- Arrange --
        let renderer = ViewRenderer.make(Text("Static").id("content"))

        // -- Act --
        let frame = renderer.render(.now)

        // -- Assert --
        #expect(frame.grid?.snapshotText == "Static")
        #expect(frame.nextUpdate == nil)
    }
}
