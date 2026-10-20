/// Mounted typed identity bookkeeping must not invalidate presentation.
@MainActor
final class TaskIdentity<ID: Equatable> {
    private var value: ID?

    func update(_ next: ID) -> Bool {
        defer { value = next }
        guard let value else { return true }
        return value != next
    }
}
