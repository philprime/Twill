/// Manually signaled work registered with a TUI run loop.
///
/// Signals carry readiness rather than payloads. Repeated signals coalesce until the
/// action begins, while a signal raised by the action schedules another delivery.
/// This model is only appropriate when one pending notification represents all current
/// work. Lossless inputs such as keyboard bytes require their own payload queue.
@MainActor
public final class RunLoopSource {
    let action: @MainActor () -> Void

    public init(action: @escaping @MainActor () -> Void) {
        self.action = action
    }
}
