import Dispatch

#if DEBUG
    @MainActor
    public protocol RunLoop: AnyObject {
        func add(_ timer: Timer)
        func run() async
    }

    extension DefaultRunLoop: RunLoop {}
#else
    public typealias RunLoop = DefaultRunLoop
#endif

/// Consumes events while remaining suspended between them.
///
/// Dispatch sources feed the async stream without coupling the runtime to
/// Foundation's `RunLoop`, on both macOS and Linux.
@MainActor
public final class DefaultRunLoop {
    private enum Event: Sendable {
        case scheduleTimer(Timer)
        case fireTimer(Timer)
    }

    private let eventStream: AsyncStream<Event>
    private let eventContinuation: AsyncStream<Event>.Continuation

    public init() {
        (eventStream, eventContinuation) = AsyncStream.makeStream()
    }

    /// Registers a timer to start when the run loop processes the registration.
    public func add(_ timer: Timer) {
        eventContinuation.yield(.scheduleTimer(timer))
    }

    /// Runs until its task is cancelled or the event stream is finished.
    public func run() async {
        var sources: [ObjectIdentifier: DispatchSourceTimer] = [:]
        defer {
            for source in sources.values {
                source.cancel()
            }
        }

        for await event in eventStream {
            guard !Task.isCancelled else { break }
            switch event {
            case .scheduleTimer(let timer):
                let identifier = ObjectIdentifier(timer)
                guard sources[identifier] == nil else { continue }
                let source = DispatchSource.makeTimerSource()
                source.schedule(
                    deadline: .now() + timer.interval,
                    repeating: timer.repeats ? timer.interval : .never
                )
                source.setEventHandler { @Sendable [eventContinuation] in
                    eventContinuation.yield(.fireTimer(timer))
                }
                sources[identifier] = source
                source.activate()
            case .fireTimer(let timer):
                let identifier = ObjectIdentifier(timer)
                guard sources[identifier] != nil else { continue }
                if !timer.repeats {
                    sources.removeValue(forKey: identifier)?.cancel()
                }
                timer.action()
            }
        }
    }
}
