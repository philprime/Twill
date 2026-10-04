import Foundation
import Testing

@testable import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Keyboard event source")
@MainActor
struct KeyboardEventSourceTests {
    @Test("Decodes bytes on MainActor without applying application shortcuts", .timeLimit(.minutes(1)))
    func deliversKeys() async throws {
        // -- Arrange --
        let pipe = Pipe()
        defer { try? pipe.fileHandleForReading.close() }
        let input = DefaultInputSource(fileDescriptor: .custom(pipe.fileHandleForReading.fileDescriptor))
        let keyboard = DefaultKeyboardEventSource(inputSource: input, runLoop: DefaultRunLoop())
        var received: [KeyEvent] = []
        keyboard.onKeyEvent = { key in
            MainActor.assertIsolated()
            received.append(key)
        }
        try pipe.fileHandleForWriting.write(contentsOf: Data([0x61, 0x1B, 0x5B, 0x41, 0xC3, 0xA9, 0x03, 0x62]))
        try pipe.fileHandleForWriting.close()

        // -- Act --
        try await keyboard.run()

        // -- Assert --
        #expect(received == [.a, .arrowUp, .character("é"), .control(3), .b])
    }

    @Test("A superseded Escape timer cannot flush a newer sequence", .timeLimit(.minutes(1)))
    func supersededEscapeDeadline() async throws {
        // -- Arrange --
        let input = SequencedInputSource()
        let runLoop = RecordingRunLoop()
        let (registrations, registrationContinuation) = AsyncStream<Twill.Timer>.makeStream()
        runLoop.onAdd = { registrationContinuation.yield($0) }
        var timers = registrations.makeAsyncIterator()
        let keyboard = DefaultKeyboardEventSource(inputSource: input, runLoop: runLoop)
        var received: [KeyEvent] = []
        keyboard.onKeyEvent = { received.append($0) }
        let task = Task { try await keyboard.run() }

        // -- Act --
        input.send([0x61, 0x1B])
        let firstDeadline = try #require(await timers.next())
        input.send([0x5B])
        let supersededDeadline = try #require(await timers.next())
        firstDeadline.action()
        input.send([0x41, 0x62, 0x1B])
        let currentDeadline = try #require(await timers.next())
        supersededDeadline.action()
        let beforeCurrentDeadline = received
        currentDeadline.action()
        keyboard.stop()
        try await task.value

        // -- Assert --
        #expect(beforeCurrentDeadline == [.a, .arrowUp, .b])
        #expect(received == [.a, .arrowUp, .b, .escape])
        if case .milliseconds(let timeout) = currentDeadline.interval {
            #expect(timeout >= 45)
        } else {
            Issue.record("Escape deadline must use a millisecond interval")
        }
    }

    @Test("Drains a burst before EOF and restores the descriptor", .timeLimit(.minutes(1)))
    func drainsBeforeEOF() async throws {
        // -- Arrange --
        let pipe = Pipe()
        defer { try? pipe.fileHandleForReading.close() }
        let descriptor = pipe.fileHandleForReading.fileDescriptor
        let flags = fcntl(descriptor, F_GETFL)
        let keyboard = DefaultKeyboardEventSource(
            inputSource: DefaultInputSource(fileDescriptor: .custom(descriptor)), runLoop: DefaultRunLoop()
        )
        var received: [KeyEvent] = []
        keyboard.onKeyEvent = { received.append($0) }
        try pipe.fileHandleForWriting.write(contentsOf: Data(repeating: 0x61, count: 5000))
        try pipe.fileHandleForWriting.close()

        // -- Act --
        try await keyboard.run()

        // -- Assert --
        #expect(received == [KeyEvent](repeating: .a, count: 5000))
        #expect(fcntl(descriptor, F_GETFL) == flags)
    }

