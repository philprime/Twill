/// How a picker's explicitly valued choices are arranged.
public enum PickerPresentation: Equatable, Sendable {
    /// Shows marked options beside the control label, adjusted with Left/Right.
    case inline
    /// Shows only the effective value beside the label, adjusted with Left/Right.
    case compact
    /// Shows marked rows below the label; Up/Down also change selection.
    case vertical
}
