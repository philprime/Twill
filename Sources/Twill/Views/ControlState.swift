/// A presentation snapshot. Styling does not change interaction eligibility or focus.
public struct ControlState: Equatable, Sendable {
    /// The family of the nearest control owner.
    public let kind: ControlKind
    /// Whether keyboard focus belongs to this control, not a nested control.
    public let isFocused: Bool
    /// Effective inherited availability, including command availability.
    public let isEnabled: Bool
    /// Toggle-on, selected option, expanded header, or enclosing selected-row state.
    public let isSelected: Bool
}
