/// Optional presentation overrides applied after ordinary inherited styles.
/// Nil inherits; a supplied color style may resolve to terminal default, and an
/// empty attribute set explicitly clears inherited text flags.
public struct ControlAppearance: Sendable {
    /// The foreground override, resolved in the nearest theme.
    public let foreground: (any Style)?
    /// The background override, including the control's drawn regions.
    public let background: (any Style)?
    /// Replacement text attributes, or nil to retain inherited flags.
    public let attributes: TextAttributes?
    /// Reverse-video emphasis without changing logical focus.
    public let focusEffect: ControlFocusEffect

    /// Creates presentation overrides without changing content, layout, or actions.
    public init(
        foreground: (any Style)? = nil, background: (any Style)? = nil, attributes: TextAttributes? = nil,
        focusEffect: ControlFocusEffect = .automatic
    ) {
        self.foreground = foreground
        self.background = background
        self.attributes = attributes
        self.focusEffect = focusEffect
    }
}
