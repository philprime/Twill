// Linux's Dispatch overlay lacks Sendable annotations for thread-safe source cancellation.
@preconcurrency import Dispatch

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

#if TESTING
    @MainActor
    public protocol TerminalViewport: AnyObject, Sendable {
        var events: AsyncThrowingStream<TerminalSize, Error> { get }
        func start() throws -> TerminalSize?
        func cancel()
        func stop() async
    }

    extension DefaultTerminalViewport: TerminalViewport {}
#else
    public typealias TerminalViewport = DefaultTerminalViewport
#endif

/// A single-use viewport stream over a borrowed output descriptor. Unlike input
/// bytes, intermediate resize events may be coalesced: only the newest size matters.
@MainActor
public final class DefaultTerminalViewport {
    public let events: AsyncThrowingStream<TerminalSize, Error>
    private let continuation: AsyncThrowingStream<TerminalSize, Error>.Continuation
    private let fileDescriptor: FileDescriptor
    private let queue = DispatchQueue(label: "Twill.TerminalViewport")
    private var source: DispatchSourceSignal?

    public init(fileDescriptor: FileDescriptor = .standardOutput) {
        self.fileDescriptor = fileDescriptor
        (events, continuation) = AsyncThrowingStream.makeStream(bufferingPolicy: .bufferingNewest(1))
    }

    public func size() throws -> TerminalSize? {
        try Self.readSize(fileDescriptor.rawValue)
    }

    /// Returns the initial proposal before the first frame. Pipes stay unscheduled,
    /// but their stream stays open until cancellation rather than ending the app.
    public func start() throws -> TerminalSize? {
        let descriptor = fileDescriptor.rawValue
        let initial = try Self.readSize(descriptor)
        guard initial != nil || isatty(descriptor) != 0 else { return nil }

        // SIGWINCH's default disposition is ignore. No process-global SIG_IGN override
        // is needed. All descriptor reads are serialized with stop()'s queue barrier.
        let source = DispatchSource.makeSignalSource(signal: SIGWINCH, queue: queue)
        // Dispatch invokes this as an ordinary queue callback, not as a raw POSIX signal
        // handler, so reading the descriptor and yielding to the stream are safe here.
        let readDimensions: @Sendable () -> Void = { [continuation] in
            guard !source.isCancelled else { return }
            do {
                if let size = try Self.readSize(descriptor) { continuation.yield(size) }
            } catch {
                continuation.finish(throwing: error)
            }
        }
        // Re-read after registration to cover a resize between the initial read and
        // installation of the signal observer. Duplicate sizes are ignored by the host.
        source.setRegistrationHandler(handler: readDimensions)
        source.setEventHandler(handler: readDimensions)
        continuation.onTermination = { @Sendable _ in source.cancel() }
        self.source = source
        source.activate()
        return initial
    }

    public func cancel() {
        source?.cancel()
        continuation.finish()
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
