// Linux's Dispatch overlay lacks Sendable annotations for sources. Cancellation
// and isCancelled are thread-safe libdispatch operations on both platforms.
@preconcurrency import Dispatch

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

#if TESTING
    /// A single-consumer byte stream with explicit resource ownership.
    @MainActor
    public protocol InputSource: AnyObject, Sendable {
        var events: AsyncThrowingStream<[UInt8], Error> { get }
        func start()
        func cancel()
        func stop() async
    }

    extension DefaultInputSource: InputSource {}
#else
    public typealias InputSource = DefaultInputSource
#endif

/// Drains a borrowed descriptor without interpreting its bytes or invoking UI callbacks.
///
/// Each source is single-use and has one stream consumer. EOF completes iteration and
/// input errors are thrown. Cancellation stops reads, but the owner must still await
/// stop() before closing the descriptor or restoring terminal modes and flags.
@MainActor
public final class DefaultInputSource {
    private nonisolated static let readBufferSize = 4096

    public let events: AsyncThrowingStream<[UInt8], Error>
    private let continuation: AsyncThrowingStream<[UInt8], Error>.Continuation
    private let fileDescriptor: FileDescriptor
    private let queue = DispatchQueue(label: "Twill.InputSource")
    private var source: DispatchSourceRead?
    private var originalFlags: Int32?

    /// The descriptor remains owned by the caller and must have no other reader.
    public init(fileDescriptor: FileDescriptor) {
        self.fileDescriptor = fileDescriptor
        // Dropping a chunk can corrupt UTF-8 or an escape sequence. This bridge is
        // lossless, not backpressured, and the runtime must continuously consume it.
        (events, continuation) = AsyncThrowingStream.makeStream(bufferingPolicy: .unbounded)
    }

    public func start() {
        let descriptor = fileDescriptor.rawValue
        // Readiness is only a notification, not a promise that another read will succeed.
        // Nonblocking mode lets us drain a burst without parking the Dispatch worker.
        let flags = fcntl(descriptor, F_GETFL)
        guard flags != -1, fcntl(descriptor, F_SETFL, flags | O_NONBLOCK) != -1 else {
            continuation.finish(throwing: TerminalError.configureInput(errno: errno))
            return
        }
        originalFlags = flags
        let source = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: queue)
        // Stream cancellation can happen off-actor. Cancel only the thread-safe
        // Dispatch source here; stop() owns the awaited flag restoration.
        continuation.onTermination = { @Sendable _ in source.cancel() }
        // Dispatch invokes this on its worker queue. Explicit Sendable prevents Swift
        // from inheriting MainActor isolation from start() and trapping at runtime.
        source.setEventHandler { @Sendable [continuation] in
            var buffer = [UInt8](repeating: 0, count: Self.readBufferSize)
            while !source.isCancelled {
                let count = read(descriptor, &buffer, buffer.count)
                if count > 0 {
                    if case .terminated = continuation.yield(Array(buffer.prefix(count))) { return }
                } else if count == 0 {
                    continuation.finish()
                    return
                } else if errno == EINTR {
                    continue
                } else {
                    if errno != EAGAIN && errno != EWOULDBLOCK {
                        continuation.finish(throwing: TerminalError.readInput(errno: errno))
                    }
                    return
                }
            }
        }
        self.source = source
        source.activate()
    }

    /// Requests cancellation without blocking or spawning a task. Await stop() before
    /// reusing the descriptor, because a Dispatch read may already be in flight.
    public func cancel() {
        source?.cancel()
        continuation.finish()
    }

    public func stop() async {
        cancel()
        // A read already in progress must finish before flags can change. The serial
        // queue barrier suspends rather than blocks the UI actor. Checked continuations
        // still wait when the caller is cancelled, so cancellation cannot skip cleanup.
        await withCheckedContinuation { completion in
            queue.async { @Sendable in completion.resume() }
        }
        source?.setEventHandler(handler: nil)
        source = nil
        if let originalFlags {
            _ = fcntl(fileDescriptor.rawValue, F_SETFL, originalFlags)
            self.originalFlags = nil
        }
    }
}
