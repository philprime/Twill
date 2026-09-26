// Linux's Dispatch overlay lacks Sendable annotations for sources. Cancellation
// and isCancelled are thread-safe libdispatch operations on both platforms.
@preconcurrency import Dispatch

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

#if DEBUG
    /// A run-loop collaborator. Delivery can originate off-actor, but dispatch runs on the UI actor.
    @MainActor
    public protocol InputSource: AnyObject, Sendable {
        func start(deliver: @escaping @Sendable (InputEvent) -> Void)
        func dispatch(_ event: InputEvent)
        func stop()
    }

    extension DefaultInputSource: InputSource {}
#else
    public typealias InputSource = DefaultInputSource
#endif

/// Drains a borrowed descriptor on a Dispatch queue without interpreting its bytes.
/// The run loop owns activation and shutdown so callbacks share the timer executor.
@MainActor
public final class DefaultInputSource {
    private nonisolated static let readBufferSize = 4096

    private let fileDescriptor: FileDescriptor
    private let action: @MainActor (InputEvent) -> Void
    private let queue = DispatchQueue(label: "Twill.InputSource")
    private var source: DispatchSourceRead?
    private var originalFlags: Int32?

    /// The descriptor remains owned by the caller and must have no other reader.
    public init(fileDescriptor: FileDescriptor, action: @escaping @MainActor (InputEvent) -> Void) {
        self.fileDescriptor = fileDescriptor
        self.action = action
    }

    public func start(deliver: @escaping @Sendable (InputEvent) -> Void) {
        let descriptor = fileDescriptor.rawValue
        // Readiness is only a notification, not a promise that another read will succeed.
        // Nonblocking mode lets us drain a burst without parking the Dispatch worker.
        let flags = fcntl(descriptor, F_GETFL)
        guard flags != -1, fcntl(descriptor, F_SETFL, flags | O_NONBLOCK) != -1 else {
            deliver(.failure(.configureInput(errno: errno)))
            return
        }
        originalFlags = flags
        let source = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: queue)
        // Dispatch invokes this on its worker queue. Explicit Sendable prevents Swift
        // from inheriting MainActor isolation from start() and trapping at runtime.
        source.setEventHandler { @Sendable in
            var buffer = [UInt8](repeating: 0, count: Self.readBufferSize)
            while !source.isCancelled {
                let count = read(descriptor, &buffer, buffer.count)
                if count > 0 {
                    deliver(.bytes(Array(buffer.prefix(count))))
                } else if count == 0 {
                    source.cancel()
                    deliver(.endOfFile)
                    return
                } else if errno == EINTR {
                    continue
                } else {
                    if errno != EAGAIN && errno != EWOULDBLOCK {
                        let code = errno
                        source.cancel()
                        deliver(.failure(.readInput(errno: code)))
                    }
                    return
                }
            }
        }
        self.source = source
        source.activate()
    }

    public func dispatch(_ event: InputEvent) {
        action(event)
    }

    public func stop() {
        source?.cancel()
        // Finish any in-flight reads before restoring the descriptor's blocking mode.
        queue.sync {}
        source?.setEventHandler(handler: nil)
        source = nil
        if let originalFlags {
            _ = fcntl(fileDescriptor.rawValue, F_SETFL, originalFlags)
            self.originalFlags = nil
        }
    }
}
