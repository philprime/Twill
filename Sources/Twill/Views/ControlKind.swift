/// The control family whose presentation is being resolved.
public enum ControlKind: CaseIterable, Sendable {
    /// An action button.
    case button
    /// A Boolean checkbox.
    case toggle
    /// A choice group or one of its options.
    case picker
    /// A floating-point adjustment control.
    case slider
    /// An integer adjustment control.
    case stepper
    /// Determinate or indeterminate progress.
    case progress
    /// A disclosure header, excluding its expanded content.
    case disclosure
}
