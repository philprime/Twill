/// Keeps callback mutation independent of the scheduler's source and timer registries.
@MainActor
final class RunLoopObservations {
    private var registrations: [(identifier: UInt, observer: RunLoopObserver)] = []
    private var nextIdentifier: UInt = 0

    func add(_ observer: RunLoopObserver) {
        guard !registrations.contains(where: { $0.observer === observer }) else { return }
        nextIdentifier &+= 1
        registrations.append((nextIdentifier, observer))
        registrations.sort {
            if $0.observer.order == $1.observer.order { return $0.identifier < $1.identifier }
            return $0.observer.order < $1.observer.order
        }
    }

    func remove(_ observer: RunLoopObserver) {
        registrations.removeAll { $0.observer === observer }
    }

    func removeAll() {
        registrations.removeAll()
    }

    func notify(_ activity: RunLoopActivity, while isActive: () -> Bool) {
        // A snapshot defers additions. Generation checks suppress removed and re-added entries.
        let snapshot = registrations
        for registration in snapshot {
            guard isActive() else { break }
            guard registration.observer.activities.contains(activity),
                registrations.contains(where: { $0.identifier == registration.identifier })
            else { continue }
            if !registration.observer.repeats { remove(registration.observer) }
            registration.observer.action(activity)
        }
    }
}
