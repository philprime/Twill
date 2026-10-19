/// Whether an editing control accepts user changes to its bound value.
public enum TextEditingMode: Hashable, Sendable {
    /// Accept text insertion and deletion.
    case editable
    /// Retain focus, caret navigation and normal submit routing without editing
    /// the binding. Application-owned value updates remain visible.
    case readOnly
}
