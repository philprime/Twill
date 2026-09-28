import Synchronization

/// A thread-safe signaling capability for one run-loop source registration.
///
/// The registration carries readiness only. Producers retain payloads in their own
/// synchronized storage before signaling the registration.
public final class RunLoopSourceRegistration: Sendable {
    private struct State {
        var readiness: UInt = 0
        var isPending = false
        var isActive = true
    }

    let identifier: UInt
    private let state = Mutex(State())
    private let wake: @Sendable (_ identifier: UInt, _ readiness: UInt) -> Void

    init(
        identifier: UInt,
        wake: @escaping @Sendable (_ identifier: UInt, _ readiness: UInt) -> Void
    ) {
        self.identifier = identifier
        self.wake = wake
    }

    /// Marks the source ready and wakes its run loop.
    ///
    /// Repeated signals coalesce until readiness is consumed or delivered.
    public func signal() {
        let readiness = state.withLock { state -> UInt? in
            guard state.isActive, !state.isPending else { return nil }
            state.readiness &+= 1
            state.isPending = true
            return state.readiness
        }
        if let readiness { wake(identifier, readiness) }
    }

    func consume() {
        state.withLock { state in
            guard state.isActive, state.isPending else { return }
            state.readiness &+= 1
            state.isPending = false
        }
    }

    func beginDelivery(readiness: UInt) -> Bool {
        state.withLock { state in
            guard state.isActive, state.isPending, state.readiness == readiness else { return false }
            state.isPending = false
            return true
        }
    }

    func deactivate() {
        state.withLock { state in
            guard state.isActive else { return }
            state.isActive = false
            state.readiness &+= 1
            state.isPending = false
        }
    }
}
