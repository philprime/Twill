#if TESTING
    import Twill

    @MainActor
    final class RecordingTerminalOutput: TerminalOutput {
        private(set) var writes: [String] = []
        var failure: Error?

        func write(_ text: String) throws {
            MainActor.assertIsolated()
            if let failure { throw failure }
            writes.append(text)
        }
    }
#endif
