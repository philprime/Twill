@testable import Twill

@MainActor
final class RecordingRunLoop: RunLoop {
    private(set) var timers: [Twill.Timer] = []
    private(set) var cancelled: [Twill.Timer] = []
    var onAdd: ((Twill.Timer) -> Void)?

    func add(_ timer: Twill.Timer) {
        timers.append(timer)
        onAdd?(timer)
    }
    func cancel(_ timer: Twill.Timer) {
        timer.isCancelled = true
        cancelled.append(timer)
    }
    func stop() {}
    func run() async {}
}
