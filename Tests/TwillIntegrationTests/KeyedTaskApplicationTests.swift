import Foundation
import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Keyed task terminal ownership")
@MainActor
struct KeyedTaskApplicationTests {
    private struct Fixture: View {
        @State private var job = 1
        let work: @MainActor @Sendable (Int) async -> Void
        var body: some View {
            let requested = job
            return VStack {
                Button("Next") { job += 1 }
                Text("Job \(requested)")
            }.task(id: requested) { await work(requested) }
        }
    }

    @Test(
        "Replacement and shutdown join cleanup before terminal restoration", .timeLimit(.minutes(1)),
        arguments: [false, true])
    func cleanupOrdering(cancel: Bool) async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXON | IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let output = DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))
        var running: Task<Void, Error>?
        weak var active: Application?
        var events: [String] = []
        var borrowed: [Bool] = []
        let root = Fixture { id in
            events.append("start\(id)")
            do {
                if id == 1 {
                    try terminal.send(Array("\r".utf8))
                } else if cancel {
                    running?.cancel()
                } else {
                    try terminal.send(Array("\u{3}".utf8))
                }
                let idle = AsyncStream<Void>.makeStream()
                for await _ in idle.stream {}
                events.append("cancel\(id)")
                await Task.yield()
                borrowed.append(try terminal.snapshot() != original)
                try output.write("cleanup\(id)")
                events.append("finish\(id)")
            } catch {
                Issue.record(error)
                active?.stop()
            }
        }
        let application = Application(
            rootView: root, runLoop: DefaultRunLoop(),
            terminalSession: DefaultTerminalSession(fileDescriptor: .custom(terminal.fileDescriptor), output: output))
        active = application

        // -- Act --
        let task = Task { try await application.run() }
        running = task
        try await task.value
        try pipe.fileHandleForWriting.close()
        let bytes = try #require(try pipe.fileHandleForReading.readToEnd())
        try pipe.fileHandleForReading.close()
        let rendered = try #require(String(data: bytes, encoding: .utf8))

        // -- Assert --
        #expect(events == ["start1", "cancel1", "finish1", "start2", "cancel2", "finish2"])
        #expect(borrowed == [true, true])
        let cleanup = try #require(rendered.range(of: "cleanup2"))
        let restore = try #require(rendered.range(of: "\u{1B}[?1049l"))
        #expect(cleanup.lowerBound < restore.lowerBound)
        #expect(try terminal.snapshot() == original)
    }
}
