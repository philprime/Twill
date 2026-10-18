import Foundation
import Testing

@testable import Twill

@Suite("View tasks")
@MainActor
struct TaskViewTests {
    private struct LoadedView: View {
        @State private var title = "Loading"
        let didLoad: AsyncStream<Void>.Continuation
        let recordStart: @MainActor () -> Void

        var body: some View {
            Text(title).task {
                recordStart()
                title = "Loaded"
                didLoad.yield(())
            }
        }
    }

    @Test("A mounted task updates state and a parent refresh does not restart it")
    func mountAndRefresh() async throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var starts = 0
        let loaded = AsyncStream.makeStream(of: Void.self)
        let root = TimelineView(.periodic(from: start, by: 1)) { _ in
            LoadedView(didLoad: loaded.continuation) { starts += 1 }
        }
        let renderer = ViewRenderer.make(root)
        let initial = renderer.render(start)

        // -- Act --
        var iterator = loaded.stream.makeAsyncIterator()
        _ = await iterator.next()
        let updated = renderer.render(start.addingTimeInterval(1))

        // -- Assert --
        #expect(initial.grid?.snapshotText == "Loading")
        #expect(updated.grid?.snapshotText == "Loaded")
        #expect(starts == 1)
    }

    @Test("Removing a branch cancels its mounted task")
    func removedBranch() async {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let started = AsyncStream.makeStream(of: Void.self)
        let cancelled = AsyncStream.makeStream(of: Void.self)
        let root = TimelineView(.periodic(from: start, by: 1)) { context in
            Group {
                if context.date == start {
                    Text("Active").task {
                        started.continuation.yield(())
                        do { try await Task.sleep(for: .seconds(60)) } catch { cancelled.continuation.yield(()) }
                    }
                } else {
                    Text("Gone")
                }
            }
        }
        let renderer = ViewRenderer.make(root)
        _ = renderer.render(start)
        var starts = started.stream.makeAsyncIterator()
        _ = await starts.next()

        // -- Act --
        let frame = renderer.render(start.addingTimeInterval(1))
        var cancellations = cancelled.stream.makeAsyncIterator()
        _ = await cancellations.next()

        // -- Assert --
        #expect(frame.grid?.snapshotText == "Gone")
    }

    @MainActor
    private final class GatedTaskCleanup {
        let started = AsyncStream<Void>.makeStream()
        let cleanupStarted = AsyncStream<Void>.makeStream()
        private let idle = AsyncStream<Void>.makeStream()
        private var continuation: CheckedContinuation<Void, Never>?
        private(set) var isFinished = false

        func run() async {
            started.continuation.yield(())
            for await _ in idle.stream {}
            await withCheckedContinuation { continuation in
                self.continuation = continuation
                cleanupStarted.continuation.yield(())
            }
            isFinished = true
        }

        func release() {
            continuation?.resume()
            continuation = nil
        }
    }

    @Test("Shutdown joins gated cleanup after the owning keyed node is removed", .timeLimit(.minutes(1)))
    func removedKeyedTaskCleanup() async throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var now = start
        let cleanup = GatedTaskCleanup()
        let joinStarted = AsyncStream<Void>.makeStream()
        var joinReturned = false
        let runLoop = RecordingRunLoop()
        let host = ViewHost(
            rootView: TimelineView(.periodic(from: start, by: 1)) { context in
                ForEach(context.date == start ? [1] : [], id: \.self) { _ in
                    Text("Active").task { await cleanup.run() }
                }
            }, runLoop: runLoop, output: RecordingTerminalOutput(), now: { now })
        try host.start()
        defer {
            host.stop()
            cleanup.release()
        }
        let timer = try #require(runLoop.timers.first)
        var starts = cleanup.started.stream.makeAsyncIterator()
        _ = await starts.next()

        // -- Act --
        now = start.addingTimeInterval(1)
        timer.action()
        var cleanups = cleanup.cleanupStarted.stream.makeAsyncIterator()
        _ = await cleanups.next()
        host.stop()
        let join = Task {
            joinStarted.continuation.yield(())
            await host.joinTasks()
            joinReturned = true
            return cleanup.isFinished
        }
        var joins = joinStarted.stream.makeAsyncIterator()
        _ = await joins.next()
        await Task.yield()
        let returnedBeforeRelease = joinReturned
        let finishedBeforeRelease = cleanup.isFinished
        cleanup.release()
        let finishedWhenJoined = await join.value

        // -- Assert --
        #expect(!returnedBeforeRelease)
        #expect(!finishedBeforeRelease)
        #expect(finishedWhenJoined)
        #expect(joinReturned)
    }

    @Test("Unmounting before a task starts does not run its action")
    func stopBeforeStart() async throws {
        // -- Arrange --
        var starts = 0
        let host = ViewHost(
            rootView: Text("Ready").task { starts += 1 },
            runLoop: RecordingRunLoop(), output: RecordingTerminalOutput()
        )

        // -- Act --
        try host.start()
        host.stop()
        await host.joinTasks()

        // -- Assert --
        #expect(starts == 0)
    }

    @Test("Stopping the host cancels and joins its tasks")
    func hostShutdown() async throws {
        // -- Arrange --
        let started = AsyncStream.makeStream(of: Void.self)
        let cancelled = AsyncStream.makeStream(of: Void.self)
        let host = ViewHost(
            rootView: Text("Active").task {
                started.continuation.yield(())
                do { try await Task.sleep(for: .seconds(60)) } catch { cancelled.continuation.yield(()) }
            },
            runLoop: RecordingRunLoop(), output: RecordingTerminalOutput()
        )
        try host.start()
        var starts = started.stream.makeAsyncIterator()
        _ = await starts.next()

        // -- Act --
        host.stop()
        await host.joinTasks()
        var cancellations = cancelled.stream.makeAsyncIterator()
        let didCancel: Void? = await cancellations.next()

        // -- Assert --
        #expect(didCancel != nil)
    }
}
