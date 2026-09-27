#if TESTING
    import Testing
    import Twill

    #if canImport(Darwin)
        import Darwin
    #else
        import Glibc
    #endif

    @Suite("Application task ownership")
    @MainActor
    struct ApplicationOwnershipTests {
        @Test(
            "Shutdown awaits reader cleanup before restoring terminal state",
            .timeLimit(.minutes(1)), arguments: [false, true])
        func awaitsSourceCleanup(cancel: Bool) async throws {
            // -- Arrange --
            let runLoop = DefaultRunLoop()
            let input = GatedInputSource()
            let session = TrackingTerminalSession()
            let keyboard = DefaultKeyboardEventSource(inputSource: input, runLoop: runLoop)
            let application = Application(
                rootView: EmptyView(), runLoop: runLoop, terminalSession: session, keyboardEventSource: keyboard
            )
            let (ready, continuation) = AsyncStream<Void>.makeStream()
            application.onKeyEvent = { _ in
                continuation.yield(())
                continuation.finish()
            }
            var returned = false
            let task = Task {
                try await application.run()
                returned = true
            }
            for await _ in ready {}

            // -- Act --
            if cancel { task.cancel() } else { application.stop() }
            for await _ in input.cleanupStarted {}
            let returnedBeforeCleanup = returned
            let activeBeforeCleanup = session.isActive
            input.allowCleanup()
            try await task.value

            // -- Assert --
            #expect(!returnedBeforeCleanup)
            #expect(activeBeforeCleanup)
            #expect(returned)
            #expect(!session.isActive)
        }

        @Test(
            "Input failure survives timer shutdown and restores the terminal after cleanup",
            .timeLimit(.minutes(1)), arguments: [false, true])
        func failureCleanup(stopDuringCleanup: Bool) async throws {
            // -- Arrange --
            let failure = TerminalError.readInput(errno: EIO)
            let input = GatedInputSource(failure: failure)
            let runLoop = DefaultRunLoop()
            let session = TrackingTerminalSession()
            let keyboard = DefaultKeyboardEventSource(inputSource: input, runLoop: runLoop)
            let application = Application(
                rootView: EmptyView(), runLoop: runLoop, terminalSession: session, keyboardEventSource: keyboard
            )
            var receivedError: TerminalError?
            let task = Task {
                do { try await application.run() } catch { receivedError = error as? TerminalError }
            }
            for await _ in input.cleanupStarted {}
            let activeBeforeCleanup = session.isActive

            // -- Act --
            if stopDuringCleanup {
                // Hold the failure until the timer task has finished and Application
                // has requested its sibling's shutdown. No scheduler timing assumptions.
                input.onCancelDuringCleanup = { [weak input] in input?.allowCleanup() }
                runLoop.stop()
            } else {
                input.allowCleanup()
            }
            await task.value
            // A finished run loop cannot accept more work after the sibling failed.
            var timerFired = false
            runLoop.add(Twill.Timer(interval: .milliseconds(0)) { timerFired = true })
            await runLoop.run()

            // -- Assert --
            #expect(activeBeforeCleanup)
            #expect(!session.isActive)
            #expect(receivedError == failure)
            #expect(!timerFired)
        }

        private enum PresentationFailure: Error { case output }

        @Test("A scheduled output failure awaits input cleanup before restoring the terminal", .timeLimit(.minutes(1)))
        func renderingFailureCleanup() async throws {
            // -- Arrange --
            let input = GatedInputSource()
            let runLoop = DefaultRunLoop()
            let session = TrackingTerminalSession()
            let output = RecordingTerminalOutput()
            let failure = PresentationFailure.output
            let keyboard = DefaultKeyboardEventSource(inputSource: input, runLoop: runLoop)
            var frames = 0
            let root = TimelineView(.periodic(from: .now, by: 0.05)) { _ -> Text in
                frames += 1
                return Text("Clock \(frames)")
            }
            let application = Application(
                rootView: root,
                runLoop: runLoop, terminalSession: session, keyboardEventSource: keyboard, terminalOutput: output
            )
            runLoop.add(Twill.Timer(interval: .milliseconds(1)) { output.failure = failure })
            var receivedError: PresentationFailure?
            let task = Task {
                do { try await application.run() } catch { receivedError = error as? PresentationFailure }
            }
            for await _ in input.cleanupStarted {}
            let activeBeforeCleanup = session.isActive

            // -- Act --
            input.allowCleanup()
            await task.value

            // -- Assert --
            #expect(activeBeforeCleanup)
            #expect(receivedError == failure)
            #expect(!session.isActive)
            #expect(output.writes == ["\r\u{1B}[2KClock 1"])
        }

        @Test("EOF finishes the application without a key handler", .timeLimit(.minutes(1)))
        func endsOnEOF() async throws {
            // -- Arrange --
            let input = GatedInputSource(finishesAfterBytes: true)
            let runLoop = DefaultRunLoop()
            let session = TrackingTerminalSession()
            let keyboard = DefaultKeyboardEventSource(inputSource: input, runLoop: runLoop)
            let application = Application(
                rootView: EmptyView(), runLoop: runLoop, terminalSession: session, keyboardEventSource: keyboard
            )
            let task = Task { try await application.run() }
            for await _ in input.cleanupStarted {}
            let activeBeforeCleanup = session.isActive

            // -- Act --
            input.allowCleanup()
            try await task.value

            // -- Assert --
            #expect(activeBeforeCleanup)
            #expect(!session.isActive)
        }
    }
#endif
