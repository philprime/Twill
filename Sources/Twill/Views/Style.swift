/// Resolves a terminal style to a color for cell presentation.
public protocol Style: Sendable {
    var color: Color { get }
}
