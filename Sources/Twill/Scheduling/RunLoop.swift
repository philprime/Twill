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
        case timerWake(generation: UInt)
    }

    private struct SourceRegistration {
        let source: RunLoopSource
        let registration: RunLoopSourceRegistration
    }

    private struct TimerRegistration {
        let timer: Timer
        var deadline: DispatchTime
        let order: UInt
    }

    private let eventStream: AsyncStream<Event>
    private let eventContinuation: AsyncStream<Event>.Continuation
    private let timerBackend: RunLoopTimerBackend
    private let now: @MainActor () -> DispatchTime
    private var sourceIdentifiers: [ObjectIdentifier: UInt] = [:]
    private var sources: [UInt: SourceRegistration] = [:]
    private var nextRegistrationIdentifier: UInt = 0
    private var timers: [ObjectIdentifier: TimerRegistration] = [:]
    private var nextTimerOrder: UInt = 0
    private var timerWakeGeneration: UInt = 0
    private var armedTimerDeadline: DispatchTime?

    // Finishing an AsyncStream still drains buffered events. This flag prevents queued
    // callbacks from running after an action has requested shutdown.
    private var isStopped = false

    public convenience init() {
        self.init(timerBackend: DispatchRunLoopTimerBackend(), now: { .now() })
    }

    init(
        timerBackend: RunLoopTimerBackend,
        now: @escaping @MainActor () -> DispatchTime
    ) {
        self.timerBackend = timerBackend
        self.now = now
        (eventStream, eventContinuation) = AsyncStream.makeStream()
    }

    /// Registers a timer to start when the run loop processes the registration.
    public func add(_ timer: Timer) {
        eventContinuation.yield(.scheduleTimer(timer))
    }

    /// Permanently cancels a timer, including a registration still waiting in the queue.
    public func cancel(_ timer: Timer) {
        timer.isCancelled = true
        guard timers.removeValue(forKey: ObjectIdentifier(timer)) != nil else { return }
        scheduleNextTimerWake()
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
        timers.removeAll()
        armedTimerDeadline = nil
        timerBackend.stop()
        eventContinuation.finish()
    }

    /// Runs until stopped or its task is cancelled.
    public func run() async {
        defer { stop() }
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
            register(timer)
        case .timerWake(let generation):
            fireDueTimers(generation: generation)
        }
    }

    private func register(_ timer: Timer) {
        let identifier = ObjectIdentifier(timer)
        guard !timer.isCancelled, timers[identifier] == nil else { return }
        nextTimerOrder &+= 1
        timers[identifier] = TimerRegistration(
            timer: timer,
            deadline: timer.deadline ?? now() + timer.interval,
            order: nextTimerOrder
        )
        scheduleNextTimerWake()
    }

    private func fireDueTimers(generation: UInt) {
        guard generation == timerWakeGeneration else { return }
        armedTimerDeadline = nil
        let iterationDate = now()
        let dueTimers = timers.values
            .filter { $0.deadline <= iterationDate }
            .sorted {
                if $0.deadline == $1.deadline { return $0.order < $1.order }
                return $0.deadline < $1.deadline
            }

        for dueTimer in dueTimers {
            guard !isStopped else { return }
            let identifier = ObjectIdentifier(dueTimer.timer)
            guard var registration = timers[identifier], registration.order == dueTimer.order else { continue }
            let nextDeadline =
                registration.timer.repeats
                ? nextRepeatingDeadline(
                    after: registration.deadline,
                    interval: registration.timer.interval,
                    now: iterationDate
                ) : nil
            if let nextDeadline {
                registration.deadline = nextDeadline
                timers[identifier] = registration
            } else {
                timers.removeValue(forKey: identifier)
            }
            registration.timer.action()
        }

        scheduleNextTimerWake()
    }

    private func scheduleNextTimerWake() {
        guard !isStopped else { return }
        guard let nextDeadline = timers.values.map(\.deadline).min() else {
            guard armedTimerDeadline != nil else { return }
            armedTimerDeadline = nil
            timerWakeGeneration &+= 1
            timerBackend.disarm()
            return
        }
        guard nextDeadline != armedTimerDeadline else { return }

        armedTimerDeadline = nextDeadline
        timerWakeGeneration &+= 1
        let generation = timerWakeGeneration
        let continuation = eventContinuation
        timerBackend.schedule(deadline: nextDeadline) {
            continuation.yield(.timerWake(generation: generation))
        }
    }

    private func nextRepeatingDeadline(
        after deadline: DispatchTime,
        interval: DispatchTimeInterval,
        now: DispatchTime
    ) -> DispatchTime? {
        guard let intervalNanoseconds = interval.nanoseconds, intervalNanoseconds > 0 else { return nil }
        let elapsed = now.uptimeNanoseconds - deadline.uptimeNanoseconds
        let skippedIntervals = elapsed / intervalNanoseconds + 1
        let (advance, overflowed) = intervalNanoseconds.multipliedReportingOverflow(by: skippedIntervals)
        guard !overflowed else { return .distantFuture }
        let (uptime, additionOverflowed) = deadline.uptimeNanoseconds.addingReportingOverflow(advance)
        return additionOverflowed ? .distantFuture : DispatchTime(uptimeNanoseconds: uptime)
    }
}

extension DispatchTimeInterval {
    fileprivate var nanoseconds: UInt64? {
        switch self {
        case .seconds(let value):
            value > 0 ? UInt64(value) * 1_000_000_000 : nil
        case .milliseconds(let value):
            value > 0 ? UInt64(value) * 1_000_000 : nil
        case .microseconds(let value):
            value > 0 ? UInt64(value) * 1_000 : nil
        case .nanoseconds(let value):
            value > 0 ? UInt64(value) : nil
        case .never:
            nil
        @unknown default:
            nil
        }
    }
}
