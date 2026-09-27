import Testing

@testable import Twill

@Suite("State bindings")
@MainActor
struct BindingTests {
    private struct Child: View {
        @Binding var count: Int
        let captureIncrement: @MainActor (@escaping @MainActor () -> Void) -> Void

        var body: some View {
            let binding = $count
            captureIncrement { binding.wrappedValue += 1 }
            return Text("\(count)")
        }
    }

    private struct Parent: View {
        @State private var count = 0
        let captureIncrement: @MainActor (@escaping @MainActor () -> Void) -> Void

        var body: some View {
            Child(count: $count, captureIncrement: captureIncrement)
        }
    }

    private struct ExposingParent: View {
        @State private var count = 0
        let captureBinding: @MainActor (Binding<Int>) -> Void

        var body: some View {
            captureBinding($count)
            return Text("\(count)")
        }
    }

    @Test("A retained binding does not retain its mounted owner")
    func ownerLifetime() {
        // -- Arrange --
        var binding: Binding<Int>?
        weak var owner: ViewRenderer?

        // -- Act --
        do {
            let renderer = ViewRenderer.make(ExposingParent { binding = $0 })
            owner = renderer
            _ = renderer.render(.now)
        }

        // -- Assert --
        #expect(binding?.wrappedValue == 0)
        #expect(owner == nil)
    }

    @Test("A child writes its parent's state through a binding")
    func childWrite() throws {
        // -- Arrange --
        let runLoop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        var increment: (@MainActor () -> Void)?
        let host = ViewHost(rootView: Parent { increment = $0 }, runLoop: runLoop, output: output)
        try host.start()

        // -- Act --
        let action = try #require(increment)
        action()
        action()
        let pendingCount = runLoop.timers.count
        try #require(runLoop.timers.last).action()
        host.stop()

        // -- Assert --
        #expect(pendingCount == 1)
        #expect(output.writes == ["\r\u{1B}[2K0", "\r2", "\n"])
    }
}
