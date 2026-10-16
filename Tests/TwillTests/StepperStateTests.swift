import Testing

@testable import Twill

@Suite("Mounted stepper state")
@MainActor
struct StepperStateTests {
    private struct Counter: View {
        @State private var value = 1
        let capture: @MainActor (Binding<Int>) -> Void

        var body: some View {
            capture($value)
            return VStack(alignment: .leading) {
                Stepper("Count", value: $value, in: 0...3)
                Button("Done") {}
            }
        }
    }

    @Test("Rapid adjustments coalesce presentation and blocked adjustments leave the host idle")
    func coalescedPresentation() throws {
        // -- Arrange --
        let runLoop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        var binding: Binding<Int>?
        let host = ViewHost(rootView: Counter { binding = $0 }, runLoop: runLoop, output: output)
        try host.start()
        let source = try #require(runLoop.sources.first)

        // -- Act --
        _ = host.handle(.arrowRight)
        _ = host.handle(.arrowRight)
        source.action()
        let updated = try #require(output.writes.last)
        let writes = output.writes.count
        _ = host.handle(.arrowRight)
        source.action()
        let unchanged = output.writes.count == writes
        host.stop()

        // -- Assert --
        #expect(updated.contains("3"))
        #expect(binding?.wrappedValue == 3)
        #expect(unchanged)
        #expect(runLoop.signalled.count == 1)
        #expect(runLoop.timers.isEmpty)
    }

    @Test("An external state write updates an unfocused stepper's value and availability")
    func externalStateWrite() throws {
        // -- Arrange --
        var binding: Binding<Int>?
        let renderer = ViewRenderer.make(Counter { binding = $0 })
        _ = renderer.render(.now)
        _ = renderer.handle(.arrowDown)

        // -- Act --
        try #require(binding).wrappedValue = 0
        let grid = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(grid.snapshotText.hasPrefix("(-) Count: 0 [+]"))
        #expect(!grid.isFocused(column: 0, row: 0))
        #expect(grid.isFocused(column: 0, row: 1))
    }
}
