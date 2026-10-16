import Dispatch

/// A timer registered with a TUI run loop. Its action runs on the UI actor.
@MainActor
public final class Timer {
    let interval: DispatchTimeInterval
    let repeats: Bool
    let action: @MainActor () -> Void
    let deadline: DispatchTime?
    var isCancelled = false

    /// Creates a logical timer whose first deadline is measured when the run loop processes registration.
    /// Repeating timers preserve their deadline phase and skip missed periods.
    public init(
        interval: DispatchTimeInterval,
        repeats: Bool = false,
        action: @escaping @MainActor () -> Void
    ) {
        self.interval = interval
        self.repeats = repeats
        self.action = action
        deadline = nil
    }

    // Presentation deadlines are computed before registration reaches the event queue.
    init(deadline: DispatchTime, action: @escaping @MainActor () -> Void) {
        self.deadline = deadline
        interval = .never
        repeats = false
        self.action = action
    }
}
