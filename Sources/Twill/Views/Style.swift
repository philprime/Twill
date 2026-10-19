/// Resolves a terminal style to a color for cell presentation.
public protocol Style: Sendable {
    /// Resolves in the node's nearest palette. Nil explicitly selects the terminal default.
    func resolve(in theme: Theme) -> Color?
}
