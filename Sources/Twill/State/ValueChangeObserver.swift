/// Type erasure belongs to the mounted runtime; each observer keeps its values typed.
@MainActor
protocol AnyValueChangeObserver: AnyObject {
    var isQueued: Bool { get set }
    var isMounted: Bool { get }
    var hasPendingChange: Bool { get }
    func deliver()
    func cancel()
}

@MainActor
final class ValueChangeObserver<Value: Equatable>: AnyValueChangeObserver {
    var isQueued = false
    private(set) var isMounted = false
    private var baseline: Value?
    private var latest: Value?
    private var initialPending = false
    private var action: (@MainActor (Value, Value) -> Void)?

    func prepare(value: Value, initial: Bool, action: @escaping @MainActor (Value, Value) -> Void) {
        if baseline == nil {
            baseline = value
            initialPending = initial
        }
        latest = value
        self.action = action
        isMounted = true
    }

    var hasPendingChange: Bool {
        guard let baseline, let latest else { return false }
        return initialPending || baseline != latest
    }

    func deliver() {
        isQueued = false
        guard isMounted, hasPendingChange, let baseline, let latest else { return }
        let old = initialPending ? latest : baseline
        initialPending = false
        self.baseline = latest
        action?(old, latest)
    }

    func cancel() {
        isMounted = false
        isQueued = false
        baseline = nil
        latest = nil
        action = nil
    }
}
