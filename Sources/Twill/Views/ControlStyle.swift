/// Resolves state-aware control presentation, separately from contextual `Style`.
public protocol ControlStyle: Sendable {
    /// Produces immutable overrides for one presentation without performing output or interaction.
    func resolve(_ state: ControlState, in context: StyleContext) -> ControlAppearance
}
