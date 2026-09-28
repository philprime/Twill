// Linux's Dispatch overlay lacks Sendable annotations for sources. Cancellation
// and isCancelled are thread-safe libdispatch operations on both platforms.
@preconcurrency import Dispatch
import Synchronization

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

#if TESTING
    @MainActor
    public protocol InputSource: AnyObject, Sendable {
        var events: AsyncThrowingStream<[UInt8], Error> { get }
        func start()
        func start(signaling registration: RunLoopSourceRegistration)
        func takeEvents(limit: Int) -> [InputSourceEvent]
        func cancel()
        func stop() async
    }

    extension InputSource {
        public func start(signaling registration: RunLoopSourceRegistration) { start() }
        public func takeEvents(limit: Int) -> [InputSourceEvent] { [] }
    }

    extension DefaultInputSource: InputSource {}
#else
    public typealias InputSource = DefaultInputSource
#endif

private final class PendingInputEvents: Sendable {
    private struct State {
        var events: [InputSourceEvent] = []
        var isAccepting = true
    }

    private let state = Mutex(State())

    func append(_ event: InputSourceEvent, terminal: Bool = false) -> Bool {
        state.withLock { state in
            guard state.isAccepting else { return false }
            state.events.append(event)
            if terminal { state.isAccepting = false }
            return true
        }
    }

    func take(limit: Int) -> (events: [InputSourceEvent], hasMore: Bool) {
        state.withLock { state in
            let count = min(max(0, limit), state.events.count)
            let events = Array(state.events.prefix(count))
            state.events.removeFirst(count)
            return (events, !state.events.isEmpty)
        }
    }

    func cancel() {
        state.withLock { state in
            state.isAccepting = false
            state.events.removeAll()
        }
    }
}

/// Drains a borrowed descriptor without interpreting its bytes or invoking UI callbacks.
@MainActor
public final class DefaultInputSource {
    private enum Delivery: Sendable {
        case stream(AsyncThrowingStream<[UInt8], Error>.Continuation)
        case source(PendingInputEvents, RunLoopSourceRegistration)
    }

    private nonisolated static let readBufferSize = 4096

    public let events: AsyncThrowingStream<[UInt8], Error>
    private let continuation: AsyncThrowingStream<[UInt8], Error>.Continuation
    private let fileDescriptor: FileDescriptor
    private let queue = DispatchQueue(label: "Twill.InputSource")
    private let pendingEvents = PendingInputEvents()
    private var registration: RunLoopSourceRegistration?
    private var source: DispatchSourceRead?
    private var originalFlags: Int32?

    /// The descriptor remains owned by the caller and must have no other reader.
    public init(fileDescriptor: FileDescriptor) {
        self.fileDescriptor = fileDescriptor
        (events, continuation) = AsyncThrowingStream.makeStream(bufferingPolicy: .unbounded)
    }

    public func start() {
        start(delivery: .stream(continuation))
    }

    public func start(signaling registration: RunLoopSourceRegistration) {
        self.registration = registration
        start(delivery: .source(pendingEvents, registration))
    }

    public func takeEvents(limit: Int) -> [InputSourceEvent] {
        let batch = pendingEvents.take(limit: limit)
        if batch.hasMore { registration?.signal() }
        return batch.events
    }

    private func start(delivery: Delivery) {
        let descriptor = fileDescriptor.rawValue
        let flags = fcntl(descriptor, F_GETFL)
        guard flags != -1, fcntl(descriptor, F_SETFL, flags | O_NONBLOCK) != -1 else {
            deliver(.failure(TerminalError.configureInput(errno: errno)), using: delivery)
            return
        }
        originalFlags = flags
        let source = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: queue)
        if case .stream(let continuation) = delivery {
            continuation.onTermination = { @Sendable _ in source.cancel() }
        }
        source.setEventHandler { @Sendable in
            var buffer = [UInt8](repeating: 0, count: Self.readBufferSize)
            while !source.isCancelled {
                let count = read(descriptor, &buffer, buffer.count)
                if count > 0 {
                    Self.deliver(.bytes(Array(buffer.prefix(count))), using: delivery)
                } else if count == 0 {
                    Self.deliver(.end, using: delivery)
                    source.cancel()
                    return
                } else if errno == EINTR {
                    continue
                } else {
                    if errno != EAGAIN && errno != EWOULDBLOCK {
                        Self.deliver(.failure(TerminalError.readInput(errno: errno)), using: delivery)
                        source.cancel()
                    }
                    return
                }
            }
        }
        self.source = source
        source.activate()
    }

    private nonisolated static func deliver(_ event: InputSourceEvent, using delivery: Delivery) {
        switch delivery {
        case .stream(let continuation):
            switch event {
            case .bytes(let bytes): continuation.yield(bytes)
            case .end: continuation.finish()
            case .failure(let error): continuation.finish(throwing: error)
            }
        case .source(let pendingEvents, let registration):
            let terminal: Bool
            switch event {
            case .bytes: terminal = false
            case .end, .failure: terminal = true
            }
            if pendingEvents.append(event, terminal: terminal) { registration.signal() }
        }
    }

    private func deliver(_ event: InputSourceEvent, using delivery: Delivery) {
        Self.deliver(event, using: delivery)
    }

    /// Requests cancellation without blocking. Await stop() before descriptor reuse.
    public func cancel() {
        registration = nil
        pendingEvents.cancel()
        source?.cancel()
        continuation.finish()
    }

    public func stop() async {
        cancel()
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
