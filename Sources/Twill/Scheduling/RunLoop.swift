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
    /// The run loop used by a Twill application.
    public typealias RunLoop = DefaultRunLoop
#endif

/// Coordinates manually signaled sources and logical timer deadlines for a Twill application.
///
/// A run loop suspends when no source is ready and no timer is due. Source and timer actions
/// execute serially on `MainActor`, making them safe entry points into application and mounted
/// view state. The run loop is event-driven and does not poll or use Foundation's `RunLoop`.
///
/// Sources communicate readiness rather than payloads. A producer must store its data before
/// signaling its ``RunLoopSourceRegistration``. Repeated signals may coalesce, so payload owners
/// that require lossless delivery must retain every unread value themselves.
///
/// Timers are logical registrations multiplexed onto one physical timer backend. Actions due in
/// the same iteration are ordered by deadline and registration order. Serialization on
/// `MainActor` does not establish a global FIFO order among independent event producers.
///
/// Each instance is single-use. After ``stop()`` or cancellation of ``run()``, registrations are
/// inactive and the instance cannot be restarted.
@MainActor
public final class DefaultRunLoop {
    /// Events are wake-up notices rather than payloads. Sources retain their own data,
    /// and logical timers remain in `timers` until this queue processes their deadline.
    private enum Event: Sendable {
        /// A registered source transitioned from idle to ready. `readiness` identifies
        /// that transition so a notification made stale by consume, removal, or a later
        /// signal cannot deliver the source action.
        case sourceReady(registration: UInt, readiness: UInt)

        /// Defers timer registration onto the run loop so interval-based deadlines are
        /// anchored consistently with other run-loop work.
        case scheduleTimer(Timer)

        /// The single physical timer fired. The generation identifies the particular
        /// arm operation because Dispatch may still invoke a superseded callback.
        case timerWake(generation: UInt)
    }

    /// Associates source work with the thread-safe capability for one registration
    /// lifecycle. Re-registering a removed source creates a different identifier.
    private struct SourceRegistration {
        let source: RunLoopSource
        let registration: RunLoopSourceRegistration
    }

    /// State retained for a logical timer. `order` provides deterministic ordering when
    /// multiple timers have the same deadline.
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

    // Each physical arm or disarm invalidates callbacks from every earlier arm.
    private var timerWakeGeneration: UInt = 0

    // Mirrors the physical backend's intended state and avoids rearming an unchanged
    // earliest deadline. It is cleared before processing a valid wake-up.
    private var armedTimerDeadline: DispatchTime?

    // Finishing an AsyncStream still drains buffered events. This flag prevents queued
    // callbacks from running after an action has requested shutdown.
    private var isStopped = false

    /// Creates a run loop backed by a monotonic Dispatch timer.
    ///
    /// The run loop does not begin delivering work until ``run()`` is called. Sources may be
    /// registered and timers may be queued before then.
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

    /// Registers a logical timer with the run loop.
    ///
    /// Registration is queued with other run-loop events. For an interval-based timer, its first
    /// deadline is measured from when that registration is processed, not when this method is
    /// called. Adding a timer that is already registered has no effect.
    ///
    /// A timer that was cancelled, or one added after the run loop stopped, is not delivered.
    ///
    /// - Parameter timer: The timer whose action should run when its deadline becomes due.
    public func add(_ timer: Timer) {
        eventContinuation.yield(.scheduleTimer(timer))
    }

    /// Permanently cancels a logical timer.
    ///
    /// Cancellation suppresses a queued registration, a pending deadline, and all future
    /// repetitions. A cancelled timer instance cannot be registered again. Calling this method
    /// more than once has no additional effect.
    ///
    /// - Parameter timer: The timer to cancel.
    public func cancel(_ timer: Timer) {
        timer.isCancelled = true
        guard timers.removeValue(forKey: ObjectIdentifier(timer)) != nil else { return }
        scheduleNextTimerWake()
    }

    /// Registers a manually signaled source.
    ///
    /// Registering the same source repeatedly during one registration lifecycle returns the same
    /// capability. After the source is removed, adding it again creates a new lifecycle and a new
    /// capability. If the run loop has already stopped, the returned capability is inactive.
    ///
    /// The returned registration is `Sendable` and may be signaled from any executor. Producers
    /// must update their synchronized payload storage before signaling it.
    ///
    /// - Parameter source: The source whose action should run when it becomes ready.
    /// - Returns: A thread-safe signaling capability for this registration lifecycle.
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

    /// Marks a registered source as ready from `MainActor`.
    ///
    /// This is a convenience for actor-isolated clients. Off-actor producers should retain and
    /// signal the ``RunLoopSourceRegistration`` returned when registering the source. Signals
    /// coalesce while readiness is pending. An unregistered source is ignored.
    ///
    /// - Parameter source: The registered source to mark ready.
    public func signal(_ source: RunLoopSource) {
        registration(for: source)?.signal()
    }

    /// Clears a source's pending readiness without invoking its action.
    ///
    /// Use this when another path has already handled the work represented by a pending signal.
    /// Any queued notification for the consumed readiness becomes stale and is ignored. A later
    /// signal can make the source ready again. An unregistered source is ignored.
    ///
    /// - Parameter source: The source whose pending readiness should be consumed.
    public func consume(_ source: RunLoopSource) {
        registration(for: source)?.consume()
    }

    /// Removes a source and ends its current registration lifecycle.
    ///
    /// Removal suppresses queued readiness and makes the corresponding
    /// ``RunLoopSourceRegistration`` inactive. The same source may subsequently be added as a new
    /// lifecycle. Removing an unregistered source has no effect.
    ///
    /// - Parameter source: The source to remove.
    public func remove(_ source: RunLoopSource) {
        let key = ObjectIdentifier(source)
        guard let identifier = sourceIdentifiers.removeValue(forKey: key) else { return }
        sources.removeValue(forKey: identifier)?.registration.deactivate()
    }

    /// Permanently stops the run loop.
    ///
    /// Stopping deactivates source registrations, removes logical timers, stops the physical timer
    /// backend, and suppresses buffered callbacks. If called from an action, that action finishes
    /// before ``run()`` returns. This method is idempotent.
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

    /// Delivers source and timer actions until the run loop stops or the calling task is cancelled.
    ///
    /// The method suspends without polling while no work is ready. On return it performs the same
    /// shutdown as ``stop()``, including when cancellation ends the loop. A stopped run loop cannot
    /// be run again.
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
            // `beginDelivery` atomically validates this readiness generation and clears
            // pending readiness before the action. A signal raised by the action therefore
            // queues a distinct future delivery rather than being lost or delivered twice.
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
        // Rescheduling cannot reliably retract a callback already submitted by Dispatch.
        // Only the callback from the currently armed generation may inspect due timers.
        guard generation == timerWakeGeneration else { return }
        armedTimerDeadline = nil

        // Use one clock reading for the entire iteration so all timers are judged against
        // the same boundary even when earlier actions take time to execute.
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

            // `dueTimers` is a snapshot. An earlier callback may cancel another timer or
            // otherwise replace registry state, so its live registration must be checked.
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

            // Update registry state before invoking user work. The action may cancel this
            // timer, register other timers, or stop the run loop reentrantly.
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

        // Capture the arm generation rather than trusting backend cancellation. A callback
        // already enqueued for an older deadline will become a harmless stale event.
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
        // Advance from the scheduled deadline, not from delivery time, to preserve phase.
        // Moving directly past `now` skips missed periods instead of emitting catch-up work.
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
