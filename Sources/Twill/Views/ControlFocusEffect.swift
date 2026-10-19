/// Reverse-video presentation, independent of logical focus and the terminal caret.
public enum ControlFocusEffect: Sendable {
    /// Retains the runtime's ordinary focus and selected-row highlighting.
    case automatic
    /// Suppresses reverse video without changing focus or key routing.
    case none
    /// Requests reverse video even when the control is not focused.
    case reversed
}
