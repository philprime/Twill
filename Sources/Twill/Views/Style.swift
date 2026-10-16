/// Resolves a terminal style to a color for cell presentation.
public protocol Style: Sendable {
    /// The terminal color resolved by this style.
    var color: Color { get }
}
