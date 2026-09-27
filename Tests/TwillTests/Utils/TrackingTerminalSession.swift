#if TESTING
    import Twill

    /// Lets lifecycle tests observe restoration while an injected reader is still stopping.
    @MainActor
    final class TrackingTerminalSession: TerminalSession {
        let fileDescriptor = FileDescriptor.standardInput
        let output: TerminalOutput
        private(set) var isActive = false

        init(output: TerminalOutput = DefaultTerminalOutput()) { self.output = output }

        func start() throws { isActive = true }
        func beginPresentation() throws {}
        func restore() { isActive = false }
    }
#endif
