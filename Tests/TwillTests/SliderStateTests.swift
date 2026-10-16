import Testing

@testable import Twill

@Suite("Mounted slider state")
@MainActor
struct SliderStateTests {
    private struct Level: View {
        @State private var value = 0.0
        let capture: @MainActor (Binding<Double>) -> Void

        var body: some View {
            capture($value)
            return VStack(alignment: .leading, spacing: 0) {
                Slider("Level", value: $value, step: 0.25)
                Button("Done") {}
            }
        }
    }

    @Test("Rapid adjustments coalesce presentation and blocked keys leave the host idle")
    func coalescedPresentation() throws {
        // -- Arrange --
        let runLoop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        var binding: Binding<Double>?
        let host = ViewHost(rootView: Level { binding = $0 }, runLoop: runLoop, output: output)
        try host.start()
        let source = try #require(runLoop.sources.first)

        // -- Act --
        for _ in 0..<4 { _ = host.handle(.arrowRight) }
        source.action()
        let writes = output.writes.count
        _ = host.handle(.arrowRight)
        source.action()
        let unchanged = output.writes.count == writes
        host.stop()

        // -- Assert --
        #expect(binding?.wrappedValue == 1)
        #expect(writes == 2)
        #expect(unchanged)
        #expect(runLoop.signalled.count == 1)
        #expect(runLoop.timers.isEmpty)
    }

    @Test("External state writes update an unfocused value and thumb")
    func externalStateWrite() throws {
        // -- Arrange --
        var binding: Binding<Double>?
        let renderer = ViewRenderer.make(Level { binding = $0 })
        _ = renderer.render(.now, proposal: .init(width: 12))
        _ = renderer.handle(.arrowDown)

        // -- Act --
        try #require(binding).wrappedValue = 1
        let grid = try #require(renderer.render(.now, proposal: .init(width: 12)).grid)

        // -- Assert --
        #expect(grid.snapshotText.hasPrefix("Level 1.0   \n━━━━━━━━━━━●"))
        #expect(!grid.isFocused(column: 11, row: 1))
        #expect(grid.isFocused(column: 0, row: 2))
    }

    private struct Panes: View {
        @State private var value = 0.5

        var body: some View {
            HStack(spacing: 1) {
                ScrollView { Slider("Level", value: $value, step: 0.25) }.frame(width: 12, height: 2)
                ScrollView { Button("Other") {} }.frame(width: 6, height: 2)
            }
        }
    }

    @Test("Pane switching retains the slider value and restores focus without a caret")
    func panes() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(Panes())
        _ = renderer.render(.now)
        _ = renderer.handle(.arrowRight)

        // -- Act --
        _ = renderer.handle(.tab)
        let away = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.shiftTab)
        let restored = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(away.snapshotText.hasPrefix("Level 0.75"))
        #expect(!away.isFocused(column: 0, row: 0))
        #expect(away.isFocused(column: 13, row: 0))
        #expect(restored.isFocused(column: 0, row: 0))
        #expect(renderer.caretPosition == nil)
    }
}
