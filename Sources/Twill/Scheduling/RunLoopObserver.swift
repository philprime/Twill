/// A synchronous observer of Twill run-loop phases on `MainActor`.
///
/// Observers do not schedule work or wake an idle loop. To measure active processing,
/// bracket work with `afterWaiting` and `beforeWaiting`, closing any remaining interval
/// at `exit`. Detecting an ongoing block requires a separate off-actor watchdog because
/// observer callbacks share the executor with the work being measured.
@MainActor
public final class RunLoopObserver {
    let activities: Set<RunLoopActivity>
    let repeats: Bool
    let order: Int
    let action: @MainActor (RunLoopActivity) -> Void

    /// Creates an observer, retained by each run loop until removal, one-shot delivery, or exit.
    ///
    /// - Parameters:
    ///   - activities: Phases to observe. By default all phases are observed.
    ///   - repeats: Whether to remain registered after the first matching phase.
    ///   - order: Lower values run first. Equal values preserve registration order.
    ///   - action: Synchronous work to perform at each selected phase. Keep it short because
    ///     its execution contributes to run-loop latency.
    public init(
        activities: Set<RunLoopActivity> = Set(RunLoopActivity.allCases),
        repeats: Bool = true,
        order: Int = 0,
        action: @escaping @MainActor (RunLoopActivity) -> Void
    ) {
        self.activities = activities
        self.repeats = repeats
        self.order = order
        self.action = action
    }
}
