import Foundation
import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Sheet dismissal terminal interaction")
@MainActor
struct SheetDismissalApplicationTests {
    private struct Fixture: View {
        @State private var presented = false
        let action: @MainActor (String) -> Void
        var body: some View {
            HStack {
                Button("Before") { action("before") }
                Button("Open") {
                    action("open")
                    presented = true
                }
            }.sheet(
                isPresented: $presented, onDismiss: { action("dismiss") },
                content: { dismiss in
                    Button("Close") {
                        dismiss()
                        dismiss()
                    }
                })
        }
    }

    @Test("Escape and scoped dismissal restore focus and call lifecycle hooks once", .timeLimit(.minutes(1)))
    func dismissalPaths() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXON | IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let loop = DefaultRunLoop()
        var actions: [String] = []
        var leaked: [KeyEvent] = []
        let application = Application(
            rootView: Fixture(action: { actions.append($0) }), runLoop: loop,
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.fileDescriptor),
                output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))))
        application.options.ui.mode = .inline
        application.onKeyEvent = { leaked.append($0) }
        loop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                do { try terminal.send(Array("\t\rx\u{1B}\r\r\u{3}".utf8)) } catch {
                    Issue.record(error)
                    application.stop()
                }
            })

        // -- Act --
        try await application.run()
        try pipe.fileHandleForWriting.close()
        _ = try pipe.fileHandleForReading.readToEnd()
        try pipe.fileHandleForReading.close()

        // -- Assert --
        #expect(actions == ["open", "dismiss", "open", "dismiss"])
        #expect(leaked.isEmpty)
        #expect(try terminal.snapshot() == original)
    }

    @Test("Cancellation joins sheet-owned cleanup before terminal restoration", .timeLimit(.minutes(1)))
    func cancellationCleanup() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXON | IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let started = AsyncStream<Void>.makeStream()
        let cleaning = AsyncStream<Void>.makeStream()
        var release: CheckedContinuation<Void, Never>?
        var callbacks = 0
        var finished = false
        let application = Application(
            rootView: Text("Base").sheet(
                isPresented: .constant(true),
                onDismiss: { callbacks += 1 },
                content: {
                    Text("Modal").task {
                        started.continuation.yield(())
                        let idle = AsyncStream<Void>.makeStream()
                        for await _ in idle.stream {}
                        cleaning.continuation.yield(())
                        await withCheckedContinuation { release = $0 }
                        finished = true
                    }
                }), runLoop: DefaultRunLoop(),
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.fileDescriptor),
                output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))))
        let task = Task { try await application.run() }
        var notifications = started.stream.makeAsyncIterator()
        _ = await notifications.next()

        // -- Act --
        task.cancel()
        var cleanups = cleaning.stream.makeAsyncIterator()
        _ = await cleanups.next()
        let retained = try terminal.snapshot() != original && !finished
        release?.resume()
        try await task.value
        try pipe.fileHandleForWriting.close()
        _ = try pipe.fileHandleForReading.readToEnd()
        try pipe.fileHandleForReading.close()

        // -- Assert --
        #expect(retained && finished && callbacks == 1)
        #expect(try terminal.snapshot() == original)
    }
}
