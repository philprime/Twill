import Foundation
import Testing

@testable import Twill

@Suite("Selection policy scheduling")
@MainActor
struct SelectionPolicySchedulingTests {
    @Test("Policy updates retain sibling timeline phases")
    func independentDeadlines() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var dates: [Date] = []
        var rowDates: [Date] = []
        func content(_ policy: SelectionPolicy) -> some View {
            HStack {
                List([1], id: \.self, selection: .constant(nil), selectionPolicy: policy) { _ in
                    TimelineView(.periodic(from: start, by: 20)) { context in
                        rowDates.append(context.date)
                        return Text("Row")
                    }
                }
                TimelineView(.periodic(from: start, by: 10)) { context in
                    dates.append(context.date)
                    return Text("Sibling")
                }
            }
        }
        let renderer = ViewRenderer.make(content(.firstVisible))
        _ = renderer.render(start)

        // -- Act --
        renderer.update(content(.allowEmpty), at: start.addingTimeInterval(1))
        let changed = renderer.render(start.addingTimeInterval(1))
        let ticked = renderer.render(start.addingTimeInterval(10))

        // -- Assert --
        #expect(rowDates == [start, start])
        #expect(dates == [start, start, start.addingTimeInterval(10)])
        #expect(changed.nextUpdate == start.addingTimeInterval(10))
        #expect(ticked.nextUpdate == start.addingTimeInterval(20))
    }

    @Test("Unchanged empty selection emits no output on a parent tick")
    func unchangedOutput() throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var now = start
        let loop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        let host = ViewHost(
            rootView: TimelineView(.periodic(from: start, by: 1)) { _ in
                List([1, 2], id: \.self, selection: .constant(nil), selectionPolicy: .allowEmpty) { Text("\($0)") }
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
