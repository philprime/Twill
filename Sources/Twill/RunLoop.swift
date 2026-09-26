import Dispatch

#if TESTING
    @MainActor
    public protocol RunLoop: AnyObject {
        func add(_ timer: Timer)
        func stop()
        func run() async
    }

    extension DefaultRunLoop: RunLoop {}
#else
    public typealias RunLoop = DefaultRunLoop
#endif

/// Schedules timer actions while remaining suspended between events.
///
/// The UI actor serializes these actions with keyboard handling. Input does not pass
/// through this queue: its application-owned task already resumes on the same actor.
@MainActor
public final class DefaultRunLoop {
    private enum Event: Sendable {
        case scheduleTimer(Timer)
        case fireTimer(Timer)
    }

    private let eventStream: AsyncStream<Event>
    private let eventContinuation: AsyncStream<Event>.Continuation
    private var timers: [ObjectIdentifier: DispatchSourceTimer] = [:]

    // Finishing an AsyncStream still drains buffered events. This flag prevents queued
    // callbacks from running after an action has requested shutdown.
    private var isStopped = false

    public init() {
        (eventStream, eventContinuation) = AsyncStream.makeStream()
    }

    /// Registers a timer to start when the run loop processes the registration.
    public func add(_ timer: Timer) {
        eventContinuation.yield(.scheduleTimer(timer))
    }

    /// Finishes this single-use run loop after the current callback returns.
    public func stop() {
        isStopped = true
        eventContinuation.finish()
    }

    /// Runs until stopped or its task is cancelled.
    public func run() async {
        defer {
            stop()
            for source in timers.values {
                source.cancel()
            }
            timers.removeAll()
        }
        for await event in eventStream {
            guard !Task.isCancelled else { break }
            // Discard buffered registrations without dispatching so a stopped loop
            // releases timer callbacks and any owners they captured.
            guard !isStopped else { continue }
            dispatch(event)
        }
    }

    private func dispatch(_ event: Event) {
        switch event {
        case .scheduleTimer(let timer):
            let identifier = ObjectIdentifier(timer)
            guard timers[identifier] == nil else { return }
            let source = DispatchSource.makeTimerSource()
            source.schedule(
                deadline: .now() + timer.interval,
                repeating: timer.repeats ? timer.interval : .never
            )
            source.setEventHandler { @Sendable [eventContinuation] in
                eventContinuation.yield(.fireTimer(timer))
            }
            timers[identifier] = source
            source.activate()
        case .fireTimer(let timer):
            let identifier = ObjectIdentifier(timer)
            guard timers[identifier] != nil else { return }
            if !timer.repeats {
                timers.removeValue(forKey: identifier)?.cancel()
            }
            timer.action()
        }
    }
}
