import Dispatch

/// A timer registered with a TUI run loop. Its action runs on the UI actor.
@MainActor
public final class Timer {
    let interval: DispatchTimeInterval
    let repeats: Bool
    let action: @MainActor () -> Void

    public init(
        interval: DispatchTimeInterval,
        repeats: Bool = false,
        action: @escaping @MainActor () -> Void
    ) {
        self.interval = interval
        self.repeats = repeats
        self.action = action
    }
}
