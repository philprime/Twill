import Dispatch

@MainActor
final class ControlledRunLoopClock {
    var now: DispatchTime

    init(now: DispatchTime) {
        self.now = now
    }
}
