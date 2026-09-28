@testable import Twill

@MainActor
final class RecordingRunLoop: RunLoop {
    private(set) var timers: [Twill.Timer] = []
    private(set) var cancelled: [Twill.Timer] = []
    private(set) var sources: [RunLoopSource] = []
    private(set) var signalled: [RunLoopSource] = []
    private(set) var consumed: [RunLoopSource] = []
    private(set) var removed: [RunLoopSource] = []
    var onAdd: ((Twill.Timer) -> Void)?

    func add(_ timer: Twill.Timer) {
        timers.append(timer)
        onAdd?(timer)
    }
    func cancel(_ timer: Twill.Timer) {
        timer.isCancelled = true
        cancelled.append(timer)
    }
    @discardableResult
    func add(_ source: RunLoopSource) -> RunLoopSourceRegistration {
        sources.append(source)
        return RunLoopSourceRegistration(identifier: UInt(sources.count)) { _, _ in }
    }
    func signal(_ source: RunLoopSource) {
        signalled.append(source)
    }
    func consume(_ source: RunLoopSource) {
        consumed.append(source)
    }
    func remove(_ source: RunLoopSource) {
        removed.append(source)
        sources.removeAll { $0 === source }
    }
    func stop() {}
    func run() async {}
}
