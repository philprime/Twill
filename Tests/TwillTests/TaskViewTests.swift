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
