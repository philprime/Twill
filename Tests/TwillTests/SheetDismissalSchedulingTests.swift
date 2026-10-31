import Foundation
import Testing

@testable import Twill

@Suite("Sheet dismissal scheduling and ownership")
@MainActor
struct SheetDismissalSchedulingTests {
    @Test("Dismissal removes modal deadlines without shifting base phase")
    func basePhase() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var presented = true
        var dismiss: DismissAction?
        var callbacks = 0
        var baseDates: [Date] = []
        let renderer = ViewRenderer.make(
            TimelineView(.periodic(from: start, by: 20)) { context in
                baseDates.append(context.date)
                return Text("Base")
            }.sheet(
                isPresented: Binding(get: { presented }, set: { presented = $0 }), onDismiss: { callbacks += 1 },
                content: { action in
                    dismiss = action
                    return TimelineView(.periodic(from: start, by: 10)) { _ in Text("Modal") }
                }))
        _ = renderer.render(start)
        _ = renderer.render(start.addingTimeInterval(10))

        // -- Act --
        dismiss?()
        let closed = renderer.render(start.addingTimeInterval(11))
        renderer.unmount()

        // -- Assert --
        #expect(closed.nextUpdate == start.addingTimeInterval(20))
        #expect(baseDates == [start, start])
        #expect(callbacks == 1)
    }

    @Test("A live dismissal context does not emit output on unchanged parent ticks")
    func unchangedOutput() throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var now = start
        let loop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        let host = ViewHost(
            rootView: TimelineView(.periodic(from: start, by: 1)) { _ in
                Text("Base").sheet(isPresented: .constant(true)) { _ in Text("Modal") }
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

    @Test("Dismissal cancels owned work and the registry retains its cleanup join", .timeLimit(.minutes(1)))
    func ownedWork() async {
        // -- Arrange --
        let registry = MountedTaskRegistry()
        let started = AsyncStream<Void>.makeStream()
        var presented = true
        var dismiss: DismissAction?
        var callbacks = 0
        var finished = false
        let renderer = ViewRenderer.make(
            Text("Base").sheet(
                isPresented: Binding(get: { presented }, set: { presented = $0 }), onDismiss: { callbacks += 1 },
                content: { action in
                    dismiss = action
                    return Text("Modal").task {
                        started.continuation.yield(())
                        let idle = AsyncStream<Void>.makeStream()
                        for await _ in idle.stream {}
                        finished = true
                    }
                }), taskRegistry: registry)
        _ = renderer.render(.now)
        var notifications = started.stream.makeAsyncIterator()
        _ = await notifications.next()

        // -- Act --
        dismiss?()
        _ = renderer.render(.now)
        await registry.join()
        renderer.unmount()

        // -- Assert --
        #expect(callbacks == 1 && finished)
    }

    @Test("Retained dismissal actions do not retain an unmounted presentation")
    func weakOwner() {
        // -- Arrange --
        var dismiss: DismissAction?
        var callbacks = 0
        var renderer: ViewRenderer? = ViewRenderer.make(
            Text("Base").sheet(
                isPresented: .constant(true),
                onDismiss: { callbacks += 1 },
                content: { action in
                    dismiss = action
                    return Text("Modal")
                }))
        weak var owner: ViewRenderer?
        owner = renderer
        _ = renderer?.render(.now)

        // -- Act --
        renderer?.unmount()
        renderer = nil
        dismiss?()

        // -- Assert --
        #expect(owner == nil && callbacks == 1)
    }
}
