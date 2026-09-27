#if TESTING
    import Testing
    @testable import Twill

    #if canImport(Darwin)
        import Darwin
    #else
        import Glibc
    #endif

    @Suite("Application viewport stream ownership")
    @MainActor
    struct ViewportOwnershipTests {
        @Test(
            "Viewport shutdown finishes before terminal restoration", .timeLimit(.minutes(1)), arguments: [false, true])
        func joinsViewport(cancel: Bool) async throws {
            // -- Arrange --
            let loop = DefaultRunLoop()
            let input = GatedInputSource()
            let viewport = GatedViewport()
            let session = TrackingTerminalSession()
            let application = Application(
                rootView: EmptyView(), runLoop: loop, terminalSession: session,
                keyboardEventSource: DefaultKeyboardEventSource(inputSource: input, runLoop: loop),
                terminalViewport: viewport
            )
            let (ready, continuation) = AsyncStream<Void>.makeStream()
            application.onKeyEvent = { _ in continuation.finish() }
            var returned = false
            let task = Task {
                try await application.run()
                returned = true
            }
            for await _ in ready {}

            // -- Act --
            if cancel { task.cancel() } else { application.stop() }
            for await _ in input.cleanupStarted {}
            input.allowCleanup()
            for await _ in viewport.cleanupStarted {}
            let activeDuringCleanup = session.isActive
            let returnedBeforeCleanup = returned
            viewport.allowCleanup()
            try await task.value

            // -- Assert --
            #expect(activeDuringCleanup)
            #expect(!returnedBeforeCleanup)
            #expect(returned)
            #expect(!session.isActive)
        }

        @Test("Viewport failures propagate after input cleanup", .timeLimit(.minutes(1)))
        func viewportFailure() async throws {
            // -- Arrange --
            let loop = DefaultRunLoop()
            let input = GatedInputSource()
            let viewport = RecordingTerminalViewport()
            let session = TrackingTerminalSession()
            let failure = TerminalError.readSize(errno: EIO)
            let application = Application(
                rootView: EmptyView(), runLoop: loop, terminalSession: session,
                keyboardEventSource: DefaultKeyboardEventSource(inputSource: input, runLoop: loop),
                terminalViewport: viewport
            )
            application.onKeyEvent = { _ in viewport.fail(failure) }
            var received: TerminalError?
            let task = Task {
                do { try await application.run() } catch { received = error as? TerminalError }
            }
            for await _ in input.cleanupStarted {}

            // -- Act --
            let activeDuringCleanup = session.isActive
            input.allowCleanup()
            await task.value

            // -- Assert --
            #expect(activeDuringCleanup)
            #expect(received == failure)
            #expect(viewport.isStopped)
            #expect(!session.isActive)
        }
    }

    @MainActor
    private final class GatedViewport: TerminalViewport {
        let events: AsyncThrowingStream<TerminalSize, Error>
        let cleanupStarted: AsyncStream<Void>
        private let continuation: AsyncThrowingStream<TerminalSize, Error>.Continuation
        private let cleanupContinuation: AsyncStream<Void>.Continuation
        private var completion: CheckedContinuation<Void, Never>?

        init() {
            (events, continuation) = AsyncThrowingStream.makeStream(bufferingPolicy: .bufferingNewest(1))
            (cleanupStarted, cleanupContinuation) = AsyncStream.makeStream()
        }

        func start() throws -> TerminalSize? { nil }
        func cancel() { continuation.finish() }
        func stop() async {
            cancel()
            await withCheckedContinuation { completion in
                self.completion = completion
                cleanupContinuation.finish()
            }
        }
        func allowCleanup() {
            completion?.resume()
            completion = nil
        }
    }
#endif
