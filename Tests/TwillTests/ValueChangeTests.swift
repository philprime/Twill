import Testing

@testable import Twill

@Suite("Mounted value-change observation")
@MainActor
struct ValueChangeTests {
    @Test("Initial delivery is opt-in and reports current/current after body evaluation")
    func initialDelivery() {
        // -- Arrange --
        var changes: [String] = []
        let initial = ViewRenderer.make(
            Text("Initial").onChange(of: 1, initial: true) { old, new in
                changes.append("\(old):\(new)")
            })
        let ordinary = ViewRenderer.make(Text("Ordinary").onChange(of: 2) { _, _ in changes.append("unexpected") })
        let before = changes

        // -- Act --
        _ = initial.render(.now)
        _ = ordinary.render(.now)
        _ = initial.render(.now)

        // -- Assert --
        #expect(before.isEmpty)
        #expect(changes == ["1:1"])
    }

    @Test("Updates coalesce from the delivered baseline and use the current action")
    func coalescingAndEquality() {
        // -- Arrange --
        var changes: [String] = []
        func content(_ value: Int, tag: String) -> some View {
            Text("\(value)").onChange(of: value) { old, new in changes.append("\(tag):\(old):\(new)") }
        }
        let renderer = ViewRenderer.make(content(0, tag: "initial"))
        _ = renderer.render(.now)

        // -- Act --
        renderer.update(content(1, tag: "stale"), at: .now)
        renderer.update(content(2, tag: "latest"), at: .now)
        let beforeDelivery = changes
        _ = renderer.render(.now)
        renderer.update(content(3, tag: "intermediate"), at: .now)
        renderer.update(content(2, tag: "equal"), at: .now)
        _ = renderer.render(.now)

        // -- Assert --
        #expect(beforeDelivery.isEmpty)
        #expect(changes == ["latest:0:2"])
    }

    @Test("Removal before delivery cancels the pending observation")
    func removal() {
        // -- Arrange --
        var changes = 0
        @ViewBuilder func content(_ show: Bool, value: Int) -> some View {
            if show { Text("Value").onChange(of: value) { _, _ in changes += 1 } } else { Text("Removed") }
        }
        let renderer = ViewRenderer.make(content(true, value: 0))
        _ = renderer.render(.now)

        // -- Act --
        renderer.update(content(true, value: 1), at: .now)
        renderer.update(content(false, value: 1), at: .now)
        _ = renderer.render(.now)

        // -- Assert --
        #expect(changes == 0)
    }

    private struct Reentrant: View {
        @State private var value = 0
        let callback: @MainActor (Int, Int) -> Void
        var body: some View {
            Text("\(value)").onChange(of: value, initial: true) { old, new in
                callback(old, new)
                if new < 2 { value = new + 1 }
            }
        }
    }

    @Test("Reentrant writes wait for a later mounted pass rather than recursive delivery")
    func reentrantWrites() throws {
        // -- Arrange --
        var changes: [String] = []
        let renderer = ViewRenderer.make(Reentrant(callback: { changes.append("\($0):\($1)") }))

        // -- Act --
        let first = try #require(renderer.render(.now).grid)
        let firstChanges = changes
        _ = renderer.render(.now)
        let final = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(first.snapshotText == "0" && firstChanges == ["0:0"])
        #expect(final.snapshotText == "2" && changes == ["0:0", "0:1", "1:2"])
    }

    @Test("Stopping from an initial observer cancels later delivery and avoids post-stop output")
    func stopBeforePresentation() throws {
        // -- Arrange --
        var later = 0
        weak var stoppedHost: ViewHost?
        let output = RecordingTerminalOutput()
        let host = ViewHost(
            rootView: Text("Stop").onChange(of: 1, initial: true) { _, _ in
                later += 1
            }.onChange(of: 2, initial: true) { _, _ in
                stoppedHost?.stop()
            }, runLoop: RecordingRunLoop(), output: output)
        stoppedHost = host

        // -- Act --
        try host.start()

        // -- Assert --
        #expect(later == 0)
        #expect(output.writes.isEmpty)
    }
}
