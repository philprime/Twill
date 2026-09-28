import Dispatch

#if TESTING
    @MainActor
    public protocol RunLoopTimerBackend: AnyObject {
        func schedule(deadline: DispatchTime, action: @escaping @Sendable () -> Void)
        func disarm()
        func stop()
    }

    extension DispatchRunLoopTimerBackend: RunLoopTimerBackend {}
#else
    typealias RunLoopTimerBackend = DispatchRunLoopTimerBackend
#endif

// Dispatch sources support thread-safe cancellation. The box guarantees cancellation
// even when a run loop is constructed but never entered on MainActor.
private final class DispatchTimerSourceBox: @unchecked Sendable {
    let source = DispatchSource.makeTimerSource()

    deinit {
        source.cancel()
    }
}

/// Bridges the earliest logical run-loop deadline to one Dispatch timer source.
@MainActor
final class DispatchRunLoopTimerBackend {
    private let sourceBox = DispatchTimerSourceBox()
    private var source: DispatchSourceTimer { sourceBox.source }
    private var isStopped = false

    init() {
        source.setEventHandler {}
        source.schedule(deadline: .distantFuture)
        source.activate()
    }

    func schedule(deadline: DispatchTime, action: @escaping @Sendable () -> Void) {
        guard !isStopped else { return }
        source.setEventHandler(handler: action)
        source.schedule(deadline: deadline)
    }

    func disarm() {
        guard !isStopped else { return }
        source.setEventHandler {}
        source.schedule(deadline: .distantFuture)
    }

    func stop() {
        guard !isStopped else { return }
        isStopped = true
        source.setEventHandler {}
        source.cancel()
    }
}
