import Foundation
import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Run loop input sources")
@MainActor
struct InputSourceTests {
    @Test("Dispatch input reaches a MainActor callback", .timeLimit(.minutes(1)))
    func deliversBytes() async throws {
        // -- Arrange --
        let pipe = Pipe()
        defer {
            try? pipe.fileHandleForReading.close()
            try? pipe.fileHandleForWriting.close()
        }
        let runLoop = DefaultRunLoop()
        var received: [UInt8] = []
        let source = DefaultInputSource(fileDescriptor: .custom(pipe.fileHandleForReading.fileDescriptor)) { event in
            MainActor.assertIsolated()
            if case .bytes(let bytes) = event {
                received.append(contentsOf: bytes)
                runLoop.stop()
            }
        }
        runLoop.add(source)
        try pipe.fileHandleForWriting.write(contentsOf: Data([0x61, 0x62]))

        // -- Act --
        await runLoop.run()

        // -- Assert --
        #expect(received == [0x61, 0x62])
    }

    @Test("Drains a burst before EOF and ignores duplicate registration", .timeLimit(.minutes(1)))
    func drainsBeforeEOF() async throws {
        // -- Arrange --
        let pipe = Pipe()
        defer { try? pipe.fileHandleForReading.close() }
        let descriptor = pipe.fileHandleForReading.fileDescriptor
        let flags = fcntl(descriptor, F_GETFL)
        let runLoop = DefaultRunLoop()
        var received: [UInt8] = []
        var reachedEOF = false
        let source = DefaultInputSource(fileDescriptor: .custom(descriptor)) { event in
            switch event {
            case .bytes(let bytes): received.append(contentsOf: bytes)
            case .endOfFile:
                reachedEOF = true
                runLoop.stop()
            case .failure(let error):
                Issue.record("Unexpected input error: \(error)")
                runLoop.stop()
            }
        }
        let payload = [UInt8](repeating: 0x61, count: 5000)
        try pipe.fileHandleForWriting.write(contentsOf: Data(payload))
        try pipe.fileHandleForWriting.close()
        runLoop.add(source)
        runLoop.add(source)

        // -- Act --
        await runLoop.run()

        // -- Assert --
        #expect(received == payload)
        #expect(reachedEOF)
        #expect(fcntl(descriptor, F_GETFL) == flags)
    }

    @Test("Invalid descriptors report their error through the actor", .timeLimit(.minutes(1)))
    func invalidDescriptor() async {
        // -- Arrange --
        let runLoop = DefaultRunLoop()
        var receivedError: TerminalError?
        runLoop.add(
            DefaultInputSource(fileDescriptor: .custom(-1)) { event in
                if case .failure(let error) = event { receivedError = error }
                runLoop.stop()
            })

        // -- Act --
        await runLoop.run()

        // -- Assert --
        #expect(receivedError == .configureInput(errno: EBADF))
    }

    @Test(
        "Cancellation restores descriptor flags without closing or consuming it",
        .timeLimit(.minutes(1)), arguments: [false, true])
    func cancellation(initiallyNonblocking: Bool) async throws {
        // -- Arrange --
        let pipe = Pipe()
        defer {
            try? pipe.fileHandleForReading.close()
            try? pipe.fileHandleForWriting.close()
        }
        let descriptor = pipe.fileHandleForReading.fileDescriptor
        if initiallyNonblocking {
            #expect(fcntl(descriptor, F_SETFL, fcntl(descriptor, F_GETFL) | O_NONBLOCK) == 0)
        }
        let originalFlags = fcntl(descriptor, F_GETFL)
        let runLoop = DefaultRunLoop()
        let (ready, continuation) = AsyncStream<Void>.makeStream()
        var deliveries = 0
        runLoop.add(DefaultInputSource(fileDescriptor: .custom(descriptor)) { _ in deliveries += 1 })
        runLoop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                continuation.yield(())
                continuation.finish()
            })
        let task = Task { await runLoop.run() }
        for await _ in ready {}
        let runningFlags = fcntl(descriptor, F_GETFL)

        // -- Act --
        task.cancel()
        await task.value
        try pipe.fileHandleForWriting.write(contentsOf: Data([0x62]))
        var readiness = pollfd(fd: descriptor, events: Int16(POLLIN), revents: 0)
        let unread = poll(&readiness, 1, 0)

        // -- Assert --
        #expect(runningFlags & O_NONBLOCK != 0)
        #expect(fcntl(descriptor, F_GETFL) == originalFlags)
        #expect(deliveries == 0)
        #expect(unread == 1)
    }

    @Test("Stopping in a callback suppresses the rest of a queued burst", .timeLimit(.minutes(1)))
    func stopDuringDelivery() async throws {
        // -- Arrange --
        let pipe = Pipe()
        defer { try? pipe.fileHandleForReading.close() }
        try pipe.fileHandleForWriting.write(contentsOf: Data(repeating: 0x61, count: 5000))
        try pipe.fileHandleForWriting.close()
        let runLoop = DefaultRunLoop()
        var deliveries = 0
        runLoop.add(
            DefaultInputSource(fileDescriptor: .custom(pipe.fileHandleForReading.fileDescriptor)) { _ in
                deliveries += 1
                runLoop.stop()
            })

        // -- Act --
        await runLoop.run()

        // -- Assert --
        #expect(deliveries == 1)
    }
}
