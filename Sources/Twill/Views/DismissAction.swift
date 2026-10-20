/// A callable action scoped to the currently mounted sheet content lifetime.
/// Retaining an action does not retain the sheet or dismiss a later presentation.
@MainActor
public struct DismissAction {
    private let action: @MainActor () -> Void

    init(_ action: @escaping @MainActor () -> Void) { self.action = action }

    /// Requests dismissal of this action's owning sheet, if it is still active.
    public func callAsFunction() { action() }
}
