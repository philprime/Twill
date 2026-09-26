#if TESTING
    import Twill

    /// Lets lifecycle tests observe restoration while an injected reader is still stopping.
    @MainActor
    final class TrackingTerminalSession: TerminalSession {
        let fileDescriptor = FileDescriptor.standardInput
        private(set) var isActive = false

        func start() throws { isActive = true }
        func restore() { isActive = false }
    }
#endif
