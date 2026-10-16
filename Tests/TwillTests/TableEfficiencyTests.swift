import Testing

@testable import Twill

@Suite("Table event-driven efficiency")
@MainActor
struct TableEfficiencyTests {
    @Test("A large table returns to idle after a coalesced state update")
    func tableReturnsToIdle() throws {
        // -- Arrange --
        let runLoop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        var revisions: [Int] = []
        let host = ViewHost(
            rootView: TableFixture(onBody: { revisions.append($0) }), runLoop: runLoop, output: output)
        try host.start(size: TerminalSize(columns: 80, rows: 24), mode: .fullscreen)
        defer { host.stop() }
        // Initial focus synchronization may request one settling presentation.
        try #require(runLoop.sources.first).action()
        let initialSignals = runLoop.signalled.count
        let initialWrites = output.writes.count

        // -- Act --
        _ = host.handle(.space)
        _ = host.handle(.space)
        let pendingSignals = runLoop.signalled.count
        try #require(runLoop.sources.first).action()
        let settledEvaluations = revisions.count
        let settledWrites = output.writes.count
        _ = host.handle(.q)

        // -- Assert --
        #expect(pendingSignals == initialSignals + 1)
        #expect(runLoop.signalled.count == pendingSignals)
        #expect(runLoop.timers.isEmpty)
        #expect(revisions.count == settledEvaluations)
        #expect(revisions.last == 2)
        #expect(settledWrites > initialWrites)
        #expect(output.writes.count == settledWrites)
    }

    private struct TableFixture: View {
        struct Row: Identifiable {
            let id: Int
            var name: String { "Record \(id)" }
        }

        @State private var selection: Int? = 0
        @State private var revision = 0
        let onBody: @MainActor (Int) -> Void
        private let rows = (0..<500).map { Row(id: $0) }

        var body: some View {
            onBody(revision)
            return VStack {
                Text("Revision \(revision)")
                Table(rows, selection: $selection) {
                    TableColumn("Name", value: \.name)
                    TableColumn("ID") { Text(String($0.id)) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onKeyPress { key in
                guard key == .space else { return .ignored }
                revision += 1
                return .handled
            }
        }
    }
}
