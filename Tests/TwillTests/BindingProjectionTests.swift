import Testing

@testable import Twill

@Suite("Binding projections")
@MainActor
struct BindingProjectionTests {
    private struct Settings {
        var count = 0
        var title = "Initial"
    }

    private struct Model {
        var settings = Settings()
    }

    private struct Parent: View {
        @State private var model = Model()
        let captureBinding: @MainActor (Binding<Int>) -> Void

        var body: some View {
            captureBinding($model.settings.count)
            return Text("\(model.settings.count)")
        }
    }

    @Test("A constant binding ignores edits from a text field")
    func constantField() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(TextField("Prompt", text: .constant("Fixed")))
        _ = renderer.render(.now)

        // -- Act --
        let inserted = renderer.handle(.x)
        let deleted = renderer.handle(.backspace)
        let frame = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(inserted && deleted)
        #expect(frame.snapshotText == "Fixed")
    }

    @Test("A projected binding reads the latest owner value")
    func readsLatestValue() {
        // -- Arrange --
        var settings = Settings()
        let binding = Binding(get: { settings }, set: { settings = $0 })
        let count = binding.count

        // -- Act --
        settings.count = 7

        // -- Assert --
        #expect(count.wrappedValue == 7)
    }

    @Test("A projected write preserves the owner's latest sibling properties")
    func preservesSiblingProperties() {
        // -- Arrange --
        var settings = Settings()
        let binding = Binding(get: { settings }, set: { settings = $0 })
        let count = binding.count
        settings.title = "Updated"

        // -- Act --
        count.wrappedValue = 3

        // -- Assert --
        #expect(settings.count == 3)
        #expect(settings.title == "Updated")
    }

    @Test("Nested projected writes invalidate their mounted owner")
    func nestedMountedWrite() throws {
        // -- Arrange --
        let runLoop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        var count: Binding<Int>?
        let host = ViewHost(rootView: Parent { count = $0 }, runLoop: runLoop, output: output)
        try host.start()

        // -- Act --
        let source = try #require(runLoop.sources.first)
        let binding = try #require(count)
        binding.wrappedValue = 4
        binding.wrappedValue += 1
        source.action()
        host.stop()

        // -- Assert --
        #expect(runLoop.signalled.count == 1)
        #expect(output.writes == ["\r\u{1B}[2K0", "\r5", "\n"])
    }

    @Test("A retained nested projection does not retain its mounted owner")
    func projectedOwnerLifetime() {
        // -- Arrange --
        var count: Binding<Int>?
        weak var owner: ViewRenderer?

        // -- Act --
        do {
            let renderer = ViewRenderer.make(Parent { count = $0 })
            owner = renderer
            _ = renderer.render(.now)
        }

        // -- Assert --
        #expect(count?.wrappedValue == 0)
        #expect(owner == nil)
    }
}
