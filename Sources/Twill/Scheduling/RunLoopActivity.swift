/// Observable boundaries in Twill's event-processing lifecycle.
public enum RunLoopActivity: Sendable, Hashable, CaseIterable {
    /// The single-use run begins, before fetching its first event.
    case entry
    /// Immediately before requesting the next event, which may already be buffered.
    case beforeWaiting
    /// An event was received, before dispatching it.
    case afterWaiting
    /// A ready source is about to run.
    case beforeSources
    /// A valid timer wake is about to deliver its due timers.
    case beforeTimers
    /// Event processing has ended, including shutdown and cancellation.
    case exit
}
