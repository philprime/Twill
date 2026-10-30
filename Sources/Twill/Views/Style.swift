/// Resolves a terminal style using the inherited foreground and control tint.
public protocol Style: Sendable {
    /// Returns a color and additional attributes without changing layout or interaction.
    func resolve(in context: StyleContext) -> ResolvedStyle
}
