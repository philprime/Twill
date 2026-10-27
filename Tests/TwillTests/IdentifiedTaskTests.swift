import Foundation
import Testing

@testable import Twill

@Suite("Explicit identity task lifetimes")
@MainActor
struct IdentifiedTaskTests {
    @Test("Equal IDs preserve owned tasks and changed IDs cancel replaced tasks", .timeLimit(.minutes(1)))
    func taskLifetime() async {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let registry = MountedTaskRegistry()
        let started = AsyncStream<Int>.makeStream()
        var starts: [Int] = []
        var finishes: [Int] = []
        func content(id: Int) -> some View {
            Text("Active").task {
                starts.append(id)
                started.continuation.yield(id)
                let idle = AsyncStream<Void>.makeStream()
                for await _ in idle.stream {}
                finishes.append(id)
            }.id(id)
        }
        let renderer = ViewRenderer.make(content(id: 1), taskRegistry: registry)
        _ = renderer.render(start)
        var notifications = started.stream.makeAsyncIterator()
        let initialID = await notifications.next()

        // -- Act --
        renderer.update(content(id: 1), at: start.addingTimeInterval(1))
        await Task.yield()
        let startsAfterEqualID = starts
        renderer.update(content(id: 2), at: start.addingTimeInterval(2))
        let replacementID = await notifications.next()
        renderer.unmount()
        await registry.join()

        // -- Assert --
        #expect(initialID == 1)
        #expect(startsAfterEqualID == [1])
        #expect(replacementID == 2)
        #expect(starts == [1, 2])
        #expect(finishes.sorted() == [1, 2])
    }

    @Test("Tasks outside the identity modifier retain their existing lifetime", .timeLimit(.minutes(1)))
    func outerTaskLifetime() async {
        // -- Arrange --
        let registry = MountedTaskRegistry()
        let started = AsyncStream<Void>.makeStream()
        var starts = 0
        func content(id: Int) -> some View {
            Text("Active").id(id).task {
                starts += 1
                started.continuation.yield(())
            }
        }
        let renderer = ViewRenderer.make(content(id: 1), taskRegistry: registry)
        _ = renderer.render(.now)
        var notifications = started.stream.makeAsyncIterator()
        _ = await notifications.next()

        // -- Act --
        renderer.update(content(id: 2), at: .now)
        await registry.join()
        renderer.unmount()

        // -- Assert --
        #expect(starts == 1)
    }
}
