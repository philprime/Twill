import Dispatch

@testable import Twill

@MainActor
final class RecordingRunLoopTimerBackend: RunLoopTimerBackend {
    let scheduledDeadlines: AsyncStream<DispatchTime>
    private let deadlineContinuation: AsyncStream<DispatchTime>.Continuation
    private var action: (@Sendable () -> Void)?
    private(set) var disarmCount = 0
    private(set) var stopCount = 0

    init() {
        (scheduledDeadlines, deadlineContinuation) = AsyncStream.makeStream()
    }

    func schedule(deadline: DispatchTime, action: @escaping @Sendable () -> Void) {
        self.action = action
        deadlineContinuation.yield(deadline)
    }

    func disarm() {
        action = nil
        disarmCount += 1
    }

    func stop() {
        action = nil
        stopCount += 1
        deadlineContinuation.finish()
    }

    func fire() {
        action?()
    }
}
