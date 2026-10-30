/// A terminal color and additional text attributes produced by contextual style resolution.
public struct ResolvedStyle: Equatable, Sendable {
    /// The resolved color. Nil explicitly selects the terminal default.
    public let color: Color?
    /// Attributes contributed by the style independently of explicit view attributes.
    public let attributes: TextAttributes

    /// Creates a resolved style without changing layout or interaction.
    public init(color: Color?, attributes: TextAttributes = []) {
        self.color = color
        self.attributes = attributes
    }
}
