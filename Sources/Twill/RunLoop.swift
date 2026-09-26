import Dispatch

#if DEBUG
    @MainActor
    public protocol RunLoop: AnyObject {
        func add(_ timer: Timer)
        func add(_ source: InputSource)
        func stop()
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
        case scheduleInput(InputSource)
        case input(InputSource, InputEvent)
    }

    private let eventStream: AsyncStream<Event>
    private let eventContinuation: AsyncStream<Event>.Continuation
    private var timers: [ObjectIdentifier: DispatchSourceTimer] = [:]
    private var inputs: [ObjectIdentifier: InputSource] = [:]

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

    public func add(_ source: InputSource) {
        eventContinuation.yield(.scheduleInput(source))
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
            for input in inputs.values {
                input.stop()
            }
            inputs.removeAll()
            for source in timers.values {
                source.cancel()
            }
            timers.removeAll()
        }

        // Dispatch callbacks only enqueue Sendable payloads. Consuming them here keeps
        // source actions and timer actions serialized without blocking the UI actor when idle.
        for await event in eventStream {
            guard !Task.isCancelled else { break }
            // finish() preserves buffered elements. Discard them without dispatching
            // so a stopped loop does not retain callbacks and their captured owners.
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
        case .scheduleInput(let input):
            let identifier = ObjectIdentifier(input)
            guard inputs[identifier] == nil else { return }
            inputs[identifier] = input
            input.start { @Sendable [eventContinuation] event in
                eventContinuation.yield(.input(input, event))
            }
        case .input(let input, let event):
            input.dispatch(event)
        }
    }
}
