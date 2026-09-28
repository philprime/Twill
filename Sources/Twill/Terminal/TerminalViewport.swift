// Linux's Dispatch overlay lacks Sendable annotations for thread-safe source cancellation.
@preconcurrency import Dispatch
import Synchronization

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

#if TESTING
    @MainActor
    public protocol TerminalViewport: AnyObject, Sendable {
        func start(signaling registration: RunLoopSourceRegistration) throws -> TerminalSize?
        func consume() throws -> TerminalSize?
        func cancel()
        func stop() async
    }

    extension DefaultTerminalViewport: TerminalViewport {}
#else
    public typealias TerminalViewport = DefaultTerminalViewport
#endif

private final class PendingViewportResult: Sendable {
    private struct State {
        var result: Result<TerminalSize, any Error>?
        var isAccepting = true
    }

    private let state = Mutex(State())

    func store(_ result: Result<TerminalSize, any Error>, terminal: Bool = false) -> Bool {
        state.withLock { state in
            guard state.isAccepting else { return false }
            state.result = result
            if terminal { state.isAccepting = false }
            return true
        }
    }

    func take() -> Result<TerminalSize, any Error>? {
        state.withLock { state in
            defer { state.result = nil }
            return state.result
        }
    }

    func cancel() {
        state.withLock { state in
            state.isAccepting = false
            state.result = nil
        }
    }
}

/// Observes a borrowed output descriptor and buffers its newest unread viewport result.
@MainActor
public final class DefaultTerminalViewport {
    private let fileDescriptor: FileDescriptor
    private let queue = DispatchQueue(label: "Twill.TerminalViewport")
    private let pendingResult = PendingViewportResult()
    private var source: DispatchSourceSignal?

    public init(fileDescriptor: FileDescriptor = .standardOutput) {
        self.fileDescriptor = fileDescriptor
    }

    public func size() throws -> TerminalSize? {
        try Self.readSize(fileDescriptor.rawValue)
    }

    /// Returns the initial proposal before the first frame. Pipes stay unscheduled.
    public func start(signaling registration: RunLoopSourceRegistration) throws -> TerminalSize? {
        let descriptor = fileDescriptor.rawValue
        let initial = try Self.readSize(descriptor)
        guard initial != nil || isatty(descriptor) != 0 else { return nil }

        // SIGWINCH's default disposition is ignore. No process-global SIG_IGN override
        // is needed. All descriptor reads are serialized with stop()'s queue barrier.
        let source = DispatchSource.makeSignalSource(signal: SIGWINCH, queue: queue)
        let pendingResult = pendingResult
        // Dispatch invokes this as an ordinary queue callback, not as a raw POSIX signal
        // handler, so reading the descriptor and signaling readiness are safe here.
        let readDimensions: @Sendable () -> Void = {
            guard !source.isCancelled else { return }
            do {
                if let size = try Self.readSize(descriptor), pendingResult.store(.success(size)) {
                    registration.signal()
                }
            } catch {
                if pendingResult.store(.failure(error), terminal: true) {
                    registration.signal()
                }
                source.cancel()
            }
        }
        // Re-read after registration to cover a resize between the initial read and
        // installation of the signal observer. Duplicate sizes are ignored by the host.
        source.setRegistrationHandler(handler: readDimensions)
        source.setEventHandler(handler: readDimensions)
        self.source = source
        source.activate()
        return initial
    }

    /// Consumes the newest unread size or throws the terminal observation failure.
    public func consume() throws -> TerminalSize? {
        guard let result = pendingResult.take() else { return nil }
        return try result.get()
    }

    public func cancel() {
        pendingResult.cancel()
        source?.cancel()
    }

    /// Join an in-flight ioctl before the caller may release its borrowed descriptor.
    public func stop() async {
        cancel()
        await withCheckedContinuation { completion in
            queue.async { @Sendable in completion.resume() }
        }
        source?.setEventHandler(handler: nil)
        source?.setRegistrationHandler(handler: nil)
        source = nil
    }

    private nonisolated static func readSize(_ descriptor: Int32) throws -> TerminalSize? {
        var dimensions = winsize()
        guard ioctl(descriptor, UInt(TIOCGWINSZ), &dimensions) == 0 else {
            let code = errno
            if code == ENOTTY { return nil }
            throw TerminalError.readSize(errno: code)
        }
        guard dimensions.ws_col > 0, dimensions.ws_row > 0 else { return nil }
        return TerminalSize(columns: Int(dimensions.ws_col), rows: Int(dimensions.ws_row))
    }
}
