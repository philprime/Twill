import Foundation
import Testing

@testable import Twill

@Suite("Command palette scheduling")
@MainActor
struct CommandPaletteSchedulingTests {
    @Test("Parent ticks retain search and sibling phases; removal releases palette work")
    func independentPhases() throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var dates: [Date] = []
        var actions: [String] = []
        func content(_ show: Bool) -> some View {
            VStack {
                if show {
                    TimelineView(.periodic(from: start, by: 10)) { _ in
                        CommandPalette(
                            commands: [
                                Command("alpha", title: "Alpha") { actions.append("alpha") },
                                Command("run", title: "Run") { actions.append("run") },
                            ], dismiss: {})
                    }.id(1)
                }
                TimelineView(.periodic(from: start, by: 20)) { context in
                    dates.append(context.date)
                    return Text("Sibling")
                }
            }
        }
        let renderer = ViewRenderer.make(content(true))
        _ = renderer.render(start)
        _ = renderer.handle(.r)
        _ = renderer.render(start)
        weak var palette: ViewRenderer?
        palette = renderer.keyedNode(for: 1)

        // -- Act --
        renderer.update(content(true), at: start.addingTimeInterval(1))
        let updated = renderer.render(start.addingTimeInterval(1))
        _ = renderer.render(start.addingTimeInterval(10))
        let filtered = try #require(renderer.render(start.addingTimeInterval(10)).grid)
        _ = renderer.handle(.enter)
        renderer.update(content(false), at: start.addingTimeInterval(11))
        let removed = renderer.render(start.addingTimeInterval(11))

        // -- Assert --
        #expect(!filtered.snapshotText.contains("Alpha"))
        #expect(actions == ["run"] && palette == nil)
        #expect(updated.nextUpdate == start.addingTimeInterval(10))
        #expect(removed.nextUpdate == start.addingTimeInterval(20))
        #expect(dates == [start, start, start])
    }

    @Test("Unchanged palette output stays suppressed on parent ticks")
    func unchangedOutput() throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var now = start
        let loop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        let host = ViewHost(
            rootView: TimelineView(.periodic(from: start, by: 1)) { _ in
                CommandPalette(commands: [Command(1, title: "Run", action: {})], dismiss: {})
            }, runLoop: loop, output: output, now: { now })
        try host.start()
        defer { host.stop() }
        let writes = output.writes
        let timer = try #require(loop.timers.first)

        // -- Act --
        now = start.addingTimeInterval(1)
        timer.action()

        // -- Assert --
        #expect(output.writes == writes)
    }
}
