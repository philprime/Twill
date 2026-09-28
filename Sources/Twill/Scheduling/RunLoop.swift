import Dispatch

#if TESTING
    @MainActor
    public protocol RunLoop: AnyObject {
        func add(_ timer: Timer)
        func cancel(_ timer: Timer)
        func add(_ source: RunLoopSource)
        func signal(_ source: RunLoopSource)
        func consume(_ source: RunLoopSource)
        func remove(_ source: RunLoopSource)
        func stop()
        func run() async
    }

    extension DefaultRunLoop: RunLoop {}
#else
    public typealias RunLoop = DefaultRunLoop
#endif

/// Delivers manually signaled work and timer actions while suspended between events.
///
/// The UI actor serializes these actions with keyboard handling. Input does not pass
/// through this queue: its application-owned task already resumes on the same actor.
/// This is deliberately not a global application event queue. Actor serialization does
/// not impose a FIFO policy across independently resumed input, viewport, and timer tasks.
@MainActor
public final class DefaultRunLoop {
    private enum Event: Sendable {
        case sourceReady(RunLoopSource, registration: UInt, readiness: UInt)
        case scheduleTimer(Timer)
        case fireTimer(Timer)
    }

    // Separate registration and readiness generations prevent queued notifications
    // from crossing removal, re-registration, consumption, or a later signal.
    private struct SourceRegistration {
        let source: RunLoopSource
        let identifier: UInt
        var readiness: UInt = 0
        var isPending = false
    }

    private let eventStream: AsyncStream<Event>
    private let eventContinuation: AsyncStream<Event>.Continuation
    private var sources: [ObjectIdentifier: SourceRegistration] = [:]
    private var nextRegistrationIdentifier: UInt = 0
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

    /// Permanently cancels a timer, including a registration still waiting in the queue.
    public func cancel(_ timer: Timer) {
        timer.isCancelled = true
        timers.removeValue(forKey: ObjectIdentifier(timer))?.cancel()
    }

    /// Registers a source. Adding an already registered source has no effect.
    public func add(_ source: RunLoopSource) {
        let key = ObjectIdentifier(source)
        guard !isStopped, sources[key] == nil else { return }
        nextRegistrationIdentifier &+= 1
        sources[key] = SourceRegistration(source: source, identifier: nextRegistrationIdentifier)
    }

    /// Marks a registered source ready and wakes the suspended consumer.
    public func signal(_ source: RunLoopSource) {
        let key = ObjectIdentifier(source)
        guard !isStopped, var registration = sources[key], !registration.isPending else { return }
        registration.readiness &+= 1
        registration.isPending = true
        sources[key] = registration
        eventContinuation.yield(
            .sourceReady(
                source, registration: registration.identifier, readiness: registration.readiness
            ))
    }

    /// Consumes pending readiness without invoking its action.
    public func consume(_ source: RunLoopSource) {
        let key = ObjectIdentifier(source)
        guard var registration = sources[key], registration.isPending else { return }
        registration.readiness &+= 1
        registration.isPending = false
        sources[key] = registration
    }

    /// Removes a source. The same source may be registered again as a new lifecycle.
    public func remove(_ source: RunLoopSource) {
        sources.removeValue(forKey: ObjectIdentifier(source))
    }

    /// Finishes this single-use run loop after the current callback returns.
    public func stop() {
        isStopped = true
        sources.removeAll()
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
        case .sourceReady(let source, let registrationIdentifier, let readiness):
            let key = ObjectIdentifier(source)
            guard var registration = sources[key],
                registration.identifier == registrationIdentifier,
                registration.readiness == readiness,
                registration.isPending
            else { return }
            // Clear readiness before the callback so signaling from the callback
            // schedules a distinct later delivery.
            registration.isPending = false
            sources[key] = registration
            source.action()
        case .scheduleTimer(let timer):
            let identifier = ObjectIdentifier(timer)
            guard !timer.isCancelled, timers[identifier] == nil else { return }
            let source = DispatchSource.makeTimerSource()
            source.schedule(
                deadline: timer.deadline ?? .now() + timer.interval,
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
