import Testing

@testable import Twill

@Suite("Keyed view task lifetimes")
@MainActor
struct KeyedTaskTests {
    @MainActor
    private final class CleanupGate {
        private var continuation: CheckedContinuation<Void, Never>?
        func wait() async { await withCheckedContinuation { continuation = $0 } }
        func open() {
            continuation?.resume()
            continuation = nil
        }
    }

    @Test("Rapid ID changes join cancelled intermediates before the latest action starts", .timeLimit(.minutes(1)))
    func serialReplacement() async {
        // -- Arrange --
        let registry = MountedTaskRegistry()
        let cleanup = CleanupGate()
        let started = AsyncStream<Int>.makeStream()
        let cancelled = AsyncStream<Void>.makeStream()
        var events: [String] = []
        func content(_ id: Int) -> some View {
            Text("Work").task(id: id) {
                events.append("start\(id)")
                started.continuation.yield(id)
                if id == 1 {
                    let idle = AsyncStream<Void>.makeStream()
                    for await _ in idle.stream {}
                    do { try Task.checkCancellation() } catch is CancellationError { events.append("cancel1") } catch {
                        Issue.record(error)
                    }
                    cancelled.continuation.yield(())
                    await cleanup.wait()
                }
                events.append("finish\(id)")
            }
        }
        let renderer = ViewRenderer.make(content(1), taskRegistry: registry)
        _ = renderer.render(.now)
        var starts = started.stream.makeAsyncIterator()
        var cancellations = cancelled.stream.makeAsyncIterator()
        let first = await starts.next()

        // -- Act --
        renderer.update(content(1), at: .now)
        await Task.yield()
        let equal = events == ["start1"]
        renderer.update(content(2), at: .now)
        renderer.update(content(3), at: .now)
        _ = await cancellations.next()
        await Task.yield()
        let waiting = events == ["start1", "cancel1"]
        cleanup.open()
        let latest = await starts.next()
        renderer.unmount()
        await registry.join()

        // -- Assert --
        #expect(first == 1 && latest == 3 && equal && waiting)
        #expect(events == ["start1", "cancel1", "finish1", "start3", "finish3"])
    }

    @Test("Equal IDs preserve completed work and replacement uses the current action", .timeLimit(.minutes(1)))
    func completedTask() async {
        // -- Arrange --
        let registry = MountedTaskRegistry()
        var events: [String] = []
        func content(_ id: Int?, tag: String) -> some View {
            Text("Work").task(id: id, priority: .utility) { events.append(tag) }
        }
        let renderer = ViewRenderer.make(content(nil, tag: "initial"), taskRegistry: registry)
        _ = renderer.render(.now)
        await registry.join()

        // -- Act --
        renderer.update(content(nil, tag: "ignored"), at: .now)
        await registry.join()
        renderer.update(content(1, tag: "replacement"), at: .now)
        await registry.join()
        renderer.unmount()

        // -- Assert --
        #expect(events == ["initial", "replacement"])
    }

    @Test("Removal cancels the full chain, releases the owner and joins unfinished cleanup", .timeLimit(.minutes(1)))
    func removalJoinsAll() async {
        // -- Arrange --
        let registry = MountedTaskRegistry()
        let cleanup = CleanupGate()
        let started = AsyncStream<Void>.makeStream()
        let cancelled = AsyncStream<Void>.makeStream()
        var events: [Int] = []
        func content(_ id: Int) -> some View {
            Text("Work").task(id: id) {
                events.append(id)
                started.continuation.yield(())
                if id == 1 {
                    let idle = AsyncStream<Void>.makeStream()
                    for await _ in idle.stream {}
                    cancelled.continuation.yield(())
                    await cleanup.wait()
                }
            }
        }
        var renderer: ViewRenderer? = ViewRenderer.make(content(1), taskRegistry: registry)
        weak var owner: ViewRenderer?
        owner = renderer
        _ = renderer?.render(.now)
        var starts = started.stream.makeAsyncIterator()
        var cancellations = cancelled.stream.makeAsyncIterator()
        _ = await starts.next()

        // -- Act --
        renderer?.update(content(2), at: .now)
        _ = await cancellations.next()
        renderer?.unmount()
        renderer = nil
        var joined = false
        let join = Task {
            await registry.join()
            joined = true
        }
        await Task.yield()
        let waiting = !joined
        let released = owner == nil
        cleanup.open()
        await join.value

        // -- Assert --
        #expect(waiting && released && joined)
        #expect(events == [1])
    }
}
