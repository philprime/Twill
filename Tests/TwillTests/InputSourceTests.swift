import Foundation
import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Input source async sequences")
@MainActor
struct InputSourceTests {
    @Test("The stream preserves a burst and completes on EOF", .timeLimit(.minutes(1)))
    func completesOnEOF() async throws {
        // -- Arrange --
        let pipe = Pipe()
        defer { try? pipe.fileHandleForReading.close() }
        let descriptor = pipe.fileHandleForReading.fileDescriptor
        let originalFlags = fcntl(descriptor, F_GETFL)
        let source = DefaultInputSource(fileDescriptor: .custom(descriptor))
        let payload = [UInt8](repeating: 0x61, count: 5000)
        try pipe.fileHandleForWriting.write(contentsOf: Data(payload))
        try pipe.fileHandleForWriting.close()
        var received: [UInt8] = []

        // -- Act --
        source.start()
        do {
            for try await bytes in source.events {
                received.append(contentsOf: bytes)
            }
        } catch {
            await source.stop()
            throw error
        }
        await source.stop()

        // -- Assert --
        #expect(received == payload)
        #expect(fcntl(descriptor, F_GETFL) == originalFlags)
    }

    @Test("Configuration errors are thrown by iteration", .timeLimit(.minutes(1)))
    func throwsConfigurationError() async {
        // -- Arrange --
        let source = DefaultInputSource(fileDescriptor: .custom(-1))
        var receivedError: TerminalError?

        // -- Act --
        source.start()
        do {
            for try await _ in source.events {
                Issue.record("An invalid descriptor cannot produce bytes")
            }
            Issue.record("Expected the input stream to fail")
        } catch {
            receivedError = error as? TerminalError
        }
        await source.stop()

        // -- Assert --
        #expect(receivedError == .configureInput(errno: EBADF))
    }

    @Test("Cancelling an idle consumer allows awaited cleanup", .timeLimit(.minutes(1)))
    func cancelsIdleConsumer() async throws {
        // -- Arrange --
        let pipe = Pipe()
        defer {
            try? pipe.fileHandleForReading.close()
            try? pipe.fileHandleForWriting.close()
        }
        let descriptor = pipe.fileHandleForReading.fileDescriptor
        let originalFlags = fcntl(descriptor, F_GETFL)
        let source = DefaultInputSource(fileDescriptor: .custom(descriptor))
        let (ready, continuation) = AsyncStream<Void>.makeStream()
        var received: [UInt8] = []
        source.start()
        let task = Task {
            continuation.yield(())
            continuation.finish()
            for try await bytes in source.events {
                received.append(contentsOf: bytes)
            }
        }
        for await _ in ready {}

        // -- Act --
        task.cancel()
        await source.stop()
        try await task.value
        try pipe.fileHandleForWriting.write(contentsOf: Data([0x62]))
        var readiness = pollfd(fd: descriptor, events: Int16(POLLIN), revents: 0)
        let unread = poll(&readiness, 1, 0)

        // -- Assert --
        #expect(received.isEmpty)
        #expect(fcntl(descriptor, F_GETFL) == originalFlags)
        #expect(unread == 1)
    }

    @Test("Stopping a source finishes an idle consumer", .timeLimit(.minutes(1)))
    func stopFinishesStream() async throws {
        // -- Arrange --
        let pipe = Pipe()
        defer {
            try? pipe.fileHandleForReading.close()
            try? pipe.fileHandleForWriting.close()
        }
        let source = DefaultInputSource(fileDescriptor: .custom(pipe.fileHandleForReading.fileDescriptor))
        source.start()
        let task = Task {
            var received: [UInt8] = []
            for try await bytes in source.events { received.append(contentsOf: bytes) }
            return received
        }

        // -- Act --
        await source.stop()
        let received = try await task.value

        // -- Assert --
        #expect(received.isEmpty)
    }
}
