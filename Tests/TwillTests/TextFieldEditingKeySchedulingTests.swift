import Foundation
import Testing

@testable import Twill

@Suite("Endpoint editing scheduling")
@MainActor
struct TextFieldEditingKeySchedulingTests {
    @Test("Caret changes preserve sibling deadlines and boundary no-ops write no output")
    func editingDeadlines() throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var text = "abc"
        let loop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        let host = ViewHost(
            rootView: HStack {
                TextField("Value", text: Binding(get: { text }, set: { text = $0 }))
                TimelineView(.periodic(from: start, by: 10)) { _ in Text("First") }
                TimelineView(.periodic(from: start, by: 20)) { _ in Text("Second") }
            }, runLoop: loop, output: output, now: { start })
        try host.start()
        defer { host.stop() }
        let source = try #require(loop.sources.first)
        source.action()
        let timers = loop.timers

        // -- Act --
        _ = host.handle(.home)
        source.action()
        _ = host.handle(.delete)
        source.action()
        _ = host.handle(.end)
        source.action()
        let edited = output.writes
        _ = host.handle(.end)
        _ = host.handle(.delete)
        source.action()

        // -- Assert --
        #expect(text == "bc")
        #expect(loop.timers.count == timers.count)
        #expect(zip(loop.timers, timers).allSatisfy { $0 === $1 })
        #expect(loop.cancelled.isEmpty)
        #expect(output.writes == edited)
    }
}
