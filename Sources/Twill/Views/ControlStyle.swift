/// Resolves state-aware control presentation, separately from color-only `Style`.
public protocol ControlStyle: Sendable {
    /// Produces immutable overrides for one presentation without performing output or interaction.
    func resolve(_ state: ControlState, in theme: Theme) -> ControlAppearance
}
