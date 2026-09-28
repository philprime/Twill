import Dispatch

#if TESTING
    @MainActor
    public protocol RunLoop: AnyObject {
        func add(_ timer: Timer)
        func cancel(_ timer: Timer)
        @discardableResult func add(_ source: RunLoopSource) -> RunLoopSourceRegistration
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
        case sourceReady(registration: UInt, readiness: UInt)
        case scheduleTimer(Timer)
        case fireTimer(Timer)
    }

    private struct SourceRegistration {
        let source: RunLoopSource
        let registration: RunLoopSourceRegistration
    }

    private let eventStream: AsyncStream<Event>
    private let eventContinuation: AsyncStream<Event>.Continuation
    private var sourceIdentifiers: [ObjectIdentifier: UInt] = [:]
    private var sources: [UInt: SourceRegistration] = [:]
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

    /// Registers a source and returns a capability that can signal it from any executor.
    @discardableResult
    public func add(_ source: RunLoopSource) -> RunLoopSourceRegistration {
        let key = ObjectIdentifier(source)
        if let identifier = sourceIdentifiers[key], let existing = sources[identifier] {
            return existing.registration
        }

        nextRegistrationIdentifier &+= 1
        let identifier = nextRegistrationIdentifier
        let continuation = eventContinuation
        let registration = RunLoopSourceRegistration(identifier: identifier) { identifier, readiness in
            continuation.yield(.sourceReady(registration: identifier, readiness: readiness))
        }
        guard !isStopped else {
            registration.deactivate()
            return registration
        }
        sourceIdentifiers[key] = identifier
        sources[identifier] = SourceRegistration(source: source, registration: registration)
        return registration
    }

    /// Marks a registered source ready from the UI actor.
    public func signal(_ source: RunLoopSource) {
        registration(for: source)?.signal()
    }

    /// Consumes pending readiness without invoking its action.
    public func consume(_ source: RunLoopSource) {
        registration(for: source)?.consume()
    }

    /// Removes a source. The same source may be registered again as a new lifecycle.
    public func remove(_ source: RunLoopSource) {
        let key = ObjectIdentifier(source)
        guard let identifier = sourceIdentifiers.removeValue(forKey: key) else { return }
        sources.removeValue(forKey: identifier)?.registration.deactivate()
    }

    /// Finishes this single-use run loop after the current callback returns.
    public func stop() {
        guard !isStopped else { return }
        isStopped = true
        for source in sources.values {
            source.registration.deactivate()
        }
        sourceIdentifiers.removeAll()
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

    private func registration(for source: RunLoopSource) -> RunLoopSourceRegistration? {
        guard let identifier = sourceIdentifiers[ObjectIdentifier(source)] else { return nil }
        return sources[identifier]?.registration
    }

    private func dispatch(_ event: Event) {
        switch event {
        case .sourceReady(let identifier, let readiness):
            guard let registration = sources[identifier],
                registration.registration.beginDelivery(readiness: readiness)
            else { return }
            registration.source.action()
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
