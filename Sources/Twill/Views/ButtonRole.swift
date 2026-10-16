/// The semantic purpose of an action, including modal cancellation and destructive operations.
public enum ButtonRole: Sendable {
    /// Identifies the cancellation action in a dialog.
    case cancel
    /// Identifies an action that performs a destructive operation.
    case destructive
}