    @Test("Input errors propagate without producing keyboard events", .timeLimit(.minutes(1)))
    func invalidDescriptor() async {
        // -- Arrange --
        let keyboard = DefaultKeyboardEventSource(
            inputSource: DefaultInputSource(fileDescriptor: .custom(-1)), runLoop: DefaultRunLoop()
        )
        var receivedError: TerminalError?
        keyboard.onKeyEvent = { _ in Issue.record("Invalid input must not produce keys") }

        // -- Act --
        do {
            try await keyboard.run()
        } catch { receivedError = error as? TerminalError }

        // -- Assert --
        #expect(receivedError == .configureInput(errno: EBADF))
    }

    @Test(
        "Cancellation restores flags without closing or consuming the descriptor",
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
        let keyboard = DefaultKeyboardEventSource(
            inputSource: DefaultInputSource(fileDescriptor: .custom(descriptor)), runLoop: DefaultRunLoop()
        )
        let (ready, continuation) = AsyncStream<Void>.makeStream()
        var keys: [KeyEvent] = []
        keyboard.onKeyEvent = { key in
            keys.append(key)
            continuation.yield(())
            continuation.finish()
        }
        try pipe.fileHandleForWriting.write(contentsOf: Data([0x61]))
        let task = Task { try await keyboard.run() }
        for await _ in ready {}
        let runningFlags = fcntl(descriptor, F_GETFL)

        // -- Act --
        task.cancel()
        try await task.value
        try pipe.fileHandleForWriting.write(contentsOf: Data([0x62]))
        var readiness = pollfd(fd: descriptor, events: Int16(POLLIN), revents: 0)
        let unread = poll(&readiness, 1, 0)

        // -- Assert --
        #expect(runningFlags & O_NONBLOCK != 0)
        #expect(fcntl(descriptor, F_GETFL) == originalFlags)
        #expect(keys == [.a])
        #expect(unread == 1)
    }

    @Test("Stopping in a handler suppresses the rest of a byte batch", .timeLimit(.minutes(1)))
    func stopDuringDelivery() async throws {
        // -- Arrange --
        let pipe = Pipe()
        defer { try? pipe.fileHandleForReading.close() }
        try pipe.fileHandleForWriting.write(contentsOf: Data(repeating: 0x61, count: 5000))
        try pipe.fileHandleForWriting.close()
        let keyboard = DefaultKeyboardEventSource(
            inputSource: DefaultInputSource(fileDescriptor: .custom(pipe.fileHandleForReading.fileDescriptor)),
            runLoop: DefaultRunLoop()
        )
        var deliveries = 0
        keyboard.onKeyEvent = { [weak keyboard] _ in
            deliveries += 1
            keyboard?.stop()
        }

        // -- Act --
        try await keyboard.run()

        // -- Assert --
        #expect(deliveries == 1)
    }

    @Test("An idle keyboard source can be stopped without cancelling its caller", .timeLimit(.minutes(1)))
    func stopWhileIdle() async throws {
        // -- Arrange --
        let pipe = Pipe()
        defer {
            try? pipe.fileHandleForReading.close()
            try? pipe.fileHandleForWriting.close()
        }
        let keyboard = DefaultKeyboardEventSource(
            inputSource: DefaultInputSource(fileDescriptor: .custom(pipe.fileHandleForReading.fileDescriptor)),
            runLoop: DefaultRunLoop()
        )
        let (ready, continuation) = AsyncStream<Void>.makeStream()
        keyboard.onKeyEvent = { _ in
            continuation.yield(())
            continuation.finish()
        }
        try pipe.fileHandleForWriting.write(contentsOf: Data([0x61]))
        let task = Task { try await keyboard.run() }
        for await _ in ready {}

        // -- Act --
        keyboard.stop()
        try await task.value

        // -- Assert --
        #expect(!task.isCancelled)
    }
}

@MainActor
private final class SequencedInputSource: InputSource {
    let events: AsyncThrowingStream<[UInt8], Error>
    private let continuation: AsyncThrowingStream<[UInt8], Error>.Continuation

    init() {
        (events, continuation) = AsyncThrowingStream.makeStream()
    }

    func start() {}
    func send(_ bytes: [UInt8]) { continuation.yield(bytes) }
    func cancel() { continuation.finish() }
    func stop() async { cancel() }
}
